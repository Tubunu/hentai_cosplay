import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/browse_provider.dart';
import 'providers/download_provider.dart';
import 'providers/gallery_provider.dart';
import 'providers/history_provider.dart';
import 'providers/jable_browse_provider.dart';
import 'providers/jable_download_provider.dart';
import 'providers/local_jable_provider.dart';
import 'providers/local_video_provider.dart';
import 'providers/mzt_browse_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/video_browse_provider.dart';
import 'services/config_service.dart';
import 'services/jable/api_client.dart';
import 'services/jable/navigator_service.dart';
import 'services/notification_service.dart';
import 'ui/pages/home_scaffold.dart';
import 'ui/theme/ios_theme.dart';

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('Flutter Error: ${details.exception}');
    };

    // Immersive edge-to-edge system navigation
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );

    await ConfigService.init();
    await NotificationService.init();

    // Initialize Jable proxy if configured
    final cfg = ConfigService.loadConfig();
    if (cfg.customProxy.isNotEmpty) {
      ApiClient().setProxy(cfg.customProxy);
    }

    // Protect from iOS Jetsam memory kills when scrolling large photo sets
    PaintingBinding.instance.imageCache.maximumSize = 100;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 120 * 1024 * 1024; // 120MB limit

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(create: (_) => BrowseProvider()),
          ChangeNotifierProvider(create: (_) => MztBrowseProvider()),
          ChangeNotifierProvider(create: (_) => VideoBrowseProvider()),
          ChangeNotifierProvider(create: (_) => JableBrowseProvider()),
          ChangeNotifierProvider(create: (_) => DownloadProvider()),
          ChangeNotifierProvider(create: (_) => JableDownloadProvider()),
          ChangeNotifierProvider(create: (_) => HistoryProvider()),
          ChangeNotifierProvider(create: (_) => GalleryProvider()),
          ChangeNotifierProvider(create: (_) => LocalVideoProvider()),
          ChangeNotifierProvider(create: (_) => LocalJableProvider()),
        ],
        child: const HentaiCosplayApp(),
      ),
    );
  }, (error, stack) {
    debugPrint('Uncaught async error: $error\n$stack');
  });
}

class HentaiCosplayApp extends StatelessWidget {
  const HentaiCosplayApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select<SettingsProvider, ThemeMode>((s) => s.themeMode);

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Hentai Cosplay Downloader',
      debugShowCheckedModeBanner: false,
      theme: IosTheme.lightTheme,
      darkTheme: IosTheme.darkTheme,
      themeMode: themeMode,
      home: const HomeScaffold(),
    );
  }
}
