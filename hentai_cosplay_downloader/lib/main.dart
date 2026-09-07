import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/browse_provider.dart';
import 'providers/browsing_history_provider.dart';
import 'providers/coomer_browse_provider.dart';
import 'providers/cosplaytele_browse_provider.dart';
import 'providers/cosvault_browse_provider.dart';
import 'providers/download_provider.dart';
import 'providers/eporner_browse_provider.dart';
import 'providers/exhentai_browse_provider.dart';
import 'providers/gallery_provider.dart';
import 'providers/galleryepic_browse_provider.dart';
import 'providers/hanime1_browse_provider.dart';
import 'providers/history_provider.dart';
import 'providers/hqporner_browse_provider.dart';
import 'providers/iwara_browse_provider.dart';
import 'providers/jable_browse_provider.dart';
import 'providers/jable_download_provider.dart';
import 'providers/kuraa_browse_provider.dart';
import 'providers/local_jable_provider.dart';
import 'providers/local_video_provider.dart';
import 'providers/misskon_browse_provider.dart';
import 'providers/mzt_browse_provider.dart';
import 'providers/nucosplay_browse_provider.dart';
import 'providers/pinse_browse_provider.dart';
import 'providers/pixibb_browse_provider.dart';
import 'providers/pornbox_browse_provider.dart';
import 'providers/pornhub_browse_provider.dart';
import 'providers/rule34video_browse_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/spankbang_browse_provider.dart';
import 'providers/twitter_browse_provider.dart';
import 'providers/video_browse_provider.dart';
import 'providers/xvideos_browse_provider.dart';
import 'providers/cosxplay_browse_provider.dart';
import 'providers/cosplayporntube_browse_provider.dart';
import 'providers/xhamster_browse_provider.dart';
import 'providers/xnxx_browse_provider.dart';
import 'providers/nsfwpub_browse_provider.dart';
import 'providers/thothub_browse_provider.dart';
import 'providers/njav_browse_provider.dart';
import 'providers/vjav_browse_provider.dart';
import 'providers/javguru_browse_provider.dart';
import 'providers/av123_browse_provider.dart';
import 'providers/javmost_browse_provider.dart';
import 'providers/disguise_provider.dart';
import 'services/config_service.dart';
import 'services/jable/navigator_service.dart';
import 'services/notification_service.dart';
import 'ui/theme/ios_theme.dart';
import 'ui/widgets/app_lock_gate.dart';

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

    // Initialize configuration service & proxy settings
    await ConfigService.init();

    // Initialize local notifications
    await NotificationService.init();

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
          ChangeNotifierProvider(create: (_) => MisskonBrowseProvider()),
          ChangeNotifierProvider(create: (_) => CoomerBrowseProvider()),
          ChangeNotifierProvider(create: (_) => PinseBrowseProvider()),
          ChangeNotifierProvider(create: (_) => PornboxBrowseProvider()),
          ChangeNotifierProvider(create: (_) => KuraaBrowseProvider()),
          ChangeNotifierProvider(create: (_) => TwitterBrowseProvider()),
          ChangeNotifierProvider(create: (_) => ExHentaiBrowseProvider()),
          ChangeNotifierProvider(create: (_) => PixibbBrowseProvider()),
          ChangeNotifierProvider(create: (_) => CosplayteleBrowseProvider()),
          ChangeNotifierProvider(create: (_) => NucosplayBrowseProvider()),
          ChangeNotifierProvider(create: (_) => CosvaultBrowseProvider()),
          ChangeNotifierProvider(create: (_) => GalleryepicBrowseProvider()),
          ChangeNotifierProvider(create: (_) => Hanime1BrowseProvider()),
          ChangeNotifierProvider(create: (_) => IwaraBrowseProvider()),
          ChangeNotifierProvider(create: (_) => Rule34VideoBrowseProvider()),
          ChangeNotifierProvider(create: (_) => EpornerBrowseProvider()),
          ChangeNotifierProvider(create: (_) => HqpornerBrowseProvider()),
          ChangeNotifierProvider(create: (_) => SpankbangBrowseProvider()),
          ChangeNotifierProvider(create: (_) => PornhubBrowseProvider()),
          ChangeNotifierProvider(create: (_) => XVideosBrowseProvider()),
          ChangeNotifierProvider(create: (_) => CosxplayBrowseProvider()),
          ChangeNotifierProvider(create: (_) => CosplayporntubeBrowseProvider()),
          ChangeNotifierProvider(create: (_) => XhamsterBrowseProvider()),
          ChangeNotifierProvider(create: (_) => XnxxBrowseProvider()),
          ChangeNotifierProvider(create: (_) => NsfwpubBrowseProvider()),
          ChangeNotifierProvider(create: (_) => ThothubBrowseProvider()),
          ChangeNotifierProvider(create: (_) => NjavBrowseProvider()),
          ChangeNotifierProvider(create: (_) => VjavBrowseProvider()),
          ChangeNotifierProvider(create: (_) => JavguruBrowseProvider()),
          ChangeNotifierProvider(create: (_) => Av123BrowseProvider()),
          ChangeNotifierProvider(create: (_) => JavmostBrowseProvider()),
          ChangeNotifierProvider(create: (_) => JableBrowseProvider()),
          ChangeNotifierProvider(create: (_) => DownloadProvider()),
          ChangeNotifierProvider(create: (_) => JableDownloadProvider()),
          ChangeNotifierProvider(create: (_) => HistoryProvider()),
          ChangeNotifierProvider(create: (_) => BrowsingHistoryProvider()),
          ChangeNotifierProvider(create: (_) => GalleryProvider()),
          ChangeNotifierProvider(create: (_) => LocalVideoProvider()),
          ChangeNotifierProvider(create: (_) => LocalJableProvider()),
          ChangeNotifierProvider(
            create: (ctx) => DisguiseProvider(
              disguiseMode: ctx.read<SettingsProvider>().config.disguiseMode,
            ),
          ),
        ],
        child: const HentaiCosplayApp(),
      ),
    );
  }, (error, stack) {
    debugPrint('Uncaught async error: $error\n$stack');
  });
}

class HentaiCosplayApp extends StatefulWidget {
  const HentaiCosplayApp({super.key});

  @override
  State<HentaiCosplayApp> createState() => _HentaiCosplayAppState();
}

class _HentaiCosplayAppState extends State<HentaiCosplayApp> with WidgetsBindingObserver {
  final ViewingRouteObserver _routeObserver = ViewingRouteObserver();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      // Release decoded image bitmaps to drastically reduce background memory footprint
      // and prevent iOS Jetsam / Android LMK process termination
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      debugPrint('[Memory] Cleared in-memory image cache on entering background');

      try {
        final settings = context.read<SettingsProvider>();
        context.read<DisguiseProvider>().onLifecycleStateChanged(
              state,
              settings.config.disguiseMode,
              settings.config.disguiseRelockOnBackground,
            );
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select<SettingsProvider, ThemeMode>((s) => s.themeMode);

    return MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: [_routeObserver],
      title: 'Hentai Cosplay Downloader',
      debugShowCheckedModeBanner: false,
      theme: IosTheme.lightTheme,
      darkTheme: IosTheme.darkTheme,
      themeMode: themeMode,
      home: const AppLockGate(),
    );
  }
}
