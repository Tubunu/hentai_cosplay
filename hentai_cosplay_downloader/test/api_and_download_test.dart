import 'package:flutter_test/flutter_test.dart';
import 'package:hentai_cosplay_downloader/models/album_item.dart';
import 'package:hentai_cosplay_downloader/models/app_config.dart';
import 'package:hentai_cosplay_downloader/models/download_task.dart';
import 'package:hentai_cosplay_downloader/models/history_record.dart';
import 'package:hentai_cosplay_downloader/models/video_item.dart';
import 'package:hentai_cosplay_downloader/services/hc_api_service.dart';
import 'package:hentai_cosplay_downloader/services/video_api_service.dart';

void main() {
  group('HCApiService URL and Parser Tests', () {
    test('buildBrowseUrl and buildSearchUrl generate correct URLs', () {
      // Latest Category (默认最新)
      expect(
        HCApiService.buildBrowseUrl(category: BrowseCategory.latest, page: 1),
        'https://zh.hentai-cosplay-xxx.com/search/',
      );
      expect(
        HCApiService.buildBrowseUrl(category: BrowseCategory.latest, page: 2),
        'https://zh.hentai-cosplay-xxx.com/search/page/2/',
      );

      // Ranking Category (热门文章)
      expect(
        HCApiService.buildBrowseUrl(category: BrowseCategory.ranking, page: 1),
        'https://zh.hentai-cosplay-xxx.com/ranking/',
      );
      expect(
        HCApiService.buildBrowseUrl(category: BrowseCategory.ranking, page: 2),
        'https://zh.hentai-cosplay-xxx.com/ranking/page/2/',
      );

      // Download Ranking (下载排行)
      expect(
        HCApiService.buildBrowseUrl(category: BrowseCategory.rankingDownload, page: 1),
        'https://zh.hentai-cosplay-xxx.com/ranking-download/',
      );
      expect(
        HCApiService.buildBrowseUrl(category: BrowseCategory.rankingDownload, page: 3),
        'https://zh.hentai-cosplay-xxx.com/ranking-download/page/3/',
      );

      // Bookmark Ranking (收藏排行)
      expect(
        HCApiService.buildBrowseUrl(category: BrowseCategory.rankingBookmark, page: 1),
        'https://zh.hentai-cosplay-xxx.com/ranking-bookmark/',
      );
      expect(
        HCApiService.buildBrowseUrl(category: BrowseCategory.rankingBookmark, page: 4),
        'https://zh.hentai-cosplay-xxx.com/ranking-bookmark/page/4/',
      );

      // Like Ranking (点赞排行)
      expect(
        HCApiService.buildBrowseUrl(category: BrowseCategory.rankingLike, page: 1),
        'https://zh.hentai-cosplay-xxx.com/ranking-like/',
      );
      expect(
        HCApiService.buildBrowseUrl(category: BrowseCategory.rankingLike, page: 5),
        'https://zh.hentai-cosplay-xxx.com/ranking-like/page/5/',
      );

      // Tag Search (标签浏览)
      expect(
        HCApiService.buildBrowseUrl(tag: 'cosplay', page: 1),
        'https://zh.hentai-cosplay-xxx.com/search/tag/cosplay/',
      );
      expect(
        HCApiService.buildBrowseUrl(tag: 'cosplay', page: 2),
        'https://zh.hentai-cosplay-xxx.com/search/tag/cosplay/page/2/',
      );

      // Keyword Search (搜索词)
      expect(
        HCApiService.buildBrowseUrl(keyword: '焖焖碳', page: 1),
        'https://zh.hentai-cosplay-xxx.com/search/keyword/%E7%84%96%E7%84%96%E7%A2%B3/',
      );
      expect(
        HCApiService.buildBrowseUrl(keyword: '焖焖碳', page: 2),
        'https://zh.hentai-cosplay-xxx.com/search/keyword/%E7%84%96%E7%84%96%E7%A2%B3/page/2/',
      );

      // Ranking Tags & Keywords URLs
      expect(
        HCApiService.buildRankingTagsUrl(isTag: true, page: 1),
        'https://zh.hentai-cosplay-xxx.com/ranking-tag/',
      );
      expect(
        HCApiService.buildRankingTagsUrl(isTag: true, page: 2),
        'https://zh.hentai-cosplay-xxx.com/ranking-tag/page/2/',
      );
      expect(
        HCApiService.buildRankingTagsUrl(isTag: false, page: 1),
        'https://zh.hentai-cosplay-xxx.com/ranking-keyword/',
      );
      expect(
        HCApiService.buildRankingTagsUrl(isTag: false, page: 3),
        'https://zh.hentai-cosplay-xxx.com/ranking-keyword/page/3/',
      );
    });

    test('parseRankingTags parses tags and search keywords with counts', () {
      const mockTagsHtml = '''
<div id="display_area_tag">
  <ul>
    <li>
      <a href="https://zh.hentai-cosplay-xxx.com/search/tag/cosplay/">cosplay</a>
      <span>(15,420)</span>
    </li>
    <li>
      <a href="/search/tag/genshin-impact/">原神</a>
      <span>(3280)</span>
    </li>
  </ul>
</div>
      ''';

      final tags = HCApiService.parseRankingTags(mockTagsHtml, true);
      expect(tags.length, 2);
      expect(tags[0].name, 'cosplay');
      expect(tags[0].count, '15420');
      expect(tags[0].targetUrl, 'https://zh.hentai-cosplay-xxx.com/search/tag/cosplay/');
      expect(tags[1].name, '原神');
      expect(tags[1].count, '3280');
    });

    test('parseAlbumList extracts items from HTML snippet', () {
      const mockHtml = '''
<div id="display_area_image">
  <ul id="image-list" class="clearfix">
    <li>
      <div class="image-list-item">
        <div class="image-list-item-image">
          <a href="/image/byoru-zenith-maid/">
            <img src="https://static17.hentai-cosplay-xxx.com/upload/20260404/436/446230/p=160x200/31.jpg" alt="Byoru – Zenith Maid"/>
          </a>
        </div>
        <p class="image-list-item-title">
          <a href="/image/byoru-zenith-maid/">Byoru – Zenith Maid</a>
        </p>
        <p class="image-list-item-regist-date">
          <span>2026/08/15</span>
        </p>
      </div>
    </li>
    <li>
      <div class="image-list-item">
        <div class="image-list-item-image">
          <a href="/image/coser-hoshilily-azur-route-shinano-swimsuit-53p/">
            <img src="https://static17.hentai-cosplay-xxx.com/upload/20260512/439/449027/p=160x200/44.jpg" alt="Coser@ Hoshilily - Azur Route Shinano Swimsuit (53P)"/>
          </a>
        </div>
        <p class="image-list-item-title">
          <a href="/image/coser-hoshilily-azur-route-shinano-swimsuit-53p/">Coser@ Hoshilily - Azur Route Shinano Swimsuit (53P)</a>
        </p>
        <p class="image-list-item-regist-date">
          <span>2026/08/15</span>
        </p>
      </div>
    </li>
  </ul>
</div>
<div class="wp-pagenavi">
  <a class="last" href="/search/page/18339/">最后一页 &gt;&gt;</a>
</div>
      ''';

      final items = HCApiService.parseAlbumList(mockHtml);
      expect(items.length, 2);

      expect(items[0].title, 'Byoru – Zenith Maid');
      expect(items[0].slug, 'byoru-zenith-maid');
      expect(items[0].detailUrl, 'https://zh.hentai-cosplay-xxx.com/image/byoru-zenith-maid/');
      expect(items[0].coverUrl, 'https://static17.hentai-cosplay-xxx.com/upload/20260404/436/446230/p=160x200/31.jpg');
      expect(items[0].author, 'Byoru');
      expect(items[0].date, '2026/08/15');

      expect(items[1].title, 'Coser@ Hoshilily - Azur Route Shinano Swimsuit (53P)');
      expect(items[1].author, 'Hoshilily');

      final totalPages = HCApiService.parseTotalPages(mockHtml, items.length);
      expect(totalPages, 18339);
    });

    test('parseAlbumList strictly ignores secondary sections like recent downloads and hot posts', () {
      const mockFullPageHtml = '''
<div id="post_list_title">
  <h2>新到图像列表</h2>
</div>
<div id="display_area_image">
  <ul id="image-list" class="clearfix">
    <li>
      <div class="image-list-item">
        <div class="image-list-item-image">
          <a href="/image/main-item-1/"><img src="https://static.site/1.jpg" alt="Main Item 1"/></a>
        </div>
        <p class="image-list-item-title"><a href="/image/main-item-1/">Main Item 1</a></p>
        <p class="image-list-item-regist-date"><span>2026/08/17</span></p>
      </div>
    </li>
  </ul>
</div>
<div class="wp-pagenavi">
  <a class="last" href="/search/page/100/">100</a>
</div>
<div id="recent_download_post">
  <h3>最近下载</h3>
  <div class="image-list-item">
    <div class="image-list-item-image">
      <a href="/image/recent-sidebar-item/"><img src="https://static.site/2.jpg" alt="Sidebar Item"/></a>
    </div>
    <p class="image-list-item-title"><a href="/image/recent-sidebar-item/">Sidebar Item</a></p>
    <p class="image-list-item-regist-date"><span>2026/08/17</span></p>
  </div>
</div>
      ''';

      final items = HCApiService.parseAlbumList(mockFullPageHtml);
      expect(items.length, 1);
      expect(items[0].title, 'Main Item 1');
    });
  });

  group('AlbumItem and Model Tests', () {
    test('inferAuthor parses various title formats', () {
      expect(AlbumItem.inferAuthor('Byoru – Zenith Maid'), 'Byoru');
      expect(AlbumItem.inferAuthor('Coser@星之迟迟: 鸣潮 尤诺'), '星之迟迟');
      expect(AlbumItem.inferAuthor('【贤儿sherry】鸣潮cos合集'), '贤儿sherry');
      expect(AlbumItem.inferAuthor('Umeko J - Liliel 2'), 'Umeko J');
    });

    test('cleanFilename strips invalid characters', () {
      expect(AlbumItem.cleanFilename('Test/Title: With*Invalid?"Chars"|'), 'Test_Title_ With_Invalid__Chars__');
    });

    test('resolveExt extracts extensions', () {
      expect(AlbumItem.resolveExt('https://static.site.com/upload/1.jpg'), 'jpg');
      expect(AlbumItem.resolveExt('https://static.site.com/upload/2.webp'), 'webp');
      expect(AlbumItem.resolveExt('https://static.site.com/upload/3.png'), 'png');
    });

    test('AppConfig and HistoryRecord serialization', () {
      final config = AppConfig(savePath: 'D:/Photos', packWorkers: 4, imgWorkers: 16);
      final json = config.toJson();
      final restoredConfig = AppConfig.fromJson(json);
      expect(restoredConfig.savePath, 'D:/Photos');
      expect(restoredConfig.packWorkers, 4);
      expect(restoredConfig.imgWorkers, 16);

      final record = HistoryRecord(
        id: '123',
        title: 'Sample Album',
        author: 'Sample Coser',
        targetFolder: 'D:/Photos/Sample',
        imageCount: 50,
        downloadedBytes: 1024000,
        completedAt: DateTime(2026, 8, 15),
        detailUrl: 'https://hentai-cosplay-xxx.com/image/sample/',
      );
      final recordJson = record.toJson();
      final restoredRecord = HistoryRecord.fromJson(recordJson);
      expect(restoredRecord.id, '123');
      expect(restoredRecord.title, 'Sample Album');
      expect(restoredRecord.imageCount, 50);
    });

    test('AlbumDownloadTask persistence listToJson and listFromJson', () {
      final task = AlbumDownloadTask(
        id: 'task_1',
        albumItem: AlbumItem(
          title: 'Test Album',
          slug: 'test-album',
          author: 'Test Author',
          date: '2026/08/17',
          detailUrl: 'https://zh.hentai-cosplay-xxx.com/image/test-album/',
        ),
        targetFolder: 'D:/Photos/Test',
        status: TaskStatus.completed,
        totalImages: 30,
        downloadedImages: 28,
        skippedImages: 2,
      );

      final jsonStr = AlbumDownloadTask.listToJson([task]);
      final restoredList = AlbumDownloadTask.listFromJson(jsonStr);
      expect(restoredList.length, 1);
      expect(restoredList[0].id, 'task_1');
      expect(restoredList[0].albumItem.title, 'Test Album');
      expect(restoredList[0].status, TaskStatus.completed);
      expect(restoredList[0].downloadedImages, 28);
      expect(restoredList[0].skippedImages, 2);
    });

    test('parseDetailTotalPages detects multi-page albums with >100 images', () {
      const singlePageHtml = '''
<div id="display_area_image">
  <div class="icon-overlay"><a href="https://img.site/1.jpg"><img src="https://img.site/t1.jpg"/></a></div>
</div>
      ''';
      expect(HCApiService.parseDetailTotalPages(singlePageHtml), 1);

      const multiPageHtml = '''
<div id="display_area_image">
  <div class="icon-overlay"><a href="https://img.site/1.jpg"><img src="https://img.site/t1.jpg"/></a></div>
</div>
<div class="wp-pagenavi">
  <span class="pages">1/3</span>
  <span class="current">1</span>
  <a class="page larger" href="/image/poppachan-cipher-1/page/2/">2</a>
  <a class="page larger" href="/image/poppachan-cipher-1/page/3/">3</a>
  <a class="last" href="/image/poppachan-cipher-1/page/3/">最后一页 &gt;&gt;</a>
</div>
      ''';
      expect(HCApiService.parseDetailTotalPages(multiPageHtml), 3);
    });
  });

  group('VideoApiService and Video Model Tests', () {
    test('buildBrowseUrl generates correct video routing URLs for all 9 categories', () {
      // 1. LATEST 最新
      expect(
        VideoApiService.buildBrowseUrl(category: VideoCategory.latest, page: 1),
        'https://porn-video-xxx.com/latest/',
      );
      expect(
        VideoApiService.buildBrowseUrl(category: VideoCategory.latest, page: 2),
        'https://porn-video-xxx.com/latest/page/2/',
      );

      // 2. RANKING 排行榜
      expect(
        VideoApiService.buildBrowseUrl(category: VideoCategory.ranking, page: 1),
        'https://porn-video-xxx.com/ranking/',
      );
      expect(
        VideoApiService.buildBrowseUrl(category: VideoCategory.ranking, page: 3),
        'https://porn-video-xxx.com/ranking/page/3/',
      );

      // 3. RANKING DAY 日榜
      expect(
        VideoApiService.buildBrowseUrl(category: VideoCategory.rankingDay, page: 1),
        'https://porn-video-xxx.com/ranking/type/day/',
      );
      expect(
        VideoApiService.buildBrowseUrl(category: VideoCategory.rankingDay, page: 2),
        'https://porn-video-xxx.com/ranking/type/day/page/2/',
      );

      // 4. RANKING WEEK 周排行榜
      expect(
        VideoApiService.buildBrowseUrl(category: VideoCategory.rankingWeek, page: 1),
        'https://porn-video-xxx.com/ranking/type/week/',
      );

      // 5. RANKING MONTH 月度排行榜
      expect(
        VideoApiService.buildBrowseUrl(category: VideoCategory.rankingMonth, page: 1),
        'https://porn-video-xxx.com/ranking/type/month/',
      );

      // 6. RANKING PLAY 播放排行榜
      expect(
        VideoApiService.buildBrowseUrl(category: VideoCategory.rankingPlay, page: 1),
        'https://porn-video-xxx.com/ranking-play/',
      );
      expect(
        VideoApiService.buildBrowseUrl(category: VideoCategory.rankingPlay, page: 5),
        'https://porn-video-xxx.com/ranking-play/page/5/',
      );

      // 7. RANKING DOWNLOAD 下载排行榜
      expect(
        VideoApiService.buildBrowseUrl(category: VideoCategory.rankingDownload, page: 1),
        'https://porn-video-xxx.com/ranking-download/',
      );

      // 8. RANKING BOOKMARK 收藏排行
      expect(
        VideoApiService.buildBrowseUrl(category: VideoCategory.rankingBookmark, page: 1),
        'https://porn-video-xxx.com/bookmark/',
      );

      // 9. RANKING GOOD 好评排行
      expect(
        VideoApiService.buildBrowseUrl(category: VideoCategory.rankingGood, page: 1),
        'https://porn-video-xxx.com/evaluation/',
      );

      // TAG 标签浏览
      expect(
        VideoApiService.buildBrowseUrl(tag: 'cosplay', page: 1),
        'https://porn-video-xxx.com/search/tag/cosplay/',
      );
      expect(
        VideoApiService.buildBrowseUrl(tag: 'cosplay', page: 2),
        'https://porn-video-xxx.com/search/tag/cosplay/page/2/',
      );

      // 关键词搜索
      expect(
        VideoApiService.buildBrowseUrl(keyword: 'cosplay', page: 1),
        'https://porn-video-xxx.com/search/keyword/cosplay/',
      );
      expect(
        VideoApiService.buildBrowseUrl(keyword: 'cosplay', page: 2),
        'https://porn-video-xxx.com/search/keyword/cosplay/page/2/',
      );

      // TAG 列表
      expect(
        VideoApiService.buildTagsUrl(page: 1),
        'https://porn-video-xxx.com/tag-list/all/',
      );
      expect(
        VideoApiService.buildTagsUrl(page: 2),
        'https://porn-video-xxx.com/tag-list/all/page/2/',
      );
    });

    test('parseVideoList and parseVideoDetail accurately extracts video metadata and links', () {
      const sampleHtml = '''
<ul id="video-list">
  <li class="video-list-item">
    <a href="/video/cosplay-girl-dance-1080p/">
      <img src="https://static.pv.com/cover/1.jpg" alt="[Coser Alice] Cute Bunny Girl Dance 4K" />
      <p class="title"><a>[Coser Alice] Cute Bunny Girl Dance 4K</a></p>
      <span class="duration">12:34</span>
      <span class="regist-date">2026/08/18</span>
    </a>
  </li>
</ul>
<div class="wp-pagenavi">
  <span class="pages">1/10</span>
  <span class="current">1</span>
  <a class="page larger" href="/latest/page/2/">2</a>
  <a class="last" href="/latest/page/10/">最后一页</a>
</div>
      ''';

      final items = VideoApiService.parseVideoList(sampleHtml);
      expect(items.length, 1);
      expect(items[0].title, '[Coser Alice] Cute Bunny Girl Dance 4K');
      expect(items[0].author, 'Alice');
      expect(items[0].duration, '12:34');
      expect(items[0].coverUrl, 'https://static.pv.com/cover/1.jpg');

      final totalPages = VideoApiService.parseTotalPages(sampleHtml, 1, items.length);
      expect(totalPages, 10);

      const detailHtml = '''
<script type="application/ld+json">
{
  "@type": "VideoObject",
  "name": "Cute Bunny Girl Dance 4K",
  "contentUrl": "https://stream.pv.com/videos/alice_bunny/video.m3u8",
  "thumbnailUrl": "https://static.pv.com/poster/1.jpg"
}
</script>
<video poster="https://static.pv.com/poster/1.jpg">
  <source src="https://stream.pv.com/videos/alice_bunny/video.m3u8" type="application/x-mpegURL" />
</video>
<p id="detail_tag">
  <a href="/search/tag/cosplay/">cosplay</a>
  <a href="/search/tag/bunny/">bunny</a>
</p>
      ''';

      final detailed = VideoApiService.parseVideoDetail(detailHtml, items[0]);
      expect(detailed.videoUrl, 'https://stream.pv.com/videos/alice_bunny/video.m3u8');
      expect(detailed.tags, containsAll(['cosplay', 'bunny']));
    });
  });
}
