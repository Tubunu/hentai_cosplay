import 'package:flutter_test/flutter_test.dart';
import 'package:hentai_cosplay_downloader/models/album_item.dart';
import 'package:hentai_cosplay_downloader/models/favorite_item.dart';
import 'package:hentai_cosplay_downloader/models/video_item.dart';
import 'package:hentai_cosplay_downloader/providers/favorite_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('FavoriteItem Model Tests', () {
    test('FavoriteItem fromAlbum preserves essential fields and converts properly', () {
      final album = AlbumItem(
        title: 'Test Cosplay Album',
        slug: 'test-cosplay-album',
        detailUrl: 'https://hentai-cosplay-xxx.com/album/test-cosplay-album/',
        coverUrl: 'https://example.com/cover.jpg',
        date: '2026-03-01',
        author: 'Coser A',
        tags: ['Cute', 'Uniform'],
        imageUrls: ['https://example.com/1.jpg', 'https://example.com/2.jpg'],
      );

      final fav = FavoriteItem.fromAlbum(
        album,
        siteKey: 'hc',
        siteName: 'Hentai Cosplay',
      );

      expect(fav.id, 'hc_test-cosplay-album');
      expect(fav.title, 'Test Cosplay Album');
      expect(fav.isAlbum, isTrue);
      expect(fav.isVideo, isFalse);
      expect(fav.author, 'Coser A');
      expect(fav.imageCount, 2);
      expect(fav.siteKey, 'hc');
      expect(fav.siteName, 'Hentai Cosplay');

      // Test JSON roundtrip
      final json = fav.toJson();
      final revived = FavoriteItem.fromJson(json);
      expect(revived.id, fav.id);
      expect(revived.title, fav.title);
      expect(revived.detailUrl, fav.detailUrl);
      expect(revived.imageCount, 2);

      // Test conversion to AlbumItem
      final convertedAlbum = fav.toAlbumItem();
      expect(convertedAlbum.title, fav.title);
      expect(convertedAlbum.author, fav.author);

      // Test conversion to BrowsingHistoryRecord
      final record = fav.toHistoryRecord();
      expect(record.title, fav.title);
      expect(record.siteKey, 'hc');
      expect(record.isVideo, isFalse);
    });

    test('FavoriteItem fromAlbum truncates excessive imageUrls to protect storage', () {
      final manyImages = List.generate(50, (i) => 'https://example.com/img_$i.jpg');
      final album = AlbumItem(
        title: 'Large Cosplay Album',
        slug: 'large-cosplay-album',
        detailUrl: 'https://hentai-cosplay-xxx.com/album/large-cosplay-album/',
        coverUrl: 'https://example.com/cover.jpg',
        date: '2026-03-01',
        author: 'Coser A',
        tags: ['Cosplay'],
        imageUrls: manyImages,
      );

      final fav = FavoriteItem.fromAlbum(album, siteKey: 'hc');
      expect(fav.imageCount, 50);
      final rawImages = fav.rawData['imageUrls'] as List;
      expect(rawImages.length, 10);
      expect(rawImages.first, 'https://example.com/img_0.jpg');
      expect(rawImages.last, 'https://example.com/img_9.jpg');
    });

    test('FavoriteItem fromVideo preserves essential fields and converts properly', () {
      final video = VideoItem(
        title: 'Test Video',
        slug: 'test-video-slug',
        detailUrl: 'https://porn-video-xxx.com/video/12345/',
        coverUrl: 'https://example.com/thumb.jpg',
        duration: '18:45',
        date: '2026-03-05',
        author: 'Studio X',
        tags: ['HD', 'Cosplay'],
        videoUrl: 'https://example.com/video.mp4',
      );

      final fav = FavoriteItem.fromVideo(
        video,
        siteKey: 'hc_video',
        siteName: 'HC 视频',
      );

      expect(fav.id, 'hc_video_test-video-slug');
      expect(fav.title, 'Test Video');
      expect(fav.isAlbum, isFalse);
      expect(fav.isVideo, isTrue);
      expect(fav.duration, '18:45');
      expect(fav.videoUrl, 'https://example.com/video.mp4');

      // Test JSON roundtrip
      final json = fav.toJson();
      final revived = FavoriteItem.fromJson(json);
      expect(revived.id, fav.id);
      expect(revived.duration, '18:45');
      expect(revived.videoUrl, 'https://example.com/video.mp4');

      // Test conversion to VideoItem
      final convertedVideo = fav.toVideoItem();
      expect(convertedVideo.title, fav.title);
      expect(convertedVideo.duration, '18:45');
    });
  });

  group('FavoriteProvider Logic Tests', () {
    test('Add, toggle, remove, and filter operations work correctly', () async {
      final provider = FavoriteProvider();

      final album1 = AlbumItem(
        title: 'Genshin Impact Cosplay',
        slug: 'genshin-cos',
        detailUrl: 'https://example.com/genshin',
        coverUrl: 'https://example.com/cover1.jpg',
        date: '2026-01-01',
        author: 'Ganyu',
        tags: ['Genshin', 'Cosplay'],
      );

      final video1 = VideoItem(
        title: 'Honkai Star Rail Action',
        slug: 'hsr-video',
        detailUrl: 'https://example.com/hsr',
        coverUrl: 'https://example.com/thumb1.jpg',
        duration: '12:00',
        date: '2026-02-01',
        author: 'Kafka',
        tags: ['HSR', 'Action'],
      );

      // Toggle album 1 -> should add
      final added1 = await provider.toggleAlbum(album1, siteKey: 'hc', siteName: 'Hentai Cosplay');
      expect(added1, isTrue);
      expect(provider.totalCount, 1);
      expect(provider.isFavorite('hc_genshin-cos'), isTrue);
      expect(provider.isFavoriteUrl('https://example.com/genshin'), isTrue);

      // Toggle video 1 -> should add
      final added2 = await provider.toggleVideo(video1, siteKey: 'jable', siteName: 'Jable');
      expect(added2, isTrue);
      expect(provider.totalCount, 2);
      expect(provider.isFavorite('jable_hsr-video'), isTrue);

      // Filter by mediaType: album
      provider.setMediaTypeFilter('album');
      expect(provider.filteredFavorites.length, 1);
      expect(provider.filteredFavorites.first.id, 'hc_genshin-cos');

      // Filter by mediaType: video
      provider.setMediaTypeFilter('video');
      expect(provider.filteredFavorites.length, 1);
      expect(provider.filteredFavorites.first.id, 'jable_hsr-video');

      // Reset mediaType filter
      provider.setMediaTypeFilter('all');
      expect(provider.filteredFavorites.length, 2);

      // Filter by siteKey
      provider.setSiteFilter('jable');
      expect(provider.filteredFavorites.length, 1);
      expect(provider.filteredFavorites.first.siteKey, 'jable');

      provider.setSiteFilter(null);
      expect(provider.filteredFavorites.length, 2);

      // Search Query
      provider.setSearchQuery('ganyu');
      expect(provider.filteredFavorites.length, 1);
      expect(provider.filteredFavorites.first.title, 'Genshin Impact Cosplay');

      provider.setSearchQuery('');
      expect(provider.filteredFavorites.length, 2);

      // Toggle album 1 again -> should remove
      final removed = await provider.toggleAlbum(album1, siteKey: 'hc', siteName: 'Hentai Cosplay');
      expect(removed, isFalse);
      expect(provider.totalCount, 1);
      expect(provider.isFavorite('hc_genshin-cos'), isFalse);

      // Clear all
      await provider.clearAll();
      expect(provider.totalCount, 0);
      expect(provider.filteredFavorites.isEmpty, isTrue);
    });
  });
}
