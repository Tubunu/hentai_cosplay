import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pool/pool.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_config.dart';
import '../models/download_task.dart';
import '../models/history_record.dart';
import '../models/pack_item.dart';
import '../services/api_service.dart';
import '../services/download_engine.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';

class LogEntry {
  final DateTime timestamp;
  final String message;
  final String level; // 'info', 'warn', 'error', 'success'

  LogEntry({
    required this.timestamp,
    required this.message,
    this.level = 'info',
  });

  String get timeFormatted => DateFormat('HH:mm:ss').format(timestamp);
}

class DownloadProvider extends ChangeNotifier {
  static const String _kHistoryKey = 'mzt_download_history_v1';
  static const String _kTasksKey = 'mzt_download_tasks_v1';

  final List<PackDownloadTask> _allTasks = [];
  final List<LogEntry> _logs = [];

  // Track tasks belonging to the current download batch
  final Set<String> _currentBatchTaskIds = {};

  bool _isEngineRunning = false;
  DownloadEngine? _currentEngine;
  DateTime? _batchStartTime;

  // Speed measurement
  int _bytesSinceLastTick = 0;
  double _currentSpeedBps = 0.0;
  Timer? _speedTimer;

  // Configuration snapshot
  AppConfig _config = AppConfig();

  // Callbacks for notifying history and gallery
  void Function(HistoryRecord record)? onBatchCompleted;
  void Function()? onPacksChanged;

  List<PackDownloadTask> get allTasks => _allTasks;
  List<PackDownloadTask> get queuedTasks =>
      _allTasks.where((t) => t.status == TaskStatus.queued).toList();
  List<PackDownloadTask> get activeTasks =>
      _allTasks.where((t) => t.status == TaskStatus.downloading).toList();
  List<PackDownloadTask> get pausedTasks =>
      _allTasks.where((t) => t.status == TaskStatus.paused).toList();
  List<PackDownloadTask> get completedTasks =>
      _allTasks.where((t) => t.status == TaskStatus.completed).toList();
  List<PackDownloadTask> get failedTasks =>
      _allTasks.where((t) => t.status == TaskStatus.failed).toList();

  List<LogEntry> get logs => UnmodifiableListView(_logs);

  bool get isDownloading => _isEngineRunning || activeTasks.isNotEmpty;
  bool get hasActiveOrPausedTasks =>
      activeTasks.isNotEmpty || queuedTasks.isNotEmpty || pausedTasks.isNotEmpty;

  PackDownloadTask? get currentActiveTask {
    if (activeTasks.isNotEmpty) return activeTasks.first;
    if (queuedTasks.isNotEmpty) return queuedTasks.first;
    if (pausedTasks.isNotEmpty) return pausedTasks.first;
    return null;
  }

  double get overallProgress {
    if (_allTasks.isEmpty) return 0.0;
    int totalImages = 0;
    int finishedImages = 0;
    for (final task in _allTasks) {
      totalImages += task.totalImages;
      finishedImages += task.finishedImages;
    }
    if (totalImages == 0) return 0.0;
    return (finishedImages / totalImages).clamp(0.0, 1.0);
  }

  String get formattedSpeed {
    if (_currentSpeedBps <= 0) return '0 KB/s';
    if (_currentSpeedBps < 1024 * 1024) {
      return '${(_currentSpeedBps / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(_currentSpeedBps / (1024 * 1024)).toStringAsFixed(2)} MB/s';
  }

  DownloadProvider() {
    _startSpeedTimer();
    loadSavedTasks();
    NotificationService.init();
    NotificationService.requestNotificationPermission();
  }

  void updateConfig(AppConfig config) {
    _config = config;
  }

  /// Load persisted download tasks from SharedPreferences
  Future<void> loadSavedTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kTasksKey);
      if (raw != null && raw.isNotEmpty) {
        final loaded = PackDownloadTask.listFromJson(raw);
        for (final t in loaded) {
          // If task was downloading before app close, restore as paused so user can resume
          if (t.status == TaskStatus.downloading) {
            t.status = TaskStatus.paused;
          }
          final key = t.packItem.id ?? t.packItem.title;
          if (!_allTasks.any((existing) => (existing.packItem.id ?? existing.packItem.title) == key)) {
            _allTasks.add(t);
          }
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading saved tasks: $e');
    }
  }

  /// Persist all tasks to SharedPreferences
  Future<void> _persistTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kTasksKey, PackDownloadTask.listToJson(_allTasks));
    } catch (e) {
      debugPrint('Error saving tasks: $e');
    }
  }

  void _startSpeedTimer() {
    _speedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _currentSpeedBps = _bytesSinceLastTick.toDouble();
      _bytesSinceLastTick = 0;

      if (hasActiveOrPausedTasks) {
        notifyListeners();
        _updateNotification();
      }
    });
  }

  void _updateNotification() {
    final active = currentActiveTask;
    if (active != null) {
      NotificationService.updateProgressNotification(
        title: active.packItem.title,
        progress: overallProgress,
        speed: formattedSpeed,
        finishedCount: completedTasks.length,
        totalCount: _allTasks.length,
        isPaused: !isDownloading && pausedTasks.isNotEmpty,
      );
    }
  }

  @override
  void dispose() {
    _speedTimer?.cancel();
    _currentEngine?.cancel();
    super.dispose();
  }

  void appendLog(String message, [String level = 'info']) {
    _logs.insert(0, LogEntry(timestamp: DateTime.now(), message: message, level: level));
    if (_logs.length > 500) {
      _logs.removeLast();
    }
    notifyListeners();
  }

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  /// Add a single pack to download queue
  void addSinglePack(PackItem item) {
    final key = item.id ?? item.title;
    final existingIndex = _allTasks.indexWhere((t) => (t.packItem.id ?? t.packItem.title) == key);

    if (existingIndex != -1) {
      final existingTask = _allTasks[existingIndex];
      if (existingTask.status == TaskStatus.downloading || existingTask.status == TaskStatus.queued) {
        appendLog('图包已在下载队列中: ${item.title}', 'warn');
        return;
      }
      if (existingTask.status == TaskStatus.paused) {
        existingTask.status = TaskStatus.queued;
        _currentBatchTaskIds.add(existingTask.id);
        appendLog('恢复图包下载: ${item.title}', 'info');
        _persistTasks();
        notifyListeners();
        _triggerDownloadLoop();
        return;
      }
    }

    final taskId = '${DateTime.now().millisecondsSinceEpoch}_${item.title.hashCode.abs()}';
    final task = PackDownloadTask(
      id: taskId,
      packItem: item,
      targetFolder: '${_config.savePath}/${PackItem.cleanFilename(item.title)}',
      totalImages: item.urls.length,
      status: TaskStatus.queued,
    );

    _allTasks.add(task);
    _currentBatchTaskIds.add(taskId);
    _persistTasks();
    appendLog('已添加图包到下载队列: ${item.title} (${item.urls.length}张)', 'info');
    notifyListeners();

    _triggerDownloadLoop();
  }

  /// Add multiple packs to download queue
  void addBatchPacks(List<PackItem> items) {
    int addedCount = 0;
    for (final item in items) {
      final key = item.id ?? item.title;
      final existingIndex = _allTasks.indexWhere((t) => (t.packItem.id ?? t.packItem.title) == key);

      if (existingIndex != -1) {
        final existingTask = _allTasks[existingIndex];
        if (existingTask.status == TaskStatus.paused) {
          existingTask.status = TaskStatus.queued;
          _currentBatchTaskIds.add(existingTask.id);
          addedCount++;
        }
        continue;
      }

      final taskId = '${DateTime.now().millisecondsSinceEpoch}_${addedCount}_${item.title.hashCode.abs()}';
      final task = PackDownloadTask(
        id: taskId,
        packItem: item,
        targetFolder: '${_config.savePath}/${PackItem.cleanFilename(item.title)}',
        totalImages: item.urls.length,
        status: TaskStatus.queued,
      );

      _allTasks.add(task);
      _currentBatchTaskIds.add(taskId);
      addedCount++;
    }

    _persistTasks();
    appendLog('批量添加 $addedCount 个图包到队列', 'info');
    notifyListeners();

    _triggerDownloadLoop();
  }

  /// Add page range to batch download (e.g. from page 1 to 5)
  Future<void> addPageRange(int startPage, int endPage) async {
    appendLog('正在获取第 $startPage 页到第 $endPage 页的所有图包...', 'info');
    final List<PackItem> allItems = [];

    for (int p = startPage; p <= endPage; p++) {
      appendLog('正在拉取第 $p 页数据...', 'info');
      final res = await ApiService.fetchPageData(page: p, pageSize: _config.packWorkers);
      if (res != null && res.items.isNotEmpty) {
        allItems.addAll(res.items);
      } else {
        appendLog('第 $p 页拉取失败或无数据', 'warn');
      }
    }

    if (allItems.isNotEmpty) {
      addBatchPacks(allItems);
      appendLog('区间批量抓取完成，共加入 ${allItems.length} 个图包到队列', 'success');
    } else {
      appendLog('未能获取到任何图包数据', 'error');
    }
  }

  /// Pause a single task
  void pauseSingleTask(String taskId) {
    final taskIndex = _allTasks.indexWhere((t) => t.id == taskId);
    if (taskIndex != -1) {
      final task = _allTasks[taskIndex];
      if (task.status == TaskStatus.downloading || task.status == TaskStatus.queued) {
        task.status = TaskStatus.paused;
        appendLog('已暂停图包: ${task.packItem.title}', 'warn');
        _persistTasks();
        notifyListeners();
        _updateNotification();
      }
    }
  }

  /// Resume a single task
  void resumeSingleTask(String taskId) {
    final taskIndex = _allTasks.indexWhere((t) => t.id == taskId);
    if (taskIndex != -1) {
      final task = _allTasks[taskIndex];
      if (task.status == TaskStatus.paused) {
        task.status = TaskStatus.queued;
        _currentBatchTaskIds.add(task.id);
        appendLog('已恢复图包: ${task.packItem.title}', 'info');
        _persistTasks();
        notifyListeners();
        _triggerDownloadLoop();
      }
    }
  }

  /// Remove or cancel a single task
  void cancelSingleTask(String taskId) {
    final taskIndex = _allTasks.indexWhere((t) => t.id == taskId);
    if (taskIndex != -1) {
      final task = _allTasks.removeAt(taskIndex);
      _currentBatchTaskIds.remove(taskId);
      appendLog('已移除图包任务: ${task.packItem.title}', 'info');
      _persistTasks();
      notifyListeners();
      if (_allTasks.isEmpty) {
        NotificationService.cancelNotification();
      }
    }
  }

  /// Main download queue loop with pack concurrency control
  Future<void> _triggerDownloadLoop() async {
    if (_isEngineRunning) return;
    _isEngineRunning = true;
    _batchStartTime ??= DateTime.now();
    notifyListeners();

    _currentEngine = DownloadEngine(
      config: _config,
      onLog: (msg, level) => appendLog(msg, level),
      onTaskProgress: (task) {
        notifyListeners();
      },
    );

    final packPool = Pool(_config.packWorkers.clamp(1, 20));

    try {
      while (true) {
        final pendingTasks = _allTasks.where((t) => t.status == TaskStatus.queued).toList();
        if (pendingTasks.isEmpty) break;

        final futures = <Future<void>>[];
        for (final task in pendingTasks) {
          final f = packPool.withResource(() async {
            if (task.status == TaskStatus.paused) return;

            task.status = TaskStatus.downloading;
            task.startTime ??= DateTime.now();
            notifyListeners();

            await _currentEngine?.processSinglePack(
              task,
              _config.savePath,
              onBytesReceived: (bytes) {
                _bytesSinceLastTick += bytes;
              },
            );

            _persistTasks();
            notifyListeners();
          });
          futures.add(f);
        }

        await Future.wait(futures);
      }

      // Check if auto archive is needed
      if (_config.autoArchive && _config.savePath.isNotEmpty) {
        appendLog('正在执行自动分类归档...', 'info');
        final count = await StorageService.organizeAndArchivePacks(
          _config.savePath,
          strategy: _config.archiveStrategy,
          onProgress: (msg) => appendLog(msg, 'info'),
        );
        if (count > 0) {
          appendLog('自动归档完成，共归档 $count 个图包', 'success');
        }
      }

      // Save history record specifically for this batch
      await _recordBatchHistory();
      _persistTasks();
      onPacksChanged?.call();
    } catch (e) {
      appendLog('下载循环异常: $e', 'error');
    } finally {
      _isEngineRunning = false;
      _batchStartTime = null;
      _persistTasks();
      notifyListeners();
    }
  }

  Future<void> _recordBatchHistory() async {
    if (_currentBatchTaskIds.isEmpty) return;

    // Filter tasks specifically belonging to this batch
    final batchTasks = _allTasks.where((t) => _currentBatchTaskIds.contains(t.id)).toList();
    if (batchTasks.isEmpty) return;

    int packsDownloaded = 0;
    int packsSkipped = 0;
    int imagesDownloaded = 0;
    int imagesSkipped = 0;
    int imagesFailed = 0;
    final List<String> titles = [];

    for (final t in batchTasks) {
      if (t.isDone || t.finishedImages > 0) {
        if (t.skippedImages == t.totalImages && t.totalImages > 0) {
          packsSkipped++;
        } else if (t.downloadedImages > 0) {
          packsDownloaded++;
        }
        imagesDownloaded += t.downloadedImages;
        imagesSkipped += t.skippedImages;
        imagesFailed += t.failedImages;
        titles.add(t.packItem.title);
      }
    }

    if (packsDownloaded == 0 && imagesDownloaded == 0 && packsSkipped == 0) {
      return;
    }

    final duration = _batchStartTime != null
        ? DateTime.now().difference(_batchStartTime!).inMilliseconds / 1000.0
        : 1.0;

    final record = HistoryRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      savePath: _config.savePath,
      packsDownloaded: packsDownloaded,
      packsSkipped: packsSkipped,
      imagesDownloaded: imagesDownloaded,
      imagesSkipped: imagesSkipped,
      imagesFailed: imagesFailed,
      durationSec: duration > 0 ? duration : 1.0,
      packTitles: titles,
    );

    // Save directly to SharedPreferences to guarantee persistence
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kHistoryKey);
      final List<HistoryRecord> existingList = raw != null ? HistoryRecord.listFromJson(raw) : [];
      existingList.insert(0, record);
      await prefs.setString(_kHistoryKey, HistoryRecord.listToJson(existingList));
    } catch (_) {}

    // Show system notification for completion
    NotificationService.showDownloadCompleted(
      packsCount: packsDownloaded + packsSkipped,
      imagesCount: imagesDownloaded + imagesSkipped,
      durationSec: duration,
    );

    onBatchCompleted?.call(record);
    appendLog('批次完成！新下载 $imagesDownloaded 张图片，跳过 $imagesSkipped 张，耗时 ${duration.toStringAsFixed(1)}s', 'success');

    // Reset current batch IDs after recording
    _currentBatchTaskIds.clear();
  }

  void pauseAll() {
    _currentEngine?.cancel();
    for (final task in _allTasks) {
      if (task.status == TaskStatus.downloading || task.status == TaskStatus.queued) {
        task.status = TaskStatus.paused;
      }
    }
    _isEngineRunning = false;
    _persistTasks();
    appendLog('已暂停所有下载任务', 'warn');
    notifyListeners();
    _updateNotification();
  }

  void resumeAll() {
    for (final task in _allTasks) {
      if (task.status == TaskStatus.paused) {
        task.status = TaskStatus.queued;
        _currentBatchTaskIds.add(task.id);
      }
    }
    _persistTasks();
    appendLog('已恢复所有下载任务', 'info');
    notifyListeners();
    _triggerDownloadLoop();
  }

  void cancelAll() {
    _currentEngine?.cancel();
    _allTasks.clear();
    _currentBatchTaskIds.clear();
    _isEngineRunning = false;
    _persistTasks();
    appendLog('已清空所有下载队列', 'warn');
    notifyListeners();
    NotificationService.cancelNotification();
  }

  void clearCompleted() {
    _allTasks.removeWhere((t) => t.isDone);
    _persistTasks();
    notifyListeners();
  }

  void retryFailedTasks() {
    for (final task in failedTasks) {
      task.status = TaskStatus.queued;
      task.failedImages = 0;
      _currentBatchTaskIds.add(task.id);
      for (final img in task.imageTasks) {
        if (img.status == ImageTaskStatus.failed) {
          img.status = ImageTaskStatus.pending;
        }
      }
    }
    _persistTasks();
    appendLog('正在重试失败任务...', 'info');
    notifyListeners();
    _triggerDownloadLoop();
  }
}
