import 'dart:convert';

import 'package:http/http.dart' as http;

const kFinupApiBase = 'https://api.finup.yashchauhan.pro';

class CloudUser {
  final String id;
  final String name;
  final String email;

  const CloudUser({required this.id, required this.name, required this.email});

  factory CloudUser.fromJson(Map<String, dynamic> j) => CloudUser(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? '',
        email: (j['email'] as String?) ?? '',
      );
}

class SyncSnapshot {
  final int revision;
  final String? updatedAt;
  final String? clientId;
  final Map<String, dynamic> tables;
  final Map<String, dynamic> meta;

  const SyncSnapshot({
    required this.revision,
    this.updatedAt,
    this.clientId,
    required this.tables,
    this.meta = const {},
  });

  factory SyncSnapshot.fromJson(Map<String, dynamic> j) => SyncSnapshot(
        revision: (j['revision'] as num?)?.toInt() ?? 0,
        updatedAt: j['updatedAt']?.toString(),
        clientId: j['clientId']?.toString(),
        tables: Map<String, dynamic>.from(
            (j['tables'] as Map?)?.cast<String, dynamic>() ?? const {}),
        meta: Map<String, dynamic>.from(
            (j['meta'] as Map?)?.cast<String, dynamic>() ?? const {}),
      );
}

class CloudApiException implements Exception {
  final int status;
  final String message;
  final Map<String, dynamic>? body;

  CloudApiException(this.status, this.message, [this.body]);

  @override
  String toString() => message;

  SyncSnapshot? get conflictSync {
    final sync = body?['sync'];
    if (sync is Map<String, dynamic>) return SyncSnapshot.fromJson(sync);
    if (sync is Map) {
      return SyncSnapshot.fromJson(Map<String, dynamic>.from(sync));
    }
    return null;
  }
}

class CloudApi {
  CloudApi({this.baseUrl = kFinupApiBase});

  final String baseUrl;

  Uri _u(String path) => Uri.parse('$baseUrl$path');

  Future<Map<String, dynamic>> _json(
    String method,
    String path, {
    String? token,
    Object? body,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
    final http.Response res;
    final uri = _u(path);
    switch (method) {
      case 'GET':
        res = await http.get(uri, headers: headers);
      case 'POST':
        res = await http.post(uri,
            headers: headers, body: body == null ? null : jsonEncode(body));
      default:
        throw CloudApiException(0, 'Unsupported method $method');
    }
    Map<String, dynamic>? decoded;
    if (res.body.isNotEmpty) {
      try {
        final raw = jsonDecode(res.body);
        if (raw is Map<String, dynamic>) {
          decoded = raw;
        } else if (raw is Map) {
          decoded = Map<String, dynamic>.from(raw);
        }
      } catch (_) {}
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw CloudApiException(
        res.statusCode,
        (decoded?['message'] as String?) ?? 'Request failed (${res.statusCode})',
        decoded,
      );
    }
    return decoded ?? <String, dynamic>{};
  }

  Future<({String token, CloudUser user})> signup({
    required String name,
    required String email,
    required String password,
  }) async {
    final j = await _json('POST', '/auth/signup', body: {
      'name': name,
      'email': email,
      'password': password,
    });
    return (
      token: j['token'] as String,
      user: CloudUser.fromJson(Map<String, dynamic>.from(j['user'] as Map)),
    );
  }

  Future<({String token, CloudUser user})> login({
    required String email,
    required String password,
  }) async {
    final j = await _json('POST', '/auth/login', body: {
      'email': email,
      'password': password,
    });
    return (
      token: j['token'] as String,
      user: CloudUser.fromJson(Map<String, dynamic>.from(j['user'] as Map)),
    );
  }

  Future<({CloudUser user, int revision})> me(String token) async {
    final j = await _json('GET', '/sync/me', token: token);
    final sync = j['sync'] as Map? ?? {};
    return (
      user: CloudUser.fromJson(Map<String, dynamic>.from(j['user'] as Map)),
      revision: (sync['revision'] as num?)?.toInt() ?? 0,
    );
  }

  Future<SyncSnapshot> pull(String token) async {
    final j = await _json('GET', '/sync/pull', token: token);
    return SyncSnapshot.fromJson(j);
  }

  Future<({int revision, String? updatedAt, String? clientId})> push(
    String token, {
    required int baseRevision,
    required String clientId,
    required Map<String, dynamic> tables,
    Map<String, dynamic>? meta,
    bool force = false,
  }) async {
    final j = await _json('POST', '/sync/push', token: token, body: {
      'baseRevision': baseRevision,
      'clientId': clientId,
      'tables': tables,
      'meta': meta ?? {'source': 'android'},
      'force': force,
    });
    return (
      revision: (j['revision'] as num?)?.toInt() ?? baseRevision + 1,
      updatedAt: j['updatedAt']?.toString(),
      clientId: j['clientId']?.toString(),
    );
  }
}
