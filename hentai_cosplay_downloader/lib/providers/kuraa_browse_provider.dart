import 'package:flutter/material.dart';
import '../services/kuraa/kuraa_api_service.dart';

class _KuraaLocationState {
  final List<KuraaFolderNav> navigationStack;
  final List<KuraaFileItem> items;
  final int currentPage;
  final int totalItems;
  final bool hasMore;

  const _KuraaLocationState({
    required this.navigationStack,
    required this.items,
    required this.currentPage,
    required this.totalItems,
    required this.hasMore,
  });
}

class KuraaBrowseProvider extends ChangeNotifier {
  List<KuraaStorageLocation> _locations = [];
  String _activeLocationId = '2'; // Default: 公开浏览
  final Map<String, String> _tokens = {};

  final Map<String, _KuraaLocationState> _locationStates = {};

  List<KuraaFolderNav> _navigationStack = [
    const KuraaFolderNav(id: null, name: '根目录'),
  ];

  List<KuraaFileItem> _items = [];
  final Map<String, String> _folderCoverCache = {};
  bool _isLoading = false;
  String? _errorMessage;

  int _currentPage = 1;
  static const int _pageSize = 50;
  int _totalItems = 0;
  bool _hasMore = false;

  String _searchKeyword = '';
  String _sortBy = 'updatedAt';
  String _sortOrder = 'desc';

  // Selection mode
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};
  final List<KuraaFileItem> _selectedItems = [];

  KuraaBrowseProvider({bool autoLoad = false}) {
    if (autoLoad) {
      init();
    }
  }

  List<KuraaStorageLocation> get locations => _locations;
  String get activeLocationId => _activeLocationId;
  bool get isInnerBoard => _activeLocationId == '4';
  List<KuraaFolderNav> get navigationStack => List.unmodifiable(_navigationStack);
  KuraaFolderNav get currentFolder => _navigationStack.last;
  bool get canNavigateBack => _navigationStack.length > 1;

  List<KuraaFileItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  int get currentPage => _currentPage;
  int get pageSize => _pageSize;
  int get totalItems => _totalItems;
  int get totalPages => (_totalItems / _pageSize).ceil().clamp(1, 9999);
  bool get hasMore => _hasMore;

  String get searchKeyword => _searchKeyword;
  bool get isSearchActive => _searchKeyword.trim().isNotEmpty;
  String get sortBy => _sortBy;
  String get sortOrder => _sortOrder;

  bool get isSelectionMode => _isSelectionMode;
  List<KuraaFileItem> get selectedItems => List.unmodifiable(_selectedItems);
  int get selectedCount => _selectedItems.length;

  bool isSelected(KuraaFileItem item) => _selectedIds.contains(item.id);
  String? get activeToken => _tokens[_activeLocationId];

  String? getFolderCover(String folderId) => _folderCoverCache[folderId];

  Future<void> init() async {
    await fetchLocations();
    // Auto-unlock 内板 with default password kuraa.cc
    await autoUnlockInnerBoard();
    await loadPage(1);
  }

  Future<void> autoUnlockInnerBoard() async {
    try {
      final token = await KuraaApiService.unlockStorageLocation(
        '4',
        KuraaApiService.defaultInnerPassword,
      );
      if (token != null) {
        _tokens['4'] = token;
      }
    } catch (e) {
      debugPrint('Auto unlock inner board failed: $e');
    }
  }

  Future<void> fetchLocations() async {
    try {
      final locs = await KuraaApiService.fetchStorageLocations();
      if (locs.isNotEmpty) {
        _locations = locs;
      } else {
        // Fallback default locations
        _locations = const [
          KuraaStorageLocation(id: '2', name: '公开浏览', anonymousAccess: 'read', hasPassword: false),
          KuraaStorageLocation(id: '4', name: '内板', anonymousAccess: 'read', hasPassword: true),
        ];
      }
      notifyListeners();
    } catch (e) {
      debugPrint('fetchLocations error: $e');
    }
  }

  Future<bool> unlockLocation(String locationId, String password) async {
    try {
      final token = await KuraaApiService.unlockStorageLocation(locationId, password);
      if (token != null) {
        _tokens[locationId] = token;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Unlock location error: $e');
    }
    return false;
  }

  void _saveCurrentLocationState() {
    _locationStates[_activeLocationId] = _KuraaLocationState(
      navigationStack: List.from(_navigationStack),
      items: List.from(_items),
      currentPage: _currentPage,
      totalItems: _totalItems,
      hasMore: _hasMore,
    );
  }

  Future<void> switchLocation(String locationId) async {
    if (_activeLocationId == locationId) return;

    // 1. Save state of current location before leaving
    _saveCurrentLocationState();

    _activeLocationId = locationId;
    _searchKeyword = '';
    clearSelection();

    // 2. If switching to inner board and not yet unlocked, attempt unlock
    if (locationId == '4' && _tokens['4'] == null) {
      await autoUnlockInnerBoard();
    }

    // 3. If target location state is already cached, restore immediately without reloading from network!
    final cached = _locationStates[locationId];
    if (cached != null && cached.items.isNotEmpty) {
      _navigationStack = List.from(cached.navigationStack);
      _items = List.from(cached.items);
      _currentPage = cached.currentPage;
      _totalItems = cached.totalItems;
      _hasMore = cached.hasMore;
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
      return;
    }

    // 4. Otherwise initialize and load page 1
    _navigationStack = [
      KuraaFolderNav(
        id: null,
        name: locationId == '4' ? '内板根目录' : '公开资源根目录',
      ),
    ];
    _items = [];
    await loadPage(1);
  }

  Future<void> enterFolder(KuraaFileItem folder) async {
    if (!folder.isFolder) return;
    _searchKeyword = '';
    _navigationStack.add(KuraaFolderNav(id: folder.id, name: folder.name));
    clearSelection();
    await loadPage(1);
  }

  Future<void> navigateBack() async {
    if (_navigationStack.length <= 1) return;
    _navigationStack.removeLast();
    _searchKeyword = '';
    clearSelection();
    await loadPage(1);
  }

  Future<void> navigateToIndex(int index) async {
    if (index < 0 || index >= _navigationStack.length) return;
    while (_navigationStack.length > index + 1) {
      _navigationStack.removeLast();
    }
    _searchKeyword = '';
    clearSelection();
    await loadPage(1);
  }

  Future<void> loadPage(int page) async {
    _isLoading = true;
    _errorMessage = null;
    _currentPage = page;
    notifyListeners();

    try {
      final offset = (page - 1) * _pageSize;
      KuraaPageResult res;

      if (isSearchActive) {
        res = await KuraaApiService.searchFiles(
          storageLocationId: _activeLocationId,
          query: _searchKeyword.trim(),
          offset: offset,
          limit: _pageSize,
          token: activeToken,
        );
      } else {
        res = await KuraaApiService.fetchFiles(
          storageLocationId: _activeLocationId,
          parentId: currentFolder.id,
          offset: offset,
          limit: _pageSize,
          sortBy: _sortBy,
          sortOrder: _sortOrder,
          token: activeToken,
        );
      }

      _items = res.items;
      _totalItems = res.total;
      _hasMore = res.hasMore;
      _isLoading = false;

      // Update location cache
      _saveCurrentLocationState();

      notifyListeners();

      // Asynchronously prefetch covers for all folders in the current view
      _prefetchFolderCovers(_items);
    } catch (e) {
      _isLoading = false;
      _errorMessage = '加载失败: $e';
      notifyListeners();
    }
  }

  void _prefetchFolderCovers(List<KuraaFileItem> fileItems) {
    for (final item in fileItems) {
      if (item.isFolder && !_folderCoverCache.containsKey(item.id)) {
        KuraaApiService.fetchFolderCover(item, token: activeToken).then((cover) {
          if (cover != null && cover.isNotEmpty) {
            _folderCoverCache[item.id] = cover;
            notifyListeners();
          }
        }).catchError((_) {});
      }
    }
  }

  Future<void> setSearchKeyword(String keyword) async {
    _searchKeyword = keyword.trim();
    clearSelection();
    await loadPage(1);
  }

  Future<void> clearSearch() async {
    _searchKeyword = '';
    clearSelection();
    await loadPage(1);
  }

  void setSort(String sortBy, String sortOrder) {
    if (_sortBy == sortBy && _sortOrder == sortOrder) return;
    _sortBy = sortBy;
    _sortOrder = sortOrder;
    loadPage(1);
  }

  void nextPage() {
    if (_currentPage < totalPages) {
      loadPage(_currentPage + 1);
    }
  }

  void prevPage() {
    if (_currentPage > 1) {
      loadPage(_currentPage - 1);
    }
  }

  void jumpToPage(int page) {
    if (page >= 1 && page <= totalPages) {
      loadPage(page);
    }
  }

  // Selection mode helpers
  void toggleSelectionMode() {
    _isSelectionMode = !_isSelectionMode;
    if (!_isSelectionMode) {
      clearSelection();
    }
    notifyListeners();
  }

  void toggleItemSelection(KuraaFileItem item) {
    if (_selectedIds.contains(item.id)) {
      _selectedIds.remove(item.id);
      _selectedItems.removeWhere((i) => i.id == item.id);
    } else {
      _selectedIds.add(item.id);
      _selectedItems.add(item);
    }
    notifyListeners();
  }

  void selectAll() {
    for (final item in _items) {
      if (!_selectedIds.contains(item.id)) {
        _selectedIds.add(item.id);
        _selectedItems.add(item);
      }
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedIds.clear();
    _selectedItems.clear();
    notifyListeners();
  }
}
