import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../models/jable_video_item.dart';
import '../services/config_service.dart';

class LocalJableProvider extends ChangeNotifier {
  final List<JableLocalVideoItem> _videos = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String _sortOption = 'date_desc'; // 'date_desc', 'date_asc', 'name_asc', 'size_desc'
  List<JableLocalVideoItem>? _cachedFilteredVideos;
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

  List<JableLocalVideoItem> get allVideos => List.unmodifiable(_videos);
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String get sortOption => _sortOption;

  int get totalCount => _videos.length;
  int get totalSizeBytes => _videos.fold(0, (acc, item) => acc + item.fileSizeBytes);
  String get totalFormattedSize {
    if (totalSizeBytes <= 0) return '0 B';
    if (totalSizeBytes < 1024 * 1024) {
      return '${(totalSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    if (totalSizeBytes < 1024 * 1024 * 1024) {
      return '${(totalSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(totalSizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  List<JableLocalVideoItem> get filteredVideos {
    if (_cachedFilteredVideos != null) return _cachedFilteredVideos!;
    List<JableLocalVideoItem> result = List.from(_videos);

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((v) {
        return v.title.toLowerCase().contains(q) ||
            v.fileName.toLowerCase().contains(q) ||
            v.siteName.toLowerCase().contains(q) ||
            v.tags.any((t) => t.toLowerCase().contains(q));
      }).toList();
    }

    switch (_sortOption) {
      case 'date_asc':
        result.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'name_asc':
        result.sort((a, b) => a.title.compareTo(b.title));
        break;
      case 'size_desc':
        result.sort((a, b) => b.fileSizeBytes.compareTo(a.fileSizeBytes));
        break;
      case 'date_desc':
      default:
        result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }

    _cachedFilteredVideos = result;
    return result;
  }

  LocalJableProvider() {
    scanLocalVideos();
  }

  void setSearchQuery(String query) {
    _searchQuery = query.trim();
    _cachedFilteredVideos = null;
    notifyListeners();
  }

  void setSortOption(String sort) {
    _sortOption = sort;
    _cachedFilteredVideos = null;
    notifyListeners();
  }

  Future<void> scanLocalVideos() async {
    _isLoading = true;
    notifyListeners();

    try {
      final config = ConfigService.loadConfig();
      if (config.savePath.isEmpty) {
        _videos.clear();
        _isLoading = false;
        notifyListeners();
        return;
      }

      final jableDir = Directory(p.join(config.savePath, 'jabletv'));
      if (!await jableDir.exists()) {
        _videos.clear();
        _isLoading = false;
        notifyListeners();
        return;
      }

      final List<JableLocalVideoItem> items = [];
      final entities = await jableDir.list().toList();

      for (final entity in entities) {
        if (entity is File) {
          final ext = p.extension(entity.path).toLowerCase();
          if (ext == '.mp4' || ext == '.mkv' || ext == '.ts') {
            final base = p.basenameWithoutExtension(entity.path);
            final stat = await entity.stat();
            
            // Check companion cover
            String? coverPath;
            final jpgCover = File(p.join(jableDir.path, '$base.jpg'));
            final pngCover = File(p.join(jableDir.path, '$base.png'));
            if (await jpgCover.exists()) {
              coverPath = jpgCover.path;
            } else if (await pngCover.exists()) {
              coverPath = pngCover.path;
            }

            // Check companion json
            final metaFile = File(p.join(jableDir.path, '$base.json'));
            String title = base;
            String duration = '';
            String sourceUrl = '';
            String siteName = 'JableTV';
            List<String> tags = [];

            if (await metaFile.exists()) {
              try {
                final content = await metaFile.readAsString();
                final json = jsonDecode(content) as Map<String, dynamic>;
                title = json['title'] as String? ?? base;
                duration = json['duration'] as String? ?? '';
                sourceUrl = json['url'] as String? ?? '';
                siteName = json['siteName'] as String? ?? 'JableTV';
                tags = (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
              } catch (_) {}
            }

            items.add(JableLocalVideoItem(
              id: entity.path,
              title: title,
              filePath: entity.path,
              coverPath: coverPath,
              fileSizeBytes: stat.size,
              createdAt: stat.modified,
              duration: duration,
              sourceUrl: sourceUrl,
              siteName: siteName,
              tags: tags,
            ));
          }
        }
      }

      _videos.clear();
      _videos.addAll(items);
      _cachedFilteredVideos = null;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error scanning local Jable videos: $e');
      _cachedFilteredVideos = null;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteVideo(JableLocalVideoItem item) async {
    try {
      final videoFile = File(item.filePath);
      if (await videoFile.exists()) {
        await videoFile.delete();
      }

      if (item.coverPath != null) {
        final coverFile = File(item.coverPath!);
        if (await coverFile.exists()) {
          await coverFile.delete();
        }
      }

      final parent = p.dirname(item.filePath);
      final base = p.basenameWithoutExtension(item.filePath);
      final jsonFile = File(p.join(parent, '$base.json'));
      if (await jsonFile.exists()) {
        await jsonFile.delete();
      }

      _videos.removeWhere((v) => v.filePath == item.filePath);
      _cachedFilteredVideos = null;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting local video: $e');
      return false;
    }
  }
}
