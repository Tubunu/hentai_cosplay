import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class MergeResult {
  final bool success;
  final String? error;
  final String? finalPath;
  MergeResult({required this.success, this.error, this.finalPath});
}

class Merger {
  /// Concatenates decrypted TS segment files and remuxes them into a standard MP4 file.
  /// If FFmpeg fails or is not supported, it falls back to raw TS-to-MP4 stream copy.
  /// If destination directory has no write permission, safely saves to app sandbox directory.
  static Future<MergeResult> mergeAndRemux({
    required List<String> tempSegmentPaths,
    required String outputMp4Path,
    required Function(String status) onProgress,
  }) async {
    if (tempSegmentPaths.isEmpty) {
      return MergeResult(success: false, error: "分片列表为空");
    }

    // Use the cache folder of the first segment for temporary concatenated TS
    final cacheFolder = File(tempSegmentPaths.first).parent.path;
    final tempMergedTs = "$cacheFolder/raw_combined_${DateTime.now().millisecondsSinceEpoch}.ts";
    String targetMp4Path = outputMp4Path;
    
    try {
      // Ensure target destination directory exists
      final outParentDir = File(targetMp4Path).parent;
      if (!await outParentDir.exists()) {
        try {
          await outParentDir.create(recursive: true);
        } catch (e) {
          final docDir = await getApplicationDocumentsDirectory();
          final safeDest = "${docDir.path}/jabletv";
          await Directory(safeDest).create(recursive: true);
          final fileName = p.basename(targetMp4Path);
          targetMp4Path = "$safeDest/$fileName";
        }
      }

      onProgress("正在合并视频分片...");
      final mergedFile = File(tempMergedTs);
      
      // Clean up pre-existing merge files
      if (await mergedFile.exists()) {
        await mergedFile.delete();
      }
      
      // Use RandomAccessFile for fast, reliable native binary concatenation without stream memory issues
      final raf = await mergedFile.open(mode: FileMode.write);
      int writtenSegments = 0;

      for (final path in tempSegmentPaths) {
        try {
          final file = File(path);
          if (await file.exists()) {
            final len = await file.length();
            if (len > 0) {
              final bytes = await file.readAsBytes();
              await raf.writeFrom(bytes);
              writtenSegments++;
            }
          }
        } catch (_) {}
      }
      await raf.flush();
      await raf.close();

      if (writtenSegments == 0) {
        return MergeResult(success: false, error: "未找到任何已下载的有效视频分片");
      }

      onProgress("正在修复播放索引...");
      // Execute FFmpeg to remux container format without transcoding
      // Include -bsf:a aac_adtstoasc which is required when remuxing AAC from TS to MP4 container
      try {
        final session = await FFmpegKit.executeWithArguments([
          '-y',
          '-err_detect',
          'ignore_err',
          '-i',
          tempMergedTs,
          '-c',
          'copy',
          '-bsf:a',
          'aac_adtstoasc',
          '-movflags',
          '+faststart',
          targetMp4Path,
        ]);
        final returnCode = await session.getReturnCode();

        final targetMp4 = File(targetMp4Path);
        if (ReturnCode.isSuccess(returnCode) && await targetMp4.exists() && await targetMp4.length() > 0) {
          // Successful remux: Delete temporary merged TS file
          if (await mergedFile.exists()) {
            try {
              await mergedFile.delete();
            } catch (_) {}
          }
          return MergeResult(success: true, finalPath: targetMp4Path);
        }
      } catch (_) {}

      // Fallback: Copy the concatenated TS stream directly to destination MP4 (cross-device safe)
      if (await mergedFile.exists()) {
        try {
          final targetMp4 = File(targetMp4Path);
          if (await targetMp4.exists()) await targetMp4.delete();
          await mergedFile.copy(targetMp4Path);
          await mergedFile.delete();
          return MergeResult(success: true, finalPath: targetMp4Path);
        } catch (copyErr) {
          try {
            final docDir = await getApplicationDocumentsDirectory();
            final safeDest = "${docDir.path}/jabletv";
            await Directory(safeDest).create(recursive: true);
            final fileName = p.basename(targetMp4Path);
            final safeFinalPath = "$safeDest/$fileName";
            await mergedFile.copy(safeFinalPath);
            await mergedFile.delete();
            return MergeResult(success: true, finalPath: safeFinalPath);
          } catch (sandboxErr) {
            return MergeResult(success: false, error: "保存视频失败 (权限不足): $copyErr");
          }
        }
      }
      return MergeResult(success: false, error: "分片合并失败且临时文件不可用");
    } catch (e) {
      try {
        if (await File(tempMergedTs).exists()) await File(tempMergedTs).delete();
      } catch (_) {}
      return MergeResult(success: false, error: "分片合并异常: $e");
    }
  }
}
