import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/album_item.dart';
import '../models/app_config.dart';
import '../models/download_task.dart';
import '../models/history_record.dart';
import '../models/video_item.dart';
import '../services/config_service.dart';
import '../services/download_engine.dart';
import '../services/hc_api_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/video_api_service.dart';

const String _kTasksKey = 'hc_saved_download_tasks';
const MethodChannel _bgChannel = MethodChannel('com.hentaicosplay/background_keeper');

void _setIosBackgroundKeeper(bool enable) {
  if (Platform.isIOS) {
    try {
      _bgChannel.invokeMethod('enableBackground', enable);
    } catch (e) {
      debugPrint('Error setting iOS background keeper: $e');
    }
  }
}

class DownloadProvider extends ChangeNotifier {
  final List<AlbumDownloadTask> _allTasks = [];
  final Set<AlbumDownloadTask> _runningTasks = {};
  final Map<String, DownloadEngine> _activeEngines = {};
  final Set<String> _currentBatchTaskIds = {};

  AppConfig _config = ConfigService.loadConfig();

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

  /// Add a single video task
  void addVideoTask(VideoItem video) {
    addBatchVideoTasks([video]);
  }

  /// Add multiple videos in batch
  void addBatchVideoTasks(List<VideoItem> videos) {
    _config = ConfigService.loadConfig();

    if (!isDownloading) {
      _currentBatchTaskIds.clear();
    }

    for (final video in videos) {
      final key = video.slug.isNotEmpty ? video.slug : video.title;
      final existingIndex = _allTasks.indexWhere((t) => t.albumItem.slug == key || t.albumItem.title == key);

      if (existingIndex != -1) {
        final existingTask = _allTasks[existingIndex];
        _currentBatchTaskIds.add(existingTask.id);
        if (existingTask.status == TaskStatus.paused || existingTask.status == TaskStatus.failed) {
          existingTask.status = TaskStatus.queued;
        }
        continue;
      }

      final taskId = '${DateTime.now().millisecondsSinceEpoch}_${video.title.hashCode.abs()}';
      final albumItem = AlbumItem(
        title: video.title,
        slug: video.slug,
        detailUrl: video.detailUrl,
        coverUrl: video.coverUrl,
        date: video.date,
        author: video.author,
        tags: video.tags,
      );

      final task = AlbumDownloadTask(
        id: taskId,
        albumItem: albumItem,
        targetFolder: '${_config.savePath}/video',
        totalImages: 1,
        status: TaskStatus.queued,
        isVideo: true,
        videoUrl: video.videoUrl,
        duration: video.duration,
      );
      _allTasks.add(task);
      _currentBatchTaskIds.add(taskId);
    }

    _persistTasks();
    notifyListeners();

    _triggerDownloadLoop();
  }

  /// Fetch and add online video page range to batch download queue
  Future<void> addVideoPageRange(
    int startPage,
    int endPage, {
    VideoCategory category = VideoCategory.latest,
    String? keyword,
    String? tag,
  }) async {
    _config = ConfigService.loadConfig();
    final List<VideoItem> allVideos = [];

    for (int p = startPage; p <= endPage; p++) {
      try {
        final pageData = await VideoApiService.fetchVideoPageData(
          category: category,
          keyword: keyword,
          tag: tag,
          page: p,
        );
        if (pageData != null && pageData.items.isNotEmpty) {
          allVideos.addAll(pageData.items);
        }
      } catch (e) {
        debugPrint('Error fetching video page $p during batch range download: $e');
      }
    }

    if (allVideos.isNotEmpty) {
      addBatchVideoTasks(allVideos);
    }
  }

  /// Start iOS Picture-in-Picture mode
  Future<void> startPip() async {
    if (Platform.isIOS) {
      try {
        await _bgChannel.invokeMethod('startPip');
      } catch (e) {
        debugPrint('Error starting PiP: $e');
      }
    }
  }

  /// Stop iOS Picture-in-Picture mode
  Future<void> stopPip() async {
    if (Platform.isIOS) {
      try {
        await _bgChannel.invokeMethod('stopPip');
      } catch (e) {
        debugPrint('Error stopping PiP: $e');
      }
    }
  }

  /// Check if PiP is supported
  Future<bool> isPipSupported() async {
    if (!Platform.isIOS) return false;
    try {
      final res = await _bgChannel.invokeMethod<bool>('isPipSupported');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Pause a single task
  void pauseTask(AlbumDownloadTask task) {
    _activeEngines[task.id]?.cancel();
    _activeEngines.remove(task.id);
    task.status = TaskStatus.paused;
    _runningTasks.remove(task);
    _persistTasks();
    notifyListeners();
    _updateNotification();
    _scheduleNextTasks();
  }

  /// Pause all downloading and queued tasks
  void pauseAllTasks() {
    for (final engine in _activeEngines.values) {
      engine.cancel();
    }
    _activeEngines.clear();
    for (final task in _allTasks) {
      if (task.status == TaskStatus.downloading || task.status == TaskStatus.queued) {
        task.status = TaskStatus.paused;
      }
    }
    _runningTasks.clear();
    _setIosBackgroundKeeper(false);
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
      _scheduleNextTasks();
    }
  }

  /// Resume all paused and failed tasks
  void resumeAllTasks() {
    for (final task in _allTasks) {
      if (task.status == TaskStatus.paused || task.status == TaskStatus.failed) {
        task.status = TaskStatus.queued;
        _currentBatchTaskIds.add(task.id);
      }
    }
    _persistTasks();
    notifyListeners();
    _scheduleNextTasks();
  }

  /// Retry failed tasks
  void retryFailedTasks() {
    for (final task in failedTasks) {
      task.status = TaskStatus.queued;
      _currentBatchTaskIds.add(task.id);
    }
    _persistTasks();
    notifyListeners();
    _scheduleNextTasks();
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

  void _triggerDownloadLoop() {
    _scheduleNextTasks();
  }

  /// Dynamic reactive task scheduler (Producer-Consumer worker pool)
  void _scheduleNextTasks() {
    _startSpeedTimer();
    _batchStartTime ??= DateTime.now();

    _config = ConfigService.loadConfig();
    final maxPackWorkers = _config.packWorkers.clamp(1, 20);

    while (_runningTasks.length < maxPackWorkers) {
      final queuedList = _allTasks.where((t) => t.status == TaskStatus.queued).toList();
      if (queuedList.isEmpty) break;

      final task = queuedList.first;
      task.status = TaskStatus.downloading;
      task.startTime ??= DateTime.now();
      _runningTasks.add(task);
      _setIosBackgroundKeeper(true);
      notifyListeners();
      _updateNotification();

      _executeSingleTask(task);
    }

    if (_runningTasks.isEmpty && queuedTasks.isEmpty) {
      _finishBatchIfNeeded();
    }
  }

  Future<void> _executeSingleTask(AlbumDownloadTask task) async {
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
      if (_config.savePath.isEmpty) {
        _config.savePath = await StorageService.getDefaultDownloadPath();
        await ConfigService.saveConfig(_config);
      } else {
        _config.savePath = await StorageService.resolveValidPath(_config.savePath);
      }

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
          isVideo: task.isVideo,
          duration: task.duration,
        );
        onAlbumCompleted?.call(record);
        onAlbumsChanged?.call();
      }
    } catch (e) {
      debugPrint('Task ${task.id} execution error: $e');
      if (task.status == TaskStatus.downloading) {
        task.status = TaskStatus.failed;
      }
    } finally {
      _activeEngines.remove(task.id);
      _runningTasks.remove(task);
      _persistTasks();
      notifyListeners();
      _updateNotification();

      _scheduleNextTasks();
    }
  }

  void _finishBatchIfNeeded() {
    _setIosBackgroundKeeper(false);
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
      NotificationService.showDownloadCompleted(
        albumsCount: finishedBatch.length,
        imagesCount: totalImages,
        durationSec: duration,
      );
    }
    _batchStartTime = null;
    _currentBatchTaskIds.clear();
    onAlbumsChanged?.call();
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
