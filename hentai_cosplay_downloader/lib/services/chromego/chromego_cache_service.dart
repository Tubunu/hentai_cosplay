import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../models/chromego/proxy_node.dart';

/// Service for atomic local persistence of extracted nodes.
class NodeCacheService {
  final String? customDirPath;

  NodeCacheService({this.customDirPath});

  Future<File> _getCacheFile() async {
    if (customDirPath != null) {
      return File('$customDirPath/nodes_cache.json');
    }
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/nodes_cache.json');
    } catch (_) {
      return File('./nodes_cache.json');
    }
  }

  /// Atomically saves nodes and stats to local cache file.
  Future<bool> saveCache(List<ProxyNode> nodes, {Map<String, dynamic>? stats}) async {
    if (nodes.isEmpty) return false;
    try {
      final file = await _getCacheFile();
      final tmpFile = File('${file.path}.tmp');

      final cacheData = {
        'version': 1,
        'updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'updated_at_str': DateTime.now().toIso8601String(),
        'total_nodes': nodes.length,
        'stats': stats ?? {},
        'nodes': nodes.map((n) => n.toJson()).toList(),
      };

      await tmpFile.writeAsString(jsonEncode(cacheData), flush: true);
      if (await file.exists()) {
        await file.delete();
      }
      await tmpFile.rename(file.path);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Loads cached nodes and stats from local cache file.
  Future<(List<ProxyNode>, Map<String, dynamic>)> loadCache() async {
    try {
      final file = await _getCacheFile();
      if (!await file.exists()) return (<ProxyNode>[], <String, dynamic>{});

      final content = await file.readAsString();
      final data = jsonDecode(content);

      var nodesRaw = <dynamic>[];
      var stats = <String, dynamic>{};

      if (data is Map) {
        nodesRaw = data['nodes'] as List? ?? [];
        stats = (data['stats'] is Map) ? Map<String, dynamic>.from(data['stats']) : {};
        if (data.containsKey('updated_at_str')) {
          stats['updated_at_str'] = data['updated_at_str'];
        }
      } else if (data is List) {
        nodesRaw = data;
      }

      final loadedNodes = <ProxyNode>[];
      for (final item in nodesRaw) {
        if (item is! Map) continue;
        try {
          final node = ProxyNode.fromJson(Map<String, dynamic>.from(item));
          if (node.server.isNotEmpty && node.port > 0) {
            loadedNodes.add(node);
          }
        } catch (_) {}
      }

      return (loadedNodes, stats);
    } catch (_) {
      return (<ProxyNode>[], <String, dynamic>{});
    }
  }
}
