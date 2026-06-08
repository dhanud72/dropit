import 'package:flutter/services.dart';

class DownloadChannel {
  static const _channel = MethodChannel('com.dropit/downloader');
  static const _progressChannel = EventChannel('com.dropit/progress');

  static Stream<Map<String, dynamic>>? _progressStream;

  static Stream<Map<String, dynamic>> get progressStream {
    _progressStream ??= _progressChannel
        .receiveBroadcastStream()
        .map((event) => Map<String, dynamic>.from(event as Map));
    return _progressStream!;
  }

  static Future<void> extractYtdlp() async {
    await _channel.invokeMethod('extractYtdlp');
  }

  static Future<String> getYtdlpVersion() async {
    final version = await _channel.invokeMethod<String>('getYtdlpVersion');
    return version ?? 'unknown';
  }

  static Future<String> downloadMedia({
    required String downloadId,
    required String url,
    required String platform,
    required String quality,
    required String outputPath,
    bool isPlaylist = false,
  }) async {
    final result = await _channel.invokeMethod<String>('downloadMedia', {
      'downloadId': downloadId,
      'url': url,
      'platform': platform,
      'quality': quality,
      'outputPath': outputPath,
      'isPlaylist': isPlaylist,
    });
    return result ?? '';
  }

  static Future<void> cancelDownload(String downloadId) async {
    await _channel.invokeMethod('cancelDownload', {'downloadId': downloadId});
  }

  static Future<String> fetchTitle(String url, String platform) async {
    final result = await _channel.invokeMethod<String>('fetchTitle', {
      'url': url,
      'platform': platform,
    });
    return result ?? '';
  }

  static Future<String> fetchThumbnail(String url, String platform) async {
    final result = await _channel.invokeMethod<String>('fetchThumbnail', {
      'url': url,
      'platform': platform,
    });
    return result ?? '';
  }

  static Future<void> openFile(String path) async {
    await _channel.invokeMethod('openFile', {'path': path});
  }
}
