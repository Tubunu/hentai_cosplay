import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/app_config.dart';
import '../models/jable_task.dart';
import '../models/jable_video_item.dart';
import '../services/config_service.dart';
import '../services/jable/jable_download_engine.dart';
import '../services/storage_service.dart';

const String _kJableTasksKey = 'jable_saved_download_tasks';
const String _kJableHistoryKey = 'jable_saved_history_records';

class JableDownloadProvider extends ChangeNotifier {
  final List<JableDownloadTask> _tasks = [];
  final List<JableHistoryRecord> _historyRecords = [];
  final Set<JableDownloadTask> _runningTasks = <JableDownloadTask>{};
  final Map<String, JableDownloadEngine> _activeEngines = {};
  final Map<String, int> _taskDownloadedBytes = {};

  AppConfig _config = ConfigService.loadConfig();

  Timer? _speedTimer;
  int _bytesSinceLastTick = 0;
  double _currentSpeedBps = 0.0;
  int _taskSequenceCounter = 0;

  DateTime _lastProgressNotifyTime = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _progressThrottleTimer;

  void Function()? onTasksChanged;

  List<JableDownloadTask> get allTasks => List.unmodifiable(_tasks);
  List<JableDownloadTask> get activeTasks =>
      _tasks.where((t) => t.status == JableDownloadStatus.downloading || t.status == JableDownloadStatus.merging).toList();
  List<JableDownloadTask> get queuedTasks =>
      _tasks.where((t) => t.status == JableDownloadStatus.waiting).toList();
  List<JableDownloadTask> get completedTasks =>
      _tasks.where((t) => t.status == JableDownloadStatus.completed).toList();
  List<JableDownloadTask> get failedTasks =>
      _tasks.where((t) => t.status == JableDownloadStatus.failed).toList();
  List<JableDownloadTask> get pausedTasks =>
      _tasks.where((t) => t.status == JableDownloadStatus.paused || t.status == JableDownloadStatus.cancelled).toList();
  List<JableHistoryRecord> get historyRecords => List.unmodifiable(_historyRecords);

  bool get isDownloading => activeTasks.isNotEmpty || queuedTasks.isNotEmpty;

  double get overallProgress {
    final active = _tasks.where((t) =>
        t.status == JableDownloadStatus.downloading ||
        t.status == JableDownloadStatus.merging ||
        t.status == JableDownloadStatus.waiting ||
        t.status == JableDownloadStatus.paused).toList();
    if (active.isEmpty) return 0.0;
    double sum = 0.0;
    for (final t in active) {
      sum += t.progress;
    }
    return (sum / (active.length * 100.0)).clamp(0.0, 1.0);
  }

  String get formattedSpeed {
    if (_currentSpeedBps <= 0) return '0 KB/s';
    if (_currentSpeedBps < 1024 * 1024) {
      return '${(_currentSpeedBps / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(_currentSpeedBps / (1024 * 1024)).toStringAsFixed(2)} MB/s';
  }

  JableDownloadProvider() {
    loadSavedData();
  }

  bool _isDisposed = false;

  void _throttledProgressNotify() {
    if (_isDisposed) return;
    final now = DateTime.now();
    final elapsed = now.difference(_lastProgressNotifyTime).inMilliseconds;
    if (elapsed >= 250) {
      _progressThrottleTimer?.cancel();
      _progressThrottleTimer = null;
      _lastProgressNotifyTime = now;
      notifyListeners();
    } else {
      if (_progressThrottleTimer == null || !_progressThrottleTimer!.isActive) {
        final delay = Duration(milliseconds: 250 - elapsed);
        _progressThrottleTimer = Timer(delay, () {
          if (_isDisposed) return;
          _lastProgressNotifyTime = DateTime.now();
          _progressThrottleTimer = null;
          notifyListeners();
        });
      }
    }
  }

  @override
  void notifyListeners() {
    if (_isDisposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _stopSpeedTimer();
    _progressThrottleTimer?.cancel();
    _progressThrottleTimer = null;
    for (final engine in _activeEngines.values) {
      engine.cancel();
    }
    _activeEngines.clear();
    super.dispose();
  }

  void _startSpeedTimer() {
    if (_speedTimer != null && _speedTimer!.isActive) return;
    _speedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _currentSpeedBps = _bytesSinceLastTick.toDouble();
      _bytesSinceLastTick = 0;
      if (activeTasks.isNotEmpty) {
        for (final task in activeTasks) {
          final bytes = _taskDownloadedBytes[task.id] ?? 0;
          _taskDownloadedBytes[task.id] = 0;
          final speedKb = bytes / 1024.0;
          if (speedKb >= 1024) {
            task.speed = "${(speedKb / 1024).toStringAsFixed(2)} MB/s";
          } else {
            task.speed = "${speedKb.toStringAsFixed(1)} KB/s";
          }
        }
        notifyListeners();
      } else if (!isDownloading) {
        _stopSpeedTimer();
      }
    });
  }

  void _stopSpeedTimer() {
    _speedTimer?.cancel();
    _speedTimer = null;
    _currentSpeedBps = 0.0;
  }

  void _updateWakelock() {
    try {
      if (isDownloading) {
        WakelockPlus.enable();
      } else {
        WakelockPlus.disable();
      }
    } catch (_) {}
  }

  Future<void> loadSavedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 1. Load tasks
      final rawTasks = prefs.getString(_kJableTasksKey);
      if (rawTasks != null && rawTasks.isNotEmpty) {
        final list = (jsonDecode(rawTasks) as List<dynamic>?) ?? [];
        _tasks.clear();
        for (final item in list) {
          final task = JableDownloadTask.fromMap(item as Map<String, dynamic>);
          if (task.status == JableDownloadStatus.downloading || task.status == JableDownloadStatus.merging) {
            task.status = JableDownloadStatus.paused;
          }
          _tasks.add(task);
        }
      }

      // 2. Load history
      final rawHistory = prefs.getString(_kJableHistoryKey);
      if (rawHistory != null && rawHistory.isNotEmpty) {
        final list = (jsonDecode(rawHistory) as List<dynamic>?) ?? [];
        _historyRecords.clear();
        for (final item in list) {
          _historyRecords.add(JableHistoryRecord.fromMap(item as Map<String, dynamic>));
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading saved Jable data: $e');
    }
  }

  Future<void> _persistTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _tasks.map((t) => t.toMap()).toList();
      await prefs.setString(_kJableTasksKey, jsonEncode(list));
    } catch (e) {
      debugPrint('Error saving Jable tasks: $e');
    }
  }

  Future<void> _persistHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _historyRecords.map((r) => r.toMap()).toList();
      await prefs.setString(_kJableHistoryKey, jsonEncode(list));
    } catch (e) {
      debugPrint('Error saving Jable history: $e');
    }
  }

  bool isDownloadedOrInQueue(String url) {
    if (_tasks.any((t) => t.url == url)) return true;
    if (_historyRecords.any((r) => r.url == url)) return true;
    return false;
  }

  Future<bool> enqueue(
    String url, {
    String? initialTitle,
    String? initialThumbnail,
    String siteName = 'JableTV',
    String duration = '',
  }) async {
    if (_tasks.any((t) => t.url == url)) {
      final task = _tasks.firstWhere((t) => t.url == url);
      if (task.status == JableDownloadStatus.paused ||
          task.status == JableDownloadStatus.failed ||
          task.status == JableDownloadStatus.cancelled) {
        task.status = JableDownloadStatus.waiting;
        task.errorMsg = null;
        _persistTasks();
        notifyListeners();
        _scheduleNext();
        return true;
      }
      return false;
    }

    _config = ConfigService.loadConfig();
    var savePath = _config.savePath.trim();
    if (savePath.isEmpty) {
      savePath = await StorageService.getDefaultDownloadPath();
    }
    final uniqueId = "${DateTime.now().microsecondsSinceEpoch}_${_taskSequenceCounter++}_${url.hashCode.abs()}";
    String name = initialTitle ?? "";
    if (name.isEmpty) {
      try {
        final uri = Uri.parse(url);
        final last = uri.pathSegments.lastWhere((s) => s.isNotEmpty, orElse: () => "");
        name = last.toUpperCase();
      } catch (_) {}
    }
    if (name.isEmpty) {
      name = "Jable 视频下载中...";
    }

    final task = JableDownloadTask(
      id: uniqueId,
      url: url,
      name: JableDownloadEngine.sanitizeFileName(name),
      thumbnailUrl: initialThumbnail ?? '',
      status: JableDownloadStatus.waiting,
      destPath: '$savePath/jabletv',
      siteName: siteName,
      duration: duration,
    );

    _tasks.add(task);
    _persistTasks();
    notifyListeners();

    _scheduleNext();
    return true;
  }

  Future<void> enqueueBatch(List<VideoCardModel> videos) async {
    for (final video in videos) {
      await enqueue(
        video.url,
        initialTitle: video.title,
        initialThumbnail: video.thumbnail,
        siteName: video.siteName,
        duration: video.duration,
      );
    }
  }

  void pauseTask(JableDownloadTask task) {
    _activeEngines[task.id]?.cancel();
    _activeEngines.remove(task.id);
    task.status = JableDownloadStatus.paused;
    task.speed = '0 KB/s';
    _runningTasks.remove(task);
    _persistTasks();
    notifyListeners();
    _scheduleNext();
  }

  void pauseAllTasks() {
    for (final engine in _activeEngines.values) {
      engine.cancel();
    }
    _activeEngines.clear();
    for (final task in _tasks) {
      if (task.status == JableDownloadStatus.downloading ||
          task.status == JableDownloadStatus.waiting ||
          task.status == JableDownloadStatus.merging) {
        task.status = JableDownloadStatus.paused;
        task.speed = '0 KB/s';
      }
    }
    _runningTasks.clear();
    _updateWakelock();
    _persistTasks();
    notifyListeners();
  }

  void resumeTask(JableDownloadTask task) {
    if (task.status == JableDownloadStatus.paused ||
        task.status == JableDownloadStatus.failed ||
        task.status == JableDownloadStatus.cancelled) {
      task.status = JableDownloadStatus.waiting;
      task.errorMsg = null;
      _persistTasks();
      notifyListeners();
      _scheduleNext();
    }
  }

  void resumeAllTasks() {
    for (final task in _tasks) {
      if (task.status == JableDownloadStatus.paused ||
          task.status == JableDownloadStatus.failed ||
          task.status == JableDownloadStatus.cancelled) {
        task.status = JableDownloadStatus.waiting;
        task.errorMsg = null;
      }
    }
    _persistTasks();
    notifyListeners();
    _scheduleNext();
  }

  Future<void> removeTask(JableDownloadTask task, {bool deleteFile = false}) async {
    pauseTask(task);
    if (deleteFile) {
      final mp4File = File("${task.destPath}/${task.name}.mp4");
      if (await mp4File.exists()) {
        try {
          await mp4File.delete();
        } catch (_) {}
      }
    }
    _tasks.removeWhere((t) => t.id == task.id);
    _runningTasks.remove(task);
    _persistTasks();
    notifyListeners();
    _scheduleNext();
  }

  void clearCompleted() {
    _tasks.removeWhere((t) => t.status == JableDownloadStatus.completed);
    _persistTasks();
    notifyListeners();
  }

  void removeHistoryRecord(String id) {
    _historyRecords.removeWhere((r) => r.id == id);
    _persistHistory();
    notifyListeners();
  }

  void clearAllHistory() {
    _historyRecords.clear();
    _persistHistory();
    notifyListeners();
  }

  void _scheduleNext() {
    if (_isDisposed) return;
    _updateWakelock();
    _startSpeedTimer();

    _config = ConfigService.loadConfig();
    final maxConcurrent = _config.jableWorkers.clamp(1, 10);

    while (_runningTasks.length < maxConcurrent) {
      if (_isDisposed) break;
      final waiting = _tasks.where((t) => t.status == JableDownloadStatus.waiting).toList();
      if (waiting.isEmpty) break;

      final nextTask = waiting.first;
      nextTask.status = JableDownloadStatus.downloading;
      _runningTasks.add(nextTask);
      notifyListeners();

      _executeTask(nextTask);
    }

    if (_runningTasks.isEmpty && queuedTasks.isEmpty) {
      _updateWakelock();
    }
  }

  Future<void> _executeTask(JableDownloadTask task) async {
    final engine = JableDownloadEngine(
      task: task,
      onBytesReceived: (bytes) {
        _bytesSinceLastTick += bytes;
        _taskDownloadedBytes[task.id] = (_taskDownloadedBytes[task.id] ?? 0) + bytes;
      },
      onTaskUpdated: (t) {
        _throttledProgressNotify();
      },
    );
    _activeEngines[task.id] = engine;

    try {
      await engine.run();

      if (task.status == JableDownloadStatus.completed) {
        // Record to History
        String sizeStr = "";
        final mp4File = File("${task.destPath}/${task.name}.mp4");
        if (await mp4File.exists()) {
          final len = await mp4File.length();
          sizeStr = "${(len / (1024 * 1024)).toStringAsFixed(1)} MB";
        }
        final record = JableHistoryRecord(
          id: task.id,
          url: task.url,
          name: task.name,
          size: sizeStr,
          date: DateTime.now().toString().split('.').first,
          destPath: task.destPath,
          thumbnailUrl: task.thumbnailUrl,
          siteName: task.siteName,
          duration: task.duration,
          completedAt: DateTime.now(),
        );

        _historyRecords.removeWhere((r) => r.url == task.url);
        _historyRecords.insert(0, record);
        await _persistHistory();

        onTasksChanged?.call();
      }
    } catch (e) {
      debugPrint('Jable task ${task.name} execution error: $e');
      if (task.status != JableDownloadStatus.cancelled) {
        task.status = JableDownloadStatus.failed;
        task.errorMsg = e.toString();
      }
    } finally {
      if (task.status == JableDownloadStatus.downloading || task.status == JableDownloadStatus.merging) {
        task.status = JableDownloadStatus.failed;
      }
      _activeEngines.remove(task.id);
      _runningTasks.remove(task);
      _taskDownloadedBytes.remove(task.id);
      _persistTasks();
      notifyListeners();
      _scheduleNext();
    }
  }
}
