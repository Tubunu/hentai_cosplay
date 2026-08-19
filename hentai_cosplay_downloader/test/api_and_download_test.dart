import 'package:flutter_test/flutter_test.dart';
import 'package:hentai_cosplay_downloader/models/album_item.dart';
import 'package:hentai_cosplay_downloader/models/app_config.dart';
import 'package:hentai_cosplay_downloader/models/download_task.dart';
import 'package:hentai_cosplay_downloader/models/history_record.dart';
import 'package:hentai_cosplay_downloader/services/hc_api_service.dart';

void main() {
  group('HCApiService URL and Parser Tests', () {
    test('buildSearchUrl generates correct URLs', () {
      expect(
        HCApiService.buildSearchUrl(page: 1),
        'https://zh.hentai-cosplay-xxx.com/',
      );
      expect(
        HCApiService.buildSearchUrl(page: 2),
        'https://zh.hentai-cosplay-xxx.com/page/2/',
      );
      expect(
        HCApiService.buildSearchUrl(page: 15),
        'https://zh.hentai-cosplay-xxx.com/page/15/',
      );
      expect(
        HCApiService.buildSearchUrl(page: 1, keyword: 'byoru'),
        'https://zh.hentai-cosplay-xxx.com/search/keyword/byoru/',
      );
      expect(
        HCApiService.buildSearchUrl(page: 3, keyword: 'byoru'),
        'https://zh.hentai-cosplay-xxx.com/search/keyword/byoru/page/3/',
      );
      expect(
        HCApiService.buildSearchUrl(page: 1, keyword: '焖焖碳'),
        'https://zh.hentai-cosplay-xxx.com/search/keyword/%E7%84%96%E7%84%96%E7%A2%B3/',
      );
      expect(
        HCApiService.buildSearchUrl(page: 2, keyword: '焖焖碳'),
        'https://zh.hentai-cosplay-xxx.com/search/keyword/%E7%84%96%E7%84%96%E7%A2%B3/page/2/',
      );
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
        detailUrl: 'https://zh.hentai-cosplay-xxx.com/image/sample/',
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
}
