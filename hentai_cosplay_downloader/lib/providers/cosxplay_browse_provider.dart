import 'package:flutter/foundation.dart';
import '../models/video_item.dart';
import '../services/cosxplay/cosxplay_api_service.dart';

class CosxplayBrowseProvider extends ChangeNotifier {
  List<VideoItem> _items = [];
  int _currentPage = 1;
  int _totalPages = 1;
  bool _isLoading = false;
  String? _errorMessage;

  String? _searchKeyword;
  String? _tagSlug;
  String? _actorSlug;

  bool _isSelectionMode = false;
  final Set<String> _selectedSlugs = {};

  List<VideoItem> get items => _items;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  String? get searchKeyword => _searchKeyword;
  String? get tagSlug => _tagSlug;
  String? get actorSlug => _actorSlug;
  bool get isSearchMode => _searchKeyword != null && _searchKeyword!.isNotEmpty;
  bool get hasActiveFilter => isSearchMode || _tagSlug != null || _actorSlug != null;

  bool get isSelectionMode => _isSelectionMode;
  Set<String> get selectedSlugs => _selectedSlugs;
  int get selectedCount => _selectedSlugs.length;
  List<VideoItem> get selectedItems =>
      _items.where((it) => _selectedSlugs.contains(it.slug)).toList();

  CosxplayBrowseProvider({bool autoLoad = false}) {
    if (autoLoad) {
      loadPage(1);
    }
  }

  void setSelectionMode(bool value) {
    _isSelectionMode = value;
    if (!value) {
      _selectedSlugs.clear();
    }
    notifyListeners();
  }

  void toggleItemSelection(VideoItem item) {
    if (_selectedSlugs.contains(item.slug)) {
      _selectedSlugs.remove(item.slug);
      if (_selectedSlugs.isEmpty) {
        _isSelectionMode = false;
      }
    } else {
      _selectedSlugs.add(item.slug);
      _isSelectionMode = true;
    }
    notifyListeners();
  }

  void selectAll() {
    _selectedSlugs.addAll(_items.map((it) => it.slug));
    notifyListeners();
  }

  void deselectAll() {
    _selectedSlugs.clear();
    notifyListeners();
  }

  bool isSelected(VideoItem item) => _selectedSlugs.contains(item.slug);

  void clearSearch() {
    _searchKeyword = null;
    loadPage(1);
  }

  void clearFilter() {
    _searchKeyword = null;
    _tagSlug = null;
    _actorSlug = null;
    loadPage(1);
  }

  void search(String keyword) {
    final clean = keyword.trim();
    if (clean.isEmpty) {
      clearSearch();
      return;
    }
    _searchKeyword = clean;
    _tagSlug = null;
    _actorSlug = null;
    loadPage(1);
  }

  void filterByTag(String tagSlug) {
    _tagSlug = tagSlug;
    _searchKeyword = null;
    _actorSlug = null;
    loadPage(1);
  }

  void filterByActor(String actorSlug) {
    _actorSlug = actorSlug;
    _searchKeyword = null;
    _tagSlug = null;
    loadPage(1);
  }

  Future<void> loadPage(int page) async {
    _isLoading = true;
    _errorMessage = null;
    _currentPage = page;
    notifyListeners();

    try {
      final pageData = await CosxplayApiService.fetchPageData(
        page: page,
        keyword: _searchKeyword,
        tagSlug: _tagSlug,
        actorSlug: _actorSlug,
      );

      _items = pageData.items;
      _currentPage = pageData.currentPage;
      _totalPages = pageData.totalPages;
      _selectedSlugs.clear();
      _isSelectionMode = false;
    } catch (e) {
      _errorMessage = '获取视频列表失败: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
