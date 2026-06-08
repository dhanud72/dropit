import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/download_item.dart';
import '../providers/download_provider.dart';
import '../utils/platform_detector.dart';
import '../utils/neu_theme.dart';

class AddLinksSheet extends StatefulWidget {
  const AddLinksSheet({super.key});

  @override
  State<AddLinksSheet> createState() => _AddLinksSheetState();
}

class _AddLinksSheetState extends State<AddLinksSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<_LinkEntry> _links = [];
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_parseLinks);
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryAutoPaste());
  }

  @override
  void dispose() {
    _controller.removeListener(_parseLinks);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _tryAutoPaste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (text.isNotEmpty && RegExp(r'https?://').hasMatch(text)) {
      _controller.text = text;
    } else {
      _focusNode.requestFocus();
    }
  }

  void _parseLinks() {
    final text = _controller.text;
    final matches = RegExp(r'https?://\S+').allMatches(text);
    final seen = <String>{};
    final entries = <_LinkEntry>[];
    for (final m in matches) {
      var url = m.group(0)!.trimRight();
      url = url.replaceAll(RegExp(r"""[.,;)>\]"']+$"""), '');
      if (seen.add(url)) {
        entries.add(_LinkEntry(
          url: url,
          platform: PlatformDetector.detect(url),
          isPlaylist: PlatformDetector.isPlaylist(url),
        ));
      }
    }
    setState(() => _links = entries);
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      final current = _controller.text;
      _controller.text =
          current.isEmpty ? data.text! : '$current\n${data.text!}';
      _controller.selection =
          TextSelection.collapsed(offset: _controller.text.length);
    }
  }

  Future<void> _downloadAll() async {
    if (_links.isEmpty || _downloading) return;
    setState(() => _downloading = true);
    final prov = context.read<DownloadProvider>();
    for (final link in _links) {
      await prov.addDownload(link.url);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final hasLinks = _links.isNotEmpty;
    return Container(
      decoration: const BoxDecoration(
        color: Neu.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
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
          const SizedBox(height: 18),
          Row(
            children: [
              const Text('Add Links',
                  style: TextStyle(
                      color: Neu.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const Spacer(),
              GestureDetector(
                onTap: _pasteFromClipboard,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: Neu.card(radius: 10, depth: 3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.content_paste_rounded,
                          size: 14, color: Neu.accent),
                      SizedBox(width: 6),
                      Text('Paste',
                          style: TextStyle(
                              color: Neu.accent,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Input field
          Container(
            decoration: Neu.inset(radius: 14),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              maxLines: 4,
              style: const TextStyle(
                  color: Neu.textPrimary, fontSize: 13),
              decoration: const InputDecoration(
                hintText:
                    'Paste one or more links here…\nOne per line or mixed text',
                hintStyle:
                    TextStyle(color: Neu.textSecondary, fontSize: 13),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(14),
              ),
            ),
          ),
          if (hasLinks) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  '${_links.length} link${_links.length == 1 ? '' : 's'} detected',
                  style: const TextStyle(
                      color: Neu.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (_links.length > 1)
                  GestureDetector(
                    onTap: () => setState(() {
                      _links.clear();
                      _controller.clear();
                    }),
                    child: const Text('Clear all',
                        style: TextStyle(
                            color: Color(0xFFE53E3E),
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _links.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _LinkTile(
                  entry: _links[i],
                  onRemove: () => setState(() => _links.removeAt(i)),
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          GestureDetector(
            onTap: hasLinks && !_downloading ? _downloadAll : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                color: hasLinks ? Neu.accent : Neu.bg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: hasLinks
                    ? [
                        BoxShadow(
                          color: Neu.accent.withValues(alpha: 0.4),
                          offset: const Offset(0, 6),
                          blurRadius: 16,
                        ),
                      ]
                    : Neu.raised(depth: 3),
              ),
              child: Center(
                child: _downloading
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(
                        hasLinks
                            ? 'Download ${_links.length} link${_links.length == 1 ? '' : 's'}'
                            : 'Download',
                        style: TextStyle(
                            color: hasLinks
                                ? Colors.white
                                : Neu.textSecondary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkEntry {
  final String url;
  final Platform platform;
  final bool isPlaylist;
  _LinkEntry(
      {required this.url,
      required this.platform,
      required this.isPlaylist});
}

class _LinkTile extends StatelessWidget {
  final _LinkEntry entry;
  final VoidCallback onRemove;

  const _LinkTile({required this.entry, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final dummy =
        DownloadItem(id: '', url: entry.url, platform: entry.platform);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: Neu.card(radius: 12, depth: 3),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: Neu.bg,
              borderRadius: BorderRadius.circular(10),
              boxShadow: Neu.raised(depth: 3),
            ),
            child: Center(
              child: Text(dummy.platformIcon,
                  style: const TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(width: 10),
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
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                    if (entry.isPlaylist) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Neu.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('PLAYLIST',
                            style: TextStyle(
                                color: Neu.accent,
                                fontSize: 8,
                                fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  entry.url,
                  style: const TextStyle(
                      color: Neu.textSecondary, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: Neu.bg,
                borderRadius: BorderRadius.circular(8),
                boxShadow: Neu.raised(depth: 2),
              ),
              child: const Icon(Icons.close_rounded,
                  color: Neu.textSecondary, size: 15),
            ),
          ),
        ],
      ),
    );
  }
}
