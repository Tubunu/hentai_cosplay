import 'package:flutter/foundation.dart';
import '../models/video_item.dart';
import '../services/xnxx/xnxx_api_service.dart';

class XnxxBrowseProvider extends ChangeNotifier {
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

  List<VideoItem> _items = [];
  int _currentPage = 1;
  int _totalPages = 1;
  bool _isLoading = false;
  String? _errorMessage;

  XnxxCategory _category = XnxxCategory.hits;
  String _bestMonth = XnxxApiService.getDefaultBestMonth();
  String? _searchKeyword;

  bool _isSelectionMode = false;
  final Set<String> _selectedSlugs = {};

  List<VideoItem> get items => _items;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  XnxxCategory get category => _category;
  String get bestMonth => _bestMonth;
  String? get searchKeyword => _searchKeyword;
  bool get isSearchMode => _searchKeyword != null && _searchKeyword!.isNotEmpty;

  bool get isSelectionMode => _isSelectionMode;
  Set<String> get selectedSlugs => _selectedSlugs;
  int get selectedCount => _selectedSlugs.length;
  List<VideoItem> get selectedItems =>
      _items.where((it) => _selectedSlugs.contains(it.slug)).toList();

  XnxxBrowseProvider({bool autoLoad = false}) {
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

  void selectCategory(XnxxCategory cat) {
    if (_category == cat && !isSearchMode) return;
    _category = cat;
    _searchKeyword = null;
    loadPage(1);
  }

  void selectBestMonth(String month) {
    if (_bestMonth == month && _category == XnxxCategory.best) return;
    _bestMonth = month;
    _category = XnxxCategory.best;
    _searchKeyword = null;
    loadPage(1);
  }

  void clearSearch() {
    _searchKeyword = null;
    loadPage(1);
  }

  void search(String keyword) {
    final clean = keyword.trim();
    if (clean.isEmpty) {
      clearSearch();
      return;
    }
    _searchKeyword = clean;
    loadPage(1);
  }

  Future<void> loadPage(int page) async {
    _isLoading = true;
    _errorMessage = null;
    _currentPage = page;
    notifyListeners();

    try {
      final pageData = await XnxxApiService.fetchPageData(
        page: page,
        category: _category,
        bestMonth: _bestMonth,
        keyword: _searchKeyword,
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
