import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import '../../models/chromego/proxy_node.dart';

/// Service for generating share links, subscriptions, Clash configs, and client import schemes.
class NodeExporter {
  /// Generates a Base64 payload containing all links supported by the target client.
  static String generateBatchQrPayload(List<ProxyNode> nodes, String client, {bool compact = true}) {
    final validNodes = nodes.where((n) => n.isSupportedBy(client)).toList();
    final links = validNodes.map((n) => n.toShareLink(targetClient: client, compact: compact)).toList();
    final joined = links.join('\n');
    return base64Encode(utf8.encode(joined));
  }

  /// Generates standard Base64 subscription string.
  static String generateSubscriptionBase64(List<ProxyNode> nodes, {String client = 'all'}) {
    final validNodes = nodes.where((n) => n.isSupportedBy(client)).toList();
    final links = validNodes.map((n) => n.toShareLink(targetClient: client)).toList();
    final rawStr = links.join('\n');
    return base64Encode(utf8.encode(rawStr));
  }

  /// Generates newline-separated plain share links.
  static String generatePlainShareLinks(List<ProxyNode> nodes, {String client = 'all', bool compact = false}) {
    final validNodes = nodes.where((n) => n.isSupportedBy(client)).toList();
    return validNodes.map((n) => n.toShareLink(targetClient: client, compact: compact)).join('\n');
  }

  /// Generates complete Clash.Meta configuration YAML string.
  static String generateFullClashConfig(List<ProxyNode> nodes) {
    final clashProxies = <Map<String, dynamic>>[];
    final proxyNames = <String>[];

    for (final node in nodes) {
      clashProxies.add(node.toClashDict());
      proxyNames.add(node.name);
    }

    final effectiveProxyNames = proxyNames.isNotEmpty ? proxyNames : ['DIRECT'];

    final sb = StringBuffer();
    sb.writeln('port: 7890');
    sb.writeln('socks-port: 7891');
    sb.writeln('mixed-port: 7892');
    sb.writeln('allow-lan: false');
    sb.writeln('mode: rule');
    sb.writeln('log-level: info');
    sb.writeln('dns:');
    sb.writeln('  enable: true');
    sb.writeln('  nameserver:');
    sb.writeln('    - 223.5.5.5');
    sb.writeln('    - 119.29.29.29');
    sb.writeln('    - 8.8.8.8');
    sb.writeln('proxies:');

    for (final p in clashProxies) {
      sb.writeln('  - name: "${_escapeYaml(p['name']?.toString() ?? '')}"');
      sb.writeln('    type: ${p['type']}');
      sb.writeln('    server: "${p['server']}"');
      sb.writeln('    port: ${p['port']}');
      if (p.containsKey('password')) sb.writeln('    password: "${_escapeYaml(p['password']?.toString() ?? '')}"');
      if (p.containsKey('uuid')) sb.writeln('    uuid: "${p['uuid']}"');
      if (p.containsKey('username')) sb.writeln('    username: "${_escapeYaml(p['username']?.toString() ?? '')}"');
      if (p.containsKey('cipher')) sb.writeln('    cipher: ${p['cipher']}');
      if (p.containsKey('alterId')) sb.writeln('    alterId: ${p['alterId']}');
      if (p.containsKey('network')) sb.writeln('    network: ${p['network']}');
      if (p.containsKey('tls')) sb.writeln('    tls: ${p['tls']}');
      if (p.containsKey('udp')) sb.writeln('    udp: ${p['udp']}');
      if (p.containsKey('sni')) sb.writeln('    sni: "${p['sni']}"');
      if (p.containsKey('servername')) sb.writeln('    servername: "${p['servername']}"');
      if (p.containsKey('client-fingerprint')) sb.writeln('    client-fingerprint: ${p['client-fingerprint']}');
      if (p.containsKey('skip-cert-verify')) sb.writeln('    skip-cert-verify: ${p['skip-cert-verify']}');
      if (p.containsKey('up')) sb.writeln('    up: "${p['up']}"');
      if (p.containsKey('down')) sb.writeln('    down: "${p['down']}"');
      if (p.containsKey('auth_str')) sb.writeln('    auth_str: "${p['auth_str']}"');
      if (p.containsKey('congestion-controller')) sb.writeln('    congestion-controller: ${p['congestion-controller']}');
      if (p.containsKey('reality-opts')) {
        final r = p['reality-opts'] as Map;
        sb.writeln('    reality-opts:');
        sb.writeln('      public-key: "${r['public-key']}"');
        sb.writeln('      short-id: "${r['short-id']}"');
      }
      if (p.containsKey('xhttp-opts')) {
        final x = p['xhttp-opts'] as Map;
        sb.writeln('    xhttp-opts:');
        sb.writeln('      path: "${x['path']}"');
        sb.writeln('      mode: "${x['mode']}"');
      }
      if (p.containsKey('ws-opts')) {
        final w = p['ws-opts'] as Map;
        sb.writeln('    ws-opts:');
        sb.writeln('      path: "${w['path']}"');
        if (w.containsKey('headers') && (w['headers'] as Map).containsKey('Host')) {
          sb.writeln('      headers:');
          sb.writeln('        Host: "${w['headers']['Host']}"');
        }
      }
    }

    sb.writeln('proxy-groups:');
    sb.writeln('  - name: "🚀 节点选择"');
    sb.writeln('    type: select');
    sb.writeln('    proxies:');
    sb.writeln('      - "♻️ 自动选择"');
    for (final name in effectiveProxyNames) {
      sb.writeln('      - "${_escapeYaml(name)}"');
    }
    sb.writeln('      - DIRECT');

    sb.writeln('  - name: "♻️ 自动选择"');
    sb.writeln('    type: url-test');
    sb.writeln('    url: http://www.gstatic.com/generate_204');
    sb.writeln('    interval: 300');
    sb.writeln('    tolerance: 50');
    sb.writeln('    proxies:');
    for (final name in effectiveProxyNames) {
      sb.writeln('      - "${_escapeYaml(name)}"');
    }

    sb.writeln('  - name: "🐟 漏网之鱼"');
    sb.writeln('    type: select');
    sb.writeln('    proxies:');
    sb.writeln('      - "🚀 节点选择"');
    sb.writeln('      - "♻️ 自动选择"');
    sb.writeln('      - DIRECT');

    sb.writeln('rules:');
    sb.writeln('  - GEOIP,CN,DIRECT');
    sb.writeln('  - MATCH,🚀 节点选择');

    return sb.toString();
  }

  static String _escapeYaml(String s) {
    return s.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
  }

  /// Attempts to launch an installed Android/iOS client via its URL scheme.
  static Future<bool> launchClientScheme(String schemeUrl) async {
    final uri = Uri.parse(schemeUrl);
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
    return false;
  }
}
