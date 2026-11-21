import 'package:flutter_test/flutter_test.dart';
import 'package:hentai_cosplay_downloader/models/album_item.dart';
import 'package:hentai_cosplay_downloader/models/ygjgl/ygjgl_vod_item.dart';
import 'package:hentai_cosplay_downloader/models/ygjgl/ygjgl_post_item.dart';
import 'package:hentai_cosplay_downloader/providers/ygjgl_browse_provider.dart';
import 'package:hentai_cosplay_downloader/utils/referer_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MediaSourceType & RefererHelper Tests for YGJGL', () {
    test('MediaSourceType.ygjgl enum is properly configured', () {
      expect(MediaSourceType.ygjgl.label, '一个够了');
      expect(MediaSourceType.ygjgl.badge, 'YGJ');
    });

    test('RefererHelper returns https://ygjgl.one/ for ygjgl', () {
      final referer = RefererHelper.getReferer(
        'https://ygjgl.one/video/sample.mp4',
        sourceType: MediaSourceType.ygjgl,
      );
      expect(referer, 'https://ygjgl.one/');
    });
  });

  group('YgjglVodItem Model Tests', () {
    test('fromJson parses correctly and handles missing optional fields', () {
      final json = {
        'id': 'abc12345',
        'title': 'Test VOD Title',
        'actor': 'Test Actress',
        'tags': ['Tag1', 'Tag2'],
        'published': '2026-03-01',
        'size': '1.2GB',
        'duration': '45:00',
        'cover_url': 'https://img.ygjgl.one/cover/abc.jpg',
        'cover_small_url': 'https://img.ygjgl.one/thumb/abc.jpg',
        'free': 1,
        'coin': 0,
        'pics': ['https://img.ygjgl.one/p1.jpg'],
        'pics_thumb': ['https://img.ygjgl.one/t1.jpg'],
        'views': 5200,
        'likes': 120,
        'collections': 45,
        'downloads': 88,
        'mp4': 'https://stream.ygjgl.one/video.mp4',
      };

      final item = YgjglVodItem.fromJson(json);
      expect(item.id, 'abc12345');
      expect(item.title, 'Test VOD Title');
      expect(item.actor, 'Test Actress');
      expect(item.tags, ['Tag1', 'Tag2']);
      expect(item.duration, '45:00');
      expect(item.isFree, isTrue);
      expect(item.coverUrl, 'https://ygjgl.one/img/abc12345/cover?w=480');
      expect(item.pics.first, 'https://ygjgl.one/img/abc12345/0');
      expect(item.mp4Url, 'https://stream.ygjgl.one/video.mp4');

      final videoItem = item.toVideoItem();
      expect(videoItem.title, 'Test VOD Title');
      expect(videoItem.slug, 'abc12345');
      expect(videoItem.detailUrl, 'https://ygjgl.one/play?id=abc12345');
      expect(videoItem.author, 'Test Actress');
      expect(videoItem.duration, '45:00');
      expect(videoItem.videoUrl, 'https://stream.ygjgl.one/video.mp4');
    });
  });

  group('YgjglPostItem Model Tests', () {
    test('Image Post converts correctly to AlbumItem', () {
      final json = {
        'id': 'post_img_001',
        'title': 'Sweet Cosplay Photo Session',
        'kind': 'image',
        'cover': 'https://img.ygjgl.one/cover/post1.jpg',
        'tags': ['Cosplay', 'Sweet'],
        'published': '2026-03-10',
        'series_id': 99,
        'series_title': 'Special Collection',
        'images': [
          'https://img.ygjgl.one/1.jpg',
          'https://img.ygjgl.one/2.jpg',
        ],
        'images_count': 2,
        'views': 999,
        'likes': 50,
      };

      final post = YgjglPostItem.fromJson(json, defaultKind: 'image');
      expect(post.isImage, isTrue);
      expect(post.isAudio, isFalse);
      expect(post.imageCount, 2);

      final album = post.toAlbumItem();
      expect(album.title, 'Sweet Cosplay Photo Session');
      expect(album.slug, 'post_img_001');
      expect(album.detailUrl, 'https://ygjgl.one/post?id=post_img_001');
      expect(album.author, 'Special Collection');
      expect(album.sourceType, MediaSourceType.ygjgl);
      expect(album.imageUrls.length, 2);
    });

    test('Audio Post converts correctly to VideoItem', () {
      final json = {
        'id': 'post_audio_001',
        'title': 'Nightly Radio Broadcast #1',
        'kind': 'audio',
        'cover': 'https://img.ygjgl.one/cover/audio1.jpg',
        'tags': ['ASMR', 'Voice'],
        'published': '2026-03-15',
        'audio_url': 'https://stream.ygjgl.one/audio1.mp3',
        'duration': '18:30',
        'views': 450,
      };

      final post = YgjglPostItem.fromJson(json, defaultKind: 'audio');
      expect(post.isAudio, isTrue);
      expect(post.audioUrl, 'https://stream.ygjgl.one/audio1.mp3');

      final vItem = post.toVideoItem();
      expect(vItem.title, 'Nightly Radio Broadcast #1');
      expect(vItem.slug, 'post_audio_001');
      expect(vItem.detailUrl, 'https://ygjgl.one/post?id=post_audio_001');
      expect(vItem.videoUrl, 'https://stream.ygjgl.one/audio1.mp3');
      expect(vItem.duration, '18:30');
    });
  });

  group('YgjglBrowseProvider State Tests', () {
    test('Initial state and subTab switching', () {
      final prov = YgjglBrowseProvider();
      expect(prov.activeSubTab, 0);

      prov.setActiveSubTab(1);
      expect(prov.activeSubTab, 1);

      prov.setActiveSubTab(2);
      expect(prov.activeSubTab, 2);

      prov.setActiveSubTab(0);
      expect(prov.activeSubTab, 0);
    });

    test('Vod filter mutations update state', () {
      final prov = YgjglBrowseProvider();

      expect(prov.vodSort, 'pub_desc');
      prov.setVodSort('hot');
      expect(prov.vodSort, 'hot');

      prov.setVodKeyword('test keyword');
      expect(prov.vodKeyword, 'test keyword');

      prov.setVodRegion('国产');
      expect(prov.vodSelectedRegion, '国产');

      prov.setVodDate('2025', '06');
      expect(prov.vodSelectedYear, '2025');
      expect(prov.vodSelectedMonth, '06');
    });

    test('Image and Audio filter mutations', () {
      final prov = YgjglBrowseProvider();

      prov.setImageSort('views');
      expect(prov.imageSort, 'views');

      prov.setImageRange('week');
      expect(prov.imageRange, 'week');

      prov.setImageTag('黑丝');
      expect(prov.imageSelectedTag, '黑丝');

      prov.setAudioSort('hot');
      expect(prov.audioSort, 'hot');

      prov.setAudioTag('ASMR');
      expect(prov.audioSelectedTag, 'ASMR');
    });
  });
}
