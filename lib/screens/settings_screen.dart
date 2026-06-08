import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/download_provider.dart';
import '../models/app_settings.dart';
import '../models/download_item.dart';
import '../utils/neu_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AppSettings _s;

  @override
  void initState() {
    super.initState();
    _s = context.read<DownloadProvider>().settings;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Neu.bg,
      appBar: AppBar(
        backgroundColor: Neu.bg,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Neu.bg,
              borderRadius: BorderRadius.circular(10),
              boxShadow: Neu.raised(depth: 4),
            ),
            child: const Icon(Icons.arrow_back_rounded,
                color: Neu.textPrimary, size: 20),
          ),
        ),
        title: const Text('Settings',
            style: TextStyle(
                color: Neu.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 20)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          _sectionHeader('Download Behavior'),
          _switchTile(
            'Show Confirmation',
            'Ask before downloading when URL is shared',
            _s.showConfirmationSheet,
            (v) => setState(() => _s.showConfirmationSheet = v),
          ),
          const SizedBox(height: 10),
          _switchTile(
            'Auto-Download on Share',
            'Start downloading immediately without confirmation',
            _s.autoDownloadOnShare,
            (v) => setState(() {
              _s.autoDownloadOnShare = v;
              if (v) _s.showConfirmationSheet = false;
            }),
          ),
          _sectionHeader('YouTube'),
          _switchTile(
            'MP3 Mode',
            'Download YouTube as audio-only MP3 by default',
            _s.youtubeMp3Mode,
            (v) => setState(() => _s.youtubeMp3Mode = v),
          ),
          _sectionHeader('Default Quality'),
          _qualityTile(),
          _sectionHeader('Storage'),
          _pathTile(),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: _save,
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
              child: const Center(
                child: Text('Save Settings',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 24, 0, 10),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
              color: Neu.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2),
        ),
      );

  Widget _switchTile(
      String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Container(
      decoration: Neu.card(radius: 14, depth: 4),
      child: SwitchListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(title,
            style: const TextStyle(
                color: Neu.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle,
            style: const TextStyle(
                color: Neu.textSecondary, fontSize: 12)),
        value: value,
        onChanged: onChanged,
        activeColor: Neu.accent,
        activeTrackColor: Neu.accent.withValues(alpha: 0.3),
        inactiveThumbColor: Neu.textSecondary,
        inactiveTrackColor: Neu.textSecondary.withValues(alpha: 0.2),
      ),
    );
  }

  Widget _qualityTile() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: Neu.card(radius: 14, depth: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Default Video Quality',
              style: TextStyle(
                  color: Neu.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            children: [
              _qChip(MediaQuality.audio, 'Audio'),
              const SizedBox(width: 10),
              _qChip(MediaQuality.q720p, '720p'),
              const SizedBox(width: 10),
              _qChip(MediaQuality.q1080p, '1080p'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qChip(MediaQuality q, String label) {
    final selected = _s.defaultQuality == q;
    return GestureDetector(
      onTap: () => setState(() => _s.defaultQuality = q),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Neu.accent : Neu.bg,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Neu.accent.withValues(alpha: 0.35),
                    offset: const Offset(0, 4),
                    blurRadius: 10,
                  )
                ]
              : Neu.raised(depth: 3),
        ),
        child: Text(label,
            style: TextStyle(
              color: selected ? Colors.white : Neu.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            )),
      ),
    );
  }

  Widget _pathTile() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: Neu.card(radius: 14, depth: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Save Location',
              style: TextStyle(
                  color: Neu.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            _s.customSavePath.isEmpty
                ? '/Downloads/DropIt/ (default)'
                : _s.customSavePath,
            style: const TextStyle(
                color: Neu.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => setState(() => _s.customSavePath = ''),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              decoration: Neu.card(radius: 10, depth: 3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.folder_outlined,
                      color: Neu.accent, size: 16),
                  SizedBox(width: 6),
                  Text('Reset to Default',
                      style: TextStyle(
                          color: Neu.accent,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _save() {
    context.read<DownloadProvider>().saveSettings(_s);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved')),
    );
  }
}
