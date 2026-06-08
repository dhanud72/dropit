import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/download_item.dart';
import '../providers/download_provider.dart';
import '../utils/platform_detector.dart';
import '../utils/neu_theme.dart';

class ShareBottomSheet extends StatefulWidget {
  final String url;
  const ShareBottomSheet({super.key, required this.url});

  @override
  State<ShareBottomSheet> createState() => _ShareBottomSheetState();
}

class _ShareBottomSheetState extends State<ShareBottomSheet> {
  late Platform _platform;
  late MediaQuality _quality;
  late bool _isPlaylist;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _platform = PlatformDetector.detect(widget.url);
    _isPlaylist = PlatformDetector.isPlaylist(widget.url);
    final prov = context.read<DownloadProvider>();
    _quality = _isPlaylist
        ? (_platform == Platform.instagram
            ? MediaQuality.q720p
            : MediaQuality.audio)
        : (prov.settings.platformQualities[_platform] ??
            (prov.settings.youtubeMp3Mode && _platform == Platform.youtube
                ? MediaQuality.audio
                : prov.settings.defaultQuality));
  }

  @override
  Widget build(BuildContext context) {
    final dummy = DownloadItem(id: '', url: widget.url, platform: _platform);
    return Container(
      decoration: const BoxDecoration(
        color: Neu.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
        top: 16,
        left: 20,
        right: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Neu.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Platform header card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: Neu.card(radius: 16, depth: 4),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Neu.bg,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: Neu.raised(depth: 4),
                  ),
                  child: Center(
                    child: Text(dummy.platformIcon,
                        style: const TextStyle(fontSize: 22)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            dummy.platformName,
                            style: TextStyle(
                              color: dummy.platformColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          if (_isPlaylist) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: Neu.accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: const Text('PLAYLIST',
                                  style: TextStyle(
                                      color: Neu.accent,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.url,
                        style: const TextStyle(
                            color: Neu.textSecondary, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_platform == Platform.youtube ||
              (_platform == Platform.instagram && _isPlaylist)) ...[
            const SizedBox(height: 20),
            const Text('Quality',
                style: TextStyle(
                    color: Neu.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5)),
            const SizedBox(height: 10),
            _qualitySelector(),
          ],
          const SizedBox(height: 24),
          // Download button
          GestureDetector(
            onTap: _loading ? null : _download,
            child: Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                color: Neu.accent,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Neu.accent.withValues(alpha: 0.4),
                    offset: const Offset(0, 6),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Center(
                child: _loading
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Download',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Center(
              child: Text('Cancel',
                  style: TextStyle(
                      color: Neu.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _qualitySelector() {
    final showAudio = _platform != Platform.instagram;
    return Row(
      children: [
        if (showAudio) ...[
          _qualityChip(MediaQuality.audio, 'MP3'),
          const SizedBox(width: 10),
        ],
        _qualityChip(MediaQuality.q720p, '720p'),
        const SizedBox(width: 10),
        _qualityChip(MediaQuality.q1080p, '1080p'),
      ],
    );
  }

  Widget _qualityChip(MediaQuality q, String label) {
    final selected = _quality == q;
    return GestureDetector(
      onTap: () => setState(() => _quality = q),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Neu.accent : Neu.bg,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Neu.accent.withValues(alpha: 0.35),
                    offset: const Offset(0, 4),
                    blurRadius: 10,
                  ),
                ]
              : Neu.raised(depth: 3),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Neu.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Future<void> _download() async {
    setState(() => _loading = true);
    final prov = context.read<DownloadProvider>();
    await prov.addDownload(widget.url, selectedQuality: _quality);
    if (mounted) Navigator.pop(context);
  }
}
