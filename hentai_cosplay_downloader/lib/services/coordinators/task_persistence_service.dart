import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/download_task.dart';

class TaskPersistenceService {
  static const String _kTasksKey = 'hc_saved_download_tasks';
  static const String _kTasksFileName = 'hc_download_tasks.json';
  Timer? _debounceTimer;
  String? _pendingJsonToSave;

  Future<File> _getStorageFile() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      return File('${docDir.path}/$_kTasksFileName');
    } catch (_) {
      return File('${Directory.systemTemp.path}/$_kTasksFileName');
    }
  }

  /// Load tasks from dedicated file or auto-migrate legacy data from SharedPreferences
  Future<List<AlbumDownloadTask>> loadTasks() async {
    try {
      final file = await _getStorageFile();
      String? raw;

      if (await file.exists()) {
        raw = await file.readAsString();
      } else {
        // Auto-migration from legacy SharedPreferences key
        final prefs = await SharedPreferences.getInstance();
        final legacy = prefs.getString(_kTasksKey);
        if (legacy != null && legacy.isNotEmpty) {
          raw = legacy;
          // Migrate immediately to file storage and clean up SharedPreferences
          try {
            await file.writeAsString(legacy);
            await prefs.remove(_kTasksKey);
          } catch (_) {}
        }
      }

      if (raw != null && raw.isNotEmpty) {
        final loaded = AlbumDownloadTask.listFromJson(raw);
        for (final t in loaded) {
          if (t.status == TaskStatus.downloading) {
            t.status = TaskStatus.paused;
          }
        }
        return loaded;
      }
    } catch (e) {
      debugPrint('Error loading saved tasks: $e');
    }
    return [];
  }

  /// Persist tasks with optional debounce (default: debounced by 1.5s, immediate on important state transitions)
  void persistTasks(List<AlbumDownloadTask> tasks, {bool immediate = false}) {
    // 立即同步序列化生成快照，避免异步写入前任务对象发生并发修改
    _pendingJsonToSave = AlbumDownloadTask.listToJson(tasks);

    if (immediate) {
      _debounceTimer?.cancel();
      _debounceTimer = null;
      _writeToDisk();
      return;
    }

    if (_debounceTimer == null || !_debounceTimer!.isActive) {
      _debounceTimer = Timer(const Duration(milliseconds: 1500), () {
        _debounceTimer = null;
        _writeToDisk();
      });
    }
  }

  Future<void> _writeToDisk() async {
    final jsonStr = _pendingJsonToSave;
    if (jsonStr == null) return;
    File? tempFile;
    try {
      final file = await _getStorageFile();
      tempFile = File('${file.path}.tmp_${DateTime.now().microsecondsSinceEpoch}');
      await tempFile.writeAsString(jsonStr);

      if (await file.exists()) {
        await file.delete();
      }
      await tempFile.rename(file.path);
    } catch (e) {
      debugPrint('Error persisting tasks to file: $e');
      if (tempFile != null && await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
    }
  }

  /// Flush any pending write immediately
  Future<void> flush() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    await _writeToDisk();
  }

  void dispose() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _writeToDisk();
  }
}
