import 'dart:async';
import 'dart:io';
import '../../models/chromego/proxy_node.dart';

/// Service for testing node TCP reachability and latency.
class NodePingService {
  /// Pings a single node via TCP connect. Returns latency in milliseconds, or -1 if unreachable.
  static Future<int> pingNode(ProxyNode node, {Duration timeout = const Duration(milliseconds: 2500)}) async {
    final server = node.server.replaceAll('[', '').replaceAll(']', '');
    final port = node.port;

    final stopwatch = Stopwatch()..start();
    try {
      final socket = await Socket.connect(server, port, timeout: timeout);
      stopwatch.stop();
      socket.destroy();
      return stopwatch.elapsedMilliseconds;
    } catch (_) {
      stopwatch.stop();
      return -1;
    }
  }

  /// Pings multiple nodes concurrently with progress callback.
  static Future<void> pingAllNodes(
    List<ProxyNode> nodes, {
    int concurrency = 10,
    Duration timeout = const Duration(milliseconds: 2500),
    void Function(ProxyNode node, int latency)? onNodePinged,
  }) async {
    final queue = List<ProxyNode>.from(nodes);
    final futures = <Future>[];

    for (var i = 0; i < concurrency; i++) {
      futures.add(() async {
        while (queue.isNotEmpty) {
          final node = queue.removeLast();
          final latency = await pingNode(node, timeout: timeout);
          node.pingMs = latency;
          if (onNodePinged != null) {
            onNodePinged(node, latency);
          }
        }
      }());
    }

    await Future.wait(futures);
  }
}
