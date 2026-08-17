import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pool/pool.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/album_item.dart';
import '../models/app_config.dart';
import '../models/download_task.dart';
import '../models/history_record.dart';
import '../services/config_service.dart';
import '../services/download_engine.dart';
import '../services/hc_api_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';

const String _kTasksKey = 'hc_saved_download_tasks';

class DownloadProvider extends ChangeNotifier {
  final List<AlbumDownloadTask> _allTasks = [];
  final Set<AlbumDownloadTask> _runningTasks = {};
  final Map<String, DownloadEngine> _activeEngines = {};
  final Set<String> _currentBatchTaskIds = {};

  AppConfig _config = ConfigService.loadConfig();

  bool _isEngineRunning = false;
  Timer? _speedTimer;
  int _bytesSinceLastTick = 0;
  double _currentSpeedBps = 0.0;
  DateTime? _batchStartTime;

  void Function(HistoryRecord record)? onAlbumCompleted;
  void Function()? onAlbumsChanged;

  List<AlbumDownloadTask> get allTasks => List.unmodifiable(_allTasks);
  List<AlbumDownloadTask> get activeTasks =>
      _allTasks.where((t) => t.status == TaskStatus.downloading).toList();
  List<AlbumDownloadTask> get queuedTasks =>
      _allTasks.where((t) => t.status == TaskStatus.queued).toList();
  List<AlbumDownloadTask> get completedTasks =>
      _allTasks.where((t) => t.status == TaskStatus.completed).toList();
  List<AlbumDownloadTask> get failedTasks =>
      _allTasks.where((t) => t.status == TaskStatus.failed).toList();
  List<AlbumDownloadTask> get pausedTasks =>
      _allTasks.where((t) => t.status == TaskStatus.paused).toList();

  bool get isDownloading => activeTasks.isNotEmpty || queuedTasks.isNotEmpty;
  bool get hasActiveOrPausedTasks => activeTasks.isNotEmpty || pausedTasks.isNotEmpty || queuedTasks.isNotEmpty;

  /// Accurate overall progress strictly tracking active download batch
  double get overallProgress {
    List<AlbumDownloadTask> targetTasks;
    if (_currentBatchTaskIds.isNotEmpty) {
      targetTasks = _allTasks.where((t) => _currentBatchTaskIds.contains(t.id)).toList();
    } else {
      targetTasks = _allTasks.where((t) =>
          t.status == TaskStatus.downloading ||
          t.status == TaskStatus.queued ||
          t.status == TaskStatus.paused).toList();
    }

    if (targetTasks.isEmpty) return 0.0;

    int totalImages = 0;
    int finishedImages = 0;
    for (final task in targetTasks) {
      totalImages += task.totalImages;
      finishedImages += (task.downloadedImages + task.skippedImages);
    }
    if (totalImages <= 0) return 0.0;
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
    loadSavedTasks();
    NotificationService.init();
    NotificationService.requestNotificationPermission();
  }

  @override
  void dispose() {
    _stopSpeedTimer();
    super.dispose();
  }

  void updateConfig(AppConfig config) {
    _config = config;
  }

  void _startSpeedTimer() {
    if (_speedTimer != null && _speedTimer!.isActive) return;
    _speedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _currentSpeedBps = _bytesSinceLastTick.toDouble();
      _bytesSinceLastTick = 0;
      if (activeTasks.isNotEmpty) {
        notifyListeners();
        _updateNotification();
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

  /// Load persisted download tasks from SharedPreferences
  Future<void> loadSavedTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kTasksKey);
      if (raw != null && raw.isNotEmpty) {
        final loaded = AlbumDownloadTask.listFromJson(raw);
        for (final t in loaded) {
          // If task was downloading before app closed, restore as paused
          if (t.status == TaskStatus.downloading) {
            t.status = TaskStatus.paused;
          }
          final key = t.id;
          if (!_allTasks.any((existing) => existing.id == key)) {
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
      await prefs.setString(_kTasksKey, AlbumDownloadTask.listToJson(_allTasks));
    } catch (e) {
      debugPrint('Error persisting tasks: $e');
    }
  }

  void _onBytesReceived(int bytes) {
    _bytesSinceLastTick += bytes;
  }

  /// Add single album task
  void addAlbumTask(AlbumItem item) {
    _config = ConfigService.loadConfig();

    if (!isDownloading) {
      _currentBatchTaskIds.clear();
    }

    final key = item.slug.isNotEmpty ? item.slug : item.title;
    final existingIndex = _allTasks.indexWhere((t) => t.albumItem.slug == key || t.albumItem.title == key);

    if (existingIndex != -1) {
      final existingTask = _allTasks[existingIndex];
      _currentBatchTaskIds.add(existingTask.id);
      if (existingTask.status == TaskStatus.paused || existingTask.status == TaskStatus.failed) {
        existingTask.status = TaskStatus.queued;
        _persistTasks();
        notifyListeners();
        _triggerDownloadLoop();
      }
      return;
    }

    final taskId = '${DateTime.now().millisecondsSinceEpoch}_${item.title.hashCode.abs()}';
    final task = AlbumDownloadTask(
      id: taskId,
      albumItem: item,
      targetFolder: '${_config.savePath}/${AlbumItem.cleanFilename(item.title)}',
      totalImages: item.imageUrls.length,
      status: TaskStatus.queued,
    );

    _allTasks.add(task);
    _currentBatchTaskIds.add(taskId);
    _persistTasks();
    notifyListeners();

    _triggerDownloadLoop();
  }

  /// Add multiple albums in batch
  void addBatchAlbumTasks(List<AlbumItem> items) {
    _config = ConfigService.loadConfig();

    if (!isDownloading) {
      _currentBatchTaskIds.clear();
    }

    for (final item in items) {
      final key = item.slug.isNotEmpty ? item.slug : item.title;
      final existingIndex = _allTasks.indexWhere((t) => t.albumItem.slug == key || t.albumItem.title == key);

      if (existingIndex != -1) {
        final existingTask = _allTasks[existingIndex];
        _currentBatchTaskIds.add(existingTask.id);
        if (existingTask.status == TaskStatus.paused || existingTask.status == TaskStatus.failed) {
          existingTask.status = TaskStatus.queued;
        }
        continue;
      }

      final taskId = '${DateTime.now().millisecondsSinceEpoch}_${item.title.hashCode.abs()}';
      final task = AlbumDownloadTask(
        id: taskId,
        albumItem: item,
        targetFolder: '${_config.savePath}/${AlbumItem.cleanFilename(item.title)}',
        totalImages: item.imageUrls.length,
        status: TaskStatus.queued,
      );
      _allTasks.add(task);
      _currentBatchTaskIds.add(taskId);
    }

    _persistTasks();
    notifyListeners();

    _triggerDownloadLoop();
  }

  /// Fetch and add page range (e.g. from page 1 to 5) to batch download queue
  Future<void> addPageRange(int startPage, int endPage, {String? keyword}) async {
    _config = ConfigService.loadConfig();
    final List<AlbumItem> allItems = [];

    for (int p = startPage; p <= endPage; p++) {
      try {
        final pageData = await HCApiService.fetchPageData(page: p, keyword: keyword);
        if (pageData != null && pageData.items.isNotEmpty) {
          allItems.addAll(pageData.items);
        }
      } catch (e) {
        debugPrint('Error fetching page $p during batch range download: $e');
      }
    }

    if (allItems.isNotEmpty) {
      addBatchAlbumTasks(allItems);
    }
  }

  /// Pause a single task
  void pauseTask(AlbumDownloadTask task) {
    _activeEngines[task.id]?.cancel();
    task.status = TaskStatus.paused;
    _runningTasks.remove(task);
    _persistTasks();
    notifyListeners();
    _updateNotification();
  }

  /// Resume a single task
  void resumeTask(AlbumDownloadTask task) {
    if (task.status == TaskStatus.paused || task.status == TaskStatus.failed) {
      task.status = TaskStatus.queued;
      _currentBatchTaskIds.add(task.id);
      _persistTasks();
      notifyListeners();
      _triggerDownloadLoop();
    }
  }

  /// Retry failed tasks
  void retryFailedTasks() {
    for (final task in failedTasks) {
      task.status = TaskStatus.queued;
      _currentBatchTaskIds.add(task.id);
    }
    _persistTasks();
    notifyListeners();
    _triggerDownloadLoop();
  }

  /// Clear finished/completed tasks from task manager list
  void clearCompleted() {
    _allTasks.removeWhere((t) => t.status == TaskStatus.completed);
    _currentBatchTaskIds.clear();
    _persistTasks();
    notifyListeners();
    if (_allTasks.isEmpty) {
      NotificationService.cancelNotification();
    }
  }

  /// Remove task
  void removeTask(AlbumDownloadTask task) {
    pauseTask(task);
    _allTasks.remove(task);
    _currentBatchTaskIds.remove(task.id);
    _runningTasks.remove(task);
    _persistTasks();
    notifyListeners();
    if (_allTasks.isEmpty) {
      NotificationService.cancelNotification();
    }
  }

  /// Main queue processor loop with pack concurrency control
  Future<void> _triggerDownloadLoop() async {
    if (_isEngineRunning) return;
    _isEngineRunning = true;
    _startSpeedTimer();
    _batchStartTime ??= DateTime.now();
    _config = ConfigService.loadConfig();
    if (_config.savePath.isEmpty) {
      _config.savePath = await StorageService.getDefaultDownloadPath();
      await ConfigService.saveConfig(_config);
    } else {
      _config.savePath = await StorageService.resolveValidPath(_config.savePath);
    }
    notifyListeners();

    final maxPackWorkers = _config.packWorkers.clamp(1, 20);
    final packPool = Pool(maxPackWorkers);

    try {
      while (true) {
        final pendingTasks = _allTasks.where((t) => t.status == TaskStatus.queued).toList();
        if (pendingTasks.isEmpty) break;

        final List<Future<void>> futures = [];

        for (final task in pendingTasks) {
          final future = packPool.withResource(() async {
            if (task.status == TaskStatus.paused) return;

            task.status = TaskStatus.downloading;
            task.startTime ??= DateTime.now();
            _runningTasks.add(task);
            notifyListeners();
            _updateNotification();

            final engine = DownloadEngine(
              config: _config,
              onLog: (msg, level) {},
              onTaskProgress: (t) {
                notifyListeners();
                _updateNotification();
              },
            );
            _activeEngines[task.id] = engine;

            try {
              await engine.processAlbum(
                task,
                _config.savePath,
                onBytesReceived: _onBytesReceived,
              );

              if (task.status == TaskStatus.completed) {
                final diskBytes = task.downloadedBytes > 0
                    ? task.downloadedBytes
                    : await StorageService.getFolderSize(task.targetFolder);

                final record = HistoryRecord(
                  id: task.albumItem.slug.isNotEmpty ? task.albumItem.slug : task.id,
                  title: task.albumItem.title,
                  author: task.albumItem.author,
                  coverUrl: task.albumItem.coverUrl,
                  targetFolder: task.targetFolder,
                  imageCount: task.downloadedImages + task.skippedImages,
                  downloadedBytes: diskBytes,
                  completedAt: task.finishTime ?? DateTime.now(),
                  detailUrl: task.albumItem.detailUrl,
                );
                onAlbumCompleted?.call(record);
              }
            } finally {
              _activeEngines.remove(task.id);
              _runningTasks.remove(task);
            }

            _persistTasks();
            notifyListeners();
            _updateNotification();
          });

          futures.add(future);
        }

        await Future.wait(futures);
      }

      // Check if all downloads in this batch finished
      if (activeTasks.isEmpty && queuedTasks.isEmpty) {
        final duration = _batchStartTime != null
            ? DateTime.now().difference(_batchStartTime!).inMilliseconds / 1000.0
            : 1.0;

        final batchTasks = _allTasks
            .where((t) => _currentBatchTaskIds.isEmpty || _currentBatchTaskIds.contains(t.id))
            .toList();
        final finishedBatch = batchTasks.where((t) => t.status == TaskStatus.completed).toList();

        int totalImages = 0;
        for (final t in finishedBatch) {
          totalImages += (t.downloadedImages + t.skippedImages);
        }

        if (finishedBatch.isNotEmpty) {
          await NotificationService.showDownloadCompleted(
            albumsCount: finishedBatch.length,
            imagesCount: totalImages,
            durationSec: duration,
          );
        }
      }

      _persistTasks();
      onAlbumsChanged?.call();
    } catch (e) {
      debugPrint('Download loop error: $e');
    } finally {
      _isEngineRunning = false;
      _batchStartTime = null;
      _persistTasks();
      notifyListeners();
      if (activeTasks.isNotEmpty || pausedTasks.isNotEmpty) {
        _updateNotification();
      }
    }
  }

  void _updateNotification() {
    if (activeTasks.isNotEmpty) {
      final currentTask = activeTasks.first;
      NotificationService.updateProgressNotification(
        title: currentTask.albumItem.title,
        progress: overallProgress,
        speed: formattedSpeed,
        finishedCount: currentTask.downloadedImages + currentTask.skippedImages,
        totalCount: currentTask.totalImages > 0 ? currentTask.totalImages : 1,
      );
    } else if (queuedTasks.isEmpty && activeTasks.isEmpty && pausedTasks.isNotEmpty) {
      NotificationService.updateProgressNotification(
        title: '已暂停全部任务',
        progress: overallProgress,
        speed: '0 KB/s',
        finishedCount: 0,
        totalCount: 0,
        isPaused: true,
      );
    }
  }
}
