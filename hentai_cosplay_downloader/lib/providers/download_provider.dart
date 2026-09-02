import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import '../models/album_item.dart';
import '../models/app_config.dart';
import '../models/download_task.dart';
import '../models/history_record.dart';
import '../models/video_item.dart';
import '../services/app_logger.dart';
import '../services/config_service.dart';
import '../services/coomer/coomer_api_service.dart';
import '../services/coordinators/batch_fetch_coordinator.dart';
import '../services/coordinators/download_notification_manager.dart';
import '../services/coordinators/task_persistence_service.dart';
import '../services/download_engine.dart';
import '../services/exhentai/exhentai_api_service.dart';
import '../services/kuraa/kuraa_api_service.dart';
import '../services/misskon/misskon_api_service.dart';
import '../services/notification_service.dart';
import '../services/pinse/pinse_api_service.dart';
import '../services/pornbox/pornbox_api_service.dart';
import '../services/storage_service.dart';
import '../services/twitter_rankings/twitter_site_config.dart';

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

  // Coordinators & helper services
  final TaskPersistenceService _persistenceService = TaskPersistenceService();
  final BatchFetchCoordinator _batchCoordinator = BatchFetchCoordinator();
  final DownloadNotificationManager _notificationManager = DownloadNotificationManager();

  // Fast O(1) task index maps
  final Map<String, AlbumDownloadTask> _taskBySlug = {};
  final Map<String, AlbumDownloadTask> _taskByDetailUrl = {};
  final Map<String, AlbumDownloadTask> _taskByTitle = {};
  final Map<String, AlbumDownloadTask> _taskByVideoUrl = {};
  final Map<String, AlbumDownloadTask> _taskById = {};

  // Cached filtered task lists for UI optimization
  List<AlbumDownloadTask>? _cachedImageTasks;
  List<AlbumDownloadTask>? _cachedVideoTasks;
  List<AlbumDownloadTask>? _cachedImageActive;
  List<AlbumDownloadTask>? _cachedImageCompleted;
  List<AlbumDownloadTask>? _cachedImageFailed;
  List<AlbumDownloadTask>? _cachedVideoActive;
  List<AlbumDownloadTask>? _cachedVideoCompleted;
  List<AlbumDownloadTask>? _cachedVideoFailed;

  AppConfig _config = ConfigService.loadConfig();

  Timer? _speedTimer;
  int _bytesSinceLastTick = 0;
  double _currentSpeedBps = 0.0;
  DateTime? _batchStartTime;

  int _taskSequenceCounter = 0;
  DateTime _lastProgressNotifyTime = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _progressThrottleTimer;

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

  // Cached getters for DownloadTasksPage
  List<AlbumDownloadTask> get imageTasks =>
      _cachedImageTasks ??= _allTasks.where((t) => !t.isVideo).toList();
  List<AlbumDownloadTask> get videoTasks =>
      _cachedVideoTasks ??= _allTasks.where((t) => t.isVideo).toList();
  List<AlbumDownloadTask> get imageActiveTasks =>
      _cachedImageActive ??= imageTasks
          .where((t) =>
              t.status == TaskStatus.downloading ||
              t.status == TaskStatus.queued ||
              t.status == TaskStatus.paused)
          .toList();
  List<AlbumDownloadTask> get imageCompletedTasks =>
      _cachedImageCompleted ??= imageTasks.where((t) => t.status == TaskStatus.completed).toList();
  List<AlbumDownloadTask> get imageFailedTasks =>
      _cachedImageFailed ??= imageTasks.where((t) => t.status == TaskStatus.failed).toList();
  List<AlbumDownloadTask> get videoActiveTasks =>
      _cachedVideoActive ??= videoTasks
          .where((t) =>
              t.status == TaskStatus.downloading ||
              t.status == TaskStatus.queued ||
              t.status == TaskStatus.paused)
          .toList();
  List<AlbumDownloadTask> get videoCompletedTasks =>
      _cachedVideoCompleted ??= videoTasks.where((t) => t.status == TaskStatus.completed).toList();
  List<AlbumDownloadTask> get videoFailedTasks =>
      _cachedVideoFailed ??= videoTasks.where((t) => t.status == TaskStatus.failed).toList();

  bool get isDownloading => activeTasks.isNotEmpty || queuedTasks.isNotEmpty;
  bool get hasActiveOrPausedTasks =>
      activeTasks.isNotEmpty || pausedTasks.isNotEmpty || queuedTasks.isNotEmpty;

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

  void _invalidateFilteredCache() {
    _cachedImageTasks = null;
    _cachedVideoTasks = null;
    _cachedImageActive = null;
    _cachedImageCompleted = null;
    _cachedImageFailed = null;
    _cachedVideoActive = null;
    _cachedVideoCompleted = null;
    _cachedVideoFailed = null;
  }

  void _rebuildIndexes() {
    _taskBySlug.clear();
    _taskByDetailUrl.clear();
    _taskByTitle.clear();
    _taskByVideoUrl.clear();
    _taskById.clear();

    for (final t in _allTasks) {
      _indexSingleTask(t);
    }
    _invalidateFilteredCache();
  }

  void _indexSingleTask(AlbumDownloadTask task) {
    _taskById[task.id] = task;
    if (task.albumItem.slug.isNotEmpty) {
      _taskBySlug[task.albumItem.slug] = task;
    }
    if (task.albumItem.detailUrl.isNotEmpty) {
      _taskByDetailUrl[task.albumItem.detailUrl] = task;
    }
    if (task.albumItem.title.isNotEmpty) {
      _taskByTitle[task.albumItem.title] = task;
    }
    if (task.videoUrl != null && task.videoUrl!.isNotEmpty) {
      _taskByVideoUrl[task.videoUrl!.split('?').first] = task;
    }
  }

  AlbumDownloadTask? findTask({
    String? slug,
    String? detailUrl,
    String? title,
    String? videoUrl,
    String? id,
  }) {
    if (id != null && _taskById.containsKey(id)) return _taskById[id];
    if (slug != null && slug.isNotEmpty) {
      return _taskBySlug[slug];
    }
    if (detailUrl != null && detailUrl.isNotEmpty) {
      return _taskByDetailUrl[detailUrl];
    }
    if (videoUrl != null && videoUrl.isNotEmpty) {
      final clean = videoUrl.split('?').first;
      return _taskByVideoUrl[clean];
    }
    if (title != null && title.isNotEmpty) {
      return _taskByTitle[title];
    }
    return null;
  }

  /// O(1) task lookup for AlbumItem
  AlbumDownloadTask? getTaskForAlbum(AlbumItem item) {
    return findTask(
      slug: item.slug,
      detailUrl: item.detailUrl,
      title: item.title,
    );
  }

  String _generateTaskId(String title) {
    _taskSequenceCounter++;
    return '${DateTime.now().microsecondsSinceEpoch}_${_taskSequenceCounter}_${title.hashCode.abs()}';
  }

  bool _isDisposed = false;

  void _throttledProgressNotify() {
    if (_isDisposed) return;
    final now = DateTime.now();
    final elapsed = now.difference(_lastProgressNotifyTime).inMilliseconds;
    if (elapsed >= 200) {
      _progressThrottleTimer?.cancel();
      _progressThrottleTimer = null;
      _lastProgressNotifyTime = now;
      notifyListeners();
      _updateNotification();
    } else {
      if (_progressThrottleTimer == null || !_progressThrottleTimer!.isActive) {
        final delay = Duration(milliseconds: 200 - elapsed);
        _progressThrottleTimer = Timer(delay, () {
          if (_isDisposed) return;
          _lastProgressNotifyTime = DateTime.now();
          _progressThrottleTimer = null;
          notifyListeners();
          _updateNotification();
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
    _persistenceService.dispose();
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
    final loaded = await _persistenceService.loadTasks();
    for (final t in loaded) {
      if (!_allTasks.any((existing) => existing.id == t.id)) {
        _allTasks.add(t);
      }
    }
    _rebuildIndexes();
    notifyListeners();
  }

  /// Persist all tasks to SharedPreferences (debounced unless immediate)
  void _persistTasks({bool immediate = false}) {
    _persistenceService.persistTasks(_allTasks, immediate: immediate);
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

    final existingTask = getTaskForAlbum(item);
    if (existingTask != null) {
      _currentBatchTaskIds.add(existingTask.id);
      if (existingTask.status == TaskStatus.paused || existingTask.status == TaskStatus.failed) {
        existingTask.status = TaskStatus.queued;
        _invalidateFilteredCache();
        _persistTasks(immediate: true);
        notifyListeners();
        _triggerDownloadLoop();
      }
      return;
    }

    final taskId = _generateTaskId(item.title);
    final task = AlbumDownloadTask(
      id: taskId,
      albumItem: item,
      targetFolder: p.join(_config.savePath, AlbumItem.cleanFilename(item.title)),
      totalImages: item.imageUrls.length,
      status: TaskStatus.queued,
    );

    _allTasks.add(task);
    _indexSingleTask(task);
    _invalidateFilteredCache();
    _currentBatchTaskIds.add(taskId);
    _persistTasks(immediate: true);
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
      final existingTask = getTaskForAlbum(item);
      if (existingTask != null) {
        _currentBatchTaskIds.add(existingTask.id);
        if (existingTask.status == TaskStatus.paused || existingTask.status == TaskStatus.failed) {
          existingTask.status = TaskStatus.queued;
        }
        continue;
      }

      final taskId = _generateTaskId(item.title);
      final task = AlbumDownloadTask(
        id: taskId,
        albumItem: item,
        targetFolder: p.join(_config.savePath, AlbumItem.cleanFilename(item.title)),
        totalImages: item.imageUrls.length,
        status: TaskStatus.queued,
      );
      _allTasks.add(task);
      _indexSingleTask(task);
      _currentBatchTaskIds.add(taskId);
    }

    _invalidateFilteredCache();
    _persistTasks(immediate: true);
    notifyListeners();

    _triggerDownloadLoop();
  }

  /// Fetch and add page range (e.g. from page 1 to 5) to batch download queue
  Future<void> addPageRange(int startPage, int endPage, {String? keyword}) async {
    final allItems = await _batchCoordinator.fetchHcPageRange(startPage, endPage, keyword: keyword);
    if (allItems.isNotEmpty) {
      addBatchAlbumTasks(allItems);
    }
  }

  /// Fetch and add MZT page range (e.g. from page 1 to 5) to batch download queue
  Future<void> addMztPageRange(int startPage, int endPage) async {
    final allItems = await _batchCoordinator.fetchMztPageRange(startPage, endPage);
    if (allItems.isNotEmpty) {
      addBatchAlbumTasks(allItems);
    }
  }

  /// Fetch and add MissKon page range to batch download queue
  Future<void> addMisskonPageRange(
    int startPage,
    int endPage, {
    MisskonCategory category = MisskonCategory.latest,
    String? tag,
    String? keyword,
  }) async {
    final allItems = await _batchCoordinator.fetchMisskonPageRange(
      startPage,
      endPage,
      category: category,
      tag: tag,
      keyword: keyword,
    );
    if (allItems.isNotEmpty) {
      addBatchAlbumTasks(allItems);
    }
  }

  /// Fetch and add Coomer page range to batch download queue
  Future<void> addCoomerPageRange(
    int startPage,
    int endPage, {
    String? service,
    String? query,
    CoomerCreator? creator,
  }) async {
    final allItems = await _batchCoordinator.fetchCoomerPageRange(
      startPage,
      endPage,
      service: service,
      query: query,
      creator: creator,
    );
    if (allItems.isNotEmpty) {
      addBatchAlbumTasks(allItems);
    }
  }

  /// Fetch and add 91品色 page range to batch download queue
  Future<void> addPinsePageRange(
    int startPage,
    int endPage, {
    PinseCategory category = PinseCategory.latest,
    String? keyword,
    String? author,
  }) async {
    final allVideos = await _batchCoordinator.fetchPinsePageRange(
      startPage,
      endPage,
      category: category,
      keyword: keyword,
      author: author,
    );
    if (allVideos.isNotEmpty) {
      addBatchVideoTasks(allVideos);
    }
  }

  /// Fetch and add PornBox page range to batch download queue
  Future<void> addPornboxPageRange(
    int startPage,
    int endPage, {
    PornboxCategory category = PornboxCategory.latest,
    String? keyword,
    String? studio,
  }) async {
    final allVideos = await _batchCoordinator.fetchPornboxPageRange(
      startPage,
      endPage,
      category: category,
      keyword: keyword,
      studio: studio,
    );
    if (allVideos.isNotEmpty) {
      addBatchVideoTasks(allVideos);
    }
  }

  /// Fetch and add Kuraa album to download queue
  Future<void> addKuraaAlbumTask(KuraaFileItem folderItem, {String? token}) async {
    final album = await _batchCoordinator.fetchKuraaAlbum(folderItem, token: token);
    if (album != null && album.imageUrls.isNotEmpty) {
      addBatchAlbumTasks([album]);
    }
  }

  /// Fetch and add Kuraa page range to batch download queue
  Future<void> addKuraaPageRange(
    int startPage,
    int endPage, {
    required String storageLocationId,
    String? parentId,
    String? token,
  }) async {
    final albums = await _batchCoordinator.fetchKuraaPageRange(
      startPage,
      endPage,
      storageLocationId: storageLocationId,
      parentId: parentId,
      token: token,
    );
    if (albums.isNotEmpty) {
      addBatchAlbumTasks(albums);
    }
  }

  /// Fetch and add Twitter page range to batch download queue
  Future<void> addTwitterPageRange(
    int startPage,
    int endPage, {
    required TwitterSiteConfig site,
    String? range,
    String? sort,
  }) async {
    final allVideos = await _batchCoordinator.fetchTwitterPageRange(
      startPage,
      endPage,
      site: site,
      range: range,
      sort: sort,
    );
    if (allVideos.isNotEmpty) {
      addBatchVideoTasks(allVideos);
    }
  }

  /// Fetch and add ExHentai page range to batch download queue
  Future<void> addExHentaiPageRange(
    int startPage,
    int endPage, {
    ExCategory category = ExCategory.all,
    String? keyword,
    bool isPopular = false,
  }) async {
    final allAlbums = await _batchCoordinator.fetchExHentaiPageRange(
      startPage,
      endPage,
      category: category,
      keyword: keyword,
      isPopular: isPopular,
    );
    if (allAlbums.isNotEmpty) {
      addBatchAlbumTasks(allAlbums);
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
      final incomingCleanVideoUrl = video.videoUrl != null && video.videoUrl!.isNotEmpty
          ? video.videoUrl!.split('?').first
          : '';
      final incomingTwId = _extractMediaIdentifier(video.videoUrl ?? video.detailUrl, video.slug);

      final existingIndex = _allTasks.indexWhere((t) {
        if (t.albumItem.slug == key || t.albumItem.title == key) return true;
        if (incomingCleanVideoUrl.isNotEmpty && t.videoUrl != null && t.videoUrl!.isNotEmpty) {
          if (t.videoUrl!.split('?').first == incomingCleanVideoUrl) return true;
        }
        if (incomingTwId != null && incomingTwId.isNotEmpty) {
          final existingTwId = _extractMediaIdentifier(t.videoUrl ?? t.albumItem.detailUrl, t.albumItem.slug);
          if (existingTwId != null && existingTwId == incomingTwId) return true;
        }
        return false;
      });

      if (existingIndex != -1) {
        final existingTask = _allTasks[existingIndex];
        if (existingTask.status == TaskStatus.completed) {
          debugPrint('Skipping duplicate video: ${video.title} (already downloaded)');
          continue;
        }
        _currentBatchTaskIds.add(existingTask.id);
        if (existingTask.status == TaskStatus.paused || existingTask.status == TaskStatus.failed) {
          existingTask.status = TaskStatus.queued;
        }
        continue;
      }

      final taskId = _generateTaskId(video.title);
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
        targetFolder: p.join(_config.savePath, 'video'),
        totalImages: 1,
        status: TaskStatus.queued,
        isVideo: true,
        videoUrl: video.videoUrl,
        duration: video.duration,
      );
      _allTasks.add(task);
      _indexSingleTask(task);
      _currentBatchTaskIds.add(taskId);
    }

    _invalidateFilteredCache();
    _persistTasks(immediate: true);
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
    final allVideos = await _batchCoordinator.fetchVideoPageRange(
      startPage,
      endPage,
      category: category,
      keyword: keyword,
      tag: tag,
    );
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
    _invalidateFilteredCache();
    _persistTasks(immediate: true);
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
    _invalidateFilteredCache();
    _persistTasks(immediate: true);
    notifyListeners();
    _updateNotification();
  }

  /// Resume a single task
  void resumeTask(AlbumDownloadTask task) {
    if (task.status == TaskStatus.paused || task.status == TaskStatus.failed) {
      task.status = TaskStatus.queued;
      _currentBatchTaskIds.add(task.id);
      _invalidateFilteredCache();
      _persistTasks(immediate: true);
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
    _invalidateFilteredCache();
    _persistTasks(immediate: true);
    notifyListeners();
    _scheduleNextTasks();
  }

  /// Retry failed tasks
  void retryFailedTasks() {
    for (final task in failedTasks) {
      task.status = TaskStatus.queued;
      _currentBatchTaskIds.add(task.id);
    }
    _invalidateFilteredCache();
    _persistTasks(immediate: true);
    notifyListeners();
    _scheduleNextTasks();
  }

  /// Clear finished/completed tasks from task manager list
  void clearCompleted() {
    _allTasks.removeWhere((t) => t.status == TaskStatus.completed);
    _currentBatchTaskIds.clear();
    _rebuildIndexes();
    _persistTasks(immediate: true);
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
    _rebuildIndexes();
    _persistTasks(immediate: true);
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
    if (_isDisposed) return;
    _startSpeedTimer();
    _batchStartTime ??= DateTime.now();

    _config = ConfigService.loadConfig();
    final maxPackWorkers = _config.packWorkers.clamp(1, 20);

    while (_runningTasks.length < maxPackWorkers) {
      if (_isDisposed) break;
      final queuedList = _allTasks.where((t) => t.status == TaskStatus.queued).toList();
      if (queuedList.isEmpty) break;

      final task = queuedList.first;
      task.status = TaskStatus.downloading;
      task.startTime ??= DateTime.now();
      _runningTasks.add(task);
      _setIosBackgroundKeeper(true);
      _invalidateFilteredCache();
      notifyListeners();
      _updateNotification();

      _executeSingleTask(task);
    }

    if (_runningTasks.isEmpty && queuedTasks.isEmpty) {
      _finishBatchIfNeeded();
    }
  }

  Future<void> _executeSingleTask(AlbumDownloadTask task) async {
    if (_isDisposed) return;
    final engine = DownloadEngine(
      config: _config,
      onLog: (msg, level) {
        switch (level) {
          case 'error':
            AppLogger.e('DownloadEngine', msg);
            break;
          case 'warn':
            AppLogger.w('DownloadEngine', msg);
            break;
          case 'success':
            AppLogger.s('DownloadEngine', msg);
            break;
          case 'debug':
            AppLogger.d('DownloadEngine', msg);
            break;
          default:
            AppLogger.i('DownloadEngine', msg);
        }
      },
      onTaskProgress: (t) {
        _throttledProgressNotify();
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
            : (task.isVideo
                ? 0
                : await StorageService.getFolderSize(task.targetFolder));

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
      _invalidateFilteredCache();
      _persistTasks();
      notifyListeners();
      _updateNotification();

      _scheduleNextTasks();
    }
  }

  void _finishBatchIfNeeded() {
    if (_currentBatchTaskIds.isEmpty) return;
    _setIosBackgroundKeeper(false);
    final duration = _batchStartTime != null
        ? DateTime.now().difference(_batchStartTime!).inMilliseconds / 1000.0
        : 1.0;

    final batchTasks = _allTasks
        .where((t) => _currentBatchTaskIds.contains(t.id))
        .toList();
    final finishedBatch = batchTasks.where((t) => t.status == TaskStatus.completed).toList();

    int totalImages = 0;
    for (final t in finishedBatch) {
      totalImages += (t.downloadedImages + t.skippedImages);
    }

    if (finishedBatch.isNotEmpty) {
      _notificationManager.notifyBatchCompleted(
        completedAlbumsCount: finishedBatch.length,
        totalImagesCount: totalImages,
        durationSec: duration,
      );
    }
    _batchStartTime = null;
    _currentBatchTaskIds.clear();
    onAlbumsChanged?.call();
  }

  void _updateNotification() {
    _notificationManager.updateProgress(
      activeTasks: activeTasks,
      queuedTasks: queuedTasks,
      pausedTasks: pausedTasks,
      overallProgress: overallProgress,
      formattedSpeed: formattedSpeed,
    );
  }

  String? _extractMediaIdentifier(String? url, String? slug) {
    if (url != null && url.isNotEmpty) {
      final statusMatch = RegExp(r'/status/(\d+)').firstMatch(url);
      if (statusMatch != null) return statusMatch.group(1);
      final twimgMatch = RegExp(r'/(?:ext_tw_video|amplify_video)/(\d+)').firstMatch(url);
      if (twimgMatch != null) return twimgMatch.group(1);
      final twimgDirectMatch = RegExp(r'video\.twimg\.com/[^/]+/[^/]+/([^/?#]+)').firstMatch(url);
      if (twimgDirectMatch != null) return twimgDirectMatch.group(1);
    }
    if (slug != null && slug.isNotEmpty) {
      final slugMatch = RegExp(r'(\d{15,22})').firstMatch(slug);
      if (slugMatch != null) return slugMatch.group(1);
    }
    return null;
  }
}
