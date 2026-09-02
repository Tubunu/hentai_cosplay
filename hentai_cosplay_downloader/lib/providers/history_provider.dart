import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/history_record.dart';
import '../services/storage_service.dart';

class HistoryProvider extends ChangeNotifier {
  static const String _kHistoryKey = 'hentai_cosplay_history_records';
  List<HistoryRecord> _records = [];
  bool _disposed = false;

  List<HistoryRecord> _imageRecords = [];
  List<HistoryRecord> _videoRecords = [];
  int _imageTotalImages = 0;
  int _imageTotalBytes = 0;
  int _videoTotalBytes = 0;

  final Set<String> _videoTitles = {};
  final Set<String> _videoDetailUrls = {};
  final Set<String> _albumTitles = {};
  final Set<String> _albumDetailUrls = {};

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

  List<HistoryRecord> get records => List.unmodifiable(_records);
  List<HistoryRecord> get imageRecords => List.unmodifiable(_imageRecords);
  List<HistoryRecord> get videoRecords => List.unmodifiable(_videoRecords);

  int get totalAlbums => _records.length;
  int get totalImages => _imageTotalImages;
  int get totalBytes => _imageTotalBytes + _videoTotalBytes;

  int get imageTotalImages => _imageTotalImages;
  int get imageTotalBytes => _imageTotalBytes;
  int get videoTotalBytes => _videoTotalBytes;

  HistoryProvider() {
    _loadHistory();
  }

  bool isVideoRecorded({required String title, String detailUrl = ''}) {
    if (_videoTitles.contains(title)) return true;
    if (detailUrl.isNotEmpty && _videoDetailUrls.contains(detailUrl)) return true;
    return false;
  }

  bool isAlbumRecorded({required String title, String detailUrl = ''}) {
    if (_albumTitles.contains(title)) return true;
    if (detailUrl.isNotEmpty && _albumDetailUrls.contains(detailUrl)) return true;
    return false;
  }

  void _rebuildCacheAndIndices() {
    final imgList = <HistoryRecord>[];
    final vidList = <HistoryRecord>[];
    int imgImgCount = 0;
    int imgBytes = 0;
    int vidBytes = 0;

    _videoTitles.clear();
    _videoDetailUrls.clear();
    _albumTitles.clear();
    _albumDetailUrls.clear();

    for (final r in _records) {
      if (r.isVideo) {
        vidList.add(r);
        vidBytes += r.downloadedBytes;
        if (r.title.isNotEmpty) _videoTitles.add(r.title);
        if (r.detailUrl.isNotEmpty) _videoDetailUrls.add(r.detailUrl);
      } else {
        imgList.add(r);
        imgImgCount += r.imageCount;
        imgBytes += r.downloadedBytes;
        if (r.title.isNotEmpty) _albumTitles.add(r.title);
        if (r.detailUrl.isNotEmpty) _albumDetailUrls.add(r.detailUrl);
      }
    }

    _imageRecords = imgList;
    _videoRecords = vidList;
    _imageTotalImages = imgImgCount;
    _imageTotalBytes = imgBytes;
    _videoTotalBytes = vidBytes;
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final listStr = prefs.getStringList(_kHistoryKey);
    if (listStr != null) {
      _records = listStr
          .map((s) {
            try {
              return HistoryRecord.fromJson(jsonDecode(s) as Map<String, dynamic>);
            } catch (_) {
              return null;
            }
          })
          .whereType<HistoryRecord>()
          .toList();
      _records.sort((a, b) => b.completedAt.compareTo(a.completedAt));
      _rebuildCacheAndIndices();
      notifyListeners();

      // Recalculate zero bytes asynchronously in background without delaying initial UI
      Future.microtask(() async {
        if (_disposed) return;
        bool hasUpdates = false;
        final updated = List<HistoryRecord>.from(_records);
        for (int i = 0; i < updated.length; i++) {
          if (_disposed) return;
          final r = updated[i];
          if (r.downloadedBytes == 0 && r.targetFolder.isNotEmpty && !r.isVideo) {
            final size = await StorageService.getFolderSize(r.targetFolder);
            if (size > 0) {
              updated[i] = r.copyWith(downloadedBytes: size);
              hasUpdates = true;
            }
          }
        }
        if (hasUpdates && !_disposed) {
          _records = updated;
          _rebuildCacheAndIndices();
          notifyListeners();
          await _saveHistory();
        }
      });
    }
  }

  Future<void> addRecord(HistoryRecord record) async {
    var rec = record;
    if (rec.downloadedBytes == 0 && rec.targetFolder.isNotEmpty && !rec.isVideo) {
      final size = await StorageService.getFolderSize(rec.targetFolder);
      if (size > 0) {
        rec = rec.copyWith(downloadedBytes: size);
      }
    }

    _records.removeWhere((r) =>
        r.id == rec.id ||
        (rec.detailUrl.isNotEmpty && r.detailUrl == rec.detailUrl) ||
        (rec.id.isEmpty && r.title == rec.title));
    _records.insert(0, rec);
    _rebuildCacheAndIndices();
    notifyListeners();
    await _saveHistory();
  }

  Future<void> removeRecord(String id) async {
    _records.removeWhere((r) => r.id == id);
    _rebuildCacheAndIndices();
    notifyListeners();
    await _saveHistory();
  }

  Future<void> removeRecords(List<String> ids) async {
    if (ids.isEmpty) return;
    final idSet = ids.toSet();
    _records.removeWhere((r) => idSet.contains(r.id));
    _rebuildCacheAndIndices();
    notifyListeners();
    await _saveHistory();
  }

  Future<void> clearAll() async {
    _records.clear();
    _rebuildCacheAndIndices();
    notifyListeners();
    await _saveHistory();
  }

  Future<void> clearByType({required bool isVideo}) async {
    _records.removeWhere((r) => r.isVideo == isVideo);
    _rebuildCacheAndIndices();
    notifyListeners();
    await _saveHistory();
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listStr = _records.map((r) => r.toRawJson()).toList();
      await prefs.setStringList(_kHistoryKey, listStr);
    } catch (e) {
      debugPrint('Error saving history: $e');
    }
  }
}
