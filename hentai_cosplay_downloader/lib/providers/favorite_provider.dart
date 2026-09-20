import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/album_item.dart';
import '../models/favorite_item.dart';
import '../models/video_item.dart';

/// Provider for managing cross-site user favorites (albums, videos, Jable).
class FavoriteProvider extends ChangeNotifier {
  static const String _kStorageKey = 'hentai_cosplay_favorites_v1';

  List<FavoriteItem> _favorites = [];
  final Set<String> _idSet = {};
  final Set<String> _urlSet = {};

  String _mediaTypeFilter = 'all'; // 'all' | 'album' | 'video'
  String? _siteFilter; // null = all sites
  String _searchQuery = '';
  bool _disposed = false;

  FavoriteProvider() {
    _loadFavorites();
  }

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

  List<FavoriteItem> get favorites => List.unmodifiable(_favorites);
  int get totalCount => _favorites.length;
  String get mediaTypeFilter => _mediaTypeFilter;
  String? get siteFilter => _siteFilter;
  String get searchQuery => _searchQuery;

  /// Returns filtered favorites according to current search query, media type filter, and site filter
  List<FavoriteItem> get filteredFavorites {
    return _favorites.where((item) {
      // 1. Media Type Filter
      if (_mediaTypeFilter != 'all') {
        if (item.mediaType != _mediaTypeFilter) return false;
      }

      // 2. Site Filter
      if (_siteFilter != null && _siteFilter!.isNotEmpty) {
        if (item.siteKey != _siteFilter) return false;
      }

      // 3. Search Query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchTitle = item.title.toLowerCase().contains(query);
        final matchAuthor = item.author.toLowerCase().contains(query);
        final matchTags = item.tags.any((t) => t.toLowerCase().contains(query));
        if (!matchTitle && !matchAuthor && !matchTags) return false;
      }

      return true;
    }).toList();
  }

  int get filteredCount => filteredFavorites.length;

  /// Returns a map of siteKey to siteName for all currently favorited items
  Map<String, String> get siteMap {
    final map = <String, String>{};
    for (final item in _favorites) {
      map[item.siteKey] = item.siteName;
    }
    return map;
  }

  /// Fast O(1) check if an item is favorited by ID
  bool isFavorite(String id) => _idSet.contains(id);

  /// Fast check if an item is favorited by URL
  bool isFavoriteUrl(String url) => _urlSet.contains(url);

  /// Check if an item is favorited by ID or detail URL
  bool isFavoriteItem({String? id, String? detailUrl}) {
    if (id != null && _idSet.contains(id)) return true;
    if (detailUrl != null && _urlSet.contains(detailUrl)) return true;
    return false;
  }

  void setMediaTypeFilter(String filter) {
    if (_mediaTypeFilter != filter) {
      _mediaTypeFilter = filter;
      notifyListeners();
    }
  }

  void setSiteFilter(String? siteKey) {
    if (_siteFilter != siteKey) {
      _siteFilter = siteKey;
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    final trimmed = query.trim();
    if (_searchQuery != trimmed) {
      _searchQuery = trimmed;
      notifyListeners();
    }
  }

  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listStr = prefs.getStringList(_kStorageKey);
      if (listStr != null) {
        _favorites = listStr
            .map((s) {
              try {
                return FavoriteItem.fromJson(jsonDecode(s) as Map<String, dynamic>);
              } catch (_) {
                return null;
              }
            })
            .whereType<FavoriteItem>()
            .toList();

        _favorites.sort((a, b) => b.addedAt.compareTo(a.addedAt));
        _rebuildLookupSets();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading favorites: $e');
    }
  }

  void _rebuildLookupSets() {
    _idSet.clear();
    _urlSet.clear();
    for (final f in _favorites) {
      if (f.id.isNotEmpty) _idSet.add(f.id);
      if (f.detailUrl.isNotEmpty) _urlSet.add(f.detailUrl);
    }
  }

  Future<void> _saveFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listStr = _favorites.map((f) => jsonEncode(f.toJson())).toList();
      await prefs.setStringList(_kStorageKey, listStr);
    } catch (e) {
      debugPrint('Error saving favorites: $e');
    }
  }

  /// Toggle favorite status of an item.
  /// Returns `true` if item was added to favorites, `false` if removed.
  Future<bool> toggleFavorite(FavoriteItem item) async {
    HapticFeedback.lightImpact();
    if (_idSet.contains(item.id) || (item.detailUrl.isNotEmpty && _urlSet.contains(item.detailUrl))) {
      await removeFavorite(item.id, detailUrl: item.detailUrl);
      return false;
    } else {
      await addFavorite(item);
      return true;
    }
  }

  /// Convenience toggle for AlbumItem
  Future<bool> toggleAlbum(
    AlbumItem item, {
    String? siteKey,
    String? siteName,
    int? siteColorValue,
  }) async {
    final fav = FavoriteItem.fromAlbum(
      item,
      siteKey: siteKey,
      siteName: siteName,
      siteColorValue: siteColorValue,
    );
    return toggleFavorite(fav);
  }

  /// Convenience toggle for VideoItem
  Future<bool> toggleVideo(
    VideoItem item, {
    String siteKey = 'hc_video',
    String siteName = 'HC 视频',
    int siteColorValue = 0xFFFF5252,
  }) async {
    final fav = FavoriteItem.fromVideo(
      item,
      siteKey: siteKey,
      siteName: siteName,
      siteColorValue: siteColorValue,
    );
    return toggleFavorite(fav);
  }

  /// Add a new item to favorites
  Future<void> addFavorite(FavoriteItem item) async {
    _favorites.removeWhere((f) =>
        f.id == item.id ||
        (f.detailUrl.isNotEmpty && f.detailUrl == item.detailUrl));

    _favorites.insert(0, item);
    _rebuildLookupSets();
    notifyListeners();
    await _saveFavorites();
  }

  /// Remove item from favorites by id or detailUrl
  Future<void> removeFavorite(String id, {String? detailUrl}) async {
    _favorites.removeWhere((f) =>
        f.id == id ||
        (detailUrl != null && detailUrl.isNotEmpty && f.detailUrl == detailUrl));

    _rebuildLookupSets();
    notifyListeners();
    await _saveFavorites();
  }

  /// Batch remove multiple items by ID
  Future<void> removeFavorites(Iterable<String> ids) async {
    final idSetToRemove = ids.toSet();
    _favorites.removeWhere((f) => idSetToRemove.contains(f.id));
    _rebuildLookupSets();
    notifyListeners();
    await _saveFavorites();
  }

  /// Clear all favorites
  Future<void> clearAll() async {
    _favorites.clear();
    _idSet.clear();
    _urlSet.clear();
    notifyListeners();
    await _saveFavorites();
  }
}
