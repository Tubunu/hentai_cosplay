import '../../models/download_task.dart';
import '../notification_service.dart';

class DownloadNotificationManager {
  void updateProgress({
    required List<AlbumDownloadTask> activeTasks,
    required List<AlbumDownloadTask> queuedTasks,
    required List<AlbumDownloadTask> pausedTasks,
    required double overallProgress,
    required String formattedSpeed,
  }) {
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

  void notifyBatchCompleted({
    required int completedAlbumsCount,
    required int totalImagesCount,
    required double durationSec,
  }) {
    NotificationService.showDownloadCompleted(
      albumsCount: completedAlbumsCount,
      imagesCount: totalImagesCount,
      durationSec: durationSec,
    );
  }
}
