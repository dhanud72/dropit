import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/download_provider.dart';
import '../models/download_item.dart';
import '../utils/neu_theme.dart';
import '../widgets/download_item_tile.dart';
import '../widgets/add_links_sheet.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Neu.bg,
      statusBarIconBrightness: Brightness.dark,
    ));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Neu.bg,
      appBar: AppBar(
        backgroundColor: Neu.bg,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Neu.bg,
          statusBarIconBrightness: Brightness.dark,
        ),
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Neu.bg,
                borderRadius: BorderRadius.circular(12),
                boxShadow: Neu.raised(depth: 5),
              ),
              child: const Center(
                child: Text('⬇', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'DropIt',
              style: TextStyle(
                color: Neu.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 22,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Neu.bg,
                borderRadius: BorderRadius.circular(12),
                boxShadow: Neu.raised(depth: 4),
              ),
              child: const Icon(Icons.settings_outlined,
                  color: Neu.textSecondary, size: 20),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Neu.bg,
                borderRadius: BorderRadius.circular(14),
                boxShadow: Neu.raised(depth: 4),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: Neu.accent,
                  borderRadius: BorderRadius.circular(11),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: Neu.textSecondary,
                labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13),
                unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 13),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Downloads'),
                  Tab(text: 'History'),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: GestureDetector(
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => ChangeNotifierProvider.value(
            value: context.read<DownloadProvider>(),
            child: const AddLinksSheet(),
          ),
        ),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Neu.bg,
            borderRadius: BorderRadius.circular(18),
            boxShadow: Neu.raised(depth: 7),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Neu.accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add_link_rounded,
                    color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              const Text(
                'Add Links',
                style: TextStyle(
                  color: Neu.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
      body: Consumer<DownloadProvider>(
        builder: (context, prov, _) {
          return TabBarView(
            controller: _tabController,
            children: [
              _buildList(prov.activeDownloads, prov,
                  emptyMsg: 'No active downloads',
                  emptyHint: 'Tap Add Links or share a URL to start'),
              _buildList(prov.completedDownloads, prov,
                  emptyMsg: 'No history yet',
                  emptyHint: 'Downloaded and failed items will appear here'),
            ],
          );
        },
      ),
    );
  }

  Widget _buildList(List<DownloadItem> items, DownloadProvider prov,
      {required String emptyMsg, String emptyHint = ''}) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Neu.bg,
                shape: BoxShape.circle,
                boxShadow: Neu.raised(depth: 8),
              ),
              child: const Icon(Icons.inbox_outlined,
                  color: Neu.textSecondary, size: 36),
            ),
            const SizedBox(height: 20),
            Text(emptyMsg,
                style: const TextStyle(
                    color: Neu.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            if (emptyHint.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(emptyHint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Neu.textSecondary, fontSize: 13)),
            ],
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: items.length,
      padding: const EdgeInsets.only(top: 8, bottom: 100),
      itemBuilder: (_, i) => DownloadItemTile(
        item: items[i],
        onRetry: () => prov.retryDownload(items[i].id),
        onDismiss: () => prov.removeItem(items[i].id),
      ),
    );
  }
}
