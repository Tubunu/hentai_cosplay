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

    // Use the cache folder of the first segment for temporary work
    final cacheFolder = File(tempSegmentPaths.first).parent.path;
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

      // Filter valid segment paths
      final validSegmentPaths = <String>[];
      for (final path in tempSegmentPaths) {
        final f = File(path);
        if (await f.exists() && await f.length() > 0) {
          validSegmentPaths.add(path);
        }
      }

      if (validSegmentPaths.isEmpty) {
        return MergeResult(success: false, error: "未找到任何已下载的有效视频分片");
      }

      // 1. Primary Strategy: FFmpeg Concat Demuxer (Zero intermediate TS copy, saves 1x video size storage & disk wear)
      final concatListFile = File("$cacheFolder/concat_${DateTime.now().millisecondsSinceEpoch}.txt");
      try {
        final fileEntries = validSegmentPaths.map((seg) {
          final normalized = seg.replaceAll(r'\', '/').replaceAll("'", r"'\''");
          return "file '$normalized'";
        }).join('\n');
        await concatListFile.writeAsString(fileEntries);

        onProgress("正在快速封装并修复播放索引...");
        final session = await FFmpegKit.executeWithArguments([
          '-y',
          '-err_detect',
          'ignore_err',
          '-f',
          'concat',
          '-safe',
          '0',
          '-i',
          concatListFile.path,
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
          try {
            if (await concatListFile.exists()) await concatListFile.delete();
          } catch (_) {}
          return MergeResult(success: true, finalPath: targetMp4Path);
        }
      } catch (_) {
      } finally {
        try {
          if (await concatListFile.exists()) await concatListFile.delete();
        } catch (_) {}
      }

      // 2. Secondary Strategy Fallback: Binary RAF concatenation + FFmpeg remux / stream copy
      onProgress("正在合并视频分片 (回落模式)...");
      final tempMergedTs = "$cacheFolder/raw_combined_${DateTime.now().millisecondsSinceEpoch}.ts";
      final mergedFile = File(tempMergedTs);
      
      if (await mergedFile.exists()) {
        await mergedFile.delete();
      }

      final raf = await mergedFile.open(mode: FileMode.write);
      try {
        for (final path in validSegmentPaths) {
          try {
            final file = File(path);
            final bytes = await file.readAsBytes();
            await raf.writeFrom(bytes);
          } catch (_) {}
        }
        await raf.flush();
      } finally {
        await raf.close();
      }

      onProgress("正在修复播放索引...");
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
          if (await mergedFile.exists()) {
            try {
              await mergedFile.delete();
            } catch (_) {}
          }
          return MergeResult(success: true, finalPath: targetMp4Path);
        }
      } catch (_) {}

      // Final fallback: Stream copy TS directly to destination
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
      return MergeResult(success: false, error: "分片合并异常: $e");
    }
  }
}
