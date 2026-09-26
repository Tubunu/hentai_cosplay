import 'dart:convert';

/// Represents an extracted proxy node with full protocol configurations.
class ProxyNode {
  final String name;
  final String protocol;
  final String server;
  final int port;
  String sourceTag;
  final Map<String, dynamic> auth;
  final Map<String, dynamic> tlsSettings;
  final Map<String, dynamic> transport;
  final Map<String, dynamic> extra;
  final Map<String, dynamic> rawConfig;
  int? pingMs;

  ProxyNode({
    required this.name,
    required this.protocol,
    required this.server,
    required this.port,
    this.sourceTag = '',
    Map<String, dynamic>? auth,
    Map<String, dynamic>? tlsSettings,
    Map<String, dynamic>? transport,
    Map<String, dynamic>? extra,
    Map<String, dynamic>? rawConfig,
    this.pingMs,
  })  : auth = auth ?? {},
        tlsSettings = tlsSettings ?? {},
        transport = transport ?? {},
        extra = extra ?? {},
        rawConfig = rawConfig ?? {};

  /// Returns a clean, URL-safe remark tag.
  String cleanName() {
    var n = name.replaceAll('https://', '').replaceAll('http://', '');
    if (n.contains('github.com') || n.contains('fanqiang')) {
      final srv = server.replaceAll('[', '').replaceAll(']', '');
      final parts = srv.split('.');
      final shortSrv = (parts.length == 4) ? '${parts[0]}.${parts[1]}' : (srv.length > 10 ? srv.substring(0, 10) : srv);
      final firstTag = sourceTag.isNotEmpty ? sourceTag.split(',')[0].trim() : protocol.toUpperCase();
      n = '$firstTag-${protocol.toUpperCase()}-$shortSrv:$port';
    }
    for (final ch in [':', '/', '\\', '@', '?', '#', '%', '&', ' ', '[', ']']) {
      n = n.replaceAll(ch, '-');
    }
    while (n.contains('--')) {
      n = n.replaceAll('--', '-');
    }
    n = n.trim();
    if (n.startsWith('-')) n = n.substring(1);
    if (n.endsWith('-')) n = n.substring(0, n.length - 1);
    return n.isNotEmpty ? n : '${protocol.toUpperCase()}-$server:$port';
  }

  /// Returns a concise 12-20 character tag to minimize QR payload density.
  String compactName() {
    final p = protocol.toUpperCase();
    final srv = server.split(':')[0].replaceAll('[', '').replaceAll(']', '');
    final parts = srv.split('.');
    String shortHost;
    if (parts.length == 4 && parts.every((element) => int.tryParse(element) != null)) {
      shortHost = '${parts[0]}.${parts[1]}';
    } else if (parts.length >= 2) {
      shortHost = parts[parts.length - 2];
    } else {
      shortHost = srv.length > 8 ? srv.substring(0, 8) : srv;
    }
    return '$p-$shortHost:$port';
  }

  /// Evaluates client compatibility (v2rayng, shadowrocket, clash).
  bool isSupportedBy(String client) {
    final c = client.toLowerCase();
    final p = protocol.toLowerCase();
    if (c == 'v2rayng') {
      return ['vless', 'hysteria2', 'hy2', 'vmess', 'trojan', 'ss', 'shadowsocks'].contains(p);
    } else if (c == 'shadowrocket') {
      return ['hysteria2', 'hy2', 'vless', 'hysteria', 'tuic', 'naiveproxy', 'vmess', 'trojan', 'ss', 'shadowsocks', 'juicity'].contains(p);
    } else if (c == 'clash') {
      return ['hysteria2', 'hy2', 'vless', 'hysteria', 'tuic', 'naiveproxy', 'vmess', 'trojan', 'ss', 'shadowsocks'].contains(p);
    }
    return true;
  }

  /// Converts the node into a universal URI share link.
  String toShareLink({String targetClient = 'all', bool compact = false}) {
    final proto = protocol.toLowerCase();
    final tag = compact ? compactName() : cleanName();
    final srvRaw = server.trim();
    final srv = (srvRaw.contains(':') && !srvRaw.startsWith('[')) ? '[$srvRaw]' : srvRaw;

    if (proto == 'hysteria2' || proto == 'hy2') {
      final password = Uri.encodeComponent((auth['password'] ?? auth['auth'] ?? '').toString());
      final queryParams = <String, String>{};
      if (tlsSettings['sni'] != null && tlsSettings['sni'].toString().isNotEmpty) {
        queryParams['sni'] = tlsSettings['sni'].toString();
      }
      if (tlsSettings['insecure'] != null) {
        queryParams['insecure'] = (tlsSettings['insecure'] == true || tlsSettings['insecure'] == '1') ? '1' : '0';
      }
      final queryStr = queryParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
      final queryPart = queryStr.isNotEmpty ? '?$queryStr' : '';
      final userinfo = password.isNotEmpty ? '$password@' : '';
      return 'hy2://$userinfo$srv:$port$queryPart#$tag';
    } else if (proto == 'vless') {
      final uuidVal = Uri.encodeComponent((auth['uuid'] ?? auth['id'] ?? '').toString());
      final query = <String, String>{};
      final netType = (transport['type'] ?? transport['network'] ?? 'tcp').toString();
      query['type'] = netType;
      if (transport['path'] != null) query['path'] = transport['path'].toString();
      if (transport['host'] != null) query['host'] = transport['host'].toString();
      if (transport['mode'] != null) query['mode'] = transport['mode'].toString();

      final sec = (tlsSettings['security'] ?? 'none').toString();
      query['security'] = sec;
      query['encryption'] = (auth['encryption'] ?? 'none').toString();
      if (tlsSettings['sni'] != null && tlsSettings['sni'].toString().isNotEmpty) {
        query['sni'] = tlsSettings['sni'].toString();
      }
      if (tlsSettings['fp'] != null) query['fp'] = tlsSettings['fp'].toString();
      if (tlsSettings['pbk'] != null) query['pbk'] = tlsSettings['pbk'].toString();
      if (tlsSettings['sid'] != null) query['sid'] = tlsSettings['sid'].toString();
      if (tlsSettings['flow'] != null) query['flow'] = tlsSettings['flow'].toString();

      final queryStr = query.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
      return 'vless://$uuidVal@$srv:$port?$queryStr#$tag';
    } else if (proto == 'tuic') {
      final uuidVal = Uri.encodeComponent((auth['uuid'] ?? '').toString());
      final password = Uri.encodeComponent((auth['password'] ?? '').toString());
      final query = <String, String>{};
      if (extra['congestion_control'] != null) {
        query['congestion_control'] = extra['congestion_control'].toString();
      }
      if (tlsSettings['sni'] != null && tlsSettings['sni'].toString().isNotEmpty) {
        query['sni'] = tlsSettings['sni'].toString();
      }
      if (tlsSettings['alpn'] != null) {
        final alpnVal = tlsSettings['alpn'];
        query['alpn'] = (alpnVal is List) ? alpnVal.join(',') : alpnVal.toString();
      }
      if (tlsSettings['insecure'] != null) {
        query['allow_insecure'] = (tlsSettings['insecure'] == true) ? '1' : '0';
      }
      final queryStr = query.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
      final queryPart = queryStr.isNotEmpty ? '?$queryStr' : '';
      final userinfo = (uuidVal.isNotEmpty || password.isNotEmpty) ? '$uuidVal:$password@' : '';
      return 'tuic://$userinfo$srv:$port$queryPart#$tag';
    } else if (proto == 'hysteria') {
      final query = <String, String>{};
      query['protocol'] = (rawConfig['protocol'] ?? 'udp').toString();
      final authStr = (auth['auth_str'] ?? auth['auth'] ?? '').toString();
      if (authStr.isNotEmpty) query['auth'] = authStr;
      if (tlsSettings['sni'] != null) query['peer'] = tlsSettings['sni'].toString();
      if (tlsSettings['insecure'] != null) {
        query['insecure'] = (tlsSettings['insecure'] == true) ? '1' : '0';
      }
      if (extra['up'] != null) {
        final upDigits = extra['up'].toString().replaceAll(RegExp(r'\D'), '');
        if (upDigits.isNotEmpty) query['upmbps'] = upDigits;
      }
      if (extra['down'] != null) {
        final downDigits = extra['down'].toString().replaceAll(RegExp(r'\D'), '');
        if (downDigits.isNotEmpty) query['downmbps'] = downDigits;
      }
      if (tlsSettings['alpn'] != null) {
        final alpnVal = tlsSettings['alpn'];
        query['alpn'] = (alpnVal is List && alpnVal.isNotEmpty) ? alpnVal[0].toString() : alpnVal.toString();
      }
      final queryStr = query.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
      final queryPart = queryStr.isNotEmpty ? '?$queryStr' : '';
      final userinfo = (authStr.isNotEmpty && srv.contains(':')) ? '${Uri.encodeComponent(authStr)}@' : '';
      return 'hysteria://$userinfo$srv:$port$queryPart#$tag';
    } else if (proto == 'naiveproxy') {
      final user = Uri.encodeComponent((auth['user'] ?? '').toString());
      final password = Uri.encodeComponent((auth['password'] ?? '').toString());
      final userinfo = (user.isNotEmpty || password.isNotEmpty) ? '$user:$password@' : '';
      return 'https://$userinfo$srv:$port#$tag';
    } else if (proto == 'vmess') {
      final vmessData = {
        'v': '2',
        'ps': tag,
        'add': server,
        'port': port,
        'id': (auth['uuid'] ?? '').toString(),
        'aid': auth['alterId'] ?? 0,
        'scy': (auth['security'] ?? 'auto').toString(),
        'net': (transport['network'] ?? 'tcp').toString(),
        'type': 'none',
        'host': (transport['host'] ?? '').toString(),
        'path': (transport['path'] ?? '').toString(),
        'tls': (tlsSettings['security'] == 'tls' || tlsSettings['security'] == 'reality') ? 'tls' : '',
        'sni': (tlsSettings['sni'] ?? '').toString(),
      };
      final jsonStr = jsonEncode(vmessData);
      final b64Str = base64Encode(utf8.encode(jsonStr));
      return 'vmess://$b64Str';
    } else if (proto == 'trojan') {
      final password = Uri.encodeComponent((auth['password'] ?? '').toString());
      final query = <String, String>{};
      if (tlsSettings['sni'] != null) query['sni'] = tlsSettings['sni'].toString();
      if (tlsSettings['insecure'] == true) query['allowInsecure'] = '1';
      final queryStr = query.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
      final queryPart = queryStr.isNotEmpty ? '?$queryStr' : '';
      return 'trojan://$password@$srv:$port$queryPart#$tag';
    } else if (proto == 'ss' || proto == 'shadowsocks') {
      final method = (auth['method'] ?? 'aes-256-gcm').toString();
      final password = (auth['password'] ?? '').toString();
      final userinfo = base64Encode(utf8.encode('$method:$password'));
      return 'ss://$userinfo@$srv:$port#$tag';
    } else if (proto == 'juicity') {
      final uuidVal = Uri.encodeComponent((auth['uuid'] ?? '').toString());
      final password = Uri.encodeComponent((auth['password'] ?? '').toString());
      final query = <String, String>{};
      if (tlsSettings['sni'] != null) query['sni'] = tlsSettings['sni'].toString();
      if (tlsSettings['insecure'] != null) {
        query['allow_insecure'] = (tlsSettings['insecure'] == true) ? '1' : '0';
      }
      if (extra['congestion_control'] != null) {
        query['congestion_control'] = extra['congestion_control'].toString();
      }
      final queryStr = query.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
      final queryPart = queryStr.isNotEmpty ? '?$queryStr' : '';
      return 'juicity://$uuidVal:$password@$srv:$port$queryPart#$tag';
    } else if (proto == 'shadowquic') {
      final user = Uri.encodeComponent((auth['user'] ?? '').toString());
      final password = Uri.encodeComponent((auth['password'] ?? '').toString());
      final query = <String, String>{};
      if (tlsSettings['sni'] != null) query['sni'] = tlsSettings['sni'].toString();
      final queryStr = query.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
      final queryPart = queryStr.isNotEmpty ? '?$queryStr' : '';
      return 'shadowquic://$user:$password@$srv:$port$queryPart#$tag';
    }
    return 'unknown://$srv:$port#$tag';
  }

  /// Converts the node into a Clash Meta compatible dictionary.
  Map<String, dynamic> toClashDict() {
    final node = <String, dynamic>{
      'name': name,
      'server': server,
      'port': port,
    };
    final proto = protocol.toLowerCase();

    if (proto == 'hysteria2' || proto == 'hy2') {
      node['type'] = 'hysteria2';
      node['password'] = (auth['password'] ?? auth['auth'] ?? '').toString();
      if (tlsSettings['sni'] != null && tlsSettings['sni'].toString().isNotEmpty) {
        node['sni'] = tlsSettings['sni'].toString();
      }
      if (tlsSettings['insecure'] != null) {
        node['skip-cert-verify'] = (tlsSettings['insecure'] == true || tlsSettings['insecure'] == '1');
      }
      if (extra['up'] != null) node['up'] = extra['up'].toString();
      if (extra['down'] != null) node['down'] = extra['down'].toString();
    } else if (proto == 'vless') {
      node['type'] = 'vless';
      node['uuid'] = (auth['uuid'] ?? auth['id'] ?? '').toString();
      final network = (transport['network'] ?? transport['type'] ?? 'tcp').toString();
      node['network'] = network;
      node['udp'] = true;
      node['tls'] = true;
      if (tlsSettings['sni'] != null && tlsSettings['sni'].toString().isNotEmpty) {
        node['servername'] = tlsSettings['sni'].toString();
      }
      if (tlsSettings['fp'] != null) node['client-fingerprint'] = tlsSettings['fp'].toString();

      if (tlsSettings['security'] == 'reality') {
        node['reality-opts'] = {
          'public-key': (tlsSettings['pbk'] ?? '').toString(),
          'short-id': (tlsSettings['sid'] ?? '').toString(),
        };
      }
      if (network == 'xhttp' || network == 'splithttp') {
        node['xhttp-opts'] = {
          'path': (transport['path'] ?? '/').toString(),
          'mode': (transport['mode'] ?? 'auto').toString(),
        };
      } else if (network == 'ws') {
        node['ws-opts'] = {
          'path': (transport['path'] ?? '/').toString(),
          'headers': {'Host': (transport['host'] ?? '').toString()},
        };
      }
    } else if (proto == 'tuic') {
      node['type'] = 'tuic';
      node['uuid'] = (auth['uuid'] ?? '').toString();
      node['password'] = (auth['password'] ?? '').toString();
      if (tlsSettings['sni'] != null) node['sni'] = tlsSettings['sni'].toString();
      if (tlsSettings['insecure'] != null) {
        node['skip-cert-verify'] = (tlsSettings['insecure'] == true);
      }
      if (tlsSettings['alpn'] != null) {
        final alpnVal = tlsSettings['alpn'];
        node['alpn'] = (alpnVal is List) ? alpnVal : [alpnVal.toString()];
      }
      if (extra['congestion_control'] != null) {
        node['congestion-controller'] = extra['congestion_control'].toString();
      }
    } else if (proto == 'hysteria') {
      node['type'] = 'hysteria';
      node['auth_str'] = (auth['auth_str'] ?? auth['auth'] ?? '').toString();
      if (tlsSettings['sni'] != null) node['sni'] = tlsSettings['sni'].toString();
      if (tlsSettings['insecure'] != null) {
        node['skip-cert-verify'] = (tlsSettings['insecure'] == true);
      }
      if (tlsSettings['alpn'] != null) {
        final alpnVal = tlsSettings['alpn'];
        node['alpn'] = (alpnVal is List) ? alpnVal : [alpnVal.toString()];
      }
      if (extra['up'] != null) node['up'] = extra['up'].toString();
      if (extra['down'] != null) node['down'] = extra['down'].toString();
    } else if (proto == 'naiveproxy') {
      node['type'] = 'http';
      node['username'] = (auth['user'] ?? '').toString();
      node['password'] = (auth['password'] ?? '').toString();
      node['tls'] = true;
    } else if (proto == 'vmess') {
      node['type'] = 'vmess';
      node['uuid'] = (auth['uuid'] ?? '').toString();
      node['alterId'] = auth['alterId'] ?? 0;
      node['cipher'] = 'auto';
      if (transport['network'] != null) node['network'] = transport['network'].toString();
    } else if (proto == 'trojan') {
      node['type'] = 'trojan';
      node['password'] = (auth['password'] ?? '').toString();
      if (tlsSettings['sni'] != null) node['sni'] = tlsSettings['sni'].toString();
      if (tlsSettings['insecure'] != null) {
        node['skip-cert-verify'] = (tlsSettings['insecure'] == true);
      }
    } else if (proto == 'ss' || proto == 'shadowsocks') {
      node['type'] = 'ss';
      node['cipher'] = (auth['method'] ?? 'aes-256-gcm').toString();
      node['password'] = (auth['password'] ?? '').toString();
    } else {
      node['type'] = proto;
    }

    return node;
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'protocol': protocol,
        'server': server,
        'port': port,
        'source_tag': sourceTag,
        'auth': auth,
        'tls_settings': tlsSettings,
        'transport': transport,
        'extra': extra,
        'raw_config': rawConfig,
        'ping_ms': pingMs,
      };

  factory ProxyNode.fromJson(Map<String, dynamic> json) {
    return ProxyNode(
      name: (json['name'] ?? 'Unnamed').toString(),
      protocol: (json['protocol'] ?? 'unknown').toString(),
      server: (json['server'] ?? '').toString(),
      port: (json['port'] is int) ? json['port'] : int.tryParse(json['port']?.toString() ?? '0') ?? 0,
      sourceTag: (json['source_tag'] ?? '').toString(),
      auth: (json['auth'] is Map) ? Map<String, dynamic>.from(json['auth']) : {},
      tlsSettings: (json['tls_settings'] is Map) ? Map<String, dynamic>.from(json['tls_settings']) : {},
      transport: (json['transport'] is Map) ? Map<String, dynamic>.from(json['transport']) : {},
      extra: (json['extra'] is Map) ? Map<String, dynamic>.from(json['extra']) : {},
      rawConfig: (json['raw_config'] is Map) ? Map<String, dynamic>.from(json['raw_config']) : {},
      pingMs: json['ping_ms'] as int?,
    );
  }
}
