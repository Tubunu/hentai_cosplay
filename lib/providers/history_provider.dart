import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/history_record.dart';

class HistoryProvider extends ChangeNotifier {
  static const String _kHistoryKey = 'mzt_download_history_v1';
  List<HistoryRecord> _records = [];
  bool _isLoading = true;

  List<HistoryRecord> get records => _records;
  bool get isLoading => _isLoading;

  int get totalPacksDownloaded => _records.fold(0, (sum, r) => sum + r.packsDownloaded);
  int get totalImagesDownloaded => _records.fold(0, (sum, r) => sum + r.imagesDownloaded);
  int get totalPacksSkipped => _records.fold(0, (sum, r) => sum + r.packsSkipped);
  int get totalImagesSkipped => _records.fold(0, (sum, r) => sum + r.imagesSkipped);
  int get totalImagesFailed => _records.fold(0, (sum, r) => sum + r.imagesFailed);
  double get totalDurationSeconds => _records.fold(0.0, (sum, r) => sum + r.durationSec);

  HistoryProvider() {
    loadHistory();
  }

  Future<void> loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kHistoryKey);
      if (raw != null && raw.isNotEmpty) {
        _records = HistoryRecord.listFromJson(raw);
        _records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      }
    } catch (e) {
      debugPrint('Error loading history records: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addRecord(HistoryRecord record) async {
    _records.insert(0, record);
    notifyListeners();
    await _save();
  }

  Future<void> deleteRecord(String id) async {
    _records.removeWhere((r) => r.id == id);
    notifyListeners();
    await _save();
  }

  Future<void> clearHistory() async {
    _records.clear();
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kHistoryKey, HistoryRecord.listToJson(_records));
    } catch (e) {
      debugPrint('Error saving history records: $e');
    }
  }
}
