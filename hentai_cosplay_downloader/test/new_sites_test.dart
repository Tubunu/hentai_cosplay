import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hentai_cosplay_downloader/models/iwara_category.dart';
import 'package:hentai_cosplay_downloader/models/rule34video_category.dart';
import 'package:hentai_cosplay_downloader/services/iwara/iwara_api_service.dart';
import 'package:hentai_cosplay_downloader/services/rule34video/rule34video_api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    HttpOverrides.global = null;
    IwaraApiService.setProxy('127.0.0.1:7897');
    Rule34VideoApiService.setProxy('127.0.0.1:7897');
  });

  test('Test Iwara categories, search and video detail resolution', () async {
    for (final cat in IwaraCategory.values) {
      print('Testing Iwara category: ${cat.label} (sort=${cat.sort}, rating=${cat.rating})...');
      final data = await IwaraApiService.fetchPageData(page: 1, category: cat);
      expect(data.items, isNotEmpty, reason: 'Failed for Iwara category ${cat.label}');
      print('=> [${cat.label}] Success! Fetched ${data.items.length} items (Total: ${data.totalCount}). First: ${data.items.first.title}');
    }

    print('Testing Iwara search "genshin"...');
    final searchData = await IwaraApiService.fetchPageData(page: 1, searchKeyword: 'genshin');
    expect(searchData.items, isNotEmpty, reason: 'Failed for Iwara search');
    print('=> [Iwara Search] Success! Fetched ${searchData.items.length} items. First: ${searchData.items.first.title}');

    print('Testing Iwara video detail resolution on: ${searchData.items.first.detailUrl}...');
    final resolved = await IwaraApiService.resolveVideoDetail(searchData.items.first);
    expect(resolved.videoUrl, isNotNull);
    final qualities = resolved.rawData['qualities'] as Map<String, dynamic>?;
    print('=> Iwara Detail: ${resolved.title} | Qualities: $qualities | VideoUrl: ${resolved.videoUrl}');
  });

  test('Test Rule34Video categories, search and video detail resolution', () async {
    for (final cat in Rule34VideoCategory.values) {
      print('Testing Rule34Video category: ${cat.label} (${cat.path})...');
      final data = await Rule34VideoApiService.fetchPageData(page: 1, category: cat);
      expect(data.items, isNotEmpty, reason: 'Failed for Rule34Video category ${cat.label}');
      print('=> [${cat.label}] Success! Fetched ${data.items.length} items (Page: ${data.currentPage}/${data.totalPages}). First: ${data.items.first.title}');
    }

    print('Testing Rule34Video search "genshin"...');
    final searchData = await Rule34VideoApiService.fetchPageData(page: 1, searchKeyword: 'genshin');
    expect(searchData.items, isNotEmpty, reason: 'Failed for Rule34Video search');
    print('=> [Rule34Video Search] Success! Fetched ${searchData.items.length} items. First: ${searchData.items.first.title}');

    print('Testing Rule34Video video detail resolution on: ${searchData.items.first.detailUrl}...');
    final resolved = await Rule34VideoApiService.resolveVideoDetail(searchData.items.first);
    expect(resolved.videoUrl, isNotNull);
    final qualities = resolved.rawData['qualities'] as Map<String, dynamic>?;
    print('=> Rule34Video Detail: ${resolved.title} | Qualities: $qualities | VideoUrl: ${resolved.videoUrl}');
  });
}
