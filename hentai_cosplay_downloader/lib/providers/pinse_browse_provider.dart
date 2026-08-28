import 'package:flutter/material.dart';
import '../models/video_item.dart';
import '../services/app_logger.dart';
import '../services/pinse/pinse_api_service.dart';

class PinseBrowseProvider extends ChangeNotifier {
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

  PinseCategory _category = PinseCategory.currentHot;
  String _searchKeyword = '';
  String? _selectedAuthor;

  bool _isSelectionMode = false;
  final Set<String> _selectedSlugs = {};

  List<VideoItem> get items => _items;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalItems => _totalItems;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  PinseCategory get category => _category;
  String get searchKeyword => _searchKeyword;
  String? get selectedAuthor => _selectedAuthor;
  bool get isAuthorActive => _selectedAuthor != null && _selectedAuthor!.isNotEmpty;
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

  PinseBrowseProvider({bool autoLoad = true}) {
    if (autoLoad) {
      loadPage(1);
    }
  }

  void setCategory(PinseCategory newCat) {
    _category = newCat;
    _searchKeyword = '';
    _selectedAuthor = null;
    loadPage(1);
  }

  void setSearchKeyword(String keyword) {
    _searchKeyword = keyword.trim();
    _selectedAuthor = null;
    loadPage(1);
  }

  void setSelectedAuthor(String author) {
    _selectedAuthor = author.trim();
    _searchKeyword = '';
    loadPage(1);
  }

  void clearSearch() {
    _searchKeyword = '';
    loadPage(1);
  }

  void clearAuthor() {
    _selectedAuthor = null;
    loadPage(1);
  }

  void resetToLatest() {
    _category = PinseCategory.latest;
    _searchKeyword = '';
    _selectedAuthor = null;
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
      AppLogger.i('91品色', 'PinseBrowseProvider.loadPage($page) 触发请求');
      final res = await PinseApiService.fetchPageData(
        page: page,
        category: _category,
        keyword: _searchKeyword,
        author: _selectedAuthor,
      );

      if (_disposed || reqId != _requestId) return;

      if (res != null) {
        _items = res.items;
        _currentPage = res.page;
        _totalPages = res.totalPages;
        _totalItems = res.total;
        _errorMessage = _items.isEmpty ? '暂无相关视频内容' : null;
        AppLogger.s('91品色', 'PinseBrowseProvider: 成功加载第 $page 页，共 ${_items.length} 个视频');
      } else {
        _errorMessage = '加载失败，请点击下方按钮查看诊断日志或重试';
        AppLogger.e('91品色', 'PinseBrowseProvider: fetchPageData 返回 null (加载失败)');
      }
    } catch (e, st) {
      if (_disposed || reqId != _requestId) return;
      _errorMessage = '网络请求异常: $e';
      AppLogger.e('91品色', 'PinseBrowseProvider.loadPage 发生异常: $e', e, st);
    } finally {
      if (!_disposed && reqId == _requestId) {
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
