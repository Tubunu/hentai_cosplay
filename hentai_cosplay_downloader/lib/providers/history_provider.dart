import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/history_record.dart';
import '../services/storage_service.dart';

class HistoryProvider extends ChangeNotifier {
  static const String _kHistoryKey = 'hentai_cosplay_history_records';
  List<HistoryRecord> _records = [];

  List<HistoryRecord> get records => List.unmodifiable(_records);

  int get totalAlbums => _records.length;
  int get totalImages => _records.fold(0, (sum, r) => sum + r.imageCount);
  int get totalBytes => _records.fold(0, (sum, r) => sum + r.downloadedBytes);

  HistoryProvider() {
    _loadHistory();
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
      notifyListeners();

      // Recalculate zero bytes asynchronously from disk
      bool hasUpdates = false;
      for (final r in _records) {
        if (r.downloadedBytes == 0 && r.targetFolder.isNotEmpty) {
          final size = await StorageService.getFolderSize(r.targetFolder);
          if (size > 0) {
            r.downloadedBytes = size;
            hasUpdates = true;
          }
        }
      }
      if (hasUpdates) {
        notifyListeners();
        await _saveHistory();
      }
    }
  }

  Future<void> addRecord(HistoryRecord record) async {
    if (record.downloadedBytes == 0 && record.targetFolder.isNotEmpty) {
      final size = await StorageService.getFolderSize(record.targetFolder);
      if (size > 0) {
        record.downloadedBytes = size;
      }
    }

    _records.removeWhere((r) => r.id == record.id || r.detailUrl == record.detailUrl);
    _records.insert(0, record);
    notifyListeners();
    await _saveHistory();
  }

  Future<void> removeRecord(String id) async {
    _records.removeWhere((r) => r.id == id);
    notifyListeners();
    await _saveHistory();
  }

  Future<void> clearAll() async {
    _records.clear();
    notifyListeners();
    await _saveHistory();
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final listStr = _records.map((r) => r.toRawJson()).toList();
    await prefs.setStringList(_kHistoryKey, listStr);
  }
}
