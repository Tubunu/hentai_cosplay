import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import '../models/app_config.dart';
import '../models/pack_item.dart';

class LocalPackInfo {
  final String name;
  final String dirPath;
  final String title;
  final String author;
  final List<String> imagePaths;
  final DateTime modifiedTime;
  final Map<String, dynamic>? metadata;
  final bool isArchived;

  LocalPackInfo({
    required this.name,
    required this.dirPath,
    required this.title,
    required this.author,
    required this.imagePaths,
    required this.modifiedTime,
    this.metadata,
    this.isArchived = false,
  });

  String? get coverPath => imagePaths.isNotEmpty ? imagePaths.first : null;
  int get imageCount => imagePaths.length;
}

class StorageService {
  static const Set<String> _validExtensions = {
    'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'
  };

  /// Request storage permissions on Android (supporting Android 11+ manage external storage)
  static Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid) return true;

    // Check MANAGE_EXTERNAL_STORAGE on Android 11+ (API 30+)
    if (await Permission.manageExternalStorage.isGranted) {
      return true;
    }

    final manageStatus = await Permission.manageExternalStorage.request();
    if (manageStatus.isGranted) {
      return true;
    }

    // Fallback to legacy storage permission
    if (await Permission.storage.isGranted) {
      return true;
    }

    final storageStatus = await Permission.storage.request();
    return storageStatus.isGranted;
  }

  /// Check if the target directory is writable
  static Future<bool> isDirectoryWritable(String path) async {
    try {
      final dir = Directory(path);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final testFile = File('${dir.path}/.test_write_perm_${DateTime.now().millisecondsSinceEpoch}');
      await testFile.writeAsString('ok');
      await testFile.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Scan local storage for downloaded and archived packs
  static Future<List<LocalPackInfo>> scanLocalPacks(String baseDirPath) async {
    final cleanPath = baseDirPath.trim();
    if (cleanPath.isEmpty) return [];

    final baseDir = Directory(cleanPath);
    if (!await baseDir.exists()) {
      return [];
    }

    final List<LocalPackInfo> packs = [];
    final List<MapEntry<String, bool>> candidateDirs = []; // path, isArchived

    try {
      final entities = await baseDir.list().toList();
      for (final entity in entities) {
        if (entity is Directory) {
          final dirName = p.basename(entity.path);
          if (dirName == 'archive') {
            // Scan author subdirectories
            try {
              final authorDirs = await entity.list().toList();
              for (final authorEntity in authorDirs) {
                if (authorEntity is Directory) {
                  final packDirs = await authorEntity.list().toList();
                  for (final packDir in packDirs) {
                    if (packDir is Directory) {
                      candidateDirs.add(MapEntry(packDir.path, true));
                    }
                  }
                }
              }
            } catch (_) {}
          } else {
            candidateDirs.add(MapEntry(entity.path, false));
          }
        }
      }
    } catch (e) {
      debugPrint('Error listing directory: $e');
    }

    for (final candidate in candidateDirs) {
      final dirPath = candidate.key;
      final isArchived = candidate.value;
      final dir = Directory(dirPath);

      try {
        final files = await dir.list().toList();
        final List<String> imagePaths = [];
        Map<String, dynamic>? meta;
        String? titleFromMeta;
        String? authorFromMeta;

        for (final file in files) {
          if (file is File) {
            final fileName = p.basename(file.path);
            final ext = p.extension(file.path).replaceAll('.', '').toLowerCase();

            if (fileName == kPackMetadataFilename) {
              try {
                final content = await file.readAsString();
                meta = jsonDecode(content) as Map<String, dynamic>;
                titleFromMeta = meta['title']?.toString() ??
                    meta['item']?['title']?.toString();
                final itemData = (meta['item'] as Map<String, dynamic>?) ?? {};
                authorFromMeta = PackItem.inferAuthor(titleFromMeta ?? fileName, itemData);
              } catch (_) {}
            } else if (_validExtensions.contains(ext)) {
              imagePaths.add(file.path);
            }
          }
        }

        if (imagePaths.isNotEmpty) {
          // Sort image paths naturally (1.jpg, 2.jpg, 10.jpg)
          imagePaths.sort((a, b) {
            final nameA = p.basenameWithoutExtension(a);
            final nameB = p.basenameWithoutExtension(b);
            final numA = int.tryParse(nameA);
            final numB = int.tryParse(nameB);
            if (numA != null && numB != null) {
              return numA.compareTo(numB);
            }
            return nameA.compareTo(nameB);
          });

          final folderName = p.basename(dirPath);
          final stat = await dir.stat();

          final finalTitle = titleFromMeta ?? folderName;
          final finalAuthor = authorFromMeta ??
              PackItem.cleanArchiveSegment(
                isArchived ? p.basename(p.dirname(dirPath)) : PackItem.inferAuthor(finalTitle, {}),
              );

          packs.add(
            LocalPackInfo(
              name: folderName,
              dirPath: dirPath,
              title: finalTitle,
              author: finalAuthor,
              imagePaths: imagePaths,
              modifiedTime: stat.modified,
              metadata: meta,
              isArchived: isArchived,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error inspecting folder $dirPath: $e');
      }
    }

    return packs;
  }

  /// Safely move a directory to a new target, handling cross-partition mounts and existing destinations
  static Future<void> _safeMoveDirectory(Directory src, Directory dst) async {
    if (!await src.exists()) return;

    if (!await dst.exists()) {
      try {
        await src.rename(dst.path);
        return;
      } catch (_) {
        // Rename failed (e.g. cross-partition), fallback to copy & delete
      }
    }

    // Copy files one by one into destination
    if (!await dst.exists()) {
      await dst.create(recursive: true);
    }

    final entities = await src.list(recursive: false).toList();
    for (final entity in entities) {
      final name = p.basename(entity.path);
      final targetPath = p.join(dst.path, name);
      if (entity is File) {
        final targetFile = File(targetPath);
        if (await targetFile.exists()) {
          await targetFile.delete();
        }
        await entity.copy(targetPath);
        await entity.delete();
      } else if (entity is Directory) {
        await _safeMoveDirectory(entity, Directory(targetPath));
      }
    }

    // Try to remove source directory
    try {
      await src.delete(recursive: true);
    } catch (_) {}
  }

  /// Archive unorganized packs into `savePath/archive/<author>/<pack_name>`
  static Future<int> organizeAndArchivePacks(
    String baseDirPath, {
    String strategy = 'author',
    void Function(String message)? onProgress,
  }) async {
    final cleanPath = baseDirPath.trim();
    if (cleanPath.isEmpty) return 0;

    final baseDir = Directory(cleanPath);
    if (!await baseDir.exists()) return 0;

    final archiveBaseDir = Directory(p.join(cleanPath, 'archive'));
    if (!await archiveBaseDir.exists()) {
      await archiveBaseDir.create(recursive: true);
    }

    int archivedCount = 0;

    try {
      final entities = await baseDir.list().toList();
      for (final entity in entities) {
        if (entity is Directory) {
          final folderName = p.basename(entity.path);
          if (folderName == 'archive') continue;

          // Check if this folder has any files inside
          final items = await entity.list().toList();
          if (items.isEmpty) continue;

          // Read pack metadata or infer from title
          final metaFile = File(p.join(entity.path, kPackMetadataFilename));
          String authorName = '未知作者';
          String packTitle = folderName;

          if (await metaFile.exists()) {
            try {
              final content = await metaFile.readAsString();
              final meta = jsonDecode(content) as Map<String, dynamic>;
              packTitle = meta['title']?.toString() ??
                  meta['item']?['title']?.toString() ??
                  folderName;
              final itemData = (meta['item'] as Map<String, dynamic>?) ?? {};
              authorName = PackItem.inferAuthor(packTitle, itemData);
            } catch (_) {
              authorName = PackItem.inferAuthor(folderName, {});
            }
          } else {
            authorName = PackItem.inferAuthor(folderName, {});
          }

          authorName = PackItem.cleanArchiveSegment(authorName);
          final targetAuthorDir = Directory(p.join(archiveBaseDir.path, authorName));
          if (!await targetAuthorDir.exists()) {
            await targetAuthorDir.create(recursive: true);
          }

          final targetPackDir = Directory(p.join(targetAuthorDir.path, folderName));

          // Execute move
          try {
            await _safeMoveDirectory(entity, targetPackDir);
            archivedCount++;
            onProgress?.call('归档: $folderName ➔ $authorName');
          } catch (e) {
            onProgress?.call('归档移动出错 $folderName: $e');
          }
        }
      }
    } catch (e) {
      onProgress?.call('扫描归档失败: $e');
    }

    return archivedCount;
  }
}
