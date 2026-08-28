import 'dart:async';
import 'dart:io';
import '../services/exhentai/exhentai_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/album_item.dart';
import '../models/app_config.dart';
import '../models/download_task.dart';
import '../models/history_record.dart';
import '../models/video_item.dart';
import '../services/config_service.dart';
import '../services/coomer/coomer_api_service.dart';
import '../services/download_engine.dart';
import '../services/hc_api_service.dart';
import '../services/kuraa/kuraa_api_service.dart';
import '../services/misskon/misskon_api_service.dart';
import '../services/mzt_api_service.dart';
import '../services/notification_service.dart';
import '../services/pinse/pinse_api_service.dart';
import '../services/pornbox/pornbox_api_service.dart';
import '../services/storage_service.dart';
import '../services/twitter_rankings/twitter_ranking_api_service.dart';
import '../services/twitter_rankings/twitter_site_config.dart';
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

    final taskId = _generateTaskId(item.title);
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

      final taskId = _generateTaskId(item.title);
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

  /// Fetch and add MZT page range (e.g. from page 1 to 5) to batch download queue
  Future<void> addMztPageRange(int startPage, int endPage) async {
    _config = ConfigService.loadConfig();
    final List<AlbumItem> allItems = [];

    for (int p = startPage; p <= endPage; p++) {
      try {
        final pageData = await MztApiService.fetchPageData(page: p, pageSize: 12);
        if (pageData != null && pageData.items.isNotEmpty) {
          allItems.addAll(pageData.items);
        }
      } catch (e) {
        debugPrint('Error fetching MZT page $p during batch range download: $e');
      }
    }

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
    _config = ConfigService.loadConfig();
    final List<AlbumItem> allItems = [];

    for (int p = startPage; p <= endPage; p++) {
      try {
        final pageData = await MisskonApiService.fetchPageData(
          page: p,
          category: category,
          tag: tag,
          keyword: keyword,
        );
        if (pageData != null && pageData.items.isNotEmpty) {
          allItems.addAll(pageData.items);
        }
      } catch (e) {
        debugPrint('Error fetching MissKon page $p during batch range download: $e');
      }
    }

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
    _config = ConfigService.loadConfig();
    final List<AlbumItem> allItems = [];

    for (int p = startPage; p <= endPage; p++) {
      try {
        final offset = (p - 1) * 40;
        CoomerApiResponse? pageData;
        if (creator != null) {
          pageData = await CoomerApiService.fetchCreatorPosts(
            service: creator.service,
            creatorId: creator.id,
            offset: offset,
            limit: 40,
          );
        } else {
          pageData = await CoomerApiService.fetchRecentPosts(
            offset: offset,
            limit: 40,
            service: service == 'all' ? null : service,
            query: query,
          );
        }

        if (pageData != null && pageData.items.isNotEmpty) {
          allItems.addAll(pageData.items);
        }
      } catch (e) {
        debugPrint('Error fetching Coomer page $p during batch range download: $e');
      }
    }

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
    _config = ConfigService.loadConfig();
    final List<VideoItem> allVideos = [];

    for (int p = startPage; p <= endPage; p++) {
      try {
        final pageData = await PinseApiService.fetchPageData(
          page: p,
          category: category,
          keyword: keyword,
          author: author,
        );
        if (pageData != null && pageData.items.isNotEmpty) {
          allVideos.addAll(pageData.items);
        }
      } catch (e) {
        debugPrint('Error fetching 91品色 page $p during batch range download: $e');
      }
    }

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
    _config = ConfigService.loadConfig();
    final List<VideoItem> allVideos = [];

    for (int p = startPage; p <= endPage; p++) {
      try {
        final pageData = await PornboxApiService.fetchPageData(
          page: p,
          category: category,
          keyword: keyword,
          studio: studio,
        );
        if (pageData != null && pageData.items.isNotEmpty) {
          allVideos.addAll(pageData.items);
        }
      } catch (e) {
        debugPrint('Error fetching PornBox page $p during batch range download: $e');
      }
    }

    if (allVideos.isNotEmpty) {
      addBatchVideoTasks(allVideos);
    }
  }

  /// Fetch and add Kuraa album to download queue
  Future<void> addKuraaAlbumTask(KuraaFileItem folderItem, {String? token}) async {
    _config = ConfigService.loadConfig();
    try {
      final album = await KuraaApiService.fetchAlbumDetail(folderItem, token: token);
      if (album != null && album.imageUrls.isNotEmpty) {
        addBatchAlbumTasks([album]);
      }
    } catch (e) {
      debugPrint('Error adding Kuraa album task: $e');
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
    _config = ConfigService.loadConfig();
    const pageSize = 50;

    for (int p = startPage; p <= endPage; p++) {
      try {
        final offset = (p - 1) * pageSize;
        final res = await KuraaApiService.fetchFiles(
          storageLocationId: storageLocationId,
          parentId: parentId,
          offset: offset,
          limit: pageSize,
          sortBy: 'updatedAt',
          sortOrder: 'desc',
          token: token,
        );

        for (final item in res.items) {
          if (item.isFolder) {
            await addKuraaAlbumTask(item, token: token);
          }
        }
      } catch (e) {
        debugPrint('Error fetching Kuraa page $p during batch range download: $e');
      }
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
    _config = ConfigService.loadConfig();
    final List<VideoItem> allVideos = [];

    for (int p = startPage; p <= endPage; p++) {
      try {
        final pageData = await TwitterRankingApiService.fetchPageData(
          site: site,
          range: range,
          sort: sort,
          page: p,
        );
        if (pageData != null && pageData.items.isNotEmpty) {
          for (var v in pageData.items) {
            if (v.videoUrl == null || v.videoUrl!.isEmpty) {
              v = await TwitterRankingApiService.resolveVideoDetail(site, v);
            }
            allVideos.add(v);
          }
        }
      } catch (e) {
        debugPrint('Error fetching Twitter page $p during batch range download: $e');
      }
    }

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
    _config = ConfigService.loadConfig();
    final List<AlbumItem> allAlbums = [];

    for (int p = startPage; p <= endPage; p++) {
      try {
        final res = await ExHentaiApiService.fetchPageData(
          page: p,
          category: category,
          keyword: keyword,
          isPopular: isPopular,
        );
        if (res != null && res.items.isNotEmpty) {
          allAlbums.addAll(res.items);
        }
      } catch (e) {
        debugPrint('Error fetching ExHentai page $p during batch range download: $e');
      }
    }

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
      onLog: (msg, level) {},
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
