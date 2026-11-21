import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../data/backup.dart';
import '../data/db.dart';
import 'api.dart';

enum CloudSyncStatus { idle, syncing, ok, conflict, error }

class CloudSyncResult {
  final bool ok;
  final String message;
  final SyncSnapshot? conflict;

  const CloudSyncResult({
    required this.ok,
    required this.message,
    this.conflict,
  });
}

class CloudSync {
  CloudSync._();
  static final CloudSync instance = CloudSync._();

  final CloudApi api = CloudApi();
  CloudSyncStatus status = CloudSyncStatus.idle;
  String? lastError;
  DateTime? lastSyncAt;
  bool _running = false;

  static const _kToken = 'cloudToken';
  static const _kEmail = 'cloudEmail';
  static const _kName = 'cloudName';
  static const _kUserId = 'cloudUserId';
  static const _kRevision = 'cloudRevision';
  static const _kDirty = 'cloudDirty';
  static const _kClientId = 'cloudClientId';
  static const _kLastSync = 'cloudLastSync';

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  Future<bool> get isSignedIn async {
    final p = await _prefs;
    return (p.getString(_kToken) ?? '').isNotEmpty;
  }

  Future<String?> get token async => (await _prefs).getString(_kToken);

  Future<String?> get email async => (await _prefs).getString(_kEmail);

  Future<String?> get displayName async => (await _prefs).getString(_kName);

  Future<int> get revision async => (await _prefs).getInt(_kRevision) ?? 0;

  Future<bool> get isDirty async => (await _prefs).getBool(_kDirty) ?? false;

  Future<void> markDirty() async {
    final p = await _prefs;
    if (!(p.getBool(_kDirty) ?? false)) {
      await p.setBool(_kDirty, true);
    }
  }

  Future<String> clientId() async {
    final p = await _prefs;
    var id = p.getString(_kClientId);
    if (id == null || id.isEmpty) {
      id = 'android-${const Uuid().v4()}';
      await p.setString(_kClientId, id);
    }
    return id;
  }

  Future<void> _saveSession(String token, CloudUser user) async {
    final p = await _prefs;
    await p.setString(_kToken, token);
    await p.setString(_kEmail, user.email);
    await p.setString(_kName, user.name);
    await p.setString(_kUserId, user.id);
  }

  Future<void> signOut() async {
    final p = await _prefs;
    await p.remove(_kToken);
    await p.remove(_kEmail);
    await p.remove(_kName);
    await p.remove(_kUserId);
    status = CloudSyncStatus.idle;
  }

  Future<void> _alignRevision(String token) async {
    final me = await api.me(token);
    final p = await _prefs;
    await p.setInt(_kRevision, me.revision);
  }

  Future<CloudSyncResult> signup({
    required String name,
    required String email,
    required String password,
  }) async {
    final res =
        await api.signup(name: name, email: email, password: password);
    await _saveSession(res.token, res.user);
    await _alignRevision(res.token);
    await markDirty();
    return sync();
  }

  Future<CloudSyncResult> login({
    required String email,
    required String password,
  }) async {
    final res = await api.login(email: email, password: password);
    await _saveSession(res.token, res.user);
    await _alignRevision(res.token);
    // Prefer cloud if local has no transactions; otherwise push local.
    final txns = await AppDatabase.instance.db.query('transactions', limit: 1);
    if (txns.isEmpty) {
      final p = await _prefs;
      await p.setBool(_kDirty, false);
      return sync();
    }
    await markDirty();
    return sync();
  }

  Future<Map<String, dynamic>> _exportTables() async {
    final raw = await AppDatabase.instance.exportJson();
    final root = jsonDecode(raw) as Map<String, dynamic>;
    return Map<String, dynamic>.from(root['tables'] as Map);
  }

  Future<void> _importTables(Map<String, dynamic> tables) async {
    final payload = jsonEncode({
      'app': 'FinUp',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'tables': tables,
    });
    final ok = await AppDatabase.instance.importJson(payload);
    if (!ok) throw StateError('Failed to import cloud tables');
  }

  Future<CloudSyncResult> applyConflictKeepCloud(SyncSnapshot snap) async {
    await _importTables(snap.tables);
    final p = await _prefs;
    await p.setInt(_kRevision, snap.revision);
    await p.setBool(_kDirty, false);
    await p.setString(_kLastSync, DateTime.now().toIso8601String());
    lastSyncAt = DateTime.now();
    status = CloudSyncStatus.ok;
    return const CloudSyncResult(ok: true, message: 'Kept cloud data');
  }

  Future<CloudSyncResult> applyConflictKeepLocal(SyncSnapshot snap) async {
    final p = await _prefs;
    await p.setInt(_kRevision, snap.revision);
    await p.setBool(_kDirty, true);
    return sync(force: true);
  }

  Future<CloudSyncResult> sync({bool force = false}) async {
    if (_running) {
      return const CloudSyncResult(ok: false, message: 'Sync already running');
    }
    final tok = await token;
    if (tok == null || tok.isEmpty) {
      return const CloudSyncResult(ok: false, message: 'Not signed in');
    }

    _running = true;
    status = CloudSyncStatus.syncing;
    lastError = null;

    try {
      final p = await _prefs;
      final dirty = force || (p.getBool(_kDirty) ?? false);
      var rev = p.getInt(_kRevision) ?? 0;
      final cid = await clientId();

      if (dirty) {
        try {
          final tables = await _exportTables();
          final res = await api.push(
            tok,
            baseRevision: rev,
            clientId: cid,
            tables: tables,
            force: force,
            meta: {
              'source': 'android',
              'exportedAt': DateTime.now().toIso8601String(),
            },
          );
          await p.setInt(_kRevision, res.revision);
          await p.setBool(_kDirty, false);
          await p.setString(_kLastSync, DateTime.now().toIso8601String());
          lastSyncAt = DateTime.now();
          status = CloudSyncStatus.ok;
          return CloudSyncResult(
              ok: true, message: 'Synced to cloud (rev ${res.revision})');
        } on CloudApiException catch (e) {
          if (e.status == 409 && e.conflictSync != null) {
            status = CloudSyncStatus.conflict;
            lastError = e.message;
            return CloudSyncResult(
              ok: false,
              message: e.message,
              conflict: e.conflictSync,
            );
          }
          rethrow;
        }
      } else {
        final remote = await api.pull(tok);
        if (remote.revision != rev) {
          await _importTables(remote.tables);
          await p.setInt(_kRevision, remote.revision);
        }
        await p.setString(_kLastSync, DateTime.now().toIso8601String());
        lastSyncAt = DateTime.now();
        status = CloudSyncStatus.ok;
        return CloudSyncResult(
          ok: true,
          message: remote.revision != rev
              ? 'Pulled cloud data (rev ${remote.revision})'
              : 'Up to date',
        );
      }
    } catch (e) {
      status = CloudSyncStatus.error;
      lastError = e.toString();
      return CloudSyncResult(ok: false, message: lastError!);
    } finally {
      _running = false;
    }
  }
}
