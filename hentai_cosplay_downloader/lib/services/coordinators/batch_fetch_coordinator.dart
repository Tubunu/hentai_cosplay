import 'package:flutter/foundation.dart';
import '../../models/album_item.dart';
import '../../models/video_item.dart';
import '../coomer/coomer_api_service.dart';
import '../exhentai/exhentai_api_service.dart';
import '../hc_api_service.dart';
import '../kuraa/kuraa_api_service.dart';
import '../misskon/misskon_api_service.dart';
import '../mzt_api_service.dart';
import '../pinse/pinse_api_service.dart';
import '../pornbox/pornbox_api_service.dart';
import '../twitter_rankings/twitter_ranking_api_service.dart';
import '../twitter_rankings/twitter_site_config.dart';
import '../video_api_service.dart';

class BatchFetchCoordinator {
  /// 批量获取最大并发数，避免串行卡顿或高并发限流
  static const int _kBatchConcurrency = 3;

  Future<List<AlbumItem>> fetchHcPageRange(int startPage, int endPage, {String? keyword}) async {
    final List<AlbumItem> allItems = [];
    final pages = List.generate(endPage - startPage + 1, (i) => startPage + i);

    for (int i = 0; i < pages.length; i += _kBatchConcurrency) {
      final batch = pages.skip(i).take(_kBatchConcurrency);
      final results = await Future.wait(
        batch.map((p) async {
          try {
            return await HCApiService.fetchPageData(page: p, keyword: keyword);
          } catch (e) {
            debugPrint('Error fetching page $p during batch range download: $e');
            return null;
          }
        }),
      );
      for (final pageData in results) {
        if (pageData != null && pageData.items.isNotEmpty) {
          allItems.addAll(pageData.items);
        }
      }
    }
    return allItems;
  }

  Future<List<AlbumItem>> fetchMztPageRange(int startPage, int endPage) async {
    final List<AlbumItem> allItems = [];
    final pages = List.generate(endPage - startPage + 1, (i) => startPage + i);

    for (int i = 0; i < pages.length; i += _kBatchConcurrency) {
      final batch = pages.skip(i).take(_kBatchConcurrency);
      final results = await Future.wait(
        batch.map((p) async {
          try {
            return await MztApiService.fetchPageData(page: p, pageSize: 12);
          } catch (e) {
            debugPrint('Error fetching MZT page $p during batch range download: $e');
            return null;
          }
        }),
      );
      for (final pageData in results) {
        if (pageData != null && pageData.items.isNotEmpty) {
          allItems.addAll(pageData.items);
        }
      }
    }
    return allItems;
  }

  Future<List<AlbumItem>> fetchMisskonPageRange(
    int startPage,
    int endPage, {
    MisskonCategory category = MisskonCategory.latest,
    String? tag,
    String? keyword,
  }) async {
    final List<AlbumItem> allItems = [];
    final pages = List.generate(endPage - startPage + 1, (i) => startPage + i);

    for (int i = 0; i < pages.length; i += _kBatchConcurrency) {
      final batch = pages.skip(i).take(_kBatchConcurrency);
      final results = await Future.wait(
        batch.map((p) async {
          try {
            return await MisskonApiService.fetchPageData(
              page: p,
              category: category,
              tag: tag,
              keyword: keyword,
            );
          } catch (e) {
            debugPrint('Error fetching MissKon page $p during batch range download: $e');
            return null;
          }
        }),
      );
      for (final pageData in results) {
        if (pageData != null && pageData.items.isNotEmpty) {
          allItems.addAll(pageData.items);
        }
      }
    }
    return allItems;
  }

  Future<List<AlbumItem>> fetchCoomerPageRange(
    int startPage,
    int endPage, {
    String? service,
    String? query,
    CoomerCreator? creator,
  }) async {
    final List<AlbumItem> allItems = [];
    final pages = List.generate(endPage - startPage + 1, (i) => startPage + i);

    for (int i = 0; i < pages.length; i += _kBatchConcurrency) {
      final batch = pages.skip(i).take(_kBatchConcurrency);
      final results = await Future.wait(
        batch.map((p) async {
          try {
            final offset = (p - 1) * 40;
            if (creator != null) {
              return await CoomerApiService.fetchCreatorPosts(
                service: creator.service,
                creatorId: creator.id,
                offset: offset,
                limit: 40,
              );
            } else {
              return await CoomerApiService.fetchRecentPosts(
                offset: offset,
                limit: 40,
                service: service == 'all' ? null : service,
                query: query,
              );
            }
          } catch (e) {
            debugPrint('Error fetching Coomer page $p during batch range download: $e');
            return null;
          }
        }),
      );
      for (final pageData in results) {
        if (pageData != null && pageData.items.isNotEmpty) {
          allItems.addAll(pageData.items);
        }
      }
    }
    return allItems;
  }

  Future<List<VideoItem>> fetchPinsePageRange(
    int startPage,
    int endPage, {
    PinseCategory category = PinseCategory.latest,
    String? keyword,
    String? author,
  }) async {
    final List<VideoItem> allVideos = [];
    final pages = List.generate(endPage - startPage + 1, (i) => startPage + i);

    for (int i = 0; i < pages.length; i += _kBatchConcurrency) {
      final batch = pages.skip(i).take(_kBatchConcurrency);
      final results = await Future.wait(
        batch.map((p) async {
          try {
            return await PinseApiService.fetchPageData(
              page: p,
              category: category,
              keyword: keyword,
              author: author,
            );
          } catch (e) {
            debugPrint('Error fetching 91品色 page $p during batch range download: $e');
            return null;
          }
        }),
      );
      for (final pageData in results) {
        if (pageData != null && pageData.items.isNotEmpty) {
          allVideos.addAll(pageData.items);
        }
      }
    }
    return allVideos;
  }

  Future<List<VideoItem>> fetchPornboxPageRange(
    int startPage,
    int endPage, {
    PornboxCategory category = PornboxCategory.latest,
    String? keyword,
    String? studio,
  }) async {
    final List<VideoItem> allVideos = [];
    final pages = List.generate(endPage - startPage + 1, (i) => startPage + i);

    for (int i = 0; i < pages.length; i += _kBatchConcurrency) {
      final batch = pages.skip(i).take(_kBatchConcurrency);
      final results = await Future.wait(
        batch.map((p) async {
          try {
            return await PornboxApiService.fetchPageData(
              page: p,
              category: category,
              keyword: keyword,
              studio: studio,
            );
          } catch (e) {
            debugPrint('Error fetching PornBox page $p during batch range download: $e');
            return null;
          }
        }),
      );
      for (final pageData in results) {
        if (pageData != null && pageData.items.isNotEmpty) {
          allVideos.addAll(pageData.items);
        }
      }
    }
    return allVideos;
  }

  Future<AlbumItem?> fetchKuraaAlbum(KuraaFileItem folderItem, {String? token}) async {
    try {
      final album = await KuraaApiService.fetchAlbumDetail(folderItem, token: token);
      if (album != null && album.imageUrls.isNotEmpty) {
        return album;
      }
    } catch (e) {
      debugPrint('Error adding Kuraa album task: $e');
    }
    return null;
  }

  Future<List<AlbumItem>> fetchKuraaPageRange(
    int startPage,
    int endPage, {
    required String storageLocationId,
    String? parentId,
    String? token,
  }) async {
    final List<AlbumItem> albums = [];
    const pageSize = 50;
    final pages = List.generate(endPage - startPage + 1, (i) => startPage + i);

    for (int i = 0; i < pages.length; i += _kBatchConcurrency) {
      final batch = pages.skip(i).take(_kBatchConcurrency);
      final results = await Future.wait(
        batch.map((p) async {
          try {
            final offset = (p - 1) * pageSize;
            return await KuraaApiService.fetchFiles(
              storageLocationId: storageLocationId,
              parentId: parentId,
              offset: offset,
              limit: pageSize,
              sortBy: 'updatedAt',
              sortOrder: 'desc',
              token: token,
            );
          } catch (e) {
            debugPrint('Error fetching Kuraa page $p during batch range download: $e');
            return null;
          }
        }),
      );

      for (final res in results) {
        if (res == null) continue;
        for (final item in res.items) {
          if (item.isFolder) {
            final alb = await fetchKuraaAlbum(item, token: token);
            if (alb != null) {
              albums.add(alb);
            }
          }
        }
      }
    }
    return albums;
  }

  Future<List<VideoItem>> fetchTwitterPageRange(
    int startPage,
    int endPage, {
    required TwitterSiteConfig site,
    String? range,
    String? sort,
  }) async {
    final List<VideoItem> allVideos = [];
    final pages = List.generate(endPage - startPage + 1, (i) => startPage + i);

    for (int i = 0; i < pages.length; i += _kBatchConcurrency) {
      final batch = pages.skip(i).take(_kBatchConcurrency);
      final results = await Future.wait(
        batch.map((p) async {
          try {
            return await TwitterRankingApiService.fetchPageData(
              site: site,
              range: range,
              sort: sort,
              page: p,
            );
          } catch (e) {
            debugPrint('Error fetching Twitter page $p during batch range download: $e');
            return null;
          }
        }),
      );

      for (final pageData in results) {
        if (pageData != null && pageData.items.isNotEmpty) {
          for (var v in pageData.items) {
            if (v.videoUrl == null || v.videoUrl!.isEmpty) {
              v = await TwitterRankingApiService.resolveVideoDetail(site, v);
            }
            allVideos.add(v);
          }
        }
      }
    }
    return allVideos;
  }

  Future<List<AlbumItem>> fetchExHentaiPageRange(
    int startPage,
    int endPage, {
    ExCategory category = ExCategory.all,
    String? keyword,
    bool isPopular = false,
  }) async {
    final List<AlbumItem> allAlbums = [];
    final pages = List.generate(endPage - startPage + 1, (i) => startPage + i);

    for (int i = 0; i < pages.length; i += _kBatchConcurrency) {
      final batch = pages.skip(i).take(_kBatchConcurrency);
      final results = await Future.wait(
        batch.map((p) async {
          try {
            return await ExHentaiApiService.fetchPageData(
              page: p,
              category: category,
              keyword: keyword,
              isPopular: isPopular,
            );
          } catch (e) {
            debugPrint('Error fetching ExHentai page $p during batch range download: $e');
            return null;
          }
        }),
      );
      for (final res in results) {
        if (res != null && res.items.isNotEmpty) {
          allAlbums.addAll(res.items);
        }
      }
    }
    return allAlbums;
  }

  Future<List<VideoItem>> fetchVideoPageRange(
    int startPage,
    int endPage, {
    VideoCategory category = VideoCategory.latest,
    String? keyword,
    String? tag,
  }) async {
    final List<VideoItem> allVideos = [];
    final pages = List.generate(endPage - startPage + 1, (i) => startPage + i);

    for (int i = 0; i < pages.length; i += _kBatchConcurrency) {
      final batch = pages.skip(i).take(_kBatchConcurrency);
      final results = await Future.wait(
        batch.map((p) async {
          try {
            return await VideoApiService.fetchVideoPageData(
              category: category,
              keyword: keyword,
              tag: tag,
              page: p,
            );
          } catch (e) {
            debugPrint('Error fetching video page $p during batch range download: $e');
            return null;
          }
        }),
      );
      for (final pageData in results) {
        if (pageData != null && pageData.items.isNotEmpty) {
          allVideos.addAll(pageData.items);
        }
      }
    }
    return allVideos;
  }
}
