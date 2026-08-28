import 'package:flutter/material.dart';
import '../models/video_item.dart';
import '../models/hanime1_category.dart';
import '../services/hanime1/hanime1_api_service.dart';

class Hanime1BrowseProvider extends ChangeNotifier {
  List<VideoItem> _items = [];
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalItems = 0;

  bool _isLoading = false;
  String? _errorMessage;
  int _requestId = 0;
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

  Hanime1Category _category = Hanime1Category.latest;
  String _searchKeyword = '';
  String? _selectedTag;
  String? _selectedBroadcaster;

  bool _isSelectionMode = false;
  final Set<String> _selectedSlugs = {};

  List<VideoItem> get items => _items;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalItems => _totalItems;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Hanime1Category get category => _category;
  String get searchKeyword => _searchKeyword;
  String? get selectedTag => _selectedTag;
  String? get selectedBroadcaster => _selectedBroadcaster;
  bool get isTagActive => _selectedTag != null && _selectedTag!.isNotEmpty;
  bool get isBroadcasterActive => _selectedBroadcaster != null && _selectedBroadcaster!.isNotEmpty;
  bool get isSearchActive => _searchKeyword.isNotEmpty;

  bool get isSelectionMode => _isSelectionMode;
  Set<String> get selectedSlugs => _selectedSlugs;
  int get selectedCount => _selectedSlugs.length;

  List<VideoItem> get selectedItems {
    return _items.where((it) {
      final key = it.slug.isNotEmpty ? it.slug : it.detailUrl;
      return _selectedSlugs.contains(key);
    }).toList();
  }

  Hanime1BrowseProvider({bool autoLoad = true}) {
    if (autoLoad) {
      loadPage(1);
    }
  }

  void setCategory(Hanime1Category newCat) {
    _category = newCat;
    _searchKeyword = '';
    _selectedTag = null;
    _selectedBroadcaster = null;
    loadPage(1);
  }

  void setSearchKeyword(String keyword) {
    _searchKeyword = keyword.trim();
    _selectedTag = null;
    _selectedBroadcaster = null;
    loadPage(1);
  }

  void setSelectedTag(String tag) {
    _selectedTag = tag.trim();
    _searchKeyword = '';
    _selectedBroadcaster = null;
    loadPage(1);
  }

  void setSelectedBroadcaster(String broadcaster) {
    _selectedBroadcaster = broadcaster.trim();
    _searchKeyword = '';
    _selectedTag = null;
    loadPage(1);
  }

  void clearSearch() {
    _searchKeyword = '';
    loadPage(1);
  }

  void clearTag() {
    _selectedTag = null;
    loadPage(1);
  }

  void clearBroadcaster() {
    _selectedBroadcaster = null;
    loadPage(1);
  }

  void resetToLatest() {
    _category = Hanime1Category.latest;
    _searchKeyword = '';
    _selectedTag = null;
    _selectedBroadcaster = null;
    loadPage(1);
  }

  void toggleSelectionMode() {
    _isSelectionMode = !_isSelectionMode;
    if (!_isSelectionMode) {
      _selectedSlugs.clear();
    }
    notifyListeners();
  }

  void toggleItemSelection(VideoItem item) {
    final key = item.slug.isNotEmpty ? item.slug : item.detailUrl;
    if (_selectedSlugs.contains(key)) {
      _selectedSlugs.remove(key);
    } else {
      _selectedSlugs.add(key);
    }
    notifyListeners();
  }

  void selectAll() {
    for (final item in _items) {
      final key = item.slug.isNotEmpty ? item.slug : item.detailUrl;
      _selectedSlugs.add(key);
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedSlugs.clear();
    notifyListeners();
  }

  bool isSelected(VideoItem item) {
    final key = item.slug.isNotEmpty ? item.slug : item.detailUrl;
    return _selectedSlugs.contains(key);
  }

  Future<void> loadPage(int page) async {
    final reqId = ++_requestId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await Hanime1ApiService.fetchPageData(
        page: page,
        category: _category,
        keyword: _searchKeyword,
        tag: _selectedTag,
        broadcaster: _selectedBroadcaster,
      );

      if (reqId != _requestId) return;

      if (res != null) {
        _items = res.items;
        _currentPage = res.page;
        _totalPages = res.totalPages;
        _totalItems = res.total;
        _errorMessage = null;
      } else {
        _errorMessage = '加载失败，请检查网络后重试';
      }
    } catch (e) {
      if (reqId != _requestId) return;
      _errorMessage = '请求异常: $e';
    } finally {
      if (reqId == _requestId) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> nextPage() async {
    if (_currentPage < _totalPages && !_isLoading) {
      await loadPage(_currentPage + 1);
    }
  }

  Future<void> prevPage() async {
    if (_currentPage > 1 && !_isLoading) {
      await loadPage(_currentPage - 1);
    }
  }
}
