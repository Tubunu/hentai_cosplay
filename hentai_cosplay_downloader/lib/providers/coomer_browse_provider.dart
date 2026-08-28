import 'package:flutter/material.dart';
import '../models/album_item.dart';
import '../services/coomer/coomer_api_service.dart';

enum CoomerViewMode {
  posts('动态流'),
  creators('创作者名录');

  final String label;
  const CoomerViewMode(this.label);
}

class CoomerBrowseProvider extends ChangeNotifier {
  List<AlbumItem> _posts = [];
  List<CoomerCreator> _creators = [];
  CoomerCreator? _selectedCreator;

  int _currentOffset = 0;
  final int _pageSize = 40;
  bool _hasMore = true;

  bool _isLoading = false;
  String? _errorMessage;
  int _requestId = 0;
  bool _disposed = false;

  CoomerViewMode _viewMode = CoomerViewMode.posts;
  String _selectedService = 'all'; // all, onlyfans, fansly, patreon, candfans
  String _searchQuery = '';

  bool _isSelectionMode = false;
  final Set<String> _selectedSlugs = {};

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

  List<AlbumItem> get posts => _posts;
  List<CoomerCreator> get creators => _creators;
  CoomerCreator? get selectedCreator => _selectedCreator;

  int get currentOffset => _currentOffset;
  int get currentPage => (_currentOffset ~/ _pageSize) + 1;
  bool get hasMore => _hasMore;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  CoomerViewMode get viewMode => _viewMode;
  String get selectedService => _selectedService;
  String get searchQuery => _searchQuery;
  bool get isSearchActive => _searchQuery.isNotEmpty;

  bool get isSelectionMode => _isSelectionMode;
  Set<String> get selectedSlugs => _selectedSlugs;
  int get selectedCount => _selectedSlugs.length;

  List<AlbumItem> get selectedItems {
    return _posts.where((it) {
      final key = it.slug.isNotEmpty ? it.slug : it.detailUrl;
      return _selectedSlugs.contains(key);
    }).toList();
  }

  CoomerBrowseProvider({bool autoLoad = true}) {
    if (autoLoad) {
      loadData(reset: true);
    }
  }

  void setViewMode(CoomerViewMode mode) {
    if (_viewMode == mode) return;
    _viewMode = mode;
    _searchQuery = '';
    loadData(reset: true);
  }

  void setService(String service) {
    if (_selectedService == service) return;
    _selectedService = service;
    _searchQuery = '';
    _selectedCreator = null;
    loadData(reset: true);
  }

  void setSearchQuery(String query) {
    _searchQuery = query.trim();
    loadData(reset: true);
  }

  void selectCreator(CoomerCreator? creator) {
    _selectedCreator = creator;
    _viewMode = CoomerViewMode.posts;
    loadData(reset: true);
  }

  void clearCreatorFilter() {
    _selectedCreator = null;
    loadData(reset: true);
  }

  void clearSearch() {
    _searchQuery = '';
    loadData(reset: true);
  }

  void toggleSelectionMode() {
    _isSelectionMode = !_isSelectionMode;
    if (!_isSelectionMode) {
      _selectedSlugs.clear();
    }
    notifyListeners();
  }

  void toggleItemSelection(AlbumItem item) {
    final key = item.slug.isNotEmpty ? item.slug : item.detailUrl;
    if (_selectedSlugs.contains(key)) {
      _selectedSlugs.remove(key);
    } else {
      _selectedSlugs.add(key);
    }
    notifyListeners();
  }

  void selectAll() {
    for (final item in _posts) {
      final key = item.slug.isNotEmpty ? item.slug : item.detailUrl;
      _selectedSlugs.add(key);
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedSlugs.clear();
    notifyListeners();
  }

  bool isSelected(AlbumItem item) {
    final key = item.slug.isNotEmpty ? item.slug : item.detailUrl;
    return _selectedSlugs.contains(key);
  }

  Future<void> loadData({bool reset = false}) async {
    if (_viewMode == CoomerViewMode.creators) {
      await _loadCreators();
    } else {
      await _loadPosts(reset: reset);
    }
  }

  Future<void> _loadCreators() async {
    final reqId = ++_requestId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final list = await CoomerApiService.fetchCreators(
        service: _selectedService == 'all' ? null : _selectedService,
        query: _searchQuery.isNotEmpty ? _searchQuery : null,
      );

      if (_disposed || reqId != _requestId) return;

      _creators = list;
      _errorMessage = list.isEmpty ? '暂未找到符合条件的创作者' : null;
    } catch (e) {
      if (_disposed || reqId != _requestId) return;
      _errorMessage = '加载创作者失败: $e';
    } finally {
      if (!_disposed && reqId == _requestId) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> _loadPosts({bool reset = false}) async {
    final reqId = ++_requestId;
    if (reset) {
      _currentOffset = 0;
      _posts = [];
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      CoomerApiResponse? res;

      if (_selectedCreator != null) {
        res = await CoomerApiService.fetchCreatorPosts(
          service: _selectedCreator!.service,
          creatorId: _selectedCreator!.id,
          offset: _currentOffset,
          limit: _pageSize,
        );
      } else {
        res = await CoomerApiService.fetchRecentPosts(
          offset: _currentOffset,
          limit: _pageSize,
          service: _selectedService == 'all' ? null : _selectedService,
          query: _searchQuery.isNotEmpty ? _searchQuery : null,
        );
      }

      if (_disposed || reqId != _requestId) return;

      if (res != null) {
        if (reset) {
          _posts = res.items;
        } else {
          _posts.addAll(res.items);
        }
        _hasMore = res.hasMore;
        _errorMessage = _posts.isEmpty ? '暂无相关动态内容' : null;
      } else {
        _errorMessage = '加载动态失败，请检查网络连接或代理设置';
      }
    } catch (e) {
      if (_disposed || reqId != _requestId) return;
      _errorMessage = '网络请求异常: $e';
    } finally {
      if (!_disposed && reqId == _requestId) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadNextPage() async {
    if (_isLoading || !_hasMore) return;
    _currentOffset += _pageSize;
    await _loadPosts(reset: false);
  }
}
