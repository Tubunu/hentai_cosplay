import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hentai_cosplay_downloader/main.dart';
import 'package:hentai_cosplay_downloader/providers/browse_provider.dart';
import 'package:hentai_cosplay_downloader/providers/download_provider.dart';
import 'package:hentai_cosplay_downloader/providers/gallery_provider.dart';
import 'package:hentai_cosplay_downloader/providers/history_provider.dart';
import 'package:hentai_cosplay_downloader/providers/local_video_provider.dart';
import 'package:hentai_cosplay_downloader/providers/jable_browse_provider.dart';
import 'package:hentai_cosplay_downloader/providers/jable_download_provider.dart';
import 'package:hentai_cosplay_downloader/providers/local_jable_provider.dart';
import 'package:hentai_cosplay_downloader/providers/mzt_browse_provider.dart';
import 'package:hentai_cosplay_downloader/providers/settings_provider.dart';
import 'package:hentai_cosplay_downloader/providers/video_browse_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App smoke test', (WidgetTester tester) async {
    final settingsProv = SettingsProvider();
    final browseProv = BrowseProvider(autoLoad: false);
    final mztBrowseProv = MztBrowseProvider(autoLoad: false);
    final videoBrowseProv = VideoBrowseProvider(autoLoad: false);
    final jableBrowseProv = JableBrowseProvider(autoLoad: false);
    final downloadProv = DownloadProvider();
    final jableDownloadProv = JableDownloadProvider();
    final historyProv = HistoryProvider();
    final galleryProv = GalleryProvider();
    final localVideoProv = LocalVideoProvider();
    final localJableProv = LocalJableProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settingsProv),
          ChangeNotifierProvider.value(value: browseProv),
          ChangeNotifierProvider.value(value: mztBrowseProv),
          ChangeNotifierProvider.value(value: videoBrowseProv),
          ChangeNotifierProvider.value(value: jableBrowseProv),
          ChangeNotifierProvider.value(value: downloadProv),
          ChangeNotifierProvider.value(value: jableDownloadProv),
          ChangeNotifierProvider.value(value: historyProv),
          ChangeNotifierProvider.value(value: galleryProv),
          ChangeNotifierProvider.value(value: localVideoProv),
          ChangeNotifierProvider.value(value: localJableProv),
        ],
        child: const HentaiCosplayApp(),
      ),
    );

    // Initial frame check
    expect(find.byType(MaterialApp), findsOneWidget);

    // Let any pending timers/async calls settle
    await tester.pump(const Duration(milliseconds: 100));
  });
}
