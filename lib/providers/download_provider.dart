import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/download_item.dart';
import '../models/app_settings.dart';
import '../services/download_channel.dart';
import '../services/notification_service.dart';
import '../utils/platform_detector.dart';

class DownloadProvider extends ChangeNotifier {
  final List<DownloadItem> _items = [];
  AppSettings _settings = AppSettings();
  StreamSubscription? _progressSub;
  bool _ytdlpReady = false;
  final _ytdlpReadyCompleter = Completer<void>();
  final _uuid = const Uuid();

  List<DownloadItem> get items => List.unmodifiable(_items);
  AppSettings get settings => _settings;
  bool get ytdlpReady => _ytdlpReady;

  List<DownloadItem> get activeDownloads => _items
      .where((i) =>
          i.status == DownloadStatus.downloading ||
          i.status == DownloadStatus.queued)
      .toList();

  List<DownloadItem> get completedDownloads => _items
      .where((i) =>
          i.status == DownloadStatus.done ||
          i.status == DownloadStatus.failed ||
          i.status == DownloadStatus.cancelled)
      .toList();

  Future<void> initialize() async {
    await NotificationService.init();
    await _loadSettings();
    await _loadHistory();
    await _setupYtdlp();
    _listenProgress();
  }

  Future<void> _setupYtdlp() async {
    debugPrint('[DownloadProvider] _setupYtdlp() — calling extractYtdlp()');
    try {
      await DownloadChannel.extractYtdlp();
      _ytdlpReady = true;
      debugPrint('[DownloadProvider] extractYtdlp() SUCCESS — ytdlpReady=true');
      notifyListeners();
    } catch (e) {
      debugPrint('[DownloadProvider] extractYtdlp() FAILED: $e');
    } finally {
      if (!_ytdlpReadyCompleter.isCompleted) {
        _ytdlpReadyCompleter.complete();
        debugPrint('[DownloadProvider] _ytdlpReadyCompleter completed (ytdlpReady=$_ytdlpReady)');
      }
    }
  }

  void _listenProgress() {
    debugPrint('[DownloadProvider] _listenProgress() — subscribing to EventChannel');
    _progressSub = DownloadChannel.progressStream.listen((event) {
      debugPrint('[DownloadProvider] progress event: $event');
      final id = event['downloadId'] as String?;
      if (id == null) return;
      final item = _items.firstWhere((i) => i.id == id,
          orElse: () => DownloadItem(
              id: '', url: '', platform: Platform.unknown));
      if (item.id.isEmpty) return;

      final status = event['status'] as String?;
      final progress = (event['progress'] as num?)?.toDouble();
      final title = event['title'] as String?;
      final outputPath = event['outputPath'] as String?;
      final error = event['error'] as String?;

      if (title != null && title.isNotEmpty) item.title = title;
      if (progress != null) item.progress = progress;
      if (outputPath != null) item.outputPath = outputPath;
      if (error != null) item.errorMessage = error;

      if (status == 'done') {
        item.status = DownloadStatus.done;
        item.progress = 1.0;
        NotificationService.showComplete(item.id, item.title);
      } else if (status == 'failed') {
        item.status = DownloadStatus.failed;
        NotificationService.showFailed(item.id, item.title);
      } else if (status == 'downloading') {
        item.status = DownloadStatus.downloading;
        NotificationService.showProgress(
            item.id, item.title, (item.progress * 100).toInt());
      }

      notifyListeners();
      _saveHistory();
    });
  }

  Future<String> _getOutputDir(Platform platform) async {
    final subfolder = PlatformDetector.getOutputFolder(platform);
    if (_settings.customSavePath.isNotEmpty) {
      return '${_settings.customSavePath}/DropIt/$subfolder';
    }
    // Derive the public Downloads directory from the external storage path.
    // getExternalStorageDirectory() returns something like:
    //   /storage/emulated/0/Android/data/com.dropit.dropit/files
    // The public Downloads folder is at /storage/emulated/0/Downloads/
    // We use the path up to (but not including) the "Android" segment.
    try {
      final dir = await getExternalStorageDirectory();
      if (dir != null) {
        final androidIdx = dir.path.indexOf('/Android/');
        if (androidIdx != -1) {
          final base = dir.path.substring(0, androidIdx);
          return '$base/Downloads/DropIt/$subfolder';
        }
      }
    } catch (_) {}
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/DropIt/$subfolder';
  }

  Future<DownloadItem> addDownload(String url, {MediaQuality? selectedQuality}) async {
    final platform = PlatformDetector.detect(url);
    debugPrint('[DownloadProvider] addDownload url=$url  platform=${platform.name}');
    final quality = selectedQuality ??
        _settings.platformQualities[platform] ??
        (_settings.youtubeMp3Mode && platform == Platform.youtube
            ? MediaQuality.audio
            : _settings.defaultQuality);
    debugPrint('[DownloadProvider] addDownload quality=${quality.name}  ytdlpReady=$_ytdlpReady');
    final item = DownloadItem(
      id: _uuid.v4(),
      url: url,
      platform: platform,
      title: url,
      quality: quality,
      status: DownloadStatus.queued,
    );
    _items.insert(0, item);
    notifyListeners();

    _fetchMetadata(item);
    _startDownload(item);
    return item;
  }

  Future<void> _fetchMetadata(DownloadItem item) async {
    try {
      final title =
          await DownloadChannel.fetchTitle(item.url, item.platform.name);
      if (title.isNotEmpty) {
        item.title = title;
        notifyListeners();
      }
      final thumb =
          await DownloadChannel.fetchThumbnail(item.url, item.platform.name);
      if (thumb.isNotEmpty) {
        item.thumbnailUrl = thumb;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _startDownload(DownloadItem item) async {
    debugPrint('[DownloadProvider] _startDownload id=${item.id} — awaiting ytdlp ready');
    await _ytdlpReadyCompleter.future;
    debugPrint('[DownloadProvider] _startDownload ytdlp ready, computing outputPath');
    final outputPath = await _getOutputDir(item.platform);
    debugPrint('[DownloadProvider] _startDownload outputPath=$outputPath');
    item.status = DownloadStatus.downloading;
    notifyListeners();
    final isPlaylist = PlatformDetector.isPlaylist(item.url);
    try {
      debugPrint('[DownloadProvider] calling downloadMedia id=${item.id} url=${item.url} isPlaylist=$isPlaylist');
      await DownloadChannel.downloadMedia(
        downloadId: item.id,
        url: item.url,
        platform: item.platform.name,
        quality: item.quality.name,
        outputPath: outputPath,
        isPlaylist: isPlaylist,
      );
      debugPrint('[DownloadProvider] downloadMedia returned for id=${item.id}');
    } catch (e) {
      debugPrint('[DownloadProvider] downloadMedia threw for id=${item.id}: $e');
      item.status = DownloadStatus.failed;
      item.errorMessage = e.toString();
      notifyListeners();
      _saveHistory();
    }
  }

  Future<void> retryDownload(String id) async {
    final item = _items.firstWhere((i) => i.id == id,
        orElse: () => DownloadItem(id: '', url: '', platform: Platform.unknown));
    if (item.id.isEmpty) return;
    if (item.retryCount >= 3) return;
    item.retryCount++;
    item.status = DownloadStatus.queued;
    item.progress = 0;
    item.errorMessage = null;
    notifyListeners();
    _startDownload(item);
  }

  Future<void> cancelDownload(String id) async {
    final item = _items.firstWhere((i) => i.id == id,
        orElse: () => DownloadItem(id: '', url: '', platform: Platform.unknown));
    if (item.id.isEmpty) return;
    item.status = DownloadStatus.cancelled;
    await DownloadChannel.cancelDownload(id);
    await NotificationService.cancel(id);
    notifyListeners();
    _saveHistory();
  }

  void removeItem(String id) {
    _items.removeWhere((i) => i.id == id);
    notifyListeners();
    _saveHistory();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('settings');
    if (json != null) {
      _settings = AppSettings.fromJson(jsonDecode(json));
    }
  }

  Future<void> saveSettings(AppSettings settings) async {
    _settings = settings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('settings', jsonEncode(settings.toJson()));
    notifyListeners();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('history');
    if (json != null) {
      final list = jsonDecode(json) as List;
      _items.addAll(list.map((e) => DownloadItem.fromJson(e)));
      // Reset stuck downloading/queued items to failed
      for (final item in _items) {
        if (item.status == DownloadStatus.downloading ||
            item.status == DownloadStatus.queued) {
          item.status = DownloadStatus.failed;
          item.errorMessage = 'Interrupted by app restart';
        }
      }
    }
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'history', jsonEncode(_items.map((e) => e.toJson()).toList()));
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    super.dispose();
  }
}
