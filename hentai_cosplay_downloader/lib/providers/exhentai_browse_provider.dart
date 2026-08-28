import 'package:flutter/material.dart';
import '../models/album_item.dart';
import '../services/exhentai/exhentai_api_service.dart';

class ExHentaiBrowseProvider extends ChangeNotifier {
  ExCategory _currentCategory = ExCategory.all;
  bool _isPopular = false;
  String _searchKeyword = '';

  List<AlbumItem> _items = [];
  int _page = 1;
  int _totalPages = 1;
  bool _hasMore = true;
  int _currentRequestId = 0;

  bool _isLoading = false;
  String? _errorMessage;

  // Multi-selection state
  bool _isSelectionMode = false;
  final Set<String> _selectedSlugs = {};

  ExHentaiBrowseProvider() {
    loadPage(1);
  }

  ExCategory get currentCategory => _currentCategory;
  bool get isPopular => _isPopular;
  String get searchKeyword => _searchKeyword;
  bool get isSearchActive => _searchKeyword.trim().isNotEmpty;
  ExSourceServer get currentSource => ExHentaiApiService.currentSource;
  String get customSourceUrl => ExHentaiApiService.customSourceUrl;

  List<AlbumItem> get items => _items;
  int get page => _page;
  int get totalPages => _totalPages;
  bool get hasMore => _hasMore;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get isSelectionMode => _isSelectionMode;
  Set<String> get selectedSlugs => _selectedSlugs;
  int get selectedCount => _selectedSlugs.length;

  List<AlbumItem> get selectedItems =>
      _items.where((i) => _selectedSlugs.contains(i.slug)).toList();

  bool isSelected(AlbumItem item) => _selectedSlugs.contains(item.slug);

  final Map<int, String> _pageCursors = {};

  void setSource(ExSourceServer source, {String? customUrl}) {
    ExHentaiApiService.setSource(source, customUrl: customUrl);
    clearSelection();
    _pageCursors.clear();
    _items = [];
    loadPage(1);
  }

  void setCategory(ExCategory category) {
    if (_currentCategory == category && !_isPopular) return;
    _currentCategory = category;
    _isPopular = false;
    _searchKeyword = '';
    clearSelection();
    _pageCursors.clear();
    _items = [];
    loadPage(1);
  }

  void setPopular(bool popular) {
    if (_isPopular == popular) return;
    _isPopular = popular;
    _searchKeyword = '';
    clearSelection();
    _pageCursors.clear();
    _items = [];
    loadPage(1);
  }

  void search(String keyword) {
    _searchKeyword = keyword.trim();
    _isPopular = false;
    clearSelection();
    _pageCursors.clear();
    _items = [];
    loadPage(1);
  }

  void clearSearch() {
    if (_searchKeyword.isEmpty) return;
    _searchKeyword = '';
    clearSelection();
    _pageCursors.clear();
    _items = [];
    loadPage(1);
  }

  Future<void> loadPage(int targetPage) async {
    final requestId = ++_currentRequestId;
    _page = targetPage;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final cursor = targetPage > 1 ? _pageCursors[targetPage] : null;
      final res = await ExHentaiApiService.fetchPageData(
        page: targetPage,
        category: _currentCategory,
        keyword: _searchKeyword,
        isPopular: _isPopular,
        cursor: cursor,
      );

      if (requestId != _currentRequestId) return;

      if (res != null) {
        _items = res.items;
        _page = res.currentPage;
        _totalPages = res.totalPages;
        _hasMore = res.hasMore;

        // Record next and previous cursors for continuous smooth paging
        if (res.nextCursor != null) {
          _pageCursors[targetPage + 1] = 'next=${res.nextCursor}';
        }
        if (res.prevCursor != null && targetPage > 1) {
          _pageCursors[targetPage - 1] = 'prev=${res.prevCursor}';
        }
      } else {
        _items = [];
        _hasMore = false;
      }
    } catch (e) {
      if (requestId != _currentRequestId) return;
      _errorMessage = '加载 ExHentai 列表失败: $e';
    } finally {
      if (requestId == _currentRequestId) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void nextPage() {
    if (_page < _totalPages || _hasMore) {
      loadPage(_page + 1);
    }
  }

  void prevPage() {
    if (_page > 1) {
      loadPage(_page - 1);
    }
  }

  void jumpToPage(int targetPage) {
    if (targetPage >= 1 && targetPage != _page) {
      loadPage(targetPage);
    }
  }

  Future<void> refresh() async {
    await loadPage(_page);
  }

  // Multi-select methods
  void toggleSelectionMode() {
    _isSelectionMode = !_isSelectionMode;
    if (!_isSelectionMode) {
      _selectedSlugs.clear();
    }
    notifyListeners();
  }

  void toggleSelect(AlbumItem item) {
    if (_selectedSlugs.contains(item.slug)) {
      _selectedSlugs.remove(item.slug);
    } else {
      _selectedSlugs.add(item.slug);
    }
    if (_selectedSlugs.isNotEmpty) {
      _isSelectionMode = true;
    }
    notifyListeners();
  }

  void toggleItemSelection(AlbumItem item) => toggleSelect(item);

  void selectAll() {
    _selectedSlugs.addAll(_items.map((i) => i.slug));
    _isSelectionMode = true;
    notifyListeners();
  }

  void clearSelection() {
    _selectedSlugs.clear();
    _isSelectionMode = false;
    notifyListeners();
  }
}
