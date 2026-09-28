import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hentai_cosplay_downloader/models/app_config.dart';
import 'package:hentai_cosplay_downloader/models/chromego/proxy_node.dart';
import 'package:hentai_cosplay_downloader/services/chromego/singbox_config_generator.dart';
import 'package:hentai_cosplay_downloader/services/proxy/proxy_router.dart';
import 'package:hentai_cosplay_downloader/services/proxy/site_registry.dart';

void main() {
  group('SiteRegistry Tests', () {
    test('contains expected sites and default policies', () {
      final sites = SiteRegistry.allSites;
      expect(sites.length, greaterThanOrEqualTo(35));

      final ph = SiteRegistry.getSite('pornhub');
      expect(ph, isNotNull);
      expect(ph!.defaultProxy, isTrue);

      final mzt = SiteRegistry.getSite('mzt');
      expect(mzt, isNotNull);
      expect(mzt!.defaultProxy, isFalse);

      final hc = SiteRegistry.getSite('hc_gallery');
      expect(hc, isNotNull);
      expect(hc!.defaultProxy, isFalse);
    });

    test('matchesHost matches domain names, wildcards, and strips ports/brackets', () {
      expect(SiteRegistry.matchSite('www.pornhub.com')?.key, equals('pornhub'));
      expect(SiteRegistry.matchSite('www.pornhub.com:443')?.key, equals('pornhub'));
      expect(SiteRegistry.matchSite('ci.phncdn.com')?.key, equals('pornhub'));
      expect(SiteRegistry.matchSite('jable.tv')?.key, equals('jable'));
      expect(SiteRegistry.matchSite('assets-cdn.jable.tv')?.key, equals('jable'));
      expect(SiteRegistry.matchSite('hanime1.me')?.key, equals('hanime1'));
      expect(SiteRegistry.matchSite('v.iwara.tv')?.key, equals('iwara'));
      expect(SiteRegistry.matchSite('www.mzitu.com')?.key, equals('mzt'));
      expect(SiteRegistry.matchSite('hentai-cosplays.com')?.key, equals('hc_gallery'));
      expect(SiteRegistry.matchSite('unknown-site-12345.xyz'), isNull);
    });
  });

  group('ProxyRouter Routing Tests', () {
    setUp(() {
      ProxyRouter.bypassCoreRunningCheckForTest = true;
    });

    tearDown(() {
      ProxyRouter.bypassCoreRunningCheckForTest = false;
    });

    test('Direct Mode returns DIRECT for all hosts', () {
      final config = AppConfig(
        proxyMode: AppProxyMode.direct,
        proxyRoutingStrategy: ProxyRoutingStrategy.perSite,
        builtinProxyPort: 20808,
      );
      ProxyRouter.updateConfig(config);

      expect(ProxyRouter.shouldProxyHost('www.pornhub.com'), isFalse);
      expect(ProxyRouter.shouldProxyHost('jable.tv'), isFalse);
      expect(ProxyRouter.findProxyString(Uri.parse('https://www.pornhub.com/view')), equals('DIRECT'));
      expect(ProxyRouter.getProxyForSite('pornhub'), isEmpty);
    });

    test('Builtin Mode with perSite routing strategy routes restricted sites and bypasses direct sites', () {
      final config = AppConfig(
        proxyMode: AppProxyMode.builtin,
        proxyRoutingStrategy: ProxyRoutingStrategy.perSite,
        builtinProxyPort: 20808,
      );
      ProxyRouter.updateConfig(config);

      // Restricted overseas sites should proxy
      expect(ProxyRouter.shouldProxyHost('www.pornhub.com'), isTrue);
      expect(ProxyRouter.shouldProxyHost('ci.phncdn.com'), isTrue);
      expect(ProxyRouter.shouldProxyHost('jable.tv'), isTrue);
      expect(ProxyRouter.findProxyString(Uri.parse('https://www.pornhub.com/video')),
          equals('PROXY 127.0.0.1:20808; DIRECT'));
      expect(ProxyRouter.getProxyForSite('pornhub'), equals('127.0.0.1:20808'));

      // Domestic/Direct sites should NOT proxy by default
      expect(ProxyRouter.shouldProxyHost('www.mzitu.com'), isFalse);
      expect(ProxyRouter.shouldProxyHost('hentai-cosplays.com'), isFalse);
      expect(ProxyRouter.findProxyString(Uri.parse('https://hentai-cosplays.com/image.jpg')), equals('DIRECT'));
      expect(ProxyRouter.getProxyForSite('mzt'), isEmpty);

      // Toggling MZT to proxy dynamically updates routing
      final toggles = Map<String, bool>.from(config.siteProxyToggles);
      toggles['mzt'] = true;
      final updatedConfig = config.copyWith(siteProxyToggles: toggles);
      ProxyRouter.updateConfig(updatedConfig);

      expect(ProxyRouter.shouldProxyHost('www.mzitu.com'), isTrue);
      expect(ProxyRouter.getProxyForSite('mzt'), equals('127.0.0.1:20808'));
    });

    test('Builtin Mode gracefully falls back to DIRECT when core is stopped', () {
      ProxyRouter.bypassCoreRunningCheckForTest = false;
      final config = AppConfig(
        proxyMode: AppProxyMode.builtin,
        proxyRoutingStrategy: ProxyRoutingStrategy.perSite,
        builtinProxyPort: 20808,
      );
      ProxyRouter.updateConfig(config);

      // Even for restricted sites, should not proxy to a dead local port
      expect(ProxyRouter.shouldProxyHost('www.pornhub.com'), isFalse);
      expect(ProxyRouter.findProxyString(Uri.parse('https://www.pornhub.com')), equals('DIRECT'));
    });

    test('Global Strategy routes all external sites through proxy, but bypasses loopback and private LAN addresses', () {
      final config = AppConfig(
        proxyMode: AppProxyMode.custom,
        customProxy: '127.0.0.1:7890',
        proxyRoutingStrategy: ProxyRoutingStrategy.global,
      );
      ProxyRouter.updateConfig(config);

      expect(ProxyRouter.shouldProxyHost('www.pornhub.com'), isTrue);
      expect(ProxyRouter.shouldProxyHost('www.mzitu.com'), isTrue);
      expect(ProxyRouter.shouldProxyHost('hentai-cosplays.com'), isTrue);
      expect(ProxyRouter.findProxyString(Uri.parse('https://hentai-cosplays.com')),
          equals('PROXY 127.0.0.1:7890; DIRECT'));

      // Loopback addresses must NEVER be proxied
      expect(ProxyRouter.shouldProxyHost('127.0.0.1'), isFalse);
      expect(ProxyRouter.shouldProxyHost('127.0.0.5:8080'), isFalse);
      expect(ProxyRouter.shouldProxyHost('localhost'), isFalse);
      expect(ProxyRouter.shouldProxyHost('localhost:8080'), isFalse);
      expect(ProxyRouter.shouldProxyHost('::1'), isFalse);
      expect(ProxyRouter.shouldProxyHost('[::1]:8080'), isFalse);
      expect(ProxyRouter.findProxyString(Uri.parse('http://127.0.0.1:8080/sub')), equals('DIRECT'));

      // Private LAN subnets must NEVER be proxied
      expect(ProxyRouter.shouldProxyHost('192.168.1.1'), isFalse);
      expect(ProxyRouter.shouldProxyHost('192.168.0.100:8080'), isFalse);
      expect(ProxyRouter.shouldProxyHost('10.0.0.1'), isFalse);
      expect(ProxyRouter.shouldProxyHost('172.16.0.1'), isFalse);
      expect(ProxyRouter.shouldProxyHost('172.25.10.5:8080'), isFalse);
    });
  });

  group('SingboxConfigGenerator Tests', () {
    test('generates valid JSON adhering to Sing-box 1.12+/1.13+ strict rules', () {
      final node = ProxyNode(
        name: 'US-VLESS-Test',
        protocol: 'vless',
        server: '1.2.3.4',
        port: 443,
        auth: {'uuid': '12345678-1234-1234-1234-123456789abc'},
        tlsSettings: {
          'security': 'reality',
          'sni': 'yahoo.com',
          'pbk': 'my-public-key',
          'sid': 'abcd',
          'alpn': 'h2,http/1.1',
        },
        transport: {
          'network': 'tcp',
        },
      );

      final jsonStr = SingboxConfigGenerator.generateConfigJson(node, listenPort: 20808);
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;

      // Modern DNS servers format
      final dnsServers = map['dns']['servers'] as List;
      expect(dnsServers.any((s) => s['type'] == 'local' && s['tag'] == 'local-dns'), isTrue);
      expect(dnsServers.any((s) => s['type'] == 'udp' && s['tag'] == 'remote-dns'), isTrue);

      // Inbounds
      final inbounds = map['inbounds'] as List;
      expect(inbounds.first['type'], equals('mixed'));
      expect(inbounds.first['listen_port'], equals(20808));

      // Route
      final route = map['route'] as Map<String, dynamic>;
      expect(route['default_domain_resolver'], equals('local-dns'));
      expect(route.containsKey('auto_detect_interface'), isFalse);
      final rules = route['rules'] as List;
      expect(rules.any((r) => (r['inbound'] as List?)?.contains('mixed-in') == true && r['outbound'] == 'proxy'), isTrue);

      // Outbounds
      final outbounds = map['outbounds'] as List;
      final proxyOutbound = outbounds.firstWhere((o) => o['tag'] == 'proxy') as Map<String, dynamic>;
      expect(proxyOutbound['type'], equals('vless'));
      expect(proxyOutbound['server'], equals('1.2.3.4'));
      expect(proxyOutbound['server_port'], equals(443));
      expect(proxyOutbound['uuid'], equals('12345678-1234-1234-1234-123456789abc'));
      expect(proxyOutbound['domain_resolver'], equals('local-dns'));
      expect(proxyOutbound['tls']['reality']['public_key'], equals('my-public-key'));
      expect(proxyOutbound['tls']['alpn'], equals(['h2', 'http/1.1']));

      // Ensure no deprecated dns outbound exists
      expect(outbounds.any((o) => o['type'] == 'dns'), isFalse);
    });

    test('generates valid hysteria2 outbound with obfs and rate limits', () {
      final node = ProxyNode(
        name: 'HY2-Fast',
        protocol: 'hysteria2',
        server: '5.6.7.8',
        port: 8443,
        auth: {'password': 'secretpassword'},
        tlsSettings: {'sni': 'bing.com', 'insecure': true},
        extra: {
          'up': '50mbps',
          'down': '200mbps',
          'obfs': 'salamander',
          'obfs_password': 'my-obfs-secret',
        },
      );

      final outbound = SingboxConfigGenerator.nodeToSingboxOutbound(node);
      expect(outbound['type'], equals('hysteria2'));
      expect(outbound['server'], equals('5.6.7.8'));
      expect(outbound['server_port'], equals(8443));
      expect(outbound['password'], equals('secretpassword'));
      expect(outbound['domain_resolver'], equals('local-dns'));
      expect(outbound['tls']['insecure'], isTrue);
      expect(outbound['down_mbps'], equals(200));
      expect(outbound['obfs']['type'], equals('salamander'));
      expect(outbound['obfs']['password'], equals('my-obfs-secret'));
    });

    test('generates valid tuic outbound with congestion_control and tls', () {
      final node = ProxyNode(
        name: 'TUIC-Test',
        protocol: 'tuic',
        server: '9.10.11.12',
        port: 8443,
        auth: {'uuid': '12345678-1234-1234-1234-123456789abc', 'password': 'mypassword'},
        tlsSettings: {'sni': 'tuic.server.com', 'insecure': true},
        extra: {'congestion_control': 'bbr'},
      );

      final outbound = SingboxConfigGenerator.nodeToSingboxOutbound(node);
      expect(outbound['type'], equals('tuic'));
      expect(outbound['server'], equals('9.10.11.12'));
      expect(outbound['congestion_control'], equals('bbr'));
      expect(outbound['tls']['enabled'], isTrue);
      expect(outbound['tls']['alpn'], equals(['h3']));
    });
  });
}
