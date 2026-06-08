import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'providers/download_provider.dart';
import 'screens/home_screen.dart';
import 'widgets/share_bottom_sheet.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(
    ChangeNotifierProvider(
      create: (_) => DownloadProvider()..initialize(),
      child: const DropItApp(),
    ),
  );
}

class DropItApp extends StatefulWidget {
  const DropItApp({super.key});

  @override
  State<DropItApp> createState() => _DropItAppState();
}

class _DropItAppState extends State<DropItApp> {
  StreamSubscription? _intentSub;
  final _navKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _initShareIntent();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.storage,
      Permission.videos,
      Permission.audio,
      Permission.photos,
      Permission.notification,
    ].request();
    // Android 11+: MANAGE_EXTERNAL_STORAGE needed to write to /Downloads/
    // This opens a system settings page; request separately.
    if (!await Permission.manageExternalStorage.isGranted) {
      await Permission.manageExternalStorage.request();
    }
  }

  void _initShareIntent() {
    ReceiveSharingIntent.instance
        .getInitialMedia()
        .then((List<SharedMediaFile> files) {
      for (final f in files) {
        if (f.type == SharedMediaType.url ||
            f.type == SharedMediaType.text) {
          _handleSharedUrl(f.path);
          break;
        }
      }
    });

    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> files) {
        for (final f in files) {
          if (f.type == SharedMediaType.url ||
              f.type == SharedMediaType.text) {
            _handleSharedUrl(f.path);
            break;
          }
        }
      },
    );
  }

  void _handleSharedUrl(String rawText) {
    final prov = Provider.of<DownloadProvider>(context, listen: false);
    // Extract URL from share text — some apps (Pinterest) send "Take a look! 📌 https://..."
    final urlMatch = RegExp(r'https?://\S+').firstMatch(rawText);
    if (urlMatch == null) return;
    final url = urlMatch.group(0)!;

    if (prov.settings.autoDownloadOnShare) {
      prov.addDownload(url);
    } else {
      _navKey.currentState?.push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => Scaffold(
            backgroundColor: Colors.transparent,
            body: Align(
              alignment: Alignment.bottomCenter,
              child: ChangeNotifierProvider.value(
                value: prov,
                child: ShareBottomSheet(url: url),
              ),
            ),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _intentSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navKey,
      title: 'DropIt',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: const Color(0xFFE8EBF0),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFFF5A623),
          surface: Color(0xFFE8EBF0),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFE8EBF0),
          elevation: 0,
          foregroundColor: Color(0xFF2C3E50),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Color(0xFF2C3E50),
          contentTextStyle: TextStyle(color: Colors.white),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
