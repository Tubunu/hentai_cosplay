import 'dart:convert';
import '../../models/chromego/proxy_node.dart';

/// 动态生成 Sing-box 1.12+ / 1.13+ 规范的 JSON 配置文件
/// 为应用内回环代理提供标准配置，将指定 ProxyNode 转换为 outbound 并绑定 127.0.0.1 回环端口
class SingboxConfigGenerator {
  /// 生成完整的 Sing-box 配置 Map
  static Map<String, dynamic> generateConfigMap(
    ProxyNode node, {
    String listenAddress = '127.0.0.1',
    int listenPort = 20808,
  }) {
    final outbound = nodeToSingboxOutbound(node);

    return {
      "log": {
        "level": "warn",
        "timestamp": true,
      },
      "dns": {
        "servers": [
          {
            "tag": "remote-dns",
            "type": "udp",
            "server": "8.8.8.8",
            "detour": "proxy"
          },
          {
            "tag": "local-dns",
            "type": "udp",
            "server": "223.5.5.5"
          }
        ],
        "strategy": "prefer_ipv4"
      },
      "inbounds": [
        {
          "type": "mixed",
          "tag": "mixed-in",
          "listen": listenAddress,
          "listen_port": listenPort,
        }
      ],
      "outbounds": [
        outbound,
        {
          "type": "direct",
          "tag": "direct"
        }
      ],
      "route": {
        "default_domain_resolver": "local-dns",
        "rules": [
          {
            "inbound": ["mixed-in"],
            "outbound": "proxy"
          }
        ],
        "final": "proxy"
      }
    };
  }

  /// 生成格式化的 Sing-box JSON 字符串
  static String generateConfigJson(
    ProxyNode node, {
    String listenAddress = '127.0.0.1',
    int listenPort = 20808,
  }) {
    final map = generateConfigMap(node, listenAddress: listenAddress, listenPort: listenPort);
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  static String? _nonEmpty(dynamic value) {
    if (value == null) return null;
    final str = value.toString().trim();
    return str.isEmpty ? null : str;
  }

  static bool _isTruthy(dynamic value) {
    if (value == true || value == 1 || value == '1') return true;
    return value?.toString().trim().toLowerCase() == 'true';
  }

  static Map<String, dynamic> _buildTls(
    ProxyNode node, {
    List<String>? defaultAlpn,
    bool includeAdvanced = false,
  }) {
    final tls = <String, dynamic>{
      "enabled": true,
      "insecure": _isTruthy(node.tlsSettings['insecure']),
    };
    final sni = _nonEmpty(node.tlsSettings['sni']);
    if (sni != null) {
      tls["server_name"] = sni;
    }
    if (defaultAlpn != null && defaultAlpn.isNotEmpty) {
      tls["alpn"] = defaultAlpn;
    } else if (node.tlsSettings['alpn'] != null) {
      final rawAlpn = node.tlsSettings['alpn'];
      List<String> alpnList = const [];
      if (rawAlpn is List) {
        alpnList = rawAlpn.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      } else if (rawAlpn is String && rawAlpn.isNotEmpty) {
        alpnList = rawAlpn.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
      if (alpnList.isNotEmpty) {
        tls["alpn"] = alpnList;
      }
    }
    if (includeAdvanced) {
      final fp = _nonEmpty(node.tlsSettings['fp']);
      if (fp != null) {
        tls["utls"] = {
          "enabled": true,
          "fingerprint": fp,
        };
      }
      final pbk = _nonEmpty(node.tlsSettings['pbk']);
      if (pbk != null) {
        tls["reality"] = {
          "enabled": true,
          "public_key": pbk,
          "short_id": _nonEmpty(node.tlsSettings['sid']) ?? '',
        };
      }
    }
    return tls;
  }

  static Map<String, dynamic>? _buildTransport(
    ProxyNode node, {
    bool includeHttpUpgrade = false,
  }) {
    final net = (node.transport['network'] ?? node.transport['type'] ?? 'tcp')
        .toString()
        .toLowerCase();
    final host = _nonEmpty(node.transport['host']);
    if (net == 'ws') {
      return {
        "type": "ws",
        "path": (node.transport['path'] ?? '/').toString(),
        if (host != null) "headers": {"Host": host},
      };
    }
    if (net == 'grpc') {
      return {
        "type": "grpc",
        "service_name":
            (node.transport['service_name'] ?? node.transport['path'] ?? '').toString(),
      };
    }
    if (includeHttpUpgrade && (net == 'xhttp' || net == 'splithttp')) {
      return {
        "type": "httpupgrade",
        "path": (node.transport['path'] ?? '/').toString(),
        if (host != null) "host": host,
      };
    }
    return null;
  }

  /// 将 [ProxyNode] 转换为 Sing-box 出站配置 Map
  static Map<String, dynamic> nodeToSingboxOutbound(ProxyNode node) {
    final proto = node.protocol.toLowerCase();
    final srv = node.server.trim().replaceAll('[', '').replaceAll(']', '');
    final port = node.port;
    final sni = _nonEmpty(node.tlsSettings['sni']);

    switch (proto) {
      case 'vless':
        final outbound = <String, dynamic>{
          "type": "vless",
          "tag": "proxy",
          "server": srv,
          "server_port": port,
          "uuid": (node.auth['uuid'] ?? node.auth['id'] ?? '').toString(),
          "domain_resolver": "local-dns",
        };
        final flow = _nonEmpty(node.extra['flow']);
        if (flow != null) {
          outbound['flow'] = flow;
        }

        final pbk = _nonEmpty(node.tlsSettings['pbk']);
        final isTls = _isTruthy(node.tlsSettings['tls']) ||
            node.tlsSettings['security'] == 'tls' ||
            node.tlsSettings['security'] == 'reality' ||
            sni != null ||
            pbk != null;

        if (isTls) {
          outbound['tls'] = _buildTls(node, includeAdvanced: true);
        }

        final transport = _buildTransport(node, includeHttpUpgrade: true);
        if (transport != null) {
          outbound['transport'] = transport;
        }
        return outbound;

      case 'vmess':
        final outbound = <String, dynamic>{
          "type": "vmess",
          "tag": "proxy",
          "server": srv,
          "server_port": port,
          "uuid": (node.auth['uuid'] ?? node.auth['id'] ?? '').toString(),
          "security": _nonEmpty(node.auth['security']) ?? 'auto',
          "alter_id": (node.auth['alterId'] is int)
              ? node.auth['alterId']
              : int.tryParse(node.auth['alterId']?.toString() ?? '0') ?? 0,
          "domain_resolver": "local-dns",
        };
        final isTls = _isTruthy(node.tlsSettings['tls']) ||
            node.tlsSettings['security'] == 'tls' ||
            sni != null;
        if (isTls) {
          outbound['tls'] = _buildTls(node);
        }
        final transport = _buildTransport(node, includeHttpUpgrade: true);
        if (transport != null) {
          outbound['transport'] = transport;
        }
        return outbound;

      case 'trojan':
        final outbound = <String, dynamic>{
          "type": "trojan",
          "tag": "proxy",
          "server": srv,
          "server_port": port,
          "password": (node.auth['password'] ?? '').toString(),
          "domain_resolver": "local-dns",
          "tls": _buildTls(node),
        };
        final transport = _buildTransport(node);
        if (transport != null) {
          outbound['transport'] = transport;
        }
        return outbound;

      case 'ss':
      case 'shadowsocks':
        return <String, dynamic>{
          "type": "shadowsocks",
          "tag": "proxy",
          "server": srv,
          "server_port": port,
          "method": _nonEmpty(node.auth['cipher']) ??
              _nonEmpty(node.auth['method']) ??
              'aes-256-gcm',
          "password": (node.auth['password'] ?? '').toString(),
          "domain_resolver": "local-dns",
        };

      case 'hysteria2':
      case 'hy2':
        final outbound = <String, dynamic>{
          "type": "hysteria2",
          "tag": "proxy",
          "server": srv,
          "server_port": port,
          "password": (node.auth['password'] ?? node.auth['auth'] ?? '').toString(),
          "domain_resolver": "local-dns",
          "tls": _buildTls(node),
        };
        if (node.extra['up'] != null) {
          outbound['up_mbps'] =
              int.tryParse(node.extra['up'].toString().replaceAll(RegExp(r'\D'), '')) ?? 50;
        }
        if (node.extra['down'] != null) {
          outbound['down_mbps'] =
              int.tryParse(node.extra['down'].toString().replaceAll(RegExp(r'\D'), '')) ?? 100;
        }
        final obfs = _nonEmpty(node.extra['obfs']);
        final obfsPassword = _nonEmpty(node.extra['obfs-password'] ?? node.extra['obfs_password']);
        if (obfs != null && obfsPassword != null) {
          outbound['obfs'] = {
            "type": obfs,
            "password": obfsPassword,
          };
        }
        return outbound;

      case 'tuic':
        return <String, dynamic>{
          "type": "tuic",
          "tag": "proxy",
          "server": srv,
          "server_port": port,
          "uuid": (node.auth['uuid'] ?? '').toString(),
          "password": (node.auth['password'] ?? '').toString(),
          "congestion_control": _nonEmpty(node.extra['congestion_control']) ?? 'bbr',
          "domain_resolver": "local-dns",
          "tls": _buildTls(node, defaultAlpn: const ["h3"]),
        };

      default:
        return <String, dynamic>{
          "type": proto,
          "tag": "proxy",
          "server": srv,
          "server_port": port,
          "domain_resolver": "local-dns",
        };
    }
  }
}
