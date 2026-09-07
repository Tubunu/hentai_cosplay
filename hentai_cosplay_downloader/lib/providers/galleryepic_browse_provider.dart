import 'package:flutter/foundation.dart';
import '../models/album_item.dart';
import '../services/galleryepic/galleryepic_api_service.dart';

class GalleryepicBrowseProvider extends ChangeNotifier {
  List<AlbumItem> _items = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _currentPage = 1;
  int _totalPages = 335;
  int _totalItems = 0;
  int _currentRequestId = 0;

  // 2 Categories & 5 Buttons State
  GalleryEpicMainCategory _mainCategory = GalleryEpicMainCategory.cosplay;
  GalleryEpicSubCategory _subCategory = GalleryEpicSubCategory.lists;

  // Creators & Parodies state
  List<GalleryEpicCreatorItem> _creators = [];
  int _creatorPage = 1;
  int _creatorTotalPages = 1;
  List<GalleryEpicParodyItem> _parodies = [];

  // Filter Selection
  GalleryEpicCreatorItem? _selectedCreator;
  GalleryEpicParodyItem? _selectedParody;
  List<GalleryEpicCharacterItem> _parodyCharacters = [];
  GalleryEpicCharacterItem? _selectedCharacter;
  bool _isLoadingCharacters = false;
  String? _searchKeyword;

  bool _isSelectionMode = false;
  final Set<String> _selectedSlugs = {};

  List<AlbumItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalItems => _totalItems;

  GalleryEpicMainCategory get mainCategory => _mainCategory;
  GalleryEpicSubCategory get subCategory => _subCategory;
  GalleryEpicCategory get currentCategory =>
      _mainCategory == GalleryEpicMainCategory.cosplay
          ? GalleryEpicCategory.cosplay
          : GalleryEpicCategory.albums;

  List<GalleryEpicCreatorItem> get creators => _creators;
  int get creatorPage => _creatorPage;
  int get creatorTotalPages => _creatorTotalPages;
  List<GalleryEpicParodyItem> get parodies => _parodies;

  List<GalleryEpicCreatorItem> get displayedCreators {
    if (_searchKeyword == null || _searchKeyword!.isEmpty) return _creators;
    final kw = _searchKeyword!.toLowerCase();
    return _creators.where((c) => c.name.toLowerCase().contains(kw)).toList();
  }

  List<GalleryEpicParodyItem> get displayedParodies {
    if (_searchKeyword == null || _searchKeyword!.isEmpty) return _parodies;
    final kw = _searchKeyword!.toLowerCase();
    return _parodies.where((p) => p.name.toLowerCase().contains(kw)).toList();
  }

  GalleryEpicCreatorItem? get selectedCreator => _selectedCreator;
  GalleryEpicParodyItem? get selectedParody => _selectedParody;
  List<GalleryEpicCharacterItem> get parodyCharacters => _parodyCharacters;
  GalleryEpicCharacterItem? get selectedCharacter => _selectedCharacter;
  bool get isLoadingCharacters => _isLoadingCharacters;
  String? get searchKeyword => _searchKeyword;
  bool get isSearchMode => _searchKeyword != null && _searchKeyword!.isNotEmpty;
  bool get hasActiveFilter =>
      _selectedCreator != null ||
      _selectedParody != null ||
      _selectedCharacter != null ||
      isSearchMode;

  bool get isSelectionMode => _isSelectionMode;
  Set<String> get selectedSlugs => _selectedSlugs;
  int get selectedCount => _selectedSlugs.length;
  List<AlbumItem> get selectedItems =>
      _items.where((item) => _selectedSlugs.contains(item.slug)).toList();

  GalleryepicBrowseProvider({bool autoLoad = false}) {
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

  // Load Album Page Data
  Future<void> loadPage(int page) async {
    final requestId = ++_currentRequestId;
    _currentPage = page;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final effectiveCustomPath = _selectedCharacter?.detailPath ??
          _selectedCreator?.detailPath ??
          _selectedParody?.detailPath;

      final response = await GalleryepicApiService.fetchPageData(
        page: page,
        category: currentCategory,
        keyword: _searchKeyword,
        customPath: effectiveCustomPath,
      );

      if (requestId != _currentRequestId) return;

      if (response != null) {
        _items = response.items;
        _currentPage = response.page;
        _totalPages = response.totalPages;
        _totalItems = response.total;
        _selectedSlugs.clear();
        _isSelectionMode = false;
      } else {
        _errorMessage = '获取 GalleryEpic 列表失败，请检查网络或配置代理';
      }
    } catch (e) {
      if (requestId != _currentRequestId) return;
      _errorMessage = '请求错误: $e';
    } finally {
      if (requestId == _currentRequestId) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  // Load Cosers or Models Page
  Future<void> loadCreators({int page = 1}) async {
    final requestId = ++_currentRequestId;
    _creatorPage = page;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = _subCategory == GalleryEpicSubCategory.cosers
          ? await GalleryepicApiService.fetchCosers(page: page)
          : await GalleryepicApiService.fetchModels(page: page);

      if (requestId != _currentRequestId) return;

      if (response != null) {
        _creators = response.items;
        _creatorPage = response.page;
        _creatorTotalPages = response.totalPages;
      } else {
        _errorMessage = '获取列表失败，请重试';
      }
    } catch (e) {
      if (requestId != _currentRequestId) return;
      _errorMessage = '请求错误: $e';
    } finally {
      if (requestId == _currentRequestId) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  // Load Parodies List
  Future<void> loadParodies() async {
    final requestId = ++_currentRequestId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final list = await GalleryepicApiService.fetchParodies();
      if (requestId != _currentRequestId) return;
      _parodies = list;
    } catch (e) {
      if (requestId != _currentRequestId) return;
      _errorMessage = '请求错误: $e';
    } finally {
      if (requestId == _currentRequestId) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  // Switch Main Category (Cosplay vs Album)
  void switchMainCategory(GalleryEpicMainCategory category) {
    if (_mainCategory == category) return;
    _mainCategory = category;
    _subCategory = GalleryEpicSubCategory.lists;
    _selectedCreator = null;
    _selectedParody = null;
    _selectedCharacter = null;
    _parodyCharacters = [];
    _searchKeyword = null;
    _currentPage = 1;
    _items = [];
    _selectedSlugs.clear();
    _isSelectionMode = false;
    loadPage(1);
  }

  // Switch Subcategory (Lists, Cosers, Parodies, Models)
  void switchSubCategory(GalleryEpicSubCategory subCategory) {
    if (_subCategory == subCategory && !hasActiveFilter) return;
    _subCategory = subCategory;
    _selectedCreator = null;
    _selectedParody = null;
    _selectedCharacter = null;
    _parodyCharacters = [];
    _searchKeyword = null;
    _currentPage = 1;
    _items = [];
    _selectedSlugs.clear();
    _isSelectionMode = false;

    if (subCategory == GalleryEpicSubCategory.lists) {
      loadPage(1);
    } else if (subCategory == GalleryEpicSubCategory.cosers ||
        subCategory == GalleryEpicSubCategory.models) {
      loadCreators(page: 1);
    } else if (subCategory == GalleryEpicSubCategory.parodies) {
      loadParodies();
    }
  }

  // Select a creator (Coser or Model) to view their albums
  void selectCreator(GalleryEpicCreatorItem creator) {
    _selectedCreator = creator;
    _selectedParody = null;
    _selectedCharacter = null;
    _parodyCharacters = [];
    _searchKeyword = null;
    _currentPage = 1;
    _items = [];
    _selectedSlugs.clear();
    _isSelectionMode = false;
    loadPage(1);
  }

  // Select a Parody to fetch characters and view albums
  Future<void> selectParody(GalleryEpicParodyItem parody) async {
    _selectedParody = parody;
    _selectedCreator = null;
    _selectedCharacter = null;
    _parodyCharacters = [];
    _searchKeyword = null;
    _currentPage = 1;
    _items = [];
    _selectedSlugs.clear();
    _isSelectionMode = false;
    _isLoadingCharacters = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final chars = await GalleryepicApiService.fetchParodyCharacters(parody.detailPath);
      _parodyCharacters = chars;
      _isLoadingCharacters = false;
      notifyListeners();

      if (chars.isNotEmpty) {
        selectCharacter(chars.first);
      } else {
        loadPage(1);
      }
    } catch (e) {
      _isLoadingCharacters = false;
      _errorMessage = '加载角色失败: $e';
      notifyListeners();
    }
  }

  // Select a specific Character under a Parody
  void selectCharacter(GalleryEpicCharacterItem character) {
    _selectedCharacter = character;
    _currentPage = 1;
    _items = [];
    _selectedSlugs.clear();
    _isSelectionMode = false;
    loadPage(1);
  }

  // Clear any active filter
  void clearActiveFilter() {
    _selectedCreator = null;
    _selectedParody = null;
    _selectedCharacter = null;
    _parodyCharacters = [];
    _searchKeyword = null;
    _currentPage = 1;
    _items = [];
    _selectedSlugs.clear();
    _isSelectionMode = false;

    if (_subCategory == GalleryEpicSubCategory.lists) {
      loadPage(1);
    } else if (_subCategory == GalleryEpicSubCategory.cosers ||
        _subCategory == GalleryEpicSubCategory.models) {
      loadCreators(page: _creatorPage);
    } else if (_subCategory == GalleryEpicSubCategory.parodies) {
      loadParodies();
    }
  }

  Future<void> search(String keyword) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) {
      clearActiveFilter();
      return;
    }

    _searchKeyword = trimmed;

    // If currently on parodies tab, filter parodies
    if (_subCategory == GalleryEpicSubCategory.parodies) {
      if (_parodies.isEmpty) {
        await loadParodies();
      }
      notifyListeners();
      return;
    }

    // If currently on cosers or models tab, filter creators
    if (_subCategory == GalleryEpicSubCategory.cosers ||
        _subCategory == GalleryEpicSubCategory.models) {
      if (_creators.isEmpty) {
        await loadCreators(page: 1);
      }
      notifyListeners();
      return;
    }

    final lower = trimmed.toLowerCase();

    // 1. Check if user typed an exact parody title (e.g. Fate, 原神, 碧蓝航线)
    if (_parodies.isNotEmpty) {
      final matchedParody = _parodies.cast<GalleryEpicParodyItem?>().firstWhere(
        (p) => p != null && p.name.toLowerCase() == lower,
        orElse: () => null,
      );
      if (matchedParody != null) {
        _subCategory = GalleryEpicSubCategory.parodies;
        await selectParody(matchedParody);
        return;
      }
    }

    // 2. Check if user typed an exact creator name
    if (_creators.isNotEmpty) {
      final matchedCreator = _creators.cast<GalleryEpicCreatorItem?>().firstWhere(
        (c) => c != null && c.name.toLowerCase() == lower,
        orElse: () => null,
      );
      if (matchedCreator != null) {
        selectCreator(matchedCreator);
        return;
      }
    }

    // 3. Album Search across pages
    _selectedCreator = null;
    _selectedParody = null;
    _selectedCharacter = null;
    _parodyCharacters = [];
    _currentPage = 1;
    _items = [];
    _selectedSlugs.clear();
    _isSelectionMode = false;
    await loadPage(1);
  }

  void nextPage() {
    if (_selectedCreator == null &&
        (_subCategory == GalleryEpicSubCategory.cosers ||
            _subCategory == GalleryEpicSubCategory.models)) {
      if (_creatorPage < _creatorTotalPages) {
        loadCreators(page: _creatorPage + 1);
      }
    } else {
      if (_currentPage < _totalPages) {
        loadPage(_currentPage + 1);
      }
    }
  }

  void prevPage() {
    if (_selectedCreator == null &&
        (_subCategory == GalleryEpicSubCategory.cosers ||
            _subCategory == GalleryEpicSubCategory.models)) {
      if (_creatorPage > 1) {
        loadCreators(page: _creatorPage - 1);
      }
    } else {
      if (_currentPage > 1) {
        loadPage(_currentPage - 1);
      }
    }
  }

  Future<void> refresh() async {
    if (_selectedCreator == null &&
        (_subCategory == GalleryEpicSubCategory.cosers ||
            _subCategory == GalleryEpicSubCategory.models)) {
      await loadCreators(page: _creatorPage);
    } else if (_selectedCreator == null &&
        _subCategory == GalleryEpicSubCategory.parodies) {
      await loadParodies();
    } else {
      await loadPage(_currentPage);
    }
  }
}
