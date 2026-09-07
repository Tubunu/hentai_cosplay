import 'package:flutter/foundation.dart';
import '../models/album_item.dart';
import '../services/cosvault/cosvault_api_service.dart';

class CosvaultBrowseProvider extends ChangeNotifier {
  List<AlbumItem> _items = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _currentPage = 1;
  int _totalPages = 93;
  int _totalItems = 0;
  int _currentRequestId = 0;

  CosvaultCategory _currentCategory = CosvaultCategory.latest;
  String? _searchKeyword;
  CosvaultModelItem? _selectedModel;
  List<CosvaultModelItem> _models = [];
  bool _isLoadingModels = false;

  bool _isSelectionMode = false;
  final Set<String> _selectedSlugs = {};

  List<AlbumItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalItems => _totalItems;
  CosvaultCategory get currentCategory => _currentCategory;
  String? get searchKeyword => _searchKeyword;
  bool get isSearchMode => _searchKeyword != null && _searchKeyword!.isNotEmpty;
  CosvaultModelItem? get selectedModel => _selectedModel;
  List<CosvaultModelItem> get models => _models;
  bool get isLoadingModels => _isLoadingModels;

  bool get isSelectionMode => _isSelectionMode;
  Set<String> get selectedSlugs => _selectedSlugs;
  int get selectedCount => _selectedSlugs.length;
  List<AlbumItem> get selectedItems =>
      _items.where((item) => _selectedSlugs.contains(item.slug)).toList();

  Future<void> fetchModels() async {
    if (_models.isNotEmpty) return;
    _isLoadingModels = true;
    notifyListeners();
    try {
      _models = await CosvaultApiService.fetchModels();
    } finally {
      _isLoadingModels = false;
      notifyListeners();
    }
  }

  void selectModel(CosvaultModelItem model) {
    if (_selectedModel?.slug == model.slug) return;
    _selectedModel = model;
    _searchKeyword = null;
    _currentPage = 1;
    _items = [];
    _selectedSlugs.clear();
    _isSelectionMode = false;
    loadPage(1);
  }

  void clearModel() {
    if (_selectedModel == null) return;
    _selectedModel = null;
    _currentPage = 1;
    _items = [];
    _selectedSlugs.clear();
    _isSelectionMode = false;
    loadPage(1);
  }

  CosvaultBrowseProvider({bool autoLoad = false}) {
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

  void toggleItemSelection(AlbumItem item) {
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

  bool isSelected(AlbumItem item) => _selectedSlugs.contains(item.slug);

  void selectAll() {
    for (final item in _items) {
      _selectedSlugs.add(item.slug);
    }
    _isSelectionMode = true;
    notifyListeners();
  }

  void deselectAll() {
    _selectedSlugs.clear();
    _isSelectionMode = false;
    notifyListeners();
  }

  Future<void> loadPage(int page) async {
    final requestId = ++_currentRequestId;
    _currentPage = page;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await CosvaultApiService.fetchPageData(
        page: page,
        category: _currentCategory,
        keyword: _searchKeyword,
        modelSlug: _selectedModel?.slug,
      );

      if (requestId != _currentRequestId) return;

      if (response != null) {
        _items = response.items;
        _currentPage = response.page;
        _totalPages = response.totalPages;
        _totalItems = response.total;
        _selectedSlugs.clear();
        _isSelectionMode = false;
        if (_items.isEmpty && isSearchMode) {
          _errorMessage = '未找到与 "$_searchKeyword" 相关的图包，建议尝试搜索模特名（如 atsuki、byoru）或作品标签（如 genshin-impact）';
        }
      } else {
        if (isSearchMode) {
          _items = [];
          _errorMessage = '未找到与 "$_searchKeyword" 相关的图包，建议尝试搜索模特名（如 atsuki、byoru）或作品标签（如 genshin-impact）';
        } else {
          _errorMessage = '获取 CosVault 列表失败，请检查网络或配置代理';
        }
      }
    } catch (e) {
      if (requestId != _currentRequestId) return;
      _errorMessage = isSearchMode
          ? '未找到与 "$_searchKeyword" 相关的图包'
          : '请求错误: $e';
    } finally {
      if (requestId == _currentRequestId) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void switchCategory(CosvaultCategory category) {
    if (_currentCategory == category && _searchKeyword == null && _selectedModel == null) return;
    _currentCategory = category;
    _searchKeyword = null;
    _selectedModel = null;
    _currentPage = 1;
    _items = [];
    _selectedSlugs.clear();
    _isSelectionMode = false;
    loadPage(1);
  }

  Future<void> search(String keyword) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) {
      clearSearch();
      return;
    }

    // 1. Ensure models are loaded to allow matching by model name
    if (_models.isEmpty) {
      await fetchModels();
    }

    // 2. Check if user typed a model name or slug
    final lower = trimmed.toLowerCase();
    final matchedModel = _models.cast<CosvaultModelItem?>().firstWhere(
      (m) => m != null && (m.name.toLowerCase() == lower || m.slug.toLowerCase() == lower || m.name.toLowerCase().contains(lower)),
      orElse: () => null,
    );

    if (matchedModel != null) {
      selectModel(matchedModel);
      return;
    }

    _searchKeyword = trimmed;
    _selectedModel = null;
    _currentPage = 1;
    _items = [];
    _selectedSlugs.clear();
    _isSelectionMode = false;
    loadPage(1);
  }

  void clearSearch() {
    if (_searchKeyword == null) return;
    _searchKeyword = null;
    _currentPage = 1;
    _items = [];
    _selectedSlugs.clear();
    _isSelectionMode = false;
    loadPage(1);
  }

  void nextPage() {
    if (_currentPage < _totalPages) {
      loadPage(_currentPage + 1);
    }
  }

  void prevPage() {
    if (_currentPage > 1) {
      loadPage(_currentPage - 1);
    }
  }

  Future<void> refresh() async {
    await loadPage(_currentPage);
  }
}
