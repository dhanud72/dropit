import 'package:flutter/material.dart';

enum DownloadStatus { queued, downloading, done, failed, cancelled }

enum Platform { youtube, instagram, pinterest, threads, jiosaavn, spotify, unknown }

enum MediaQuality { audio, q720p, q1080p }

class DownloadItem {
  final String id;
  final String url;
  final Platform platform;
  String title;
  String? thumbnailUrl;
  DownloadStatus status;
  double progress;
  String? outputPath;
  String? errorMessage;
  final DateTime createdAt;
  MediaQuality quality;
  int retryCount;

  DownloadItem({
    required this.id,
    required this.url,
    required this.platform,
    this.title = '',
    this.thumbnailUrl,
    this.status = DownloadStatus.queued,
    this.progress = 0.0,
    this.outputPath,
    this.errorMessage,
    DateTime? createdAt,
    this.quality = MediaQuality.q720p,
    this.retryCount = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  Color get platformColor {
    switch (platform) {
      case Platform.youtube:
        return const Color(0xFFFF0000);
      case Platform.instagram:
        return const Color(0xFFE1306C);
      case Platform.pinterest:
        return const Color(0xFFE60023);
      case Platform.threads:
        return const Color(0xFF000000);
      case Platform.jiosaavn:
        return const Color(0xFF2BC5B4);
      case Platform.spotify:
        return const Color(0xFF1DB954);
      case Platform.unknown:
        return const Color(0xFF888888);
    }
  }

  String get platformName {
    switch (platform) {
      case Platform.youtube:
        return 'YouTube';
      case Platform.instagram:
        return 'Instagram';
      case Platform.pinterest:
        return 'Pinterest';
      case Platform.threads:
        return 'Threads';
      case Platform.jiosaavn:
        return 'JioSaavn';
      case Platform.spotify:
        return 'Spotify';
      case Platform.unknown:
        return 'Unknown';
    }
  }

  String get platformIcon {
    switch (platform) {
      case Platform.youtube:
        return '▶';
      case Platform.instagram:
        return '📸';
      case Platform.pinterest:
        return '📌';
      case Platform.threads:
        return '🧵';
      case Platform.jiosaavn:
        return '🎵';
      case Platform.spotify:
        return '🎧';
      case Platform.unknown:
        return '🔗';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'platform': platform.name,
        'title': title,
        'thumbnailUrl': thumbnailUrl,
        'status': status.name,
        'progress': progress,
        'outputPath': outputPath,
        'errorMessage': errorMessage,
        'createdAt': createdAt.toIso8601String(),
        'quality': quality.name,
        'retryCount': retryCount,
      };

  factory DownloadItem.fromJson(Map<String, dynamic> json) => DownloadItem(
        id: json['id'],
        url: json['url'],
        platform: Platform.values.firstWhere((p) => p.name == json['platform'],
            orElse: () => Platform.unknown),
        title: json['title'] ?? '',
        thumbnailUrl: json['thumbnailUrl'],
        status: DownloadStatus.values.firstWhere(
            (s) => s.name == json['status'],
            orElse: () => DownloadStatus.failed),
        progress: (json['progress'] ?? 0.0).toDouble(),
        outputPath: json['outputPath'],
        errorMessage: json['errorMessage'],
        createdAt: DateTime.parse(json['createdAt']),
        quality: MediaQuality.values.firstWhere(
            (q) => q.name == json['quality'],
            orElse: () => MediaQuality.q720p),
        retryCount: json['retryCount'] ?? 0,
      );
}
