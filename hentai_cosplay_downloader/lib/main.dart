import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/app_providers.dart';
import 'providers/disguise_provider.dart';
import 'providers/settings_provider.dart';
import 'services/app_logger.dart';
import 'services/config_service.dart';
import 'services/jable/navigator_service.dart';
import 'services/notification_service.dart';
import 'constants/cache_constants.dart';
import 'ui/pages/home_scaffold.dart';
import 'ui/theme/ios_theme.dart';
import 'ui/widgets/app_lock_gate.dart';

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      AppLogger.e('FlutterError', details.exceptionAsString(), details.exception, details.stack);
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
    PaintingBinding.instance.imageCache.maximumSize = kImageCacheMaximumSize;
    PaintingBinding.instance.imageCache.maximumSizeBytes = kImageCacheMaximumSizeBytes;

    runApp(
      MultiProvider(
        providers: AppProviders.allProviders,
        child: const HentaiCosplayApp(),
      ),
    );
  }, (error, stack) {
    debugPrint('Uncaught async error: $error\n$stack');
    AppLogger.e('UncaughtAsync', error.toString(), error, stack);
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
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
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
      } catch (e, st) {
        AppLogger.e('Lifecycle', 'Error updating disguise state on lifecycle change: $e', e, st);
      }
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
      home: const HomeScaffold(),
      builder: (context, child) {
        return AppLockGate(child: child ?? const SizedBox.shrink());
      },
    );
  }
}
