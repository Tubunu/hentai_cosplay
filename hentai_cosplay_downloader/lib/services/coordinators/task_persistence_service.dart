import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/download_task.dart';

class TaskPersistenceService {
  static const String _kTasksKey = 'hc_saved_download_tasks';
  Timer? _debounceTimer;
  List<AlbumDownloadTask>? _pendingTasksToSave;

  /// Load tasks from SharedPreferences
  Future<List<AlbumDownloadTask>> loadTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kTasksKey);
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
    _pendingTasksToSave = List.from(tasks);

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
    final tasks = _pendingTasksToSave;
    if (tasks == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kTasksKey, AlbumDownloadTask.listToJson(tasks));
    } catch (e) {
      debugPrint('Error persisting tasks: $e');
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
