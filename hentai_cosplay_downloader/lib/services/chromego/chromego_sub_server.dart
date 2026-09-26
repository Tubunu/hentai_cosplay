import 'dart:io';
import '../../models/chromego/proxy_node.dart';
import 'chromego_exporter.dart';

/// Lightweight LAN HTTP subscription server for Shadowrocket, Clash, and mobile clients.
class LocalSubServer {
  final int port;
  final List<ProxyNode> Function() getNodes;
  HttpServer? _server;
  bool _isRunning = false;
  int _actualPort = 7899;

  LocalSubServer({this.port = 7899, required this.getNodes});

  bool get isRunning => _isRunning;
  int get actualPort => _actualPort;

  /// Starts the HTTP server on 0.0.0.0.
  Future<bool> start() async {
    if (_isRunning) return true;

    for (var p = port; p < port + 10; p++) {
      try {
        _server = await HttpServer.bind(InternetAddress.anyIPv4, p);
        _actualPort = p;
        _isRunning = true;
        _server!.listen(_handleRequest);
        return true;
      } catch (_) {
        // Port in use, try next
      }
    }
    return false;
  }

  /// Stops the HTTP server.
  Future<void> stop() async {
    if (!_isRunning) return;
    await _server?.close(force: true);
    _server = null;
    _isRunning = false;
  }

  void _handleRequest(HttpRequest request) {
    final path = request.uri.path;
    final nodes = getNodes();

    request.response.headers.set('Access-Control-Allow-Origin', '*');
    request.response.headers.set('Subscription-Userinfo', 'upload=0; download=0; total=107374182400; expire=0');

    if (path == '/clash' || path == '/meta') {
      final yaml = NodeExporter.generateFullClashConfig(nodes);
      request.response.headers.contentType = ContentType('text', 'yaml', charset: 'utf-8');
      request.response.write(yaml);
    } else if (path == '/plain' || path == '/v2ray') {
      final plain = NodeExporter.generatePlainShareLinks(nodes);
      request.response.headers.contentType = ContentType('text', 'plain', charset: 'utf-8');
      request.response.write(plain);
    } else {
      // Default: Base64 subscription
      final b64 = NodeExporter.generateSubscriptionBase64(nodes);
      request.response.headers.contentType = ContentType('text', 'plain', charset: 'utf-8');
      request.response.write(b64);
    }

    request.response.close();
  }

  /// Finds primary LAN IPv4 address.
  static Future<String> getLanIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
            final ip = addr.address;
            if (ip.startsWith('192.168.') || ip.startsWith('10.') || ip.startsWith('172.')) {
              return ip;
            }
          }
        }
      }
    } catch (_) {}
    return '127.0.0.1';
  }
}
