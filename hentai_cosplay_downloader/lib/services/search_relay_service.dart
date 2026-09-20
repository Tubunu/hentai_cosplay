import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 全局跨站搜索词记忆与接力服务
class SearchRelayService extends ChangeNotifier {
  static const String _kStorageKey = 'hentai_cosplay_recent_searches_v1';
  static const String _kLastSearchKey = 'hentai_cosplay_last_search_v1';
  static const int _kMaxHistory = 12;

  static final SearchRelayService instance = SearchRelayService._internal();

  factory SearchRelayService() => instance;

  String _lastKeyword = '';
  final List<String> _recentKeywords = [];
  bool _isLoaded = false;

  SearchRelayService._internal() {
    _loadFromStorage();
  }

  String get lastKeyword => _lastKeyword;
  List<String> get recentKeywords => List.unmodifiable(_recentKeywords);
  bool get hasKeyword => _lastKeyword.isNotEmpty;
  bool get isLoaded => _isLoaded;

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _lastKeyword = prefs.getString(_kLastSearchKey) ?? '';
      final rawList = prefs.getStringList(_kStorageKey);
      if (rawList != null) {
        _recentKeywords.clear();
        _recentKeywords.addAll(rawList);
      }
      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[SearchRelay] Load error: $e');
    }
  }

  Future<void> recordSearch(String keyword) async {
    final clean = keyword.trim();
    if (clean.isEmpty) return;

    _lastKeyword = clean;

    _recentKeywords.removeWhere((k) => k.toLowerCase() == clean.toLowerCase());
    _recentKeywords.insert(0, clean);
    if (_recentKeywords.length > _kMaxHistory) {
      _recentKeywords.removeRange(_kMaxHistory, _recentKeywords.length);
    }

    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLastSearchKey, _lastKeyword);
      await prefs.setStringList(_kStorageKey, _recentKeywords);
    } catch (e) {
      debugPrint('[SearchRelay] Save error: $e');
    }
  }

  Future<void> clearHistory() async {
    _recentKeywords.clear();
    _lastKeyword = '';
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kLastSearchKey);
      await prefs.remove(_kStorageKey);
    } catch (e) {
      debugPrint('[SearchRelay] Clear error: $e');
    }
  }
}
