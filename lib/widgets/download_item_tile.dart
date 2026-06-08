import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/download_item.dart';
import '../services/download_channel.dart';
import '../utils/neu_theme.dart';

class DownloadItemTile extends StatelessWidget {
  final DownloadItem item;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;

  const DownloadItemTile({
    super.key,
    required this.item,
    this.onRetry,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFF6B6B),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.white, size: 24),
      ),
      onDismissed: (_) => onDismiss?.call(),
      child: GestureDetector(
        onLongPress: item.status == DownloadStatus.done
            ? () => _showFileOptions(context)
            : null,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: Neu.card(radius: 16, depth: 5),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildThumbnail(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title.isNotEmpty ? item.title : item.url,
                            style: const TextStyle(
                              color: Neu.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              _platformBadge(),
                              const SizedBox(width: 8),
                              _buildStatusChip(),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildTrailing(),
                  ],
                ),
                if (item.status == DownloadStatus.downloading) ...[
                  const SizedBox(height: 12),
                  _progressBar(),
                ],
                if (item.status == DownloadStatus.failed &&
                    item.errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    item.errorMessage!,
                    style: const TextStyle(
                        color: Color(0xFFE53E3E), fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    if (item.thumbnailUrl != null && item.thumbnailUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: item.thumbnailUrl!,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          placeholder: (_, __) => _iconBox(),
          errorWidget: (_, __, ___) => _iconBox(),
        ),
      );
    }
    return _iconBox();
  }

  Widget _iconBox() => Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Neu.bg,
          borderRadius: BorderRadius.circular(10),
          boxShadow: Neu.raised(depth: 3),
        ),
        child: Center(
          child: Text(item.platformIcon,
              style: const TextStyle(fontSize: 20)),
        ),
      );

  Widget _platformBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Neu.bg,
          borderRadius: BorderRadius.circular(6),
          boxShadow: Neu.raised(depth: 2),
        ),
        child: Text(
          item.platformName,
          style: TextStyle(
            color: item.platformColor,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  Widget _buildStatusChip() {
    Color color;
    String label;
    switch (item.status) {
      case DownloadStatus.queued:
        color = const Color(0xFFF5A623);
        label = 'Queued';
        break;
      case DownloadStatus.downloading:
        color = const Color(0xFF4A90E2);
        label = 'Downloading';
        break;
      case DownloadStatus.done:
        color = const Color(0xFF48BB78);
        label = 'Done';
        break;
      case DownloadStatus.failed:
        color = const Color(0xFFE53E3E);
        label = 'Failed';
        break;
      case DownloadStatus.cancelled:
        color = Neu.textSecondary;
        label = 'Cancelled';
        break;
    }
    return Text(label,
        style: TextStyle(
            color: color, fontSize: 10, fontWeight: FontWeight.w600));
  }

  Widget _progressBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          height: 6,
          decoration: Neu.inset(radius: 3),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: item.progress,
              backgroundColor: Colors.transparent,
              valueColor: const AlwaysStoppedAnimation(Neu.accent),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${(item.progress * 100).toStringAsFixed(0)}%',
          style: const TextStyle(
              color: Neu.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildTrailing() {
    if (item.status == DownloadStatus.failed && item.retryCount < 3) {
      return GestureDetector(
        onTap: onRetry,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Neu.bg,
            borderRadius: BorderRadius.circular(10),
            boxShadow: Neu.raised(depth: 3),
          ),
          child: const Icon(Icons.refresh_rounded,
              color: Neu.textSecondary, size: 18),
        ),
      );
    }
    if (item.status == DownloadStatus.downloading ||
        item.status == DownloadStatus.queued) {
      return Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Neu.bg,
          borderRadius: BorderRadius.circular(10),
          boxShadow: Neu.raised(depth: 3),
        ),
        child: const Padding(
          padding: EdgeInsets.all(9),
          child: CircularProgressIndicator(
              strokeWidth: 2, color: Neu.accent),
        ),
      );
    }
    if (item.status == DownloadStatus.done) {
      return GestureDetector(
        onTap: (item.outputPath != null)
            ? () => _openFileQuick()
            : null,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Neu.bg,
            borderRadius: BorderRadius.circular(10),
            boxShadow: Neu.raised(depth: 3),
          ),
          child: const Icon(Icons.open_in_new_rounded,
              color: Neu.accent, size: 18),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Future<void> _openFileQuick() async {
    final path = item.outputPath;
    if (path == null) return;
    try {
      await DownloadChannel.openFile(path);
    } catch (_) {}
  }

  void _showFileOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Neu.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Neu.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              item.title.isNotEmpty ? item.title : 'File',
              style: const TextStyle(
                  color: Neu.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _actionButton(
                  icon: Icons.play_circle_outline_rounded,
                  label: 'Open',
                  color: Neu.accent,
                  onTap: () {
                    Navigator.pop(context);
                    _openFile(context);
                  },
                ),
                const SizedBox(width: 12),
                _actionButton(
                  icon: Icons.folder_open_rounded,
                  label: 'Folder',
                  color: const Color(0xFF4A90E2),
                  onTap: () {
                    Navigator.pop(context);
                    _openFolder(context);
                  },
                ),
                const SizedBox(width: 12),
                _actionButton(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete',
                  color: const Color(0xFFE53E3E),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteFile(context);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: Neu.card(radius: 14, depth: 4),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openFile(BuildContext context) async {
    final path = item.outputPath;
    if (path == null) return;
    try {
      await DownloadChannel.openFile(path);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot open: $e'),
            backgroundColor: Neu.textPrimary,
          ),
        );
      }
    }
  }

  Future<void> _openFolder(BuildContext context) async {
    final path = item.outputPath;
    if (path == null) return;
    try {
      await DownloadChannel.openFile(path);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot open folder: $e'),
              backgroundColor: Neu.textPrimary),
        );
      }
    }
  }

  Future<void> _deleteFile(BuildContext context) async {
    final path = item.outputPath;
    if (path != null) {
      try {
        final dir = Directory(path);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        } else {
          final f = File(path);
          if (await f.exists()) await f.delete();
        }
      } catch (_) {}
    }
    onDismiss?.call();
  }
}
