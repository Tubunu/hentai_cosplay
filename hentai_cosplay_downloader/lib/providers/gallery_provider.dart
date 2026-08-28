import 'package:flutter/material.dart';
import '../models/album_item.dart';
import '../services/storage_service.dart';

enum GallerySortMode {
  dateDesc('时间最新 (默认)'),
  dateAsc('时间最早'),
  sizeDesc('占用空间 (从高到低)'),
  sizeAsc('占用空间 (从低到高)'),
  titleAsc('名称 (A-Z)'),
  imagesDesc('图片数 (从多到少)'),
  imagesAsc('图片数 (从少到多)');

  final String label;
  const GallerySortMode(this.label);
}

enum GallerySourceFilter {
  all('全部', null),
  hc('HC图集', MediaSourceType.hc),
  exhentai('ExHentai', MediaSourceType.exhentai),
  mzt('妹子图库', MediaSourceType.mzt),
  misskon('MissKon', MediaSourceType.misskon),
  pixibb('PixiBB', MediaSourceType.pixibb),
  cosplaytele('CosplayTele', MediaSourceType.cosplaytele),
  nucosplay('NuCosplay', MediaSourceType.nucosplay),
  coomer('Coomer', MediaSourceType.coomer),
  kuraa('Kuraa', MediaSourceType.kuraa);

  final String label;
  final MediaSourceType? sourceType;
  const GallerySourceFilter(this.label, this.sourceType);
}

class GalleryProvider extends ChangeNotifier {
  List<LocalAlbumFolder> _localAlbums = [];
  bool _isScanning = false;
  String _searchQuery = '';
  GallerySortMode _sortMode = GallerySortMode.dateDesc;
  GallerySourceFilter _sourceFilter = GallerySourceFilter.all;
  List<LocalAlbumFolder>? _cachedSortedAlbums;
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

  GallerySortMode get sortMode => _sortMode;
  GallerySourceFilter get sourceFilter => _sourceFilter;

  List<LocalAlbumFolder> get localAlbums {
    if (_cachedSortedAlbums != null) {
      return _cachedSortedAlbums!;
    }
    _cachedSortedAlbums = _computeFilteredAndSortedAlbums();
    return _cachedSortedAlbums!;
  }

  List<LocalAlbumFolder> _computeFilteredAndSortedAlbums() {
    List<LocalAlbumFolder> list = _localAlbums;

    if (_sourceFilter.sourceType != null) {
      list = list.where((alb) => alb.sourceType == _sourceFilter.sourceType).toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((alb) {
        return alb.title.toLowerCase().contains(q) || alb.author.toLowerCase().contains(q);
      }).toList();
    }

    final sorted = List<LocalAlbumFolder>.from(list);
    switch (_sortMode) {
      case GallerySortMode.dateDesc:
        sorted.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
        break;
      case GallerySortMode.dateAsc:
        sorted.sort((a, b) => a.modifiedAt.compareTo(b.modifiedAt));
        break;
      case GallerySortMode.sizeDesc:
        sorted.sort((a, b) => b.totalBytes.compareTo(a.totalBytes));
        break;
      case GallerySortMode.sizeAsc:
        sorted.sort((a, b) => a.totalBytes.compareTo(b.totalBytes));
        break;
      case GallerySortMode.titleAsc:
        sorted.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case GallerySortMode.imagesDesc:
        sorted.sort((a, b) => b.imageCount.compareTo(a.imageCount));
        break;
      case GallerySortMode.imagesAsc:
        sorted.sort((a, b) => a.imageCount.compareTo(b.imageCount));
        break;
    }
    return sorted;
  }

  bool get isScanning => _isScanning;
  int get albumCount => _localAlbums.length;
  int get totalImages => _localAlbums.fold(0, (sum, a) => sum + a.imageCount);

  int getSourceCount(GallerySourceFilter filter) {
    if (filter == GallerySourceFilter.all || filter.sourceType == null) {
      return _localAlbums.length;
    }
    return _localAlbums.where((a) => a.sourceType == filter.sourceType).length;
  }

  int get hcCount => _localAlbums.where((a) => a.sourceType == MediaSourceType.hc).length;
  int get exhentaiCount => _localAlbums.where((a) => a.sourceType == MediaSourceType.exhentai).length;
  int get mztCount => _localAlbums.where((a) => a.sourceType == MediaSourceType.mzt).length;
  int get misskonCount => _localAlbums.where((a) => a.sourceType == MediaSourceType.misskon).length;
  int get pixibbCount => _localAlbums.where((a) => a.sourceType == MediaSourceType.pixibb).length;
  int get cosplayteleCount => _localAlbums.where((a) => a.sourceType == MediaSourceType.cosplaytele).length;
  int get nucosplayCount => _localAlbums.where((a) => a.sourceType == MediaSourceType.nucosplay).length;
  int get coomerCount => _localAlbums.where((a) => a.sourceType == MediaSourceType.coomer).length;
  int get kuraaCount => _localAlbums.where((a) => a.sourceType == MediaSourceType.kuraa).length;

  void setSourceFilter(GallerySourceFilter filter) {
    if (_sourceFilter == filter) return;
    _sourceFilter = filter;
    _cachedSortedAlbums = null;
    notifyListeners();
  }

  void setSortMode(GallerySortMode mode) {
    if (_sortMode == mode) return;
    _sortMode = mode;
    _cachedSortedAlbums = null;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    _cachedSortedAlbums = null;
    notifyListeners();
  }

  Future<void> scanLocalDirectory(String savePath) async {
    if (_isScanning) return;
    _isScanning = true;
    notifyListeners();

    try {
      String targetPath = savePath;
      if (targetPath.isEmpty) {
        targetPath = await StorageService.getDefaultDownloadPath();
      } else {
        targetPath = await StorageService.resolveValidPath(targetPath);
      }
      _localAlbums = await StorageService.scanLocalAlbums(targetPath);
      _cachedSortedAlbums = null;
    } catch (_) {}

    _isScanning = false;
    notifyListeners();
  }

  Future<bool> deleteLocalAlbum(LocalAlbumFolder album) async {
    final success = await StorageService.deleteAlbumFolder(album.folderPath);
    if (success) {
      _localAlbums.removeWhere((a) => a.folderPath == album.folderPath);
      _cachedSortedAlbums = null;
      notifyListeners();
    }
    return success;
  }
}
