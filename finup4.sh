#!/usr/bin/env bash
set -euo pipefail
cd app
mkdir -p lib/data lib/security lib/screens android/app/src/main/kotlin/com/yash/finup

############################ pubspec: add crypto (for PIN hashing) ############################
if ! grep -q "crypto:" pubspec.yaml; then
  sed -i "s#  intl: '>=0.19.0 <1.0.0'#  intl: '>=0.19.0 <1.0.0'\n  crypto: ^3.0.3#" pubspec.yaml
fi

############################ Manifest: biometric permission ############################
if ! grep -q "USE_BIOMETRIC" android/app/src/main/AndroidManifest.xml; then
  sed -i 's#<uses-permission android:name="android.permission.READ_SMS"/>#<uses-permission android:name="android.permission.READ_SMS"/>\n    <uses-permission android:name="android.permission.USE_BIOMETRIC"/>#' android/app/src/main/AndroidManifest.xml
fi

############################ KOTLIN: MainActivity (all native features) ############################
cat > android/app/src/main/kotlin/com/yash/finup/MainActivity.kt <<'__END__'
package com.yash.finup

import android.Manifest
import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.hardware.biometrics.BiometricManager
import android.hardware.biometrics.BiometricPrompt
import android.net.Uri
import android.os.Build
import android.os.CancellationSignal
import android.provider.MediaStore
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "finup/native"
    private val permRequestCode = 4242
    private val createDocCode = 5151
    private val openDocCode = 5252
    private var pendingResult: MethodChannel.Result? = null
    private var pendingDocResult: MethodChannel.Result? = null
    private var pendingBytes: ByteArray? = null
    private val moneyRegex = Regex("(?i)(rs\\.?|inr|₹)\\s*[0-9]")

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasSmsPermission" -> result.success(hasPermission(Manifest.permission.READ_SMS))
                "requestSmsPermission" -> askPermissions(arrayOf(Manifest.permission.READ_SMS), result)
                "requestNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= 33) {
                        askPermissions(arrayOf("android.permission.POST_NOTIFICATIONS"), result)
                    } else {
                        result.success(true)
                    }
                }
                "openAppSettings" -> {
                    val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    result.success(true)
                }
                "readSms" -> {
                    val since = (call.argument<Number>("since") ?: 0).toLong()
                    Thread {
                        val list: List<Map<String, Any?>>? = try { readSms(since) } catch (e: Exception) { null }
                        runOnUiThread {
                            if (list == null) result.error("READ_FAILED", "Could not read SMS", null)
                            else result.success(list)
                        }
                    }.start()
                }
                "scheduleReminder" -> {
                    val hour = call.argument<Int>("hour") ?: 21
                    val minute = call.argument<Int>("minute") ?: 0
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    Reminder.save(this, hour, minute, enabled)
                    Reminder.schedule(this)
                    result.success(true)
                }
                "canBiometric" -> result.success(canBiometric())
                "authenticate" -> authenticate(call.argument<String>("reason") ?: "Unlock FinUp", result)
                "saveDocument" -> {
                    val name = call.argument<String>("name") ?: "finup.txt"
                    val mime = call.argument<String>("mime") ?: "application/octet-stream"
                    val bytes = call.argument<ByteArray>("bytes")
                    if (bytes == null) {
                        result.success(false)
                    } else {
                        pendingDocResult?.success(null)
                        pendingDocResult = result
                        pendingBytes = bytes
                        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT)
                        intent.addCategory(Intent.CATEGORY_OPENABLE)
                        intent.type = mime
                        intent.putExtra(Intent.EXTRA_TITLE, name)
                        startActivityForResult(intent, createDocCode)
                    }
                }
                "openDocument" -> {
                    pendingDocResult?.success(null)
                    pendingDocResult = result
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT)
                    intent.addCategory(Intent.CATEGORY_OPENABLE)
                    intent.type = "*/*"
                    startActivityForResult(intent, openDocCode)
                }
                "shareImage" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    val name = call.argument<String>("name") ?: "finup.png"
                    val text = call.argument<String>("text") ?: ""
                    result.success(shareImage(bytes, name, text))
                }
                "shareText" -> {
                    shareText(call.argument<String>("text") ?: "")
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun hasPermission(p: String): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        return checkSelfPermission(p) == PackageManager.PERMISSION_GRANTED
    }

    private fun askPermissions(perms: Array<String>, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) { result.success(true); return }
        if (perms.all { hasPermission(it) }) { result.success(true); return }
        pendingResult?.success(false)
        pendingResult = result
        requestPermissions(perms, permRequestCode)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == permRequestCode) {
            val ok = grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            pendingResult?.success(ok)
            pendingResult = null
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == createDocCode) {
            val res = pendingDocResult
            pendingDocResult = null
            val bytes = pendingBytes
            pendingBytes = null
            val uri = data?.data
            if (resultCode != Activity.RESULT_OK || uri == null || bytes == null) {
                res?.success(false)
                return
            }
            try {
                contentResolver.openOutputStream(uri)?.use { it.write(bytes) }
                res?.success(true)
            } catch (e: Exception) {
                res?.success(false)
            }
        } else if (requestCode == openDocCode) {
            val res = pendingDocResult
            pendingDocResult = null
            val uri = data?.data
            if (resultCode != Activity.RESULT_OK || uri == null) {
                res?.success(null)
                return
            }
            try {
                val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
                res?.success(bytes)
            } catch (e: Exception) {
                res?.success(null)
            }
        }
    }

    private fun canBiometric(): Boolean {
        if (Build.VERSION.SDK_INT >= 29) {
            val bm = getSystemService(BiometricManager::class.java) ?: return false
            return bm.canAuthenticate() == BiometricManager.BIOMETRIC_SUCCESS
        }
        if (Build.VERSION.SDK_INT >= 28) {
            return packageManager.hasSystemFeature(PackageManager.FEATURE_FINGERPRINT)
        }
        return false
    }

    private fun authenticate(reason: String, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 28) { result.success(false); return }
        var replied = false
        fun reply(v: Boolean) {
            if (!replied) { replied = true; result.success(v) }
        }
        val executor = mainExecutor
        val prompt = BiometricPrompt.Builder(this)
            .setTitle("Unlock FinUp")
            .setSubtitle(reason)
            .setNegativeButton("Use PIN", executor) { _, _ -> reply(false) }
            .build()
        prompt.authenticate(CancellationSignal(), executor, object : BiometricPrompt.AuthenticationCallback() {
            override fun onAuthenticationSucceeded(r: BiometricPrompt.AuthenticationResult?) { reply(true) }
            override fun onAuthenticationError(errorCode: Int, errString: CharSequence?) { reply(false) }
        })
    }

    private fun shareImage(bytes: ByteArray?, name: String, text: String): Boolean {
        if (bytes == null) return false
        if (Build.VERSION.SDK_INT < 29) { shareText(text); return true }
        return try {
            val values = ContentValues()
            values.put(MediaStore.Images.Media.DISPLAY_NAME, name)
            values.put(MediaStore.Images.Media.MIME_TYPE, "image/png")
            values.put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/FinUp")
            val uri = contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values) ?: return false
            contentResolver.openOutputStream(uri)?.use { it.write(bytes) }
            val send = Intent(Intent.ACTION_SEND)
            send.type = "image/png"
            send.putExtra(Intent.EXTRA_STREAM, uri)
            send.putExtra(Intent.EXTRA_TEXT, text)
            send.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            startActivity(Intent.createChooser(send, "Share statement"))
            true
        } catch (e: Exception) {
            shareText(text)
            true
        }
    }

    private fun shareText(text: String) {
        val send = Intent(Intent.ACTION_SEND)
        send.type = "text/plain"
        send.putExtra(Intent.EXTRA_TEXT, text)
        startActivity(Intent.createChooser(send, "Share"))
    }

    private fun readSms(since: Long): List<Map<String, Any?>> {
        val out = ArrayList<Map<String, Any?>>()
        if (!hasPermission(Manifest.permission.READ_SMS)) return out
        val cursor = contentResolver.query(
            Uri.parse("content://sms/inbox"),
            arrayOf("_id", "address", "body", "date"),
            "date > ?", arrayOf(since.toString()), "date ASC"
        ) ?: return out
        cursor.use { c ->
            val iId = c.getColumnIndex("_id")
            val iAddr = c.getColumnIndex("address")
            val iBody = c.getColumnIndex("body")
            val iDate = c.getColumnIndex("date")
            while (c.moveToNext()) {
                val body = c.getString(iBody) ?: ""
                if (!moneyRegex.containsMatchIn(body)) continue
                out.add(mapOf(
                    "id" to c.getLong(iId).toString(),
                    "address" to (c.getString(iAddr) ?: ""),
                    "body" to body,
                    "date" to c.getLong(iDate)
                ))
            }
        }
        return out
    }
}
__END__

############################ lib/native.dart ############################
cat > lib/native.dart <<'__END__'
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RawSms {
  final String id;
  final String address;
  final String body;
  final int date;
  const RawSms(this.id, this.address, this.body, this.date);
}

class Native {
  static const _ch = MethodChannel('finup/native');

  static Future<bool> _bool(String method, [Map<String, Object?>? args]) async {
    try {
      return await _ch.invokeMethod<bool>(method, args) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> hasSms() => _bool('hasSmsPermission');
  static Future<bool> requestSms() => _bool('requestSmsPermission');
  static Future<bool> requestNotifications() =>
      _bool('requestNotificationPermission');
  static Future<bool> openSettings() => _bool('openAppSettings');
  static Future<bool> canBiometric() => _bool('canBiometric');
  static Future<bool> authenticate(String reason) =>
      _bool('authenticate', {'reason': reason});
  static Future<bool> saveDocument(String name, String mime, Uint8List bytes) =>
      _bool('saveDocument', {'name': name, 'mime': mime, 'bytes': bytes});
  static Future<bool> shareImage(Uint8List bytes, String name, String text) =>
      _bool('shareImage', {'bytes': bytes, 'name': name, 'text': text});
  static Future<bool> shareText(String text) =>
      _bool('shareText', {'text': text});

  static Future<Uint8List?> openDocument() async {
    try {
      return await _ch.invokeMethod<Uint8List>('openDocument');
    } catch (_) {
      return null;
    }
  }

  static Future<List<RawSms>> readSms(int sinceMs) async {
    final raw =
        await _ch.invokeMethod<List<dynamic>>('readSms', {'since': sinceMs});
    if (raw == null) return [];
    return raw.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return RawSms('${m['id']}', '${m['address'] ?? ''}',
          '${m['body'] ?? ''}', (m['date'] as num).toInt());
    }).toList();
  }

  static Future<void> scheduleReminder(int hour, int minute, bool enabled) async {
    try {
      await _ch.invokeMethod('scheduleReminder',
          {'hour': hour, 'minute': minute, 'enabled': enabled});
    } catch (_) {}
  }
}

class ReminderPrefs {
  static Future<bool> isOn() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool('remOn') ?? true;
  }

  static Future<void> setOn(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('remOn', v);
  }
}
__END__

############################ lib/data/people_repo.dart ############################
cat > lib/data/people_repo.dart <<'__END__'
import 'db.dart';
import 'repo.dart';

class Person {
  final int id;
  final String name;
  final String? phone;
  final List<String> upis;
  final String? note;
  const Person(
      {required this.id,
      required this.name,
      this.phone,
      this.upis = const [],
      this.note});
}

class LedgerEntry {
  final int id;
  final int personId;
  final String type; // gave | took
  final double amount;
  final String? note;
  final int? txnId;
  final DateTime? dueAt;
  final DateTime occurredAt;

  const LedgerEntry({
    required this.id,
    required this.personId,
    required this.type,
    required this.amount,
    this.note,
    this.txnId,
    this.dueAt,
    required this.occurredAt,
  });

  double get signed => type == 'gave' ? amount : -amount;

  factory LedgerEntry.fromMap(Map<String, Object?> m) => LedgerEntry(
        id: m['id'] as int,
        personId: m['person_id'] as int,
        type: m['type'] as String,
        amount: (m['amount'] as num).toDouble(),
        note: m['note'] as String?,
        txnId: m['txn_id'] as int?,
        dueAt: m['due_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['due_at'] as int),
        occurredAt:
            DateTime.fromMillisecondsSinceEpoch(m['occurred_at'] as int),
      );
}

class PersonSummary {
  final Person person;
  final double balance;
  final DateTime? lastAt;
  final DateTime? nextDue;
  const PersonSummary(this.person, this.balance, this.lastAt, this.nextDue);
}

extension People on AppDatabase {
  Person _person(Map<String, Object?> r) => Person(
        id: r['id'] as int,
        name: r['name'] as String,
        phone: r['phone'] as String?,
        upis: ((r['upi_ids'] as String?) ?? '')
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        note: r['note'] as String?,
      );

  Future<List<Person>> people() async {
    final rows = await db.query('people', orderBy: 'name COLLATE NOCASE');
    return rows.map(_person).toList();
  }

  Future<Person?> person(int id) async {
    final rows = await db.query('people', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : _person(rows.first);
  }

  Future<int> insertPerson(String name,
      {String? phone, List<String> upis = const []}) {
    return db.insert('people', {
      'name': name,
      'phone': phone,
      'upi_ids': upis.join(','),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> updatePerson(Person p) async {
    await db.update(
        'people',
        {'name': p.name, 'phone': p.phone, 'upi_ids': p.upis.join(','), 'note': p.note},
        where: 'id = ?',
        whereArgs: [p.id]);
  }

  Future<void> addUpi(int personId, String upi) async {
    final p = await person(personId);
    if (p == null) return;
    final u = upi.trim().toLowerCase();
    if (u.isEmpty || p.upis.contains(u)) return;
    await updatePerson(Person(
        id: p.id, name: p.name, phone: p.phone, upis: [...p.upis, u], note: p.note));
  }

  Future<List<LedgerEntry>> entries(int personId) async {
    final rows = await db.query('ledger',
        where: 'person_id = ?', whereArgs: [personId], orderBy: 'occurred_at DESC');
    return rows.map(LedgerEntry.fromMap).toList();
  }

  Future<List<PersonSummary>> peopleSummaries() async {
    final list = await people();
    final rows = await db.query('ledger');
    final bal = <int, double>{};
    final last = <int, DateTime>{};
    final due = <int, DateTime>{};
    for (final r in rows) {
      final e = LedgerEntry.fromMap(r);
      final pid = e.personId;
      bal[pid] = (bal[pid] ?? 0) + e.signed;
      final l = last[pid];
      if (l == null || e.occurredAt.isAfter(l)) last[pid] = e.occurredAt;
      final d = e.dueAt;
      final cur = due[pid];
      if (d != null && e.type == 'gave' && (cur == null || d.isBefore(cur))) {
        due[pid] = d;
      }
    }
    return [
      for (final p in list)
        PersonSummary(p, bal[p.id] ?? 0, last[p.id],
            (bal[p.id] ?? 0) > 0.009 ? due[p.id] : null)
    ];
  }

  Future<Txn?> txnById(int id) async {
    final r = await db.query('transactions', where: 'id = ?', whereArgs: [id]);
    return r.isEmpty ? null : Txn.fromMap(r.first);
  }

  Future<void> addEntry({
    required int personId,
    required String type,
    required double amount,
    String? note,
    DateTime? dueAt,
    required DateTime when,
    int? accountId,
    String? personName,
  }) async {
    int? txnId;
    if (accountId != null) {
      txnId = await this.addTxn(Txn(
        accountId: accountId,
        type: type == 'gave' ? TxnType.expense : TxnType.income,
        amount: amount,
        personId: personId,
        counterparty: personName,
        note: note,
        status: 'done',
        occurredAt: when,
      ));
    }
    await db.insert('ledger', {
      'person_id': personId,
      'type': type,
      'amount': amount,
      'note': note,
      'txn_id': txnId,
      'due_at': dueAt?.millisecondsSinceEpoch,
      'occurred_at': when.millisecondsSinceEpoch,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> deleteEntry(LedgerEntry e) async {
    if (e.txnId != null) {
      final t = await txnById(e.txnId!);
      if (t != null) {
        if (t.smsBody != null) {
          await db.update('transactions', {'person_id': null, 'status': 'review'},
              where: 'id = ?', whereArgs: [t.id]);
        } else {
          await this.deleteTxn(t);
        }
      }
    }
    await db.delete('ledger', where: 'id = ?', whereArgs: [e.id]);
  }

  Future<void> updateEntry(
    LedgerEntry old, {
    required String type,
    required double amount,
    String? note,
    DateTime? dueAt,
    required DateTime when,
    int? accountId,
    String? personName,
  }) async {
    final t = old.txnId == null ? null : await txnById(old.txnId!);
    if (t != null && t.smsBody != null) {
      await db.update('ledger',
          {'note': note, 'due_at': dueAt?.millisecondsSinceEpoch},
          where: 'id = ?', whereArgs: [old.id]);
      return;
    }
    await deleteEntry(old);
    await addEntry(
        personId: old.personId,
        type: type,
        amount: amount,
        note: note,
        dueAt: dueAt,
        when: when,
        accountId: accountId,
        personName: personName);
  }

  Future<void> deletePerson(int id) async {
    for (final e in await entries(id)) {
      await deleteEntry(e);
    }
    await db.update('transactions', {'person_id': null},
        where: 'person_id = ?', whereArgs: [id]);
    await db.delete('people', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> linkTxn(Txn t, int personId) async {
    final type = t.type == TxnType.income ? 'took' : 'gave';
    await db.update('transactions',
        {'person_id': personId, 'category_id': null, 'status': 'done'},
        where: 'id = ?', whereArgs: [t.id]);
    await db.insert('ledger', {
      'person_id': personId,
      'type': type,
      'amount': t.amount,
      'note': t.note,
      'txn_id': t.id,
      'occurred_at': t.occurredAt.millisecondsSinceEpoch,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    final party = t.counterparty?.trim().toLowerCase();
    if (party != null && party.contains('@')) await addUpi(personId, party);
  }

  Future<int> autoLinkPeople() async {
    final map = <String, int>{};
    for (final p in await people()) {
      for (final u in p.upis) {
        map[u] = p.id;
      }
    }
    if (map.isEmpty) return 0;
    final rows = await db.query('transactions',
        where: "status = 'review' AND person_id IS NULL AND counterparty IS NOT NULL");
    var n = 0;
    for (final r in rows) {
      final t = Txn.fromMap(r);
      if (t.type == TxnType.transfer) continue;
      final pid = map[t.counterparty!.trim().toLowerCase()];
      if (pid != null) {
        await linkTxn(t, pid);
        n++;
      }
    }
    return n;
  }
}
__END__

############################ lib/data/backup.dart ############################
cat > lib/data/backup.dart <<'__END__'
import 'dart:convert';

import 'db.dart';

const _tables = [
  'accounts', 'categories', 'transactions', 'people', 'ledger', 'rules', 'budgets', 'goals'
];

extension Backup on AppDatabase {
  Future<String> exportJson() async {
    final data = <String, Object?>{};
    for (final t in _tables) {
      data[t] = await db.query(t);
    }
    return jsonEncode({
      'app': 'FinUp',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'tables': data,
    });
  }

  Future<bool> importJson(String json) async {
    final root = jsonDecode(json);
    if (root is! Map || root['app'] != 'FinUp' || root['tables'] is! Map) {
      return false;
    }
    final tables = root['tables'] as Map;
    await db.transaction((txn) async {
      for (final t in _tables) {
        await txn.delete(t);
      }
      for (final t in _tables) {
        final rows = tables[t];
        if (rows is! List) continue;
        for (final r in rows) {
          if (r is Map) await txn.insert(t, Map<String, Object?>.from(r));
        }
      }
    });
    return true;
  }

  Future<String> exportCsv() async {
    final cats = {for (final c in await categories()) c.id: c.name};
    final accs = {for (final a in await db.query('accounts')) a['id']: a['name']};
    final ppl = {for (final p in await db.query('people')) p['id']: p['name']};
    final rows = await db.query('transactions', orderBy: 'occurred_at DESC');
    final b = StringBuffer(
        'Date,Type,Amount,Category,Account,To account,Payee,Person,Note,Status\n');
    String esc(Object? v) => '"${(v ?? '').toString().replaceAll('"', '""')}"';
    for (final r in rows) {
      final d = DateTime.fromMillisecondsSinceEpoch(r['occurred_at'] as int);
      b.writeln([
        d.toIso8601String().substring(0, 16).replaceAll('T', ' '),
        r['type'],
        r['amount'],
        cats[r['category_id']] ?? '',
        accs[r['account_id']] ?? '',
        accs[r['to_account_id']] ?? '',
        r['counterparty'],
        ppl[r['person_id']] ?? '',
        r['note'],
        r['status'],
      ].map(esc).join(','));
    }
    return b.toString();
  }

  Future<void> wipeAll() async {
    for (final t in ['accounts', 'transactions', 'people', 'ledger', 'rules', 'budgets', 'goals']) {
      await db.delete(t);
    }
  }
}
__END__

############################ lib/security/lock.dart ############################
cat > lib/security/lock.dart <<'__END__'
import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../native.dart';
import '../theme.dart';
import '../widgets/logo.dart';

class LockPrefs {
  static String _hash(String pin) =>
      sha256.convert(utf8.encode('finup:$pin')).toString();

  static Future<bool> enabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getString('pinHash') != null;
  }

  static Future<bool> biometric() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool('bioOn') ?? false;
  }

  static Future<void> setPin(String pin) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('pinHash', _hash(pin));
  }

  static Future<void> setBiometric(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('bioOn', v);
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('pinHash');
    await p.remove('bioOn');
  }

  static Future<bool> check(String pin) async {
    final p = await SharedPreferences.getInstance();
    return p.getString('pinHash') == _hash(pin);
  }
}

class AppLockGate extends StatefulWidget {
  final Widget child;
  const AppLockGate({super.key, required this.child});

  static int _suspend = 0;

  /// Use while opening system screens (file picker, share sheet, fingerprint)
  /// so returning from them does not lock the app.
  static Future<T> suspendWhile<T>(Future<T> Function() f) async {
    _suspend++;
    try {
      return await f();
    } finally {
      Future.delayed(const Duration(seconds: 2), () => _suspend--);
    }
  }

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  bool _locked = false;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    final p = await SharedPreferences.getInstance();
    final on = p.getString('pinHash') != null && (p.getBool('onboarded') ?? false);
    if (on && mounted) setState(() => _locked = true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _pausedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      _onResume();
    }
  }

  Future<void> _onResume() async {
    final at = _pausedAt;
    _pausedAt = null;
    if (at == null || AppLockGate._suspend > 0) return;
    if (DateTime.now().difference(at) < const Duration(seconds: 30)) return;
    if (await LockPrefs.enabled() && mounted) setState(() => _locked = true);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      widget.child,
      if (_locked)
        Positioned.fill(
          child: LockScreen(onUnlocked: () => setState(() => _locked = false)),
        ),
    ]);
  }
}

class PinDots extends StatelessWidget {
  final int length;
  final bool error;
  const PinDots({super.key, required this.length, this.error = false});

  @override
  Widget build(BuildContext context) {
    final c = error ? AppColors.expense : AppColors.lavender;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        4,
        (i) => AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i < length ? c : Colors.transparent,
            border: Border.all(color: error ? c : Colors.white54, width: 2),
          ),
        ),
      ),
    );
  }
}

class PinPad extends StatelessWidget {
  final ValueChanged<String> onKey;
  final Widget? extra;
  const PinPad({super.key, required this.onKey, this.extra});

  Widget _btn(String k) {
    return SizedBox(
      width: 76,
      height: 76,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          HapticFeedback.selectionClick();
          onKey(k);
        },
        child: Center(
          child: k == '<'
              ? const Icon(Icons.backspace_outlined, color: Colors.white)
              : Text(k,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];
    return Column(children: [
      for (final r in rows)
        Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [for (final k in r) _btn(k)]),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        SizedBox(width: 76, height: 76, child: Center(child: extra)),
        _btn('0'),
        _btn('<'),
      ]),
    ]);
  }
}

class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const LockScreen({super.key, required this.onUnlocked});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _pin = '';
  int _errors = 0;
  bool _bio = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initBio());
  }

  Future<void> _initBio() async {
    final on = await LockPrefs.biometric();
    final can = await Native.canBiometric();
    if (!mounted) return;
    setState(() => _bio = on && can);
    if (_bio) _authBio();
  }

  Future<void> _authBio() async {
    final ok = await AppLockGate.suspendWhile(
        () => Native.authenticate('Use your fingerprint to unlock'));
    if (ok && mounted) widget.onUnlocked();
  }

  Future<void> _key(String k) async {
    if (k == '<') {
      if (_pin.isNotEmpty) setState(() => _pin = _pin.substring(0, _pin.length - 1));
      return;
    }
    if (_pin.length >= 4) return;
    setState(() => _pin = '$_pin$k');
    if (_pin.length == 4) {
      final ok = await LockPrefs.check(_pin);
      if (!mounted) return;
      if (ok) {
        widget.onUnlocked();
      } else {
        HapticFeedback.heavyImpact();
        setState(() {
          _errors++;
          _pin = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: SafeArea(
        child: Column(children: [
          const Spacer(),
          const FinUpLogo(size: 64),
          const SizedBox(height: 18),
          Text('Enter your PIN',
              style: AppText.display(size: 20, color: Colors.white)),
          const SizedBox(height: 26),
          TweenAnimationBuilder<double>(
            key: ValueKey(_errors),
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 450),
            builder: (context, v, child) => Transform.translate(
              offset: Offset(
                  _errors == 0 ? 0 : math.sin(v * math.pi * 6) * 14 * (1 - v), 0),
              child: child,
            ),
            child: PinDots(length: _pin.length),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 20,
            child: _errors > 0
                ? const Text('Wrong PIN, try again',
                    style: TextStyle(color: AppColors.pink))
                : null,
          ),
          const Spacer(),
          PinPad(
            onKey: _key,
            extra: _bio
                ? IconButton(
                    onPressed: _authBio,
                    icon: const Icon(Icons.fingerprint_rounded,
                        color: AppColors.lavender, size: 36))
                : null,
          ),
          const SizedBox(height: 28),
        ]),
      ),
    );
  }
}

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  String _first = '';
  String _pin = '';
  bool _confirm = false;
  bool _error = false;

  Future<void> _key(String k) async {
    if (k == '<') {
      if (_pin.isNotEmpty) setState(() => _pin = _pin.substring(0, _pin.length - 1));
      return;
    }
    if (_pin.length >= 4) return;
    setState(() {
      _pin = '$_pin$k';
      _error = false;
    });
    if (_pin.length < 4) return;
    await Future.delayed(const Duration(milliseconds: 150));
    if (!_confirm) {
      setState(() {
        _first = _pin;
        _pin = '';
        _confirm = true;
      });
    } else if (_pin == _first) {
      final nav = Navigator.of(context);
      await LockPrefs.setPin(_pin);
      nav.pop(true);
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _pin = '';
        _first = '';
        _confirm = false;
        _error = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('App lock'),
      ),
      body: SafeArea(
        child: Column(children: [
          const Spacer(),
          const FinUpLogo(size: 56),
          const SizedBox(height: 18),
          Text(_confirm ? 'Confirm your PIN' : 'Create a 4-digit PIN',
              style: AppText.display(size: 20, color: Colors.white)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _error
                  ? 'PINs did not match. Start again.'
                  : 'If you forget it, the only way back in is clearing app data, so keep a backup.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: _error ? AppColors.pink : Colors.white54, height: 1.4),
            ),
          ),
          const SizedBox(height: 26),
          PinDots(length: _pin.length, error: _error),
          const Spacer(),
          PinPad(onKey: _key),
          const SizedBox(height: 28),
        ]),
      ),
    );
  }
}
__END__

############################ lib/screens/people_screen.dart ############################
cat > lib/screens/people_screen.dart <<'__END__'
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/db.dart';
import '../data/people_repo.dart';
import '../state/app_state.dart';
import '../state/txn_state.dart';
import '../theme.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/txn_tile.dart';
import 'ledger_entry_screen.dart';
import 'person_detail_screen.dart';

String initials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
  return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
}

class Avatar extends StatelessWidget {
  final String name;
  final int id;
  final double size;
  const Avatar({super.key, required this.name, required this.id, this.size = 46});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration:
          BoxDecoration(gradient: AppColors.gradientAt(id), shape: BoxShape.circle),
      child: Center(
        child: Text(initials(name),
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.36)),
      ),
    );
  }
}

Future<int?> editPerson(BuildContext context, {Person? person, String? upi}) async {
  final name = TextEditingController(text: person?.name ?? '');
  final phone = TextEditingController(text: person?.phone ?? '');
  final upis = TextEditingController(
      text: person != null ? person.upis.join(', ') : (upi ?? ''));
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(person == null ? 'New person' : 'Edit person'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: name,
            autofocus: person == null,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Name'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(hintText: 'Phone (optional)'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: upis,
            decoration: const InputDecoration(
                hintText: 'UPI IDs, comma separated (optional)'),
          ),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(d, true), child: const Text('Save')),
      ],
    ),
  );
  final n = name.text.trim();
  if (ok != true || n.isEmpty) return null;
  final ph = phone.text.trim().isEmpty ? null : phone.text.trim();
  final list = upis.text
      .split(',')
      .map((s) => s.trim().toLowerCase())
      .where((s) => s.isNotEmpty)
      .toList();
  final db = AppDatabase.instance;
  if (person == null) return db.insertPerson(n, phone: ph, upis: list);
  await db.updatePerson(
      Person(id: person.id, name: n, phone: ph, upis: list, note: person.note));
  return person.id;
}

Future<int?> pickPerson(BuildContext context,
    {String? suggestFor, String title = 'Choose person'}) async {
  final fin = context.fin;
  final people = await AppDatabase.instance.people();
  if (!context.mounted) return null;
  final raw = (suggestFor ?? '').trim().toLowerCase();
  final handle = raw.split('@').first;
  Person? found;
  if (handle.isNotEmpty) {
    for (final p in people) {
      final first = p.name.toLowerCase().split(' ').first;
      if (p.upis.contains(raw) || (first.length >= 3 && handle.contains(first))) {
        found = p;
        break;
      }
    }
  }
  final sug = found;
  final picked = await showModalBottomSheet<int>(
    context: context,
    backgroundColor: fin.card,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (c) => SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.75),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          children: [
            Text(title, style: AppText.display(size: 18, color: fin.text)),
            if (raw.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(prettyParty(suggestFor),
                    style: TextStyle(color: fin.subtext)),
              ),
            const SizedBox(height: 12),
            if (sug != null) ...[
              const Text('Suggested',
                  style: TextStyle(
                      color: AppColors.lavender,
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Avatar(name: sug.name, id: sug.id, size: 42),
                title: Text('Is this ${sug.name}?'),
                trailing:
                    const Icon(Icons.check_circle_rounded, color: AppColors.income),
                onTap: () => Navigator.pop(c, sug.id),
              ),
              const Divider(),
            ],
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                    color: AppColors.lavender.withValues(alpha: 0.18),
                    shape: BoxShape.circle),
                child: const Icon(Icons.person_add_alt_1_rounded,
                    color: AppColors.lavender),
              ),
              title: const Text('New person'),
              onTap: () => Navigator.pop(c, -1),
            ),
            for (final p in people)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Avatar(name: p.name, id: p.id, size: 42),
                title: Text(p.name),
                onTap: () => Navigator.pop(c, p.id),
              ),
          ],
        ),
      ),
    ),
  );
  if (picked == -1) {
    if (!context.mounted) return null;
    return editPerson(context, upi: raw.contains('@') ? raw : null);
  }
  return picked;
}

Future<void> linkTxnToPerson(BuildContext context, Txn txn) async {
  final txns = context.read<TxnState>();
  final messenger = ScaffoldMessenger.of(context);
  final id = await pickPerson(context,
      suggestFor: txn.counterparty,
      title: txn.type == TxnType.income ? 'Who paid you?' : 'Who did you give it to?');
  if (id == null) return;
  await AppDatabase.instance.linkTxn(txn, id);
  await txns.load();
  final hasUpi = (txn.counterparty ?? '').contains('@');
  messenger.showSnackBar(SnackBar(
      content: Text(hasUpi
          ? 'Linked. Future payments to ${prettyParty(txn.counterparty)} will link automatically.'
          : 'Linked to the people ledger.')));
}

void openPeopleEntry(BuildContext context, {int? personId}) {
  Navigator.of(context).push(fadeRoute(LedgerEntryScreen(personId: personId)));
}

class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key});

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  Future<List<PersonSummary>>? _future;
  int _version = -1;

  void _open(Widget page) => Navigator.of(context).push(fadeRoute(page));

  Future<void> _add() async {
    final txns = context.read<TxnState>();
    final id = await editPerson(context);
    if (id != null) await txns.load();
  }

  Widget _sum(String label, double v, Color color, bool hide) {
    return Column(children: [
      Text(label, style: const TextStyle(color: Colors.white70)),
      const SizedBox(height: 4),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(hide ? '₹ ••••' : inr(v, decimals: 0),
            style: AppText.display(size: 22, color: color)),
      ),
    ]);
  }

  Widget _heroBtn(IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    final txns = context.watch<TxnState>();
    final hide = context.watch<SettingsState>().hideAmounts;
    if (_future == null || _version != txns.version) {
      _version = txns.version;
      _future = AppDatabase.instance.peopleSummaries();
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: context.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: SafeArea(
        bottom: false,
        child: FutureBuilder<List<PersonSummary>>(
          future: _future,
          builder: (context, snap) {
            final list = snap.data ?? const <PersonSummary>[];
            double toGet = 0;
            double toPay = 0;
            for (final s in list) {
              if (s.balance > 0) {
                toGet += s.balance;
              } else {
                toPay += -s.balance;
              }
            }
            final soon = DateTime.now().add(const Duration(days: 7));
            final due = list
                .where((s) => s.nextDue != null && s.nextDue!.isBefore(soon))
                .toList()
              ..sort((a, b) => a.nextDue!.compareTo(b.nextDue!));

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
              children: [
                Row(children: [
                  Expanded(
                      child: Text('People',
                          style: AppText.display(size: 26, color: fin.text))),
                  IconButton(
                      onPressed: _add,
                      icon: const Icon(Icons.person_add_alt_1_rounded)),
                ]),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      color: fin.hero, borderRadius: BorderRadius.circular(26)),
                  child: Column(children: [
                    Row(children: [
                      Expanded(child: _sum("You'll get", toGet, AppColors.income, hide)),
                      Container(width: 1, height: 44, color: Colors.white24),
                      Expanded(child: _sum('You owe', toPay, AppColors.pink, hide)),
                    ]),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                          child: _heroBtn(Icons.swap_vert_rounded, 'Gave / Got',
                              () => openPeopleEntry(context))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _heroBtn(Icons.call_split_rounded, 'Split a bill',
                              () => _open(const SplitBillScreen()))),
                    ]),
                  ]),
                ),
                if (due.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('Due soon',
                      style: TextStyle(
                          color: fin.text, fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  for (final s in due.take(3))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: fin.card,
                        borderRadius: BorderRadius.circular(18),
                        child: ListTile(
                          leading: Avatar(name: s.person.name, id: s.person.id, size: 38),
                          title: Text(s.person.name),
                          subtitle: Text(hide ? '' : '${inr(s.balance, decimals: 0)} pending'),
                          trailing: Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: (s.nextDue!.isBefore(DateTime.now())
                                      ? AppColors.expense
                                      : kAmber)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              s.nextDue!.isBefore(DateTime.now())
                                  ? 'Overdue'
                                  : 'Due ${DateFormat('d MMM').format(s.nextDue!)}',
                              style: TextStyle(
                                  color: s.nextDue!.isBefore(DateTime.now())
                                      ? AppColors.expense
                                      : kAmber,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12),
                            ),
                          ),
                          onTap: () => _open(PersonDetailScreen(personId: s.person.id)),
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 20),
                if (list.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(children: [
                      const Icon(Icons.people_alt_rounded,
                          size: 56, color: AppColors.lavender),
                      const SizedBox(height: 14),
                      Text('No one here yet',
                          style: AppText.display(size: 20, color: fin.text)),
                      const SizedBox(height: 8),
                      Text(
                          'Add the people you lend to or borrow from. Link UPI payments from the review inbox.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: fin.subtext, height: 1.5)),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                          onPressed: _add,
                          icon: const Icon(Icons.person_add_alt_1_rounded),
                          label: const Text('Add person')),
                    ]),
                  )
                else
                  Material(
                    color: fin.card,
                    borderRadius: BorderRadius.circular(22),
                    clipBehavior: Clip.antiAlias,
                    child: Column(children: [
                      for (final s in list)
                        ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          leading: Avatar(name: s.person.name, id: s.person.id),
                          title: Text(s.person.name,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(s.lastAt == null
                              ? 'No entries yet'
                              : 'Last entry: ${dayLabel(s.lastAt!)}'),
                          trailing: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                s.balance.abs() < 0.01
                                    ? 'Settled'
                                    : (s.balance > 0 ? 'owes you' : 'you owe'),
                                style: TextStyle(color: fin.subtext, fontSize: 11.5),
                              ),
                              Text(
                                hide ? '••••' : inr(s.balance.abs(), decimals: 0),
                                style: TextStyle(
                                    color: s.balance > 0.009
                                        ? AppColors.income
                                        : (s.balance < -0.009
                                            ? AppColors.expense
                                            : fin.subtext),
                                    fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                          onTap: () => _open(PersonDetailScreen(personId: s.person.id)),
                        ),
                    ]),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
__END__

############################ lib/screens/person_detail_screen.dart ############################
cat > lib/screens/person_detail_screen.dart <<'__END__'
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/db.dart';
import '../data/people_repo.dart';
import '../native.dart';
import '../security/lock.dart';
import '../state/app_state.dart';
import '../state/txn_state.dart';
import '../theme.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/logo.dart';
import 'ledger_entry_screen.dart';
import 'people_screen.dart';

class PersonDetailScreen extends StatefulWidget {
  final int personId;
  const PersonDetailScreen({super.key, required this.personId});

  @override
  State<PersonDetailScreen> createState() => _PersonDetailScreenState();
}

class _PersonDetailScreenState extends State<PersonDetailScreen> {
  Future<(Person?, List<LedgerEntry>)>? _future;
  int _version = -1;

  Future<(Person?, List<LedgerEntry>)> _load() async {
    final db = AppDatabase.instance;
    return (await db.person(widget.personId), await db.entries(widget.personId));
  }

  void _open(Widget page) => Navigator.of(context).push(fadeRoute(page));

  Future<void> _delete(Person p) async {
    final txns = context.read<TxnState>();
    final accounts = context.read<AccountsState>();
    final nav = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Delete ${p.name}?'),
        content: const Text(
            'All ledger entries with this person are removed. Linked bank SMS go back to your review inbox.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Delete',
                  style: TextStyle(color: AppColors.expense))),
        ],
      ),
    );
    if (ok != true) return;
    await AppDatabase.instance.deletePerson(p.id);
    await accounts.load();
    await txns.load();
    nav.pop();
  }

  Widget _action(IconData icon, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: Material(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(children: [
              Icon(icon, color: color),
              const SizedBox(height: 4),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12.5)),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    final txns = context.watch<TxnState>();
    final hide = context.watch<SettingsState>().hideAmounts;
    if (_future == null || _version != txns.version) {
      _version = txns.version;
      _future = _load();
    }
    return FutureBuilder<(Person?, List<LedgerEntry>)>(
      future: _future,
      builder: (context, snap) {
        final p = snap.data?.$1;
        final entries = snap.data?.$2 ?? const <LedgerEntry>[];
        if (p == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
                child: snap.connectionState == ConnectionState.done
                    ? const Text('Person not found')
                    : const CircularProgressIndicator()),
          );
        }
        final balance = entries.fold<double>(0, (a, e) => a + e.signed);
        final label = balance > 0.009
            ? '${p.name} owes you'
            : (balance < -0.009 ? 'You owe ${p.name}' : 'All settled');
        final now = DateTime.now();
        return Scaffold(
          appBar: AppBar(
            title: Text(p.name),
            actions: [
              IconButton(
                tooltip: 'Statement',
                onPressed: () => _open(StatementScreen(
                    person: p, entries: entries, balance: balance)),
                icon: const Icon(Icons.ios_share_rounded),
              ),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'edit') {
                    final t = context.read<TxnState>();
                    final id = await editPerson(context, person: p);
                    if (id != null) await t.load();
                  } else if (v == 'delete') {
                    await _delete(p);
                  }
                },
                itemBuilder: (c) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit person')),
                  PopupMenuItem(value: 'delete', child: Text('Delete person')),
                ],
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: fin.hero, borderRadius: BorderRadius.circular(26)),
                child: Column(children: [
                  Avatar(name: p.name, id: p.id, size: 64),
                  const SizedBox(height: 10),
                  if (p.upis.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final u in p.upis)
                          Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20)),
                            child: Text(u,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 11.5)),
                          ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  Text(label, style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 4),
                  Text(hide ? '₹ ••••' : inr(balance.abs(), decimals: 0),
                      style: AppText.display(
                          size: 32,
                          color: balance > 0.009
                              ? AppColors.income
                              : (balance < -0.009 ? AppColors.pink : Colors.white))),
                  const SizedBox(height: 16),
                  Row(children: [
                    _action(Icons.north_east_rounded, 'You gave', AppColors.pink,
                        () => _open(LedgerEntryScreen(personId: p.id, type: 'gave'))),
                    const SizedBox(width: 8),
                    _action(Icons.south_west_rounded, 'You got', AppColors.income,
                        () => _open(LedgerEntryScreen(personId: p.id, type: 'took'))),
                    if (balance.abs() > 0.009) ...[
                      const SizedBox(width: 8),
                      _action(
                          Icons.handshake_rounded,
                          'Settle up',
                          Colors.white,
                          () => _open(LedgerEntryScreen(
                              personId: p.id,
                              type: balance > 0 ? 'took' : 'gave',
                              amount: balance.abs(),
                              note: 'Settled up'))),
                    ],
                    if (balance > 0.009) ...[
                      const SizedBox(width: 8),
                      _action(
                          Icons.notifications_active_rounded,
                          'Remind',
                          AppColors.lavender,
                          () => AppLockGate.suspendWhile(() => Native.shareText(
                              'Hi ${p.name}, a gentle reminder about ${inr(balance, decimals: 0)} pending. Thanks!'))),
                    ],
                  ]),
                ]),
              ),
              const SizedBox(height: 20),
              Text('History',
                  style: TextStyle(
                      color: fin.text, fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              if (entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('No entries yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: fin.subtext)),
                ),
              if (entries.isNotEmpty)
                Material(
                  color: fin.card,
                  borderRadius: BorderRadius.circular(22),
                  clipBehavior: Clip.antiAlias,
                  child: Column(children: [
                    for (final e in entries)
                      ListTile(
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: (e.type == 'gave' ? AppColors.expense : AppColors.income)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(
                              e.type == 'gave'
                                  ? Icons.north_east_rounded
                                  : Icons.south_west_rounded,
                              color: e.type == 'gave'
                                  ? AppColors.expense
                                  : AppColors.income),
                        ),
                        title: Row(children: [
                          Text(e.type == 'gave' ? 'You gave' : 'You got',
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          if (e.txnId != null) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.link_rounded, size: 16, color: fin.subtext),
                          ],
                        ]),
                        subtitle: Text([
                          DateFormat('d MMM yyyy').format(e.occurredAt),
                          if (e.note != null && e.note!.isNotEmpty) e.note!,
                          if (e.dueAt != null && e.type == 'gave')
                            e.dueAt!.isBefore(now)
                                ? 'Due date passed'
                                : 'Due ${DateFormat('d MMM').format(e.dueAt!)}',
                        ].join(' · ')),
                        trailing: Text(
                          hide ? '••••' : inr(e.amount, decimals: 0),
                          style: TextStyle(
                              color: e.type == 'gave' ? AppColors.expense : AppColors.income,
                              fontWeight: FontWeight.w700),
                        ),
                        onTap: () => _open(
                            LedgerEntryScreen(personId: p.id, editing: e)),
                      ),
                  ]),
                ),
            ],
          ),
        );
      },
    );
  }
}

class StatementScreen extends StatefulWidget {
  final Person person;
  final List<LedgerEntry> entries;
  final double balance;
  const StatementScreen(
      {super.key, required this.person, required this.entries, required this.balance});

  @override
  State<StatementScreen> createState() => _StatementScreenState();
}

class _StatementScreenState extends State<StatementScreen> {
  final _key = GlobalKey();
  bool _busy = false;

  String get _summary {
    final b = widget.balance;
    final n = widget.person.name;
    if (b > 0.009) return '$n owes me ${inr(b, decimals: 0)}';
    if (b < -0.009) return 'I owe $n ${inr(-b, decimals: 0)}';
    return 'All settled with $n';
  }

  String get _text {
    final lines = <String>['Statement with ${widget.person.name}', ''];
    for (final e in widget.entries.reversed) {
      lines.add(
          '${DateFormat('d MMM yyyy').format(e.occurredAt)}  ${e.type == 'gave' ? 'I gave' : 'I got'}  ${inr(e.amount, decimals: 0)}${e.note != null && e.note!.isNotEmpty ? ' (${e.note})' : ''}');
    }
    lines.addAll(['', _summary, '— via FinUp']);
    return lines.join('\n');
  }

  Future<void> _shareImage() async {
    setState(() => _busy = true);
    try {
      final boundary =
          _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data != null) {
        final bytes = data.buffer.asUint8List();
        await AppLockGate.suspendWhile(() => Native.shareImage(
            bytes,
            'FinUp-statement-${DateTime.now().millisecondsSinceEpoch}.png',
            '$_summary (via FinUp)'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const ink = AppColors.ink;
    const grey = Color(0xFF7D7D92);
    final b = widget.balance;
    final color = b > 0.009 ? AppColors.income : (b < -0.009 ? AppColors.expense : grey);
    final gave = widget.entries
        .where((e) => e.type == 'gave')
        .fold<double>(0, (a, e) => a + e.amount);
    final got = widget.entries
        .where((e) => e.type == 'took')
        .fold<double>(0, (a, e) => a + e.amount);

    return Scaffold(
      appBar: AppBar(title: const Text('Statement')),
      body: Column(children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: RepaintBoundary(
              key: _key,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(24)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const FinUpLogo(size: 40),
                      const SizedBox(width: 10),
                      const Text('FinUp',
                          style: TextStyle(
                              color: ink, fontWeight: FontWeight.w800, fontSize: 20)),
                      const Spacer(),
                      Text(DateFormat('d MMM yyyy').format(DateTime.now()),
                          style: const TextStyle(color: grey)),
                    ]),
                    const SizedBox(height: 20),
                    const Text('Statement with', style: TextStyle(color: grey)),
                    Text(widget.person.name,
                        style: const TextStyle(
                            color: ink, fontSize: 24, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14)),
                      child: Row(children: [
                        Expanded(
                            child: Text(_summary,
                                style: TextStyle(
                                    color: color, fontWeight: FontWeight.w700))),
                      ]),
                    ),
                    const SizedBox(height: 18),
                    const Row(children: [
                      SizedBox(
                          width: 84,
                          child: Text('Date',
                              style: TextStyle(color: grey, fontSize: 12))),
                      Expanded(
                          child: Text('Details',
                              style: TextStyle(color: grey, fontSize: 12))),
                      Text('Amount', style: TextStyle(color: grey, fontSize: 12)),
                    ]),
                    const Divider(color: Color(0xFFE6E6EE)),
                    for (final e in widget.entries.reversed)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: [
                          SizedBox(
                              width: 84,
                              child: Text(DateFormat('d MMM yy').format(e.occurredAt),
                                  style: const TextStyle(color: ink, fontSize: 13))),
                          Expanded(
                            child: Text(
                              '${e.type == 'gave' ? 'You gave' : 'You got'}${e.note != null && e.note!.isNotEmpty ? ' · ${e.note}' : ''}',
                              style: const TextStyle(color: ink, fontSize: 13),
                            ),
                          ),
                          Text(
                            '${e.type == 'gave' ? '-' : '+'}${inr(e.amount, decimals: 0)}',
                            style: TextStyle(
                                color: e.type == 'gave'
                                    ? AppColors.expense
                                    : AppColors.income,
                                fontWeight: FontWeight.w700,
                                fontSize: 13),
                          ),
                        ]),
                      ),
                    const Divider(color: Color(0xFFE6E6EE)),
                    Row(children: [
                      const Expanded(
                          child: Text('Total given', style: TextStyle(color: grey))),
                      Text(inr(gave, decimals: 0),
                          style: const TextStyle(color: ink, fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Expanded(
                          child: Text('Total received', style: TextStyle(color: grey))),
                      Text(inr(got, decimals: 0),
                          style: const TextStyle(color: ink, fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 18),
                    const Text('Generated by FinUp · private and offline',
                        style: TextStyle(color: grey, fontSize: 11)),
                  ],
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(58),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18))),
                  onPressed: () =>
                      AppLockGate.suspendWhile(() => Native.shareText(_text)),
                  icon: const Icon(Icons.text_snippet_rounded),
                  label: const Text('As text'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryButton(
                  label: _busy ? 'Preparing…' : 'Share image',
                  icon: Icons.image_rounded,
                  onPressed: _busy ? null : _shareImage,
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
__END__

############################ lib/screens/ledger_entry_screen.dart ############################
cat > lib/screens/ledger_entry_screen.dart <<'__END__'
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/db.dart';
import '../data/people_repo.dart';
import '../data/repo.dart';
import '../state/app_state.dart';
import '../state/txn_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'add_txn_screen.dart';
import 'people_screen.dart';

Widget _fieldTile(FinColors fin, IconData icon, Color color, String label,
    String value, VoidCallback? onTap, {Widget? trailing}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: fin.card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: fin.subtext, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: TextStyle(
                          color: fin.text, fontWeight: FontWeight.w600, fontSize: 15)),
                ],
              ),
            ),
            trailing ?? Icon(Icons.chevron_right_rounded, color: fin.subtext),
          ]),
        ),
      ),
    ),
  );
}

class LedgerEntryScreen extends StatefulWidget {
  final int? personId;
  final String type;
  final double? amount;
  final String? note;
  final LedgerEntry? editing;

  const LedgerEntryScreen(
      {super.key,
      this.personId,
      this.type = 'gave',
      this.amount,
      this.note,
      this.editing});

  @override
  State<LedgerEntryScreen> createState() => _LedgerEntryScreenState();
}

class _LedgerEntryScreenState extends State<LedgerEntryScreen> {
  int? _personId;
  String? _personName;
  late String _type;
  final _amount = TextEditingController();
  final _note = TextEditingController();
  late DateTime _when;
  DateTime? _due;
  int? _accountId;
  bool _locked = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _personId = e?.personId ?? widget.personId;
    _type = e?.type ?? widget.type;
    _when = e?.occurredAt ?? DateTime.now();
    _due = e?.dueAt;
    final amt = e?.amount ?? widget.amount;
    if (amt != null) {
      _amount.text = amt == amt.roundToDouble()
          ? amt.toStringAsFixed(0)
          : amt.toStringAsFixed(2);
    }
    _note.text = e?.note ?? widget.note ?? '';
    _loadExtra();
  }

  Future<void> _loadExtra() async {
    final db = AppDatabase.instance;
    final pid = _personId;
    if (pid != null) {
      final p = await db.person(pid);
      if (mounted) setState(() => _personName = p?.name);
    }
    final tid = widget.editing?.txnId;
    if (tid != null) {
      final t = await db.txnById(tid);
      if (t != null && mounted) {
        setState(() {
          _accountId = t.accountId;
          _locked = t.smsBody != null;
        });
      }
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  double get _value => double.tryParse(_amount.text.replaceAll(',', '').trim()) ?? 0;
  bool get _valid => !_saving && _personId != null && _value > 0;

  String _accName(int? id) {
    if (id == null) return 'Not linked to an account';
    for (final a in context.read<AccountsState>().accounts) {
      if (a.id == id) return a.name;
    }
    return 'Account';
  }

  Future<void> _pickPerson() async {
    final id = await pickPerson(context);
    if (id == null) return;
    final p = await AppDatabase.instance.person(id);
    if (mounted) {
      setState(() {
        _personId = id;
        _personName = p?.name;
      });
    }
  }

  Future<void> _pickAccount() async {
    final fin = context.fin;
    final accounts = context.read<AccountsState>().accounts;
    final res = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: fin.card,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.block_rounded),
              title: const Text('Not linked to an account'),
              subtitle: const Text('Only the ledger is updated'),
              onTap: () => Navigator.pop(c, -1),
            ),
            for (final a in accounts)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      gradient: AppColors.gradientAt(a.colorIndex),
                      shape: BoxShape.circle),
                  child: Icon(a.type.icon, color: Colors.white, size: 20),
                ),
                title: Text(a.name),
                subtitle: Text(inr(a.balance)),
                onTap: () => Navigator.pop(c, a.id),
              ),
          ],
        ),
      ),
    );
    if (res == null) return;
    setState(() => _accountId = res == -1 ? null : res);
  }

  Future<void> _pickDate({required bool due}) async {
    final init = due ? (_due ?? DateTime.now().add(const Duration(days: 7))) : _when;
    final d = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (d == null) return;
    setState(() {
      if (due) {
        _due = d;
      } else {
        _when = DateTime(d.year, d.month, d.day, _when.hour, _when.minute);
      }
    });
  }

  Future<void> _save() async {
    final txns = context.read<TxnState>();
    final accounts = context.read<AccountsState>();
    final nav = Navigator.of(context);
    setState(() => _saving = true);
    final db = AppDatabase.instance;
    final note = _note.text.trim().isEmpty ? null : _note.text.trim();
    final due = _type == 'gave' ? _due : null;
    final e = widget.editing;
    if (e != null) {
      await db.updateEntry(e,
          type: _type,
          amount: _value,
          note: note,
          dueAt: due,
          when: _when,
          accountId: _accountId,
          personName: _personName);
    } else {
      await db.addEntry(
          personId: _personId!,
          type: _type,
          amount: _value,
          note: note,
          dueAt: due,
          when: _when,
          accountId: _accountId,
          personName: _personName);
    }
    await accounts.load();
    await txns.load();
    nav.pop();
  }

  Future<void> _delete() async {
    final txns = context.read<TxnState>();
    final accounts = context.read<AccountsState>();
    final nav = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete entry?'),
        content: const Text('Any linked account balance is adjusted back.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Delete', style: TextStyle(color: AppColors.expense))),
        ],
      ),
    );
    if (ok != true) return;
    await AppDatabase.instance.deleteEntry(widget.editing!);
    await accounts.load();
    await txns.load();
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    final gave = _type == 'gave';
    final color = gave ? AppColors.expense : AppColors.income;

    Widget typeItem(String v, String label, Color c) {
      final sel = _type == v;
      return Expanded(
        child: GestureDetector(
          onTap: _locked ? null : () => setState(() => _type = v),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
                color: sel ? c : Colors.transparent,
                borderRadius: BorderRadius.circular(14)),
            child: Center(
              child: Text(label,
                  style: TextStyle(
                      color: sel ? Colors.white : fin.subtext,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editing == null ? 'Lend or borrow' : 'Edit entry'),
        actions: [
          if (widget.editing != null)
            IconButton(onPressed: _delete, icon: const Icon(Icons.delete_rounded)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
                color: fin.card, borderRadius: BorderRadius.circular(18)),
            child: Row(children: [
              typeItem('gave', 'You gave', AppColors.expense),
              typeItem('took', 'You got', AppColors.income),
            ]),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _amount,
            enabled: !_locked,
            autofocus: widget.editing == null && widget.amount == null,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: AppText.display(size: 30, color: color),
            decoration: const InputDecoration(prefixText: '₹ ', hintText: '0'),
            onChanged: (_) => setState(() {}),
          ),
          if (_locked)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text('Amount comes from a bank SMS and cannot be changed.',
                  style: TextStyle(color: fin.subtext, fontSize: 12)),
            ),
          const SizedBox(height: 14),
          _fieldTile(fin, Icons.person_rounded, AppColors.lavender, 'Person',
              _personName ?? 'Choose person', _locked ? null : _pickPerson),
          _fieldTile(fin, Icons.calendar_month_rounded, AppColors.income, 'Date',
              DateFormat('EEE, d MMM yyyy').format(_when),
              _locked ? null : () => _pickDate(due: false)),
          if (gave)
            _fieldTile(
              fin,
              Icons.event_available_rounded,
              const Color(0xFFF6A23A),
              'Expect it back by (optional)',
              _due == null ? 'No due date' : DateFormat('d MMM yyyy').format(_due!),
              () => _pickDate(due: true),
              trailing: _due == null
                  ? null
                  : IconButton(
                      onPressed: () => setState(() => _due = null),
                      icon: const Icon(Icons.close_rounded)),
            ),
          _fieldTile(
              fin,
              Icons.account_balance_wallet_rounded,
              AppColors.pink,
              gave ? 'Paid from account' : 'Received into account',
              _accName(_accountId),
              _locked ? null : _pickAccount),
          TextField(
            controller: _note,
            decoration: const InputDecoration(
                hintText: 'Note (optional)', prefixIcon: Icon(Icons.edit_note_rounded)),
          ),
          const SizedBox(height: 10),
          Text('Lending and borrowing is not counted as spending or income.',
              style: TextStyle(color: fin.subtext, fontSize: 12)),
          const SizedBox(height: 24),
          PrimaryButton(
              label: widget.editing == null ? 'Save entry' : 'Update entry',
              icon: Icons.check_rounded,
              onPressed: _valid ? _save : null),
        ],
      ),
    );
  }
}

class SplitBillScreen extends StatefulWidget {
  const SplitBillScreen({super.key});

  @override
  State<SplitBillScreen> createState() => _SplitBillScreenState();
}

class _SplitBillScreenState extends State<SplitBillScreen> {
  final _amount = TextEditingController();
  final _desc = TextEditingController();
  int? _accountId;
  int? _categoryId;
  bool _includeMe = true;
  final Set<int> _selected = {};
  List<Person> _people = [];
  final DateTime _when = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final accounts = context.read<AccountsState>().accounts;
    if (accounts.isNotEmpty) _accountId = accounts.first.id;
    _loadPeople();
  }

  Future<void> _loadPeople() async {
    final list = await AppDatabase.instance.people();
    if (mounted) setState(() => _people = list);
  }

  @override
  void dispose() {
    _amount.dispose();
    _desc.dispose();
    super.dispose();
  }

  double get _total => double.tryParse(_amount.text.replaceAll(',', '').trim()) ?? 0;
  int get _parts => _selected.length + (_includeMe ? 1 : 0);
  double get _share => _parts == 0 ? 0 : (_total / _parts * 100).floorToDouble() / 100;
  bool get _valid => !_saving && _total > 0 && _selected.isNotEmpty && _accountId != null;

  String _accName(int? id) {
    for (final a in context.read<AccountsState>().accounts) {
      if (a.id == id) return a.name;
    }
    return 'Choose account';
  }

  Future<void> _save() async {
    final txns = context.read<TxnState>();
    final accounts = context.read<AccountsState>();
    final nav = Navigator.of(context);
    setState(() => _saving = true);
    final db = AppDatabase.instance;
    final share = _share;
    final rem = double.parse((_total - share * _parts).toStringAsFixed(2));
    final desc = _desc.text.trim().isEmpty ? 'Split bill' : _desc.text.trim();
    var first = true;
    if (_includeMe) {
      await db.addTxn(Txn(
        accountId: _accountId,
        type: TxnType.expense,
        amount: share + rem,
        categoryId: _categoryId,
        counterparty: desc,
        note: 'My share of ${inr(_total)}',
        status: _categoryId == null ? 'review' : 'done',
        occurredAt: _when,
      ));
      first = false;
    }
    for (final id in _selected) {
      Person? p;
      for (final x in _people) {
        if (x.id == id) p = x;
      }
      final amt = first ? share + rem : share;
      first = false;
      await db.addEntry(
          personId: id,
          type: 'gave',
          amount: amt,
          note: 'Split: $desc',
          when: _when,
          accountId: _accountId,
          personName: p?.name);
    }
    await accounts.load();
    await txns.load();
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    final cat = context.watch<TxnState>().category(_categoryId);
    return Scaffold(
      appBar: AppBar(title: const Text('Split a bill')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          TextField(
            controller: _amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: AppText.display(size: 30, color: AppColors.expense),
            decoration: const InputDecoration(prefixText: '₹ ', hintText: 'Total bill'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _desc,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
                hintText: 'What was it? e.g. Dinner at Barbeque Nation',
                prefixIcon: Icon(Icons.receipt_rounded)),
          ),
          const SizedBox(height: 12),
          _fieldTile(fin, Icons.account_balance_wallet_rounded, AppColors.pink,
              'You paid from', _accName(_accountId), () async {
            final id = await pickAccount(context);
            if (id != null) setState(() => _accountId = id);
          }),
          _fieldTile(fin, cat?.icon ?? Icons.category_rounded,
              cat?.colorValue ?? AppColors.lavender, 'Category for your share',
              cat?.name ?? 'Choose category', () async {
            final id = await pickCategory(context, 'expense');
            if (id != null) setState(() => _categoryId = id);
          }),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _includeMe,
            onChanged: (v) => setState(() => _includeMe = v),
            title: const Text('Include my share'),
          ),
          const SizedBox(height: 4),
          Text('Split with',
              style: TextStyle(color: fin.subtext, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in _people)
                FilterChip(
                  label: Text(p.name),
                  selected: _selected.contains(p.id),
                  onSelected: (v) => setState(() {
                    if (v) {
                      _selected.add(p.id);
                    } else {
                      _selected.remove(p.id);
                    }
                  }),
                ),
              ActionChip(
                avatar: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                label: const Text('Add person'),
                onPressed: () async {
                  final id = await editPerson(context);
                  if (id != null) {
                    await _loadPeople();
                    setState(() => _selected.add(id));
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_total > 0 && _parts > 0)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: AppColors.lavender.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Each share: ${inr(_share)}',
                      style: TextStyle(color: fin.text, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                      '${_selected.length} ${_selected.length == 1 ? 'person owes' : 'people owe'} you ${inr(_share * _selected.length)}',
                      style: TextStyle(color: fin.subtext)),
                ],
              ),
            ),
          const SizedBox(height: 24),
          PrimaryButton(
              label: 'Save split', icon: Icons.check_rounded, onPressed: _valid ? _save : null),
        ],
      ),
    );
  }
}
__END__

############################ lib/screens/legal_screen.dart ############################
cat > lib/screens/legal_screen.dart <<'__END__'
import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/logo.dart';

class LegalScreen extends StatelessWidget {
  final String title;
  final String updated;
  final List<(String, String)> sections;

  const LegalScreen(
      {super.key, required this.title, required this.updated, required this.sections});

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          Text('Last updated: $updated', style: TextStyle(color: fin.subtext)),
          const SizedBox(height: 12),
          for (final s in sections) ...[
            const SizedBox(height: 14),
            Text(s.$1,
                style: TextStyle(
                    color: fin.text, fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 6),
            Text(s.$2, style: TextStyle(color: fin.subtext, height: 1.55, fontSize: 14.5)),
          ],
        ],
      ),
    );
  }
}

const termsSections = <(String, String)>[
  ('1. About FinUp',
      'FinUp is a personal expense manager that runs entirely on your phone. It is intended for personal, non-commercial use by the owner of the device.'),
  ('2. Your data and backups',
      'All information you enter or that FinUp reads is stored only on this device. You are responsible for keeping backups. Uninstalling the app or clearing its data permanently deletes everything unless you have exported a backup file.'),
  ('3. SMS reading',
      'With your permission, FinUp reads SMS messages on this device to detect bank transactions. Automatic reading can occasionally misread amounts, accounts or balances. Always check important figures against your official bank statement.'),
  ('4. Not financial advice',
      'Charts, budgets, goals and summaries are for personal tracking only. They are not financial, tax, legal or investment advice.'),
  ('5. People ledger',
      'Amounts recorded with other people are personal notes. FinUp does not collect, request or move money, and entries are not legal proof of a debt.'),
  ('6. App lock',
      'If you set a PIN and forget it, the only way to regain access is to clear the app data, which deletes all records. Keep a backup.'),
  ('7. No warranty',
      'FinUp is provided "as is", without warranties of any kind, including accuracy, availability or fitness for a particular purpose.'),
  ('8. Limitation of liability',
      'To the extent permitted by law, the developer is not liable for any loss arising from use of the app, including data loss or decisions made based on its information.'),
  ('9. Changes',
      'These terms may change when the app is updated. Continuing to use FinUp after an update means you accept the updated terms.'),
  ('10. Governing law', 'These terms are governed by the laws of India.'),
];

const privacySections = <(String, String)>[
  ('Summary',
      'FinUp has no servers, no user accounts, no ads and no analytics. Your financial data never leaves your phone unless you choose to share or export it.'),
  ('SMS permission',
      'FinUp reads your SMS inbox only to find bank transaction messages (amount, account digits, UPI ID, reference number, balance, date and time). Messages without a money amount are skipped before they reach the app. Other messages are never stored.'),
  ('What is stored',
      'Accounts, transactions, categories, rules, budgets, goals, people you add (names, optional phone numbers and UPI IDs) and your settings. Everything is kept in a private database inside the app on this device.'),
  ('Notifications',
      'Used only for your daily review reminder at the time you choose.'),
  ('Fingerprint',
      'Fingerprint unlock is handled entirely by Android. FinUp never receives or stores your fingerprint data. Your PIN is stored only as a one-way hash.'),
  ('Internet',
      'The app may use the internet only to download its fonts. No financial or personal data is ever sent.'),
  ('Sharing and exports',
      'Data leaves the app only when you tap Share, Backup or Export, and only to the place you pick. Shared statement images are also saved to Pictures/FinUp on your phone.'),
  ('Your control',
      'You can export a CSV, back up or restore your data, delete everything from Settings, and withdraw SMS or notification permission at any time in Android settings.'),
  ('Contact',
      'This copy of FinUp is built and maintained by its owner for personal use.'),
];

class AboutFinUpScreen extends StatelessWidget {
  const AboutFinUpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    void open(Widget p) => Navigator.of(context).push(fadeRoute(p));
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          const Center(child: FinUpLogo(size: 96)),
          const SizedBox(height: 16),
          Center(child: Text('FinUp', style: AppText.display(size: 30, color: fin.text))),
          Center(
              child: Text('Version 2.0.0', style: TextStyle(color: fin.subtext))),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Your money, auto-tracked. Private. Offline. Yours.',
              textAlign: TextAlign.center,
              style: TextStyle(color: fin.subtext, height: 1.5),
            ),
          ),
          const SizedBox(height: 28),
          Material(
            color: fin.card,
            borderRadius: BorderRadius.circular(22),
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.gavel_rounded),
                title: const Text('Terms & Conditions'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => open(const LegalScreen(
                    title: 'Terms & Conditions',
                    updated: '13 October 2026',
                    sections: termsSections)),
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_rounded),
                title: const Text('Privacy Policy'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => open(const LegalScreen(
                    title: 'Privacy Policy',
                    updated: '13 October 2026',
                    sections: privacySections)),
              ),
              const ListTile(
                leading: Icon(Icons.code_rounded),
                title: Text('Built with Flutter'),
                subtitle: Text('No cloud, no tracking, no ads'),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
__END__

############################ lib/screens/settings_screen.dart ############################
cat > lib/screens/settings_screen.dart <<'__END__'
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/backup.dart';
import '../data/db.dart';
import '../native.dart';
import '../security/lock.dart';
import '../state/app_state.dart';
import '../state/txn_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'account_editor.dart';
import 'budgets_screen.dart';
import 'categories_screen.dart';
import 'goals_screen.dart';
import 'intro_screen.dart';
import 'legal_screen.dart';
import 'sms_setup_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _remOn = true;
  bool _lockOn = false;
  bool _bioOn = false;
  bool _canBio = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final rem = await ReminderPrefs.isOn();
    final lock = await LockPrefs.enabled();
    final bio = await LockPrefs.biometric();
    final can = await Native.canBiometric();
    if (!mounted) return;
    setState(() {
      _remOn = rem;
      _lockOn = lock;
      _bioOn = bio;
      _canBio = can;
    });
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _open(Widget page) => Navigator.of(context).push(fadeRoute(page));

  Future<void> _editName(SettingsState s) async {
    final c = TextEditingController(text: s.userName);
    final result = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(
            controller: c, autofocus: true, textCapitalization: TextCapitalization.words),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(d, c.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) await s.setUserName(result);
  }

  Future<void> _pickTime(SettingsState s) async {
    final picked = await showTimePicker(context: context, initialTime: s.reminderTime);
    if (picked == null) return;
    await s.setReminderTime(picked);
    await Native.requestNotifications();
    await Native.scheduleReminder(picked.hour, picked.minute, _remOn);
  }

  Future<void> _toggleReminder(SettingsState s, bool v) async {
    setState(() => _remOn = v);
    await ReminderPrefs.setOn(v);
    if (v) await Native.requestNotifications();
    await Native.scheduleReminder(s.reminderTime.hour, s.reminderTime.minute, v);
  }

  Future<void> _toggleLock(bool v) async {
    if (v) {
      final ok = await Navigator.of(context)
          .push<bool>(fadeRoute<bool>(const PinSetupScreen()));
      if (ok == true && mounted) {
        setState(() => _lockOn = true);
        _snack('App lock is on.');
      }
    } else {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Turn off app lock?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Turn off')),
          ],
        ),
      );
      if (ok == true) {
        await LockPrefs.clear();
        if (mounted) {
          setState(() {
            _lockOn = false;
            _bioOn = false;
          });
        }
      }
    }
  }

  Future<void> _toggleBio(bool v) async {
    if (v) {
      final ok = await AppLockGate.suspendWhile(
          () => Native.authenticate('Confirm your fingerprint'));
      if (!ok) return;
    }
    await LockPrefs.setBiometric(v);
    if (mounted) setState(() => _bioOn = v);
  }

  Future<void> _rescan() async {
    final txns = context.read<TxnState>();
    final accounts = context.read<AccountsState>();
    final since =
        DateTime.now().subtract(const Duration(days: 90)).millisecondsSinceEpoch;
    final n = await txns.sync(accounts, sinceMs: since);
    if (mounted) {
      _snack(n == 0 ? 'No new transactions found.' : 'Added $n new transactions.');
    }
  }

  String get _stamp => DateFormat('yyyyMMdd-HHmm').format(DateTime.now());

  Future<void> _backup() async {
    setState(() => _busy = true);
    final json = await AppDatabase.instance.exportJson();
    final ok = await AppLockGate.suspendWhile(() => Native.saveDocument(
        'FinUp-backup-$_stamp.json',
        'application/json',
        Uint8List.fromList(utf8.encode(json))));
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) _snack('Backup saved.');
  }

  Future<void> _exportCsv() async {
    setState(() => _busy = true);
    final csv = await AppDatabase.instance.exportCsv();
    final ok = await AppLockGate.suspendWhile(() => Native.saveDocument(
        'FinUp-transactions-$_stamp.csv',
        'text/csv',
        Uint8List.fromList(utf8.encode(csv))));
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) _snack('CSV exported.');
  }

  Future<void> _restore() async {
    final accounts = context.read<AccountsState>();
    final txns = context.read<TxnState>();
    final go = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Restore a backup?'),
        content: const Text(
            'Everything currently in FinUp will be replaced by the backup file you choose.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Choose file')),
        ],
      ),
    );
    if (go != true) return;
    final bytes = await AppLockGate.suspendWhile(() => Native.openDocument());
    if (bytes == null) return;
    var ok = false;
    try {
      ok = await AppDatabase.instance.importJson(utf8.decode(bytes));
    } catch (_) {
      ok = false;
    }
    if (ok) {
      await accounts.load();
      await txns.load();
    }
    if (mounted) _snack(ok ? 'Backup restored.' : 'That file is not a FinUp backup.');
  }

  Future<void> _deleteAll() async {
    final settings = context.read<SettingsState>();
    final accounts = context.read<AccountsState>();
    final txns = context.read<TxnState>();
    final nav = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete all data?'),
        content: const Text(
            'This removes all accounts, transactions, people, budgets, goals and settings from this phone. Make a backup first if you might need it. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Delete everything',
                  style: TextStyle(color: AppColors.expense))),
        ],
      ),
    );
    if (ok != true) return;
    await AppDatabase.instance.wipeAll();
    final p = await SharedPreferences.getInstance();
    await p.clear();
    await Native.scheduleReminder(21, 0, false);
    await settings.load();
    await settings.setThemeMode(ThemeMode.system);
    await accounts.load();
    await txns.load();
    nav.pushAndRemoveUntil(fadeRoute(const IntroScreen()), (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsState>();
    final txns = context.watch<TxnState>();
    final accounts = context.watch<AccountsState>().accounts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        bottom: _busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2), child: LinearProgressIndicator())
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        children: [
          _Section(title: 'Profile', children: [
            ListTile(
              leading: const Icon(Icons.person_rounded),
              title: const Text('Name'),
              subtitle: Text(s.userName.isEmpty ? 'Not set' : s.userName),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _editName(s),
            ),
          ]),
          _Section(title: 'Appearance', children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('Light'),
                        icon: Icon(Icons.light_mode_rounded)),
                    ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text('Dark'),
                        icon: Icon(Icons.dark_mode_rounded)),
                    ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('System'),
                        icon: Icon(Icons.brightness_auto_rounded)),
                  ],
                  selected: {s.themeMode},
                  showSelectedIcon: false,
                  onSelectionChanged: (v) => s.setThemeMode(v.first),
                ),
              ),
            ),
          ]),
          _Section(title: 'Security', children: [
            SwitchListTile(
              secondary: const Icon(Icons.lock_rounded),
              title: const Text('App lock'),
              subtitle: const Text('Ask for a PIN when opening FinUp'),
              value: _lockOn,
              onChanged: _toggleLock,
            ),
            if (_lockOn && _canBio)
              SwitchListTile(
                secondary: const Icon(Icons.fingerprint_rounded),
                title: const Text('Unlock with fingerprint'),
                value: _bioOn,
                onChanged: _toggleBio,
              ),
            if (_lockOn)
              ListTile(
                leading: const Icon(Icons.password_rounded),
                title: const Text('Change PIN'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  final ok = await Navigator.of(context)
                      .push<bool>(fadeRoute<bool>(const PinSetupScreen()));
                  if (ok == true && mounted) _snack('PIN changed.');
                },
              ),
            SwitchListTile(
              secondary: const Icon(Icons.visibility_off_rounded),
              title: const Text('Hide amounts on Home'),
              value: s.hideAmounts,
              onChanged: s.setHideAmounts,
            ),
          ]),
          _Section(title: 'SMS tracking', children: [
            ListTile(
              leading: Icon(Icons.sms_rounded,
                  color: txns.smsEnabled ? AppColors.income : null),
              title: Text(txns.smsEnabled ? 'Auto-tracking is on' : 'Turn on auto-tracking'),
              subtitle: Text(txns.smsEnabled
                  ? 'New bank SMS are imported each time you open FinUp'
                  : 'Allow FinUp to read bank SMS'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _open(const SmsSetupScreen()),
            ),
            if (txns.smsEnabled)
              ListTile(
                leading: txns.syncing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh_rounded),
                title: const Text('Scan last 3 months again'),
                subtitle: const Text('Duplicates are skipped automatically'),
                onTap: txns.syncing ? null : _rescan,
              ),
          ]),
          _Section(title: 'Organise', children: [
            ListTile(
              leading: const Icon(Icons.category_rounded),
              title: const Text('Categories'),
              subtitle: Text('${txns.categories.length} categories'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _open(const CategoriesScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.donut_large_rounded),
              title: const Text('Budgets'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _open(const BudgetsScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.flag_rounded),
              title: const Text('Savings goals'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _open(const GoalsScreen()),
            ),
          ]),
          _Section(title: 'Accounts', children: [
            for (final a in accounts)
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      gradient: AppColors.gradientAt(a.colorIndex),
                      shape: BoxShape.circle),
                  child: Icon(a.type.icon, color: Colors.white, size: 20),
                ),
                title: Text(a.name),
                subtitle: Text((a.last4 != null && a.last4!.isNotEmpty)
                    ? '${a.type.label} · ••${a.last4}'
                    : a.type.label),
                trailing: Text(inr(a.balance, hide: s.hideAmounts)),
                onTap: () => _open(AccountEditor(account: a)),
              ),
            ListTile(
              leading: const Icon(Icons.add_circle_outline_rounded),
              title: const Text('Add account'),
              onTap: () => _open(const AccountEditor()),
            ),
          ]),
          _Section(title: 'Notifications', children: [
            SwitchListTile(
              secondary: const Icon(Icons.notifications_active_rounded),
              title: const Text('Daily review reminder'),
              value: _remOn,
              onChanged: (v) => _toggleReminder(s, v),
            ),
            ListTile(
              enabled: _remOn,
              leading: const Icon(Icons.alarm_rounded),
              title: const Text('Reminder time'),
              subtitle: Text(s.reminderTime.format(context)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _pickTime(s),
            ),
          ]),
          _Section(title: 'Your data', children: [
            ListTile(
              leading: const Icon(Icons.backup_rounded),
              title: const Text('Back up to a file'),
              subtitle: const Text('Save everything as one .json file'),
              onTap: _busy ? null : _backup,
            ),
            ListTile(
              leading: const Icon(Icons.settings_backup_restore_rounded),
              title: const Text('Restore from backup'),
              onTap: _busy ? null : _restore,
            ),
            ListTile(
              leading: const Icon(Icons.table_chart_rounded),
              title: const Text('Export transactions (CSV)'),
              subtitle: const Text('Open in Excel or Google Sheets'),
              onTap: _busy ? null : _exportCsv,
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever_rounded, color: AppColors.expense),
              title: const Text('Delete all data',
                  style: TextStyle(color: AppColors.expense)),
              onTap: _deleteAll,
            ),
          ]),
          _Section(title: 'About', children: [
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('About FinUp'),
              subtitle: const Text('Version 2.0.0'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _open(const AboutFinUpScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.gavel_rounded),
              title: const Text('Terms & Conditions'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _open(const LegalScreen(
                  title: 'Terms & Conditions',
                  updated: '13 October 2026',
                  sections: termsSections)),
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_rounded),
              title: const Text('Privacy Policy'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _open(const LegalScreen(
                  title: 'Privacy Policy',
                  updated: '13 October 2026',
                  sections: privacySections)),
            ),
          ]),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 22, 6, 8),
          child: Text(title.toUpperCase(),
              style: TextStyle(
                  color: fin.subtext,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2)),
        ),
        Material(
          color: fin.card,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ],
    );
  }
}
__END__

############################ lib/main.dart (adds app lock gate) ############################
cat > lib/main.dart <<'__END__'
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/db.dart';
import 'data/repo.dart';
import 'native.dart';
import 'screens/splash_screen.dart';
import 'security/lock.dart';
import 'state/app_state.dart';
import 'state/txn_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDatabase.instance.init();
  await AppDatabase.instance.ensureSchema();
  final settings = SettingsState();
  await settings.load();
  final accounts = AccountsState();
  await accounts.load();
  final txns = TxnState();
  await txns.load();
  if (settings.onboarded) {
    await Native.scheduleReminder(settings.reminderTime.hour,
        settings.reminderTime.minute, await ReminderPrefs.isOn());
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsState>.value(value: settings),
        ChangeNotifierProvider<AccountsState>.value(value: accounts),
        ChangeNotifierProvider<TxnState>.value(value: txns),
      ],
      child: const FinUpApp(),
    ),
  );
}

class FinUpApp extends StatelessWidget {
  const FinUpApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select<SettingsState, ThemeMode>((s) => s.themeMode);
    return MaterialApp(
      title: 'FinUp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      builder: (context, child) =>
          AppLockGate(child: child ?? const SizedBox.shrink()),
      home: const SplashScreen(),
    );
  }
}
__END__

############################ Patches to earlier parts ############################
# 1) Lending/borrowing (person-linked transactions) is excluded from spending/income stats
sed -i "s#where: 'occurred_at >= ? AND occurred_at < ?',#where: 'occurred_at >= ? AND occurred_at < ? AND person_id IS NULL',#" lib/data/stats.dart
sed -i "s#WHERE type = 'expense' AND occurred_at >= ? AND occurred_at < ?#WHERE type = 'expense' AND person_id IS NULL AND occurred_at >= ? AND occurred_at < ?#" lib/data/db.dart

# 2) Auto-link SMS payments to people after every sync
sed -i "s#import '../data/repo.dart';#import '../data/people_repo.dart';\nimport '../data/repo.dart';#" lib/state/txn_state.dart
sed -i "s#n = await SmsSync.run(sinceMs: sinceMs);#n = await SmsSync.run(sinceMs: sinceMs);\n      await AppDatabase.instance.autoLinkPeople();#" lib/state/txn_state.dart

# 3) "Lend / Borrow" chip in the review inbox
perl -0777 -pi -e 's{ActionChip\(\s*avatar: const Icon\(Icons\.more_horiz_rounded, size: 16\),}{ActionChip(avatar: const Icon(Icons.person_add_alt_1_rounded, size: 16), label: const Text(\x27Lend / Borrow\x27), onPressed: () => linkTxnToPerson(context, txn)), ActionChip(avatar: const Icon(Icons.more_horiz_rounded, size: 16),}s' lib/screens/review_screen.dart
sed -i "s#import 'add_txn_screen.dart';#import 'add_txn_screen.dart';\nimport 'people_screen.dart';#" lib/screens/review_screen.dart

for check in "person_id IS NULL',:lib/data/stats.dart" "autoLinkPeople:lib/state/txn_state.dart" "linkTxnToPerson:lib/screens/review_screen.dart"; do
  pat="${check%%:*}"; file="${check#*:}"
  if ! grep -q "$pat" "$file"; then echo "ERROR: Part 4 patch failed in $file"; exit 1; fi
done

############################ DOCS ############################
cat > SETUP.md <<'__END__'
# FinUp – Codebase & Build Setup

FinUp is a private, offline expense manager built with Flutter (Android only).
All data stays on the phone. There is no backend and no API.

## How the repository works

The GitHub repository contains only:

| File | Purpose |
|---|---|
| `.github/workflows/build.yml` | Cloud build: generates the project, builds the APK, publishes a Release |
| `finup.sh` | Part 1: theme, database, accounts, onboarding |
| `finup2.sh` | Part 2: logo, SMS engine, entries, activity, review, reminders |
| `finup3.sh` | Part 3: dashboard, insights, budgets, goals |
| `finup4.sh` | Part 4: people ledger, app lock, backup, legal pages, docs |
| `keys/debug.keystore` | Fixed signing key (created by the first build; keep the repo private) |

The scripts write the full Flutter project into `app/`. The workflow then runs
`flutter create` to add standard Android files, generates the launcher icons,
and builds `FinUp.apk`. Each release also contains `FinUp-source.zip`, which is
the complete, ready-to-open Flutter project (this file is inside it).

## Build an APK (no local install needed)

1. Push changes to GitHub.
2. GitHub → **Actions** → **Build FinUp** → **Run workflow**.
3. After about 10 minutes: **Releases** → latest build → download `FinUp.apk`.
4. Install it over the previous version. Data is kept because the signing key is fixed.

Always run `git pull` before pushing, because the first build commits the signing key.

## Build locally (optional)

Requirements: Flutter (stable), Android SDK, JDK 17.

```bash
unzip FinUp-source.zip -d finup && cd finup
flutter pub get
flutter run            # debug on a connected phone
flutter build apk      # release APK in build/app/outputs/flutter-apk/
```

## Project structure (`lib/`)

| Path | What it does |
|---|---|
| `main.dart` | App start, providers, theme, app lock gate |
| `theme.dart` | Colours, light/dark themes, fonts, `inr()` formatter |
| `native.dart` | Bridge to Kotlin: SMS, permissions, reminders, fingerprint, files, sharing |
| `data/db.dart` | SQLite schema, models (Account, Category, Txn) |
| `data/repo.dart` | Transactions, balances, rules, categories |
| `data/stats.dart` | Monthly totals, category totals, budgets, goals |
| `data/people_repo.dart` | People, ledger entries, auto-linking UPI IDs |
| `data/backup.dart` | JSON backup/restore, CSV export, wipe |
| `sms/parser.dart` | Bank SMS parser (Bank of Baroda format and generic patterns) |
| `sms/sync.dart` | Imports new SMS, de-duplicates by Ref number, updates balances |
| `state/` | `SettingsState`, `AccountsState`, `TxnState` (ChangeNotifiers) |
| `security/lock.dart` | PIN + fingerprint lock screen |
| `screens/` | All screens |
| `widgets/` | Shared widgets, charts, logo |

Native Android code lives in `android/app/src/main/kotlin/com/yash/finup/`:
`MainActivity.kt` (method channel `finup/native`) and `Reminder.kt` (daily notification).

## Adding support for another bank

Edit `lib/sms/parser.dart`:
- `_bankName()` maps the SMS sender ID to a bank name.
- The regexes `_amount`, `_drcr`, `_acct`, `_vpa`, `_ref`, `_bal`, `_date` extract the fields.
Then rebuild.
__END__

cat > USER_GUIDE.md <<'__END__'
# FinUp – User Guide

## 1. First launch
1. Watch the intro, then read the privacy promise.
2. Enter your name.
3. Set up accounts: your Bank of Baroda account (last 4 digits are used to match SMS) and Cash in hand.
4. Pick Light, Dark or System theme.
5. Allow SMS access and choose how far back to import (1, 3 or 6 months).

## 2. Home
- **Total balance** across all accounts. Tap the eye icon to hide amounts.
- **Account cards**: swipe through them; tap one to edit.
- **Review banner**: shows how many new transactions need a category.
- **Quick buttons**: Expense, Income, Transfer.
- **This month**: income vs spending and how much you have saved.
- **Budget warnings** at 80% and 100%.
- **Statistic chart**: spending for the last 6 months; tap a bar to see that month.
- Pull down to check for new SMS.

## 3. Automatic SMS tracking
- Every time you open FinUp it reads new bank SMS received since the last check, including those that arrived while the app was closed.
- The bank balance updates from the AvlBal in the SMS.
- Duplicate messages (same Ref number) are skipped. OTPs, offers and failed payments are ignored.
- ATM withdrawals become a transfer from Bank to Cash, not spending.
- Settings → **Scan last 3 months again** re-checks older messages.

## 4. End-of-day review
1. Tap the review banner (or wait for the daily reminder).
2. Tap a category chip for each transaction.
3. FinUp remembers the UPI ID: future payments to it are categorised automatically.
4. Tap **Lend / Borrow** if the money went to or came from a friend instead.
5. **Mark all done** clears the inbox without categories.

## 5. Adding entries by hand
Tap **+** → Expense, Income or Transfer. Use the number pad, pick the account, category, date and time, and add a note. Tap any transaction to edit or delete it; balances adjust automatically.

## 6. Accounts
Add bank, cash, credit card or wallet accounts from Home or Settings. For credit cards, enter the outstanding amount as a negative number.

## 7. Insights, budgets and goals
- **Insights tab**: switch months, Spending/Income, compare with last month, category donut (tap a category to see its transactions), top payees and a daily calendar.
- **Budgets**: set a monthly limit per category. Rings turn amber at 80% and red at 100%.
- **Goals**: create a goal, then use Add money / Withdraw to track progress.

## 8. People ledger
- **People tab** shows what each person owes you or what you owe them.
- **Gave / Got**: record money you lent or borrowed. Optionally link an account so its balance changes too. Lending is not counted as spending.
- **Due date**: set when you expect money back; overdue people appear under "Due soon".
- **Settle up**: records the full balance as paid.
- **Remind**: sends a friendly reminder message through WhatsApp or any app.
- **Statement**: share a clean image or text statement.
- **Split a bill**: enter the total, pick people, and FinUp records your share as spending and each friend's share in the ledger.
- Once a UPI ID is linked to a person, future SMS payments to that ID are linked automatically.

## 9. Security
Settings → Security:
- **App lock** with a 4-digit PIN, asked when opening FinUp or returning after 30 seconds.
- **Fingerprint unlock** (if your phone supports it).
- If you forget the PIN, the only option is Android Settings → Apps → FinUp → Clear data, which deletes everything. Keep backups.

## 10. Backup, restore and export
Settings → Your data:
- **Back up to a file**: saves a `.json` file wherever you choose (Downloads, Google Drive and so on).
- **Restore from backup**: replaces current data with a backup file.
- **Export transactions (CSV)**: opens in Excel or Google Sheets.
- **Delete all data**: wipes the app and starts fresh.

## 11. Daily reminder
Settings → Notifications: turn the reminder on or off and choose the time.

## 12. Troubleshooting
- **SMS not detected**: check SMS permission in Android settings, then use Scan again. Make sure the account's last 4 digits match the SMS.
- **Balance looks wrong**: open the account and correct the balance. The next SMS with AvlBal updates it automatically.
- **No reminder**: allow notifications for FinUp and disable battery optimisation for it.
- **Update did not install**: always install the newest APK from Releases; never uninstall first, or data is lost.
__END__

echo "FinUp Part 4 applied."