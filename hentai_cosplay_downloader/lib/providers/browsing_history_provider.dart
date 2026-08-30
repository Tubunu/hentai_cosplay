import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/album_item.dart';
import '../models/browsing_history_record.dart';
import '../models/video_item.dart';

class BrowsingHistoryProvider extends ChangeNotifier {
  static const String _kStorageKey = 'hentai_cosplay_browsing_history_v1';
  static const int _kMaxRecords = 500;

  List<BrowsingHistoryRecord> _records = [];
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  List<BrowsingHistoryRecord> get records => List.unmodifiable(_records);
  int get totalCount => _records.length;

  BrowsingHistoryProvider() {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listStr = prefs.getStringList(_kStorageKey);
      if (listStr != null) {
        _records = listStr
            .map((s) {
              try {
                return BrowsingHistoryRecord.fromJson(
                    jsonDecode(s) as Map<String, dynamic>);
              } catch (_) {
                return null;
              }
            })
            .whereType<BrowsingHistoryRecord>()
            .toList();
        _records.sort((a, b) => b.viewedAt.compareTo(a.viewedAt));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading browsing history: $e');
    }
  }

  /// Automatically record a resource viewed by the user
  Future<void> recordBrowsing({
    required String title,
    String? coverUrl,
    required String detailUrl,
    String? videoUrl,
    String author = '',
    required String siteKey,
    required String siteName,
    required Color siteColor,
    bool isVideo = false,
    String? duration,
    String? slug,
    Map<String, dynamic>? extra,
  }) async {
    final effectiveSlug = slug ?? '';
    final recordId = effectiveSlug.isNotEmpty
        ? '${siteKey}_$effectiveSlug'
        : '${siteKey}_${detailUrl.hashCode}';

    final record = BrowsingHistoryRecord(
      id: recordId,
      title: title.trim().isNotEmpty ? title.trim() : '未命名资源',
      author: author.trim(),
      coverUrl: coverUrl,
      detailUrl: detailUrl,
      videoUrl: videoUrl,
      siteKey: siteKey,
      siteName: siteName,
      siteColorValue: siteColor.toARGB32(),
      isVideo: isVideo,
      duration: duration,
      viewedAt: DateTime.now(),
      extra: extra,
    );

    // Remove existing record with same detail URL / ID if present
    _records.removeWhere((r) =>
        r.id == recordId ||
        (r.detailUrl.isNotEmpty && r.detailUrl == record.detailUrl));

    // Prepend to top
    _records.insert(0, record);

    // Enforce max limit
    if (_records.length > _kMaxRecords) {
      _records = _records.sublist(0, _kMaxRecords);
    }

    notifyListeners();
    await _saveHistory();
  }

  /// Convenience for AlbumItem
  Future<void> recordAlbum(
    AlbumItem item, {
    required String siteKey,
    required String siteName,
    required Color siteColor,
    Map<String, dynamic>? extra,
  }) async {
    await recordBrowsing(
      title: item.title,
      coverUrl: item.coverUrl,
      detailUrl: item.detailUrl,
      author: item.author,
      siteKey: siteKey,
      siteName: siteName,
      siteColor: siteColor,
      isVideo: false,
      duration: item.imageUrls.isNotEmpty ? '${item.imageUrls.length}P' : null,
      slug: item.slug,
      extra: extra,
    );
  }

  /// Convenience for VideoItem
  Future<void> recordVideo(
    VideoItem item, {
    required String siteKey,
    required String siteName,
    required Color siteColor,
    Map<String, dynamic>? extra,
  }) async {
    await recordBrowsing(
      title: item.title,
      coverUrl: item.coverUrl,
      detailUrl: item.detailUrl,
      videoUrl: item.videoUrl,
      author: item.author,
      siteKey: siteKey,
      siteName: siteName,
      siteColor: siteColor,
      isVideo: true,
      duration: item.duration,
      slug: item.slug,
      extra: extra,
    );
  }

  /// Remove single record
  Future<void> removeRecord(String id) async {
    _records.removeWhere((r) => r.id == id);
    notifyListeners();
    await _saveHistory();
  }

  /// Clear all browsing history
  Future<void> clearAll() async {
    _records.clear();
    notifyListeners();
    await _saveHistory();
  }

  /// Clear records by site key
  Future<void> clearBySite(String siteKey) async {
    _records.removeWhere((r) => r.siteKey == siteKey);
    notifyListeners();
    await _saveHistory();
  }

  /// Clear records by type (video / album)
  Future<void> clearByType({required bool isVideo}) async {
    _records.removeWhere((r) => r.isVideo == isVideo);
    notifyListeners();
    await _saveHistory();
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listStr = _records.map((r) => r.toRawJson()).toList();
      await prefs.setStringList(_kStorageKey, listStr);
    } catch (e) {
      debugPrint('Error saving browsing history: $e');
    }
  }
}
