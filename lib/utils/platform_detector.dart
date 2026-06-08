import '../models/download_item.dart';

class PlatformDetector {
  static Platform detect(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('youtube.com') || lower.contains('youtu.be')) {
      return Platform.youtube;
    }
    if (lower.contains('instagram.com')) return Platform.instagram;
    if (lower.contains('pinterest.com') || lower.contains('pin.it')) {
      return Platform.pinterest;
    }
    if (lower.contains('threads.net')) return Platform.threads;
    if (lower.contains('jiosaavn.com') || lower.contains('saavn.com')) {
      return Platform.jiosaavn;
    }
    if (lower.contains('spotify.com') || lower.contains('open.spotify.com')) {
      return Platform.spotify;
    }
    return Platform.unknown;
  }

  static bool isPlaylist(String url) {
    final lower = url.toLowerCase();

    // YouTube: playlist?list= or list= without a specific video
    if (lower.contains('youtube.com') || lower.contains('youtu.be')) {
      return lower.contains('playlist?list=') ||
          (lower.contains('list=') && !lower.contains('watch?v=') && !lower.contains('&v='));
    }

    // Instagram: profile or reels tab — NOT a single post (/p/) or single reel (/reel/)
    if (lower.contains('instagram.com')) {
      return !lower.contains('/p/') && !lower.contains('/reel/');
    }

    // JioSaavn: playlist/album/featured — NOT a single song
    if (lower.contains('jiosaavn.com') || lower.contains('saavn.com')) {
      return !lower.contains('/song/');
    }

    // Spotify: playlist or album — NOT a single track
    if (lower.contains('spotify.com')) {
      return lower.contains('/playlist/') || lower.contains('/album/');
    }

    return false;
  }

  static String getOutputFolder(Platform platform) {
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
      case Platform.spotify:
        return 'Music';
      case Platform.unknown:
        return 'Other';
    }
  }
}
