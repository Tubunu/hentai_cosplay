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
            "type": "https",
            "server": "1.1.1.1",
            "path": "/dns-query",
            "detour": "proxy"
          },
          {
            "tag": "local-dns",
            "type": "udp",
            "server": "223.5.5.5",
            "detour": "direct"
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
        },
        {
          "type": "block",
          "tag": "block"
        }
      ],
      "route": {
        "default_domain_resolver": "local-dns",
        "rules": [
          {
            "action": "sniff"
          },
          {
            "protocol": "dns",
            "action": "hijack-dns"
          },
          {
            "inbound": ["mixed-in"],
            "outbound": "proxy"
          }
        ],
        "auto_detect_interface": true,
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

  /// 将 [ProxyNode] 转换为 Sing-box 出站配置 Map
  static Map<String, dynamic> nodeToSingboxOutbound(ProxyNode node) {
    final proto = node.protocol.toLowerCase();
    final srv = node.server.trim().replaceAll('[', '').replaceAll(']', '');
    final port = node.port;

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
        final flow = node.extra['flow']?.toString();
        if (flow != null && flow.isNotEmpty) {
          outbound['flow'] = flow;
        }

        // TLS & Reality
        final isTls = node.tlsSettings['tls'] == true ||
            node.tlsSettings['security'] == 'tls' ||
            node.tlsSettings['security'] == 'reality' ||
            node.tlsSettings['sni'] != null;

        if (isTls) {
          final tls = <String, dynamic>{
            "enabled": true,
            "insecure": node.tlsSettings['insecure'] == true || node.tlsSettings['insecure'] == '1',
          };
          if (node.tlsSettings['sni'] != null && node.tlsSettings['sni'].toString().isNotEmpty) {
            tls["server_name"] = node.tlsSettings['sni'].toString();
          }
          if (node.tlsSettings['alpn'] != null) {
            final rawAlpn = node.tlsSettings['alpn'];
            if (rawAlpn is List) {
              tls["alpn"] = rawAlpn.map((e) => e.toString()).toList();
            } else if (rawAlpn is String && rawAlpn.isNotEmpty) {
              tls["alpn"] = rawAlpn.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
            }
          }
          if (node.tlsSettings['fp'] != null) {
            tls["utls"] = {
              "enabled": true,
              "fingerprint": node.tlsSettings['fp'].toString(),
            };
          }
          if (node.tlsSettings['security'] == 'reality' || node.tlsSettings['pbk'] != null) {
            tls["reality"] = {
              "enabled": true,
              "public_key": (node.tlsSettings['pbk'] ?? '').toString(),
              "short_id": (node.tlsSettings['sid'] ?? '').toString(),
            };
          }
          outbound['tls'] = tls;
        }

        // Transport
        final net = (node.transport['network'] ?? node.transport['type'] ?? 'tcp').toString().toLowerCase();
        if (net == 'ws') {
          outbound['transport'] = {
            "type": "ws",
            "path": (node.transport['path'] ?? '/').toString(),
            "headers": {
              if (node.transport['host'] != null) "Host": node.transport['host'].toString(),
            }
          };
        } else if (net == 'grpc') {
          outbound['transport'] = {
            "type": "grpc",
            "service_name": (node.transport['service_name'] ?? node.transport['path'] ?? '').toString(),
          };
        } else if (net == 'xhttp' || net == 'splithttp') {
          outbound['transport'] = {
            "type": "httpupgrade",
            "path": (node.transport['path'] ?? '/').toString(),
            "host": (node.transport['host'] ?? '').toString(),
          };
        }
        return outbound;

      case 'vmess':
        final outbound = <String, dynamic>{
          "type": "vmess",
          "tag": "proxy",
          "server": srv,
          "server_port": port,
          "uuid": (node.auth['uuid'] ?? node.auth['id'] ?? '').toString(),
          "security": (node.auth['security'] ?? 'auto').toString(),
          "alter_id": (node.auth['alterId'] is int)
              ? node.auth['alterId']
              : int.tryParse(node.auth['alterId']?.toString() ?? '0') ?? 0,
          "domain_resolver": "local-dns",
        };
        final isTls = node.tlsSettings['tls'] == true || node.tlsSettings['security'] == 'tls';
        if (isTls) {
          outbound['tls'] = {
            "enabled": true,
            "insecure": node.tlsSettings['insecure'] == true,
            if (node.tlsSettings['sni'] != null) "server_name": node.tlsSettings['sni'].toString(),
          };
        }
        final net = (node.transport['network'] ?? node.transport['type'] ?? 'tcp').toString().toLowerCase();
        if (net == 'ws') {
          outbound['transport'] = {
            "type": "ws",
            "path": (node.transport['path'] ?? '/').toString(),
            if (node.transport['host'] != null) "headers": {"Host": node.transport['host'].toString()},
          };
        } else if (net == 'grpc') {
          outbound['transport'] = {
            "type": "grpc",
            "service_name": (node.transport['service_name'] ?? node.transport['path'] ?? '').toString(),
          };
        } else if (net == 'xhttp' || net == 'splithttp') {
          outbound['transport'] = {
            "type": "httpupgrade",
            "path": (node.transport['path'] ?? '/').toString(),
            "host": (node.transport['host'] ?? '').toString(),
          };
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
          "tls": {
            "enabled": true,
            "insecure": node.tlsSettings['insecure'] == true,
            if (node.tlsSettings['sni'] != null) "server_name": node.tlsSettings['sni'].toString(),
          }
        };
        final net = (node.transport['network'] ?? node.transport['type'] ?? 'tcp').toString().toLowerCase();
        if (net == 'ws') {
          outbound['transport'] = {
            "type": "ws",
            "path": (node.transport['path'] ?? '/').toString(),
            if (node.transport['host'] != null) "headers": {"Host": node.transport['host'].toString()},
          };
        } else if (net == 'grpc') {
          outbound['transport'] = {
            "type": "grpc",
            "service_name": (node.transport['service_name'] ?? node.transport['path'] ?? '').toString(),
          };
        }
        return outbound;

      case 'ss':
      case 'shadowsocks':
        return <String, dynamic>{
          "type": "shadowsocks",
          "tag": "proxy",
          "server": srv,
          "server_port": port,
          "method": (node.auth['cipher'] ?? node.auth['method'] ?? 'aes-256-gcm').toString(),
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
          "tls": {
            "enabled": true,
            "insecure": node.tlsSettings['insecure'] == true || node.tlsSettings['insecure'] == '1',
            if (node.tlsSettings['sni'] != null) "server_name": node.tlsSettings['sni'].toString(),
          }
        };
        if (node.extra['up'] != null) {
          outbound['up_mbps'] =
              int.tryParse(node.extra['up'].toString().replaceAll(RegExp(r'\D'), '')) ?? 50;
        }
        if (node.extra['down'] != null) {
          outbound['down_mbps'] =
              int.tryParse(node.extra['down'].toString().replaceAll(RegExp(r'\D'), '')) ?? 100;
        }
        final obfs = node.extra['obfs']?.toString();
        final obfsPassword = (node.extra['obfs-password'] ?? node.extra['obfs_password'])?.toString();
        if (obfs != null && obfs.isNotEmpty && obfsPassword != null && obfsPassword.isNotEmpty) {
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
          "congestion_control": (node.extra['congestion_control'] ?? 'bbr').toString(),
          "domain_resolver": "local-dns",
          "tls": {
            "enabled": true,
            "insecure": node.tlsSettings['insecure'] == true,
            "alpn": ["h3"],
            if (node.tlsSettings['sni'] != null) "server_name": node.tlsSettings['sni'].toString(),
          }
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
