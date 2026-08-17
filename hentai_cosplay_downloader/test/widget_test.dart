import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hentai_cosplay_downloader/main.dart';
import 'package:hentai_cosplay_downloader/providers/browse_provider.dart';
import 'package:hentai_cosplay_downloader/providers/download_provider.dart';
import 'package:hentai_cosplay_downloader/providers/gallery_provider.dart';
import 'package:hentai_cosplay_downloader/providers/history_provider.dart';
import 'package:hentai_cosplay_downloader/providers/settings_provider.dart';
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
    final downloadProv = DownloadProvider();
    final historyProv = HistoryProvider();
    final galleryProv = GalleryProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settingsProv),
          ChangeNotifierProvider.value(value: browseProv),
          ChangeNotifierProvider.value(value: downloadProv),
          ChangeNotifierProvider.value(value: historyProv),
          ChangeNotifierProvider.value(value: galleryProv),
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
