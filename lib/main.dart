import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/browse_provider.dart';
import 'providers/download_provider.dart';
import 'providers/gallery_provider.dart';
import 'providers/history_provider.dart';
import 'providers/settings_provider.dart';
import 'services/config_service.dart';
import 'ui/pages/home_scaffold.dart';
import 'ui/theme/ios_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set immersive edge-to-edge system overlays
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  await ConfigService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => BrowseProvider()),
        ChangeNotifierProvider(create: (_) => DownloadProvider()),
        ChangeNotifierProvider(create: (_) => HistoryProvider()),
        ChangeNotifierProvider(create: (_) => GalleryProvider()),
      ],
      child: const MztDownloaderApp(),
    ),
  );
}

class MztDownloaderApp extends StatelessWidget {
  const MztDownloaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProv = context.watch<SettingsProvider>();

    return MaterialApp(
      title: 'Mzt Downloader',
      debugShowCheckedModeBanner: false,
      theme: IosTheme.lightTheme,
      darkTheme: IosTheme.darkTheme,
      themeMode: settingsProv.themeMode,
      home: const HomeScaffold(),
    );
  }
}
