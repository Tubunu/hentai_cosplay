import 'dart:convert';
import 'package:yaml/yaml.dart';
import '../../models/chromego/proxy_node.dart';

/// Parsers for ChromeGo configuration formats.
class NodeParsers {
  /// Parses Clash.Meta YAML content.
  static List<ProxyNode> parseClashYaml(String content, {String sourceTag = 'Clash.Meta'}) {
    final nodes = <ProxyNode>[];
    try {
      final doc = loadYaml(content);
      if (doc is! YamlMap && doc is! Map) return nodes;
      final proxies = doc['proxies'];
      if (proxies is! YamlList && proxies is! List) return nodes;

      for (var i = 0; i < (proxies as Iterable).length; i++) {
        final p = proxies.elementAt(i);
        if (p is! Map && p is! YamlMap) continue;

        final name = (p['name'] ?? 'Clash-Node-${i + 1}').toString().trim();
        final pType = (p['type'] ?? '').toString().toLowerCase();
        final server = (p['server'] ?? '').toString().trim();
        final port = (p['port'] is int) ? p['port'] as int : int.tryParse(p['port']?.toString() ?? '0') ?? 0;

        if (server.isEmpty || port <= 0) continue;

        final auth = <String, dynamic>{};
        final tlsSettings = <String, dynamic>{};
        final transport = <String, dynamic>{};
        final extra = <String, dynamic>{};

        if (pType == 'hysteria2') {
          auth['password'] = p['password'] ?? '';
          tlsSettings['sni'] = p['sni'] ?? '';
          tlsSettings['insecure'] = p['skip-cert-verify'] ?? false;
          extra['up'] = p['up'] ?? '20 Mbps';
          extra['down'] = p['down'] ?? '50 Mbps';
        } else if (pType == 'hysteria') {
          auth['auth_str'] = p['auth_str'] ?? p['auth-str'] ?? '';
          tlsSettings['sni'] = p['sni'] ?? '';
          tlsSettings['insecure'] = p['skip-cert-verify'] ?? false;
          tlsSettings['alpn'] = p['alpn'] ?? ['h3'];
          extra['up'] = p['up'] ?? '20 Mbps';
          extra['down'] = p['down'] ?? '50 Mbps';
        } else if (pType == 'vless') {
          auth['uuid'] = p['uuid'] ?? '';
          transport['network'] = p['network'] ?? 'tcp';
          tlsSettings['sni'] = p['servername'] ?? p['sni'] ?? '';
          tlsSettings['fp'] = p['client-fingerprint'] ?? '';
          final realityOpts = p['reality-opts'];
          if (realityOpts is Map || realityOpts is YamlMap) {
            tlsSettings['security'] = 'reality';
            tlsSettings['pbk'] = realityOpts['public-key'] ?? '';
            tlsSettings['sid'] = realityOpts['short-id'] ?? '';
          }
          final xhttpOpts = p['xhttp-opts'];
          if (xhttpOpts is Map || xhttpOpts is YamlMap) {
            transport['path'] = xhttpOpts['path'] ?? '/';
            transport['mode'] = xhttpOpts['mode'] ?? 'auto';
          }
        } else if (pType == 'tuic') {
          auth['uuid'] = p['uuid'] ?? '';
          auth['password'] = p['password'] ?? '';
          tlsSettings['sni'] = p['sni'] ?? '';
          tlsSettings['insecure'] = p['skip-cert-verify'] ?? false;
          tlsSettings['alpn'] = p['alpn'] ?? ['h3'];
          extra['congestion_control'] = p['congestion-controller'] ?? 'bbr';
        } else if (pType == 'vmess') {
          auth['uuid'] = p['uuid'] ?? '';
          auth['alterId'] = p['alterId'] ?? 0;
          transport['network'] = p['network'] ?? 'tcp';
        } else if (pType == 'trojan') {
          auth['password'] = p['password'] ?? '';
          tlsSettings['sni'] = p['sni'] ?? '';
          tlsSettings['insecure'] = p['skip-cert-verify'] ?? false;
        } else if (pType == 'ss' || pType == 'shadowsocks') {
          auth['method'] = p['cipher'] ?? 'aes-256-gcm';
          auth['password'] = p['password'] ?? '';
        } else if (pType == 'http') {
          auth['user'] = p['username'] ?? '';
          auth['password'] = p['password'] ?? '';
        }

        nodes.add(ProxyNode(
          name: name,
          protocol: pType == 'http' ? 'naiveproxy' : pType,
          server: server,
          port: port,
          sourceTag: sourceTag,
          auth: auth,
          tlsSettings: tlsSettings,
          transport: transport,
          extra: extra,
          rawConfig: Map<String, dynamic>.from(p),
        ));
      }
    } catch (e) {
      // Ignored parse exception
    }
    return nodes;
  }

  /// Parses Xray config.json.
  static List<ProxyNode> parseXrayJson(String content, {String sourceTag = 'Xray'}) {
    final nodes = <ProxyNode>[];
    try {
      final data = jsonDecode(content);
      if (data is! Map) return nodes;
      final outbounds = data['outbounds'];
      if (outbounds is! List) return nodes;

      for (final ob in outbounds) {
        if (ob is! Map) continue;
        final proto = (ob['protocol'] ?? '').toString().toLowerCase();
        if (!['vless', 'vmess', 'trojan', 'shadowsocks'].contains(proto)) continue;

        final settings = ob['settings'] as Map? ?? {};
        final stream = ob['streamSettings'] as Map? ?? {};
        final network = (stream['network'] ?? 'tcp').toString();
        final security = (stream['security'] ?? 'none').toString();

        final tlsSettings = <String, dynamic>{'security': security};
        if (security == 'reality') {
          final rSet = stream['realitySettings'] as Map? ?? {};
          tlsSettings['sni'] = rSet['serverName'] ?? '';
          tlsSettings['fp'] = rSet['fingerprint'] ?? 'chrome';
          tlsSettings['pbk'] = rSet['publicKey'] ?? '';
          tlsSettings['sid'] = rSet['shortId'] ?? '';
        } else if (security == 'tls') {
          final tSet = stream['tlsSettings'] as Map? ?? {};
          tlsSettings['sni'] = tSet['serverName'] ?? '';
          tlsSettings['alpn'] = tSet['alpn'] ?? [];
          tlsSettings['insecure'] = tSet['allowInsecure'] ?? false;
        }

        final transport = <String, dynamic>{'network': network, 'type': network};
        if (network == 'xhttp' || network == 'splithttp') {
          final xSet = (stream['xhttpSettings'] ?? stream['splithttpSettings']) as Map? ?? {};
          transport['path'] = xSet['path'] ?? '/';
          transport['mode'] = xSet['mode'] ?? 'auto';
        } else if (network == 'ws') {
          final wSet = stream['wsSettings'] as Map? ?? {};
          transport['path'] = wSet['path'] ?? '/';
          final headers = wSet['headers'] as Map? ?? {};
          if (headers.containsKey('Host')) transport['host'] = headers['Host'];
        }

        final vnext = settings['vnext'] as List? ?? [];
        for (final target in vnext) {
          if (target is! Map) continue;
          final server = (target['address'] ?? '').toString();
          final port = (target['port'] is int) ? target['port'] as int : int.tryParse(target['port']?.toString() ?? '0') ?? 0;
          final users = target['users'] as List? ?? [];
          for (final u in users) {
            if (u is! Map) continue;
            final uuidVal = (u['id'] ?? '').toString();
            final auth = {
              'uuid': uuidVal,
              'encryption': 'none',
              'flow': (u['flow'] ?? '').toString(),
            };
            final shortServer = server.length > 15 ? server.substring(0, 15) : server;
            final nodeName = '$sourceTag-VLESS-$shortServer';
            nodes.add(ProxyNode(
              name: nodeName,
              protocol: 'vless',
              server: server,
              port: port,
              sourceTag: sourceTag,
              auth: auth,
              tlsSettings: tlsSettings,
              transport: transport,
              rawConfig: Map<String, dynamic>.from(ob),
            ));
          }
        }
      }
    } catch (_) {}
    return nodes;
  }

  /// Parses Hysteria2 config.json.
  static List<ProxyNode> parseHysteria2Json(String content, {String sourceTag = 'Hysteria2'}) {
    final nodes = <ProxyNode>[];
    try {
      final data = jsonDecode(content);
      if (data is! Map) return nodes;
      final serverStr = (data['server'] ?? '').toString();
      if (serverStr.isEmpty) return nodes;

      String server;
      int port;
      if (serverStr.contains(']:')) {
        final lastIdx = serverStr.lastIndexOf(':');
        server = serverStr.substring(0, lastIdx);
        port = int.tryParse(serverStr.substring(lastIdx + 1)) ?? 443;
      } else if (serverStr.contains(':') && !serverStr.contains('[')) {
        final parts = serverStr.split(':');
        server = parts[0];
        port = int.tryParse(parts[1]) ?? 443;
      } else {
        server = serverStr;
        port = 443;
      }

      final authVal = (data['auth'] ?? '').toString();
      final tlsData = data['tls'] as Map? ?? {};
      final bwData = data['bandwidth'] as Map? ?? {};

      final cleanSrv = server.replaceAll('[', '').replaceAll(']', '');
      final shortSrv = cleanSrv.length > 15 ? cleanSrv.substring(0, 15) : cleanSrv;

      nodes.add(ProxyNode(
        name: '$sourceTag-$shortSrv',
        protocol: 'hysteria2',
        server: server,
        port: port,
        sourceTag: sourceTag,
        auth: {'password': authVal, 'auth': authVal},
        tlsSettings: {
          'sni': tlsData['sni'] ?? cleanSrv,
          'insecure': tlsData['insecure'] ?? false,
        },
        extra: {
          'up': bwData['up'] ?? '20 Mbps',
          'down': bwData['down'] ?? '50 Mbps',
        },
        rawConfig: Map<String, dynamic>.from(data),
      ));
    } catch (_) {}
    return nodes;
  }

  /// Parses Sing-box config.json.
  static List<ProxyNode> parseSingboxJson(String content, {String sourceTag = 'Sing-box'}) {
    final nodes = <ProxyNode>[];
    try {
      final data = jsonDecode(content);
      if (data is! Map) return nodes;
      final outbounds = data['outbounds'] as List? ?? [];

      for (final ob in outbounds) {
        if (ob is! Map) continue;
        var proto = (ob['type'] ?? '').toString().toLowerCase();
        if (['direct', 'block', 'dns'].contains(proto)) continue;

        final server = (ob['server'] ?? '').toString();
        final port = (ob['server_port'] is int) ? ob['server_port'] as int : int.tryParse(ob['server_port']?.toString() ?? '0') ?? 0;
        if (server.isEmpty || port <= 0) continue;

        final tls = ob['tls'] as Map? ?? {};
        final tlsSettings = {
          'sni': tls['server_name'] ?? '',
          'insecure': tls['insecure'] ?? false,
          'alpn': tls['alpn'] ?? ['h3'],
        };

        final auth = <String, dynamic>{};
        final extra = <String, dynamic>{};

        if (proto == 'tuic') {
          auth['uuid'] = ob['uuid'] ?? '';
          auth['password'] = ob['password'] ?? '';
          extra['congestion_control'] = ob['congestion_control'] ?? 'bbr';
        } else if (proto == 'hysteria' || proto == 'hy1') {
          proto = 'hysteria';
          auth['auth_str'] = ob['auth_str'] ?? '';
          extra['up'] = '${ob['up_mbps'] ?? 20} Mbps';
          extra['down'] = '${ob['down_mbps'] ?? 50} Mbps';
        } else if (proto == 'hysteria2' || proto == 'hy2') {
          proto = 'hysteria2';
          auth['password'] = ob['password'] ?? ob['auth'] ?? '';
        } else if (proto == 'vless') {
          auth['uuid'] = ob['uuid'] ?? '';
        }

        final cleanSrv = server.replaceAll('[', '').replaceAll(']', '');
        final shortSrv = cleanSrv.length > 15 ? cleanSrv.substring(0, 15) : cleanSrv;

        nodes.add(ProxyNode(
          name: '$sourceTag-${proto.toUpperCase()}-$shortSrv',
          protocol: proto,
          server: server,
          port: port,
          sourceTag: sourceTag,
          auth: auth,
          tlsSettings: tlsSettings,
          extra: extra,
          rawConfig: Map<String, dynamic>.from(ob),
        ));
      }
    } catch (_) {}
    return nodes;
  }

  /// Parses Hysteria1 config.json.
  static List<ProxyNode> parseHysteria1Json(String content, {String sourceTag = 'Hysteria1'}) {
    final nodes = <ProxyNode>[];
    try {
      final data = jsonDecode(content);
      if (data is! Map) return nodes;
      final serverStr = (data['server'] ?? '').toString();
      if (serverStr.isEmpty) return nodes;

      String server;
      int port;
      if (serverStr.contains(':')) {
        final lastIdx = serverStr.lastIndexOf(':');
        server = serverStr.substring(0, lastIdx);
        port = int.tryParse(serverStr.substring(lastIdx + 1)) ?? 443;
      } else {
        server = serverStr;
        port = 443;
      }

      final authVal = (data['auth_str'] ?? data['auth'] ?? '').toString();
      final sni = (data['server_name'] ?? data['sni'] ?? server).toString();
      final insecure = data['insecure'] ?? false;
      final alpn = data['alpn'] ?? 'h3';

      final cleanSrv = server.replaceAll('[', '').replaceAll(']', '');
      final shortSrv = cleanSrv.length > 15 ? cleanSrv.substring(0, 15) : cleanSrv;

      nodes.add(ProxyNode(
        name: '$sourceTag-$shortSrv',
        protocol: 'hysteria',
        server: server,
        port: port,
        sourceTag: sourceTag,
        auth: {'auth_str': authVal},
        tlsSettings: {
          'sni': sni,
          'insecure': insecure,
          'alpn': (alpn is List) ? alpn : [alpn.toString()],
        },
        extra: {
          'up': '${data['up_mbps'] ?? 20} Mbps',
          'down': '${data['down_mbps'] ?? 50} Mbps',
        },
        rawConfig: Map<String, dynamic>.from(data),
      ));
    } catch (_) {}
    return nodes;
  }

  /// Parses Juicity config.json.
  static List<ProxyNode> parseJuicityJson(String content, {String sourceTag = 'Juicity'}) {
    final nodes = <ProxyNode>[];
    try {
      final data = jsonDecode(content);
      if (data is! Map) return nodes;
      final serverStr = (data['server'] ?? '').toString();
      if (serverStr.isEmpty) return nodes;

      String server;
      int port;
      if (serverStr.contains(':')) {
        final lastIdx = serverStr.lastIndexOf(':');
        server = serverStr.substring(0, lastIdx);
        port = int.tryParse(serverStr.substring(lastIdx + 1)) ?? 443;
      } else {
        server = serverStr;
        port = 443;
      }

      final shortSrv = server.length > 15 ? server.substring(0, 15) : server;

      nodes.add(ProxyNode(
        name: '$sourceTag-$shortSrv',
        protocol: 'juicity',
        server: server,
        port: port,
        sourceTag: sourceTag,
        auth: {
          'uuid': (data['uuid'] ?? '').toString(),
          'password': (data['password'] ?? '').toString(),
        },
        tlsSettings: {
          'sni': (data['sni'] ?? server).toString(),
          'insecure': data['allow_insecure'] ?? false,
        },
        extra: {
          'congestion_control': (data['congestion_control'] ?? 'bbr').toString(),
        },
        rawConfig: Map<String, dynamic>.from(data),
      ));
    } catch (_) {}
    return nodes;
  }

  /// Parses NaiveProxy config.json.
  static List<ProxyNode> parseNaiveproxyJson(String content, {String sourceTag = 'NaiveProxy'}) {
    final nodes = <ProxyNode>[];
    try {
      final data = jsonDecode(content);
      if (data is! Map) return nodes;
      final proxyUrl = (data['proxy'] ?? '').toString();
      if (proxyUrl.isEmpty) return nodes;

      final uri = Uri.parse(proxyUrl);
      final server = uri.host;
      final port = uri.port != 0 ? uri.port : (uri.scheme == 'https' ? 443 : 80);
      final userInfo = uri.userInfo;
      String user = '';
      String password = '';
      if (userInfo.contains(':')) {
        final parts = userInfo.split(':');
        user = parts[0];
        password = parts[1];
      } else {
        user = userInfo;
      }

      final shortSrv = server.length > 15 ? server.substring(0, 15) : server;

      nodes.add(ProxyNode(
        name: '$sourceTag-$shortSrv',
        protocol: 'naiveproxy',
        server: server,
        port: port,
        sourceTag: sourceTag,
        auth: {'user': user, 'password': password},
        tlsSettings: {'sni': server},
        rawConfig: Map<String, dynamic>.from(data),
      ));
    } catch (_) {}
    return nodes;
  }

  /// Parses ShadowQUIC YAML content.
  static List<ProxyNode> parseShadowquicYaml(String content, {String sourceTag = 'ShadowQUIC'}) {
    final nodes = <ProxyNode>[];
    try {
      final doc = loadYaml(content);
      if (doc is! Map && doc is! YamlMap) return nodes;
      final outbound = doc['outbound'];
      if (outbound is! Map && outbound is! YamlMap) return nodes;

      final addr = (outbound['addr'] ?? '').toString();
      String server;
      int port;
      if (addr.contains(':')) {
        final lastIdx = addr.lastIndexOf(':');
        server = addr.substring(0, lastIdx);
        port = int.tryParse(addr.substring(lastIdx + 1)) ?? 443;
      } else {
        server = addr;
        port = 443;
      }

      final user = (outbound['username'] ?? '').toString();
      final password = (outbound['password'] ?? '').toString();
      final sni = (outbound['server-name'] ?? server).toString();
      final shortSrv = server.length > 15 ? server.substring(0, 15) : server;

      nodes.add(ProxyNode(
        name: '$sourceTag-$shortSrv',
        protocol: 'shadowquic',
        server: server,
        port: port,
        sourceTag: sourceTag,
        auth: {'user': user, 'password': password},
        tlsSettings: {'sni': sni},
        rawConfig: Map<String, dynamic>.from(outbound),
      ));
    } catch (_) {}
    return nodes;
  }

  /// Deduplicates nodes by (protocol, server, port) and merges source tags.
  static (List<ProxyNode>, Map<String, int>) deduplicateNodes(List<ProxyNode> nodeList) {
    final seen = <String, ProxyNode>{};
    final rawTotal = nodeList.length;

    for (final node in nodeList) {
      final fp = '${node.protocol.toLowerCase()}://${node.server.toLowerCase().replaceAll('[', '').replaceAll(']', '')}:${node.port}';
      if (seen.containsKey(fp)) {
        final existing = seen[fp]!;
        if (node.sourceTag.isNotEmpty && !existing.sourceTag.contains(node.sourceTag)) {
          existing.sourceTag = '${existing.sourceTag}, ${node.sourceTag}';
        }
      } else {
        seen[fp] = node;
      }
    }

    final uniqueNodes = seen.values.toList();
    final stats = {
      'raw_total': rawTotal,
      'unique_total': uniqueNodes.length,
      'dedup_count': rawTotal - uniqueNodes.length,
    };
    return (uniqueNodes, stats);
  }
}
