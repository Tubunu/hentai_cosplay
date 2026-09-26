import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/chromego/proxy_node.dart';
import 'chromego_parsers.dart';

class RemoteSourceInfo {
  final String patternGitlab;
  final String patternMirror;
  final String format;
  final int maxIndex;

  const RemoteSourceInfo({
    required this.patternGitlab,
    required this.patternMirror,
    required this.format,
    required this.maxIndex,
  });
}

/// Service for fetching and extracting proxy nodes from online multi-source configurations.
class NodeFetcher {
  static const Map<String, RemoteSourceInfo> remoteSources = {
    'clash.meta': RemoteSourceInfo(
      patternGitlab: 'https://gitlab.com/free9999/ipupdate/-/raw/master/backup/img/1/2/ipp/clash.meta2/{index}/config.yaml',
      patternMirror: 'https://www.67867867.xyz/Alvin9999/PAC/refs/heads/master/backup/img/1/2/ipp/clash.meta2/{index}/config.yaml',
      format: 'yaml',
      maxIndex: 6,
    ),
    'xray': RemoteSourceInfo(
      patternGitlab: 'https://gitlab.com/free9999/ipupdate/-/raw/master/backup/img/1/2/ipp/xray/{index}/config.json',
      patternMirror: 'https://www.67867867.xyz/Alvin9999/PAC/refs/heads/master/backup/img/1/2/ipp/xray/{index}/config.json',
      format: 'json',
      maxIndex: 4,
    ),
    'hysteria2': RemoteSourceInfo(
      patternGitlab: 'https://gitlab.com/free9999/ipupdate/-/raw/master/backup/img/1/2/ipp/hysteria2/{index}/config.json',
      patternMirror: 'https://www.67867867.xyz/Alvin9999/PAC/refs/heads/master/backup/img/1/2/ipp/hysteria2/{index}/config.json',
      format: 'json',
      maxIndex: 4,
    ),
    'singbox': RemoteSourceInfo(
      patternGitlab: 'https://gitlab.com/free9999/ipupdate/-/raw/master/backup/img/1/2/ipp/singbox/{index}/config.json',
      patternMirror: 'https://www.67867867.xyz/Alvin9999/PAC/refs/heads/master/backup/img/1/2/ipp/singbox/{index}/config.json',
      format: 'json',
      maxIndex: 2,
    ),
    'hysteria': RemoteSourceInfo(
      patternGitlab: 'https://gitlab.com/free9999/ipupdate/-/raw/master/backup/img/1/2/ipp/hysteria/{index}/config.json',
      patternMirror: 'https://www.67867867.xyz/Alvin9999/PAC/refs/heads/master/backup/img/1/2/ipp/hysteria/{index}/config.json',
      format: 'json',
      maxIndex: 4,
    ),
    'juicity': RemoteSourceInfo(
      patternGitlab: 'https://gitlab.com/free9999/ipupdate/-/raw/master/backup/img/1/2/ipp/juicity/{index}/config.json',
      patternMirror: 'https://www.67867867.xyz/Alvin9999/PAC/refs/heads/master/backup/img/1/2/ipp/juicity/{index}/config.json',
      format: 'json',
      maxIndex: 2,
    ),
    'naiveproxy': RemoteSourceInfo(
      patternGitlab: 'https://gitlab.com/free9999/ipupdate/-/raw/master/backup/img/1/2/ipp/naiveproxy/{index}/config.json',
      patternMirror: 'https://www.67867867.xyz/Alvin9999/PAC/refs/heads/master/backup/img/1/2/ipp/naiveproxy/{index}/config.json',
      format: 'json',
      maxIndex: 2,
    ),
    'shadowquic': RemoteSourceInfo(
      patternGitlab: 'https://gitlab.com/free9999/ipupdate/-/raw/master/backup/img/1/2/ipp/shadowquic/{index}/client.yaml',
      patternMirror: 'https://www.67867867.xyz/Alvin9999/PAC/refs/heads/master/backup/img/1/2/ipp/shadowquic/{index}/client.yaml',
      format: 'yaml',
      maxIndex: 2,
    ),
  };

  /// Fetches config and extracts nodes for a specific protocol key and ip index.
  static Future<List<ProxyNode>> fetchAndExtractProtocol(
    String protoKey,
    int ipIndex, {
    bool preferMirror = false,
    http.Client? client,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    if (!remoteSources.containsKey(protoKey)) return [];
    final info = remoteSources[protoKey]!;
    final httpClient = client ?? http.Client();

    final idx = ipIndex.clamp(1, info.maxIndex);
    final urlPrimary = info.patternGitlab.replaceAll('{index}', idx.toString());
    final urlMirror = info.patternMirror.replaceAll('{index}', idx.toString());

    final candidateUrls = preferMirror ? [urlMirror, urlPrimary] : [urlPrimary, urlMirror];
    final sourceLabel = 'IP $ipIndex';

    try {
      for (final url in candidateUrls) {
        try {
          final res = await httpClient.get(Uri.parse(url)).timeout(timeout);
          if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
            final content = utf8.decode(res.bodyBytes, allowMalformed: true);
            List<ProxyNode> nodes = [];

            if (protoKey == 'clash.meta') {
              nodes = NodeParsers.parseClashYaml(content, sourceTag: 'Clash ($sourceLabel)');
            } else if (protoKey == 'xray') {
              nodes = NodeParsers.parseXrayJson(content, sourceTag: 'Xray ($sourceLabel)');
            } else if (protoKey == 'hysteria2') {
              nodes = NodeParsers.parseHysteria2Json(content, sourceTag: 'Hy2 ($sourceLabel)');
            } else if (protoKey == 'singbox') {
              nodes = NodeParsers.parseSingboxJson(content, sourceTag: 'SingBox ($sourceLabel)');
            } else if (protoKey == 'hysteria') {
              nodes = NodeParsers.parseHysteria1Json(content, sourceTag: 'Hy1 ($sourceLabel)');
            } else if (protoKey == 'juicity') {
              nodes = NodeParsers.parseJuicityJson(content, sourceTag: 'Juicity ($sourceLabel)');
            } else if (protoKey == 'naiveproxy') {
              nodes = NodeParsers.parseNaiveproxyJson(content, sourceTag: 'Naive ($sourceLabel)');
            } else if (protoKey == 'shadowquic') {
              nodes = NodeParsers.parseShadowquicYaml(content, sourceTag: 'ShadowQUIC ($sourceLabel)');
            }

            if (nodes.isNotEmpty) {
              return nodes;
            }
          }
        } catch (_) {
          // Fallback to next candidate URL
        }
      }
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }

    return [];
  }

  /// Concurrently fetches all sources, merges protocols, and deduplicates nodes.
  static Future<(List<ProxyNode>, Map<String, int>)> fetchAllSourcesDedup({
    String protocolFilter = 'ALL',
    bool preferMirror = false,
    void Function(double progress, String status)? onProgress,
  }) async {
    final client = http.Client();
    final allNodes = <ProxyNode>[];

    final tasks = <Map<String, dynamic>>[];
    final keys = (protocolFilter == 'ALL')
        ? remoteSources.keys.toList()
        : [protocolFilter.toLowerCase()].where((k) => remoteSources.containsKey(k)).toList();

    for (final k in keys) {
      final maxIdx = remoteSources[k]!.maxIndex;
      for (var i = 1; i <= maxIdx; i++) {
        tasks.add({'key': k, 'idx': i});
      }
    }

    var completed = 0;
    final total = tasks.length;

    // Use concurrency pool of up to 10 simultaneous tasks
    const concurrency = 10;
    final queue = List<Map<String, dynamic>>.from(tasks);
    final workers = <Future>[];

    for (var w = 0; w < concurrency; w++) {
      workers.add(() async {
        while (queue.isNotEmpty) {
          final task = queue.removeLast();
          final k = task['key'] as String;
          final idx = task['idx'] as int;

          try {
            final nodes = await fetchAndExtractProtocol(
              k,
              idx,
              preferMirror: preferMirror,
              client: client,
            );
            if (nodes.isNotEmpty) {
              synchronized(allNodes, () => allNodes.addAll(nodes));
            }
          } catch (_) {}

          completed++;
          if (onProgress != null && total > 0) {
            onProgress(completed / total, '正在拉取 $k (IP $idx)...');
          }
        }
      }());
    }

    await Future.wait(workers);
    client.close();

    return NodeParsers.deduplicateNodes(allNodes);
  }

  static void synchronized(List<ProxyNode> list, void Function() fn) {
    fn();
  }
}
