import 'package:flutter/foundation.dart';
import '../../models/rule34video_category.dart';
import '../../models/video_item.dart';
import '../../services/rule34video/rule34video_api_service.dart';

class Rule34VideoBrowseProvider extends ChangeNotifier {
  List<VideoItem> _items = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;

  int _currentPage = 1;
  int _totalPages = 1;

  Rule34VideoCategory _category = Rule34VideoCategory.latest;
  String _searchKeyword = '';
  String? _selectedTag;
  String? _selectedArtist;

  // Multi-selection
  bool _isSelectionMode = false;
  final Set<String> _selectedSlugs = {};

  List<VideoItem> get items => _items;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get errorMessage => _errorMessage;

  int get currentPage => _currentPage;
  int get totalPages => _totalPages;

  Rule34VideoCategory get category => _category;
  String get searchKeyword => _searchKeyword;
  String? get selectedTag => _selectedTag;
  String? get selectedArtist => _selectedArtist;

  bool get isSearchActive => _searchKeyword.trim().isNotEmpty;
  bool get isTagActive => _selectedTag != null && _selectedTag!.isNotEmpty;
  bool get isArtistActive => _selectedArtist != null && _selectedArtist!.isNotEmpty;

  bool get isSelectionMode => _isSelectionMode;
  Set<String> get selectedSlugs => _selectedSlugs;
  int get selectedCount => _selectedSlugs.length;

  List<VideoItem> get selectedItems {
    return _items.where((it) {
      final key = it.slug.isNotEmpty ? it.slug : it.detailUrl;
      return _selectedSlugs.contains(key);
    }).toList();
  }

  Rule34VideoBrowseProvider({bool autoLoad = false}) {
    if (autoLoad) {
      loadPage(1);
    }
  }

  void setCategory(Rule34VideoCategory newCat) {
    _category = newCat;
    _searchKeyword = '';
    _selectedTag = null;
    _selectedArtist = null;
    loadPage(1);
  }

  void setSearchKeyword(String keyword) {
    _searchKeyword = keyword.trim();
    _selectedTag = null;
    _selectedArtist = null;
    loadPage(1);
  }

  void setTag(String tag) {
    _selectedTag = tag.trim();
    _searchKeyword = '';
    _selectedArtist = null;
    loadPage(1);
  }

  void setArtist(String artist) {
    _selectedArtist = artist.trim();
    _searchKeyword = '';
    _selectedTag = null;
    loadPage(1);
  }

  void resetToLatest() {
    _category = Rule34VideoCategory.latest;
    _searchKeyword = '';
    _selectedTag = null;
    _selectedArtist = null;
    loadPage(1);
  }

  Future<void> loadPage(int page) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await Rule34VideoApiService.fetchPageData(
        page: page,
        category: _category,
        searchKeyword: _searchKeyword,
        selectedTag: _selectedTag,
        selectedArtist: _selectedArtist,
      );

      _items = data.items;
      _currentPage = data.currentPage;
      _totalPages = data.totalPages;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('[Rule34VideoBrowseProvider] Error loading page $page: $e');
      _errorMessage = '加载失败，请检查网络或代理设置 ($e)';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_isLoading || _isLoadingMore || _currentPage >= _totalPages) return;

    _isLoadingMore = true;
    notifyListeners();

    final nextPage = _currentPage + 1;
    try {
      final data = await Rule34VideoApiService.fetchPageData(
        page: nextPage,
        category: _category,
        searchKeyword: _searchKeyword,
        selectedTag: _selectedTag,
        selectedArtist: _selectedArtist,
      );

      if (data.items.isNotEmpty) {
        final existingSlugs = _items.map((e) => e.slug).toSet();
        final newItems = data.items.where((e) => !existingSlugs.contains(e.slug)).toList();
        _items.addAll(newItems);
        _currentPage = data.currentPage;
        _totalPages = data.totalPages;
      }
      _isLoadingMore = false;
      notifyListeners();
    } catch (e) {
      debugPrint('[Rule34VideoBrowseProvider] Error loading more: $e');
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  // Selection Mode
  void toggleSelectionMode() {
    _isSelectionMode = !_isSelectionMode;
    if (!_isSelectionMode) {
      _selectedSlugs.clear();
    }
    notifyListeners();
  }

  void setSelectionMode(bool value) {
    _isSelectionMode = value;
    if (!_isSelectionMode) {
      _selectedSlugs.clear();
    }
    notifyListeners();
  }

  bool isSelected(VideoItem item) {
    final key = item.slug.isNotEmpty ? item.slug : item.detailUrl;
    return _selectedSlugs.contains(key);
  }

  void toggleItemSelection(VideoItem item) {
    final key = item.slug.isNotEmpty ? item.slug : item.detailUrl;
    if (_selectedSlugs.contains(key)) {
      _selectedSlugs.remove(key);
      if (_selectedSlugs.isEmpty) {
        _isSelectionMode = false;
      }
    } else {
      _selectedSlugs.add(key);
      _isSelectionMode = true;
    }
    notifyListeners();
  }

  void selectAll() {
    for (final it in _items) {
      final key = it.slug.isNotEmpty ? it.slug : it.detailUrl;
      _selectedSlugs.add(key);
    }
    _isSelectionMode = true;
    notifyListeners();
  }

  void clearSelection() {
    _selectedSlugs.clear();
    _isSelectionMode = false;
    notifyListeners();
  }
}
