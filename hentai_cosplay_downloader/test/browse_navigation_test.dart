import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hentai_cosplay_downloader/models/album_item.dart';
import 'package:hentai_cosplay_downloader/providers/app_providers.dart';
import 'package:hentai_cosplay_downloader/providers/browse_provider.dart';
import 'package:hentai_cosplay_downloader/providers/disguise_provider.dart';
import 'package:hentai_cosplay_downloader/providers/settings_provider.dart';
import 'package:hentai_cosplay_downloader/ui/pages/browse/album_detail_page.dart';
import 'package:hentai_cosplay_downloader/ui/pages/browse/browse_page.dart';
import 'package:hentai_cosplay_downloader/ui/widgets/album_card.dart';
import 'package:hentai_cosplay_downloader/ui/widgets/app_lock_gate.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Test clicking AlbumCard in BrowsePage navigates to AlbumDetailPage', (WidgetTester tester) async {
    final browseProv = BrowseProvider(autoLoad: false);
    final item = AlbumItem(
      title: 'Full Test Album Title',
      coverUrl: 'https://example.com/cover.jpg',
      author: 'Test Coser',
      date: '2026-09-09',
      imageUrls: ['https://example.com/1.jpg'],
      detailUrl: 'https://example.com/detail',
      slug: 'full-test-slug',
    );
    browseProv.items.add(item);

    await tester.pumpWidget(
      MultiProvider(
        providers: AppProviders.allProviders,
        child: MaterialApp(
          home: ChangeNotifierProvider<BrowseProvider>.value(
            value: browseProv,
            child: const BrowsePage(),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(AlbumCard), findsOneWidget);

    // Tap the album card
    await tester.tap(find.byType(AlbumCard));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    // Verify AlbumDetailPage is pushed to navigation
    expect(find.byType(AlbumDetailPage), findsOneWidget);

    // Clear any timers scheduled by fetchAlbumDetail
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Test clicking AlbumCard when AppLockGate is unlocked', (WidgetTester tester) async {
    final browseProv = BrowseProvider(autoLoad: false);
    final item = AlbumItem(
      title: 'Full Test Album Title 2',
      coverUrl: 'https://example.com/cover2.jpg',
      author: 'Test Coser 2',
      date: '2026-09-09',
      imageUrls: ['https://example.com/2.jpg'],
      detailUrl: 'https://example.com/detail2',
      slug: 'full-test-slug-2',
    );
    browseProv.items.add(item);

    await tester.pumpWidget(
      MultiProvider(
        providers: AppProviders.allProviders,
        child: Consumer2<SettingsProvider, DisguiseProvider>(
          builder: (context, settings, disguise, child) {
            settings.config.disguiseMode = true;
            disguise.unlock();
            return MaterialApp(
              builder: (ctx, c) => AppLockGate(child: c!),
              home: ChangeNotifierProvider<BrowseProvider>.value(
                value: browseProv,
                child: const BrowsePage(),
              ),
            );
          },
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AlbumCard), findsOneWidget);

    // Tap the album card
    await tester.tap(find.byType(AlbumCard));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    // Verify AlbumDetailPage is pushed to navigation even under AppLockGate
    expect(find.byType(AlbumDetailPage), findsOneWidget);

    // Settle background timers
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Test secondary AlbumDetailPage is preserved after lock and unlock', (WidgetTester tester) async {
    final browseProv = BrowseProvider(autoLoad: false);
    final disguiseProv = DisguiseProvider(disguiseMode: true);
    disguiseProv.unlock();
    final settingsProv = SettingsProvider();
    settingsProv.config.disguiseMode = true;

    final item = AlbumItem(
      title: 'Preserved Album Detail',
      coverUrl: 'https://example.com/cover3.jpg',
      author: 'Test Coser 3',
      date: '2026-09-09',
      imageUrls: ['https://example.com/3.jpg'],
      detailUrl: 'https://example.com/detail3',
      slug: 'full-test-slug-3',
    );
    browseProv.items.add(item);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ...AppProviders.allProviders,
          ChangeNotifierProvider<DisguiseProvider>.value(value: disguiseProv),
          ChangeNotifierProvider<SettingsProvider>.value(value: settingsProv),
        ],
        child: MaterialApp(
          builder: (ctx, c) => AppLockGate(child: c!),
          home: ChangeNotifierProvider<BrowseProvider>.value(
            value: browseProv,
            child: const BrowsePage(),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byType(AlbumCard));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AlbumDetailPage), findsOneWidget);

    // Simulate backgrounding: lock the disguise provider
    disguiseProv.lock();
    await tester.pump(const Duration(milliseconds: 300));

    // Under AppLockGate, the real child is kept alive in the stack, but covered
    expect(find.byType(AlbumDetailPage), findsOneWidget);

    // Simulate returning to app and unlocking
    disguiseProv.unlock();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    // AlbumDetailPage is still directly visible and interactive!
    expect(find.byType(AlbumDetailPage), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });
}
