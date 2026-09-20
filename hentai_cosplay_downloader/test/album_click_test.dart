import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hentai_cosplay_downloader/models/album_item.dart';
import 'package:hentai_cosplay_downloader/providers/app_providers.dart';
import 'package:hentai_cosplay_downloader/providers/browse_provider.dart';
import 'package:hentai_cosplay_downloader/providers/download_provider.dart';
import 'package:hentai_cosplay_downloader/providers/favorite_provider.dart';
import 'package:hentai_cosplay_downloader/ui/pages/browse/album_detail_page.dart';
import 'package:hentai_cosplay_downloader/ui/widgets/album_card.dart';
import 'package:hentai_cosplay_downloader/providers/disguise_provider.dart';
import 'package:hentai_cosplay_downloader/providers/settings_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Test clicking AlbumCard on author text', (WidgetTester tester) async {
    final browseProv = BrowseProvider(autoLoad: false);
    final downloadProv = DownloadProvider();
    final settingsProv = SettingsProvider();
    final disguiseProv = DisguiseProvider(disguiseMode: false);

    bool tapped = false;
    final item = AlbumItem(
      title: 'Test Album Title Long Text',
      coverUrl: 'https://example.com/cover.jpg',
      author: 'Test Author Name',
      date: '2026-09-09',
      imageUrls: List.generate(20, (i) => 'https://example.com/$i.jpg'),
      detailUrl: 'https://example.com/detail',
      slug: 'test-slug',
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: browseProv),
          ChangeNotifierProvider.value(value: downloadProv),
          ChangeNotifierProvider.value(value: settingsProv),
          ChangeNotifierProvider.value(value: disguiseProv),
          ChangeNotifierProvider(create: (_) => FavoriteProvider()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 300,
              child: AlbumCard(
                item: item,
                onTap: () {
                  tapped = true;
                },
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));

    // Tap directly on the author text
    await tester.tap(find.text('Test Author Name'));
    await tester.pump(const Duration(milliseconds: 150));

    expect(tapped, isTrue, reason: 'Tapping on author text should trigger album onTap when onAuthorTap is null');

    downloadProv.dispose();
  });

  testWidgets('Test AlbumDetailPage transition and build in dark theme', (WidgetTester tester) async {
    final item = AlbumItem(
      title: '【Cosplay】[Hpoi] 崩坏3 琪亚娜 泳装',
      coverUrl: 'https://static.hentai-cosplay.xxx/upload/20260909/test.jpg',
      author: 'Hpoi',
      date: '2026-09-09',
      imageUrls: const [],
      previewUrls: const [],
      tags: const ['泳装', '崩坏3'],
      detailUrl: 'https://zh.hentai-cosplay-xxx.com/image/test-slug/',
      slug: 'test-slug',
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: AppProviders.allProviders,
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AlbumDetailPage(initialItem: item),
                        ),
                      );
                    },
                    child: const Text('Push'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap Push button
    await tester.tap(find.text('Push'));

    // Pump intermediate frames of the CupertinoPageRoute transition
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 200)); // Exactly halfway (Offset ~0.5)
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.byType(AlbumDetailPage), findsOneWidget);
  });
}

