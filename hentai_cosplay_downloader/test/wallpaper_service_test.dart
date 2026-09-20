import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hentai_cosplay_downloader/models/wallpaper_item.dart';
import 'package:hentai_cosplay_downloader/services/wallpaper_service.dart';
import 'package:hentai_cosplay_downloader/ui/pages/disguise/someacg_disguise_page.dart';
import 'package:hentai_cosplay_downloader/ui/pages/disguise/wallpaper_detail_page.dart';

void main() {
  test('WallpaperService fetches real SomeACG wallpapers', () async {
    final list = await WallpaperService.fetchWallpapers(category: 'all', page: 1, limit: 10);
    expect(list.isNotEmpty, isTrue);
    expect(list.first.previewUrl.isNotEmpty, isTrue);
    expect(list.first.rawUrl.isNotEmpty, isTrue);
    // Should not contain blocked i.pximg.net directly
    for (final item in list) {
      expect(item.previewUrl.contains('i.pximg.net'), isFalse);
      expect(item.rawUrl.contains('i.pximg.net'), isFalse);
    }
  });

  testWidgets('WallpaperDetailPage pumps without crashing', (tester) async {
    final item = const WallpaperItem(
      id: 'test-1',
      title: 'Test Wallpaper',
      previewUrl: 'https://example.com/preview.jpg',
      rawUrl: 'https://example.com/raw.jpg',
      author: 'Test Author',
      width: 1920,
      height: 1080,
      tags: ['genshin'],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: WallpaperDetailPage(item: item),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Test Wallpaper'), findsOneWidget);
    expect(find.text('4K 超清'), findsOneWidget);
  });

  testWidgets('SomeAcgDisguisePage navigates into WallpaperDetailPage on card tap and back', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SomeAcgDisguisePage(),
      ),
    );

    // Pump frames to complete _loadWallpapers
    for (int i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 200));
      if (find.byType(CachedNetworkImage).evaluate().isNotEmpty) break;
    }

    expect(find.byType(SomeAcgDisguisePage), findsOneWidget);
    expect(find.byType(WallpaperDetailPage), findsNothing);

    // Tap the first wallpaper card by key prefix
    final cardFinder = find.byWidgetPredicate(
      (w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('wallpaper_card_'),
    );
    expect(cardFinder, findsWidgets);

    await tester.tap(cardFinder.first);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    // Verify WallpaperDetailPage is shown without crashing
    expect(find.byType(WallpaperDetailPage), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Tap back button in WallpaperDetailPage
    final backBtn = find.byIcon(CupertinoIcons.back);
    expect(backBtn, findsOneWidget);
    await tester.tap(backBtn);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    // Verify back to SomeAcgDisguisePage
    expect(find.byType(WallpaperDetailPage), findsNothing);
    expect(find.byType(SomeAcgDisguisePage), findsOneWidget);
  });
}
