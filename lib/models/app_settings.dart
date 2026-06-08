import 'download_item.dart';

class AppSettings {
  bool autoDownloadOnShare;
  bool youtubeMp3Mode;
  MediaQuality defaultQuality;
  Map<Platform, MediaQuality> platformQualities;
  String customSavePath;
  bool showConfirmationSheet;

  AppSettings({
    this.autoDownloadOnShare = false,
    this.youtubeMp3Mode = false,
    this.defaultQuality = MediaQuality.q720p,
    Map<Platform, MediaQuality>? platformQualities,
    this.customSavePath = '',
    this.showConfirmationSheet = true,
  }) : platformQualities = platformQualities ?? {};

  Map<String, dynamic> toJson() => {
        'autoDownloadOnShare': autoDownloadOnShare,
        'youtubeMp3Mode': youtubeMp3Mode,
        'defaultQuality': defaultQuality.name,
        'platformQualities':
            platformQualities.map((k, v) => MapEntry(k.name, v.name)),
        'customSavePath': customSavePath,
        'showConfirmationSheet': showConfirmationSheet,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        autoDownloadOnShare: json['autoDownloadOnShare'] ?? false,
        youtubeMp3Mode: json['youtubeMp3Mode'] ?? false,
        defaultQuality: MediaQuality.values.firstWhere(
            (q) => q.name == json['defaultQuality'],
            orElse: () => MediaQuality.q720p),
        platformQualities: (json['platformQualities'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(
                      Platform.values.firstWhere((p) => p.name == k,
                          orElse: () => Platform.unknown),
                      MediaQuality.values.firstWhere((q) => q.name == v,
                          orElse: () => MediaQuality.q720p),
                    )) ??
            {},
        customSavePath: json['customSavePath'] ?? '',
        showConfirmationSheet: json['showConfirmationSheet'] ?? true,
      );
}
