import 'package:flutter_test/flutter_test.dart';
import 'package:hentai_cosplay_downloader/models/chromego/proxy_node.dart';
import 'package:hentai_cosplay_downloader/services/chromego/chromego_parsers.dart';
import 'package:hentai_cosplay_downloader/services/chromego/chromego_exporter.dart';

void main() {
  group('ChromeGo Tests', () {
    test('ProxyNode cleanName and toShareLink for hy2', () {
      final node = ProxyNode(
        name: 'Test Node 01',
        protocol: 'hysteria2',
        server: '1.2.3.4',
        port: 443,
        auth: {'password': 'secret_password'},
        tlsSettings: {'sni': 'hy2.example.com', 'insecure': true},
      );

      expect(node.cleanName(), 'Test-Node-01');
      final link = node.toShareLink();
      expect(link.startsWith('hy2://secret_password@1.2.3.4:443?'), isTrue);
      expect(link.contains('sni=hy2.example.com'), isTrue);
      expect(link.contains('insecure=1'), isTrue);
      expect(link.endsWith('#Test-Node-01'), isTrue);
    });

    test('NodeParsers.parseClashYaml parses valid YAML proxies', () {
      const clashYaml = '''
proxies:
  - name: "Hysteria2 Node"
    type: hysteria2
    server: 1.2.3.4
    port: 8443
    password: mypass
    sni: example.com
    skip-cert-verify: true
  - name: "VLESS Node"
    type: vless
    server: 5.6.7.8
    port: 443
    uuid: 12345678-1234-1234-1234-123456789abc
    network: ws
''';

      final nodes = NodeParsers.parseClashYaml(clashYaml, sourceTag: 'Clash Test');
      expect(nodes.length, 2);
      expect(nodes[0].protocol, 'hysteria2');
      expect(nodes[0].server, '1.2.3.4');
      expect(nodes[0].port, 8443);
      expect(nodes[0].auth['password'], 'mypass');

      expect(nodes[1].protocol, 'vless');
      expect(nodes[1].server, '5.6.7.8');
      expect(nodes[1].port, 443);
    });

    test('NodeParsers.parseHysteria2Json parses valid JSON', () {
      const hy2Json = '''
{
  "server": "198.51.100.1:443",
  "auth": "pass123",
  "tls": {
    "sni": "my-sni.com",
    "insecure": true
  },
  "bandwidth": {
    "up": "30 Mbps",
    "down": "100 Mbps"
  }
}
''';

      final nodes = NodeParsers.parseHysteria2Json(hy2Json, sourceTag: 'Hy2 Test');
      expect(nodes.length, 1);
      expect(nodes[0].protocol, 'hysteria2');
      expect(nodes[0].server, '198.51.100.1');
      expect(nodes[0].port, 443);
      expect(nodes[0].auth['password'], 'pass123');
      expect(nodes[0].tlsSettings['sni'], 'my-sni.com');
    });

    test('NodeParsers.deduplicateNodes filters duplicate protocol+server+port', () {
      final node1 = ProxyNode(name: 'N1', protocol: 'vless', server: '1.1.1.1', port: 443, sourceTag: 'Tag1');
      final node2 = ProxyNode(name: 'N2', protocol: 'vless', server: '1.1.1.1', port: 443, sourceTag: 'Tag2');
      final node3 = ProxyNode(name: 'N3', protocol: 'hysteria2', server: '1.1.1.1', port: 443, sourceTag: 'Tag3');

      final (uniqueNodes, stats) = NodeParsers.deduplicateNodes([node1, node2, node3]);
      expect(uniqueNodes.length, 2);
      expect(stats['dedup_count'], 1);
      expect(uniqueNodes.firstWhere((n) => n.protocol == 'vless').sourceTag.contains('Tag1'), isTrue);
      expect(uniqueNodes.firstWhere((n) => n.protocol == 'vless').sourceTag.contains('Tag2'), isTrue);
    });

    test('NodeExporter generates Clash config and Base64 subscription', () {
      final node = ProxyNode(
        name: 'Test Node',
        protocol: 'hysteria2',
        server: '1.2.3.4',
        port: 443,
        auth: {'password': 'abc'},
      );

      final clashConfig = NodeExporter.generateFullClashConfig([node]);
      expect(clashConfig.contains('type: hysteria2'), isTrue);
      expect(clashConfig.contains('server: "1.2.3.4"'), isTrue);
      expect(clashConfig.contains('port: 443'), isTrue);

      final b64Sub = NodeExporter.generateSubscriptionBase64([node]);
      expect(b64Sub.isNotEmpty, isTrue);
    });
  });
}
