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

  static void init() {
    // Native → Dart callbacks reserved for future use.
  }

  static Future<bool> _bool(String method, [Map<String, Object?>? args]) async {
    try {
      return await _ch.invokeMethod<bool>(method, args) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> _str(String method, [Map<String, Object?>? args]) async {
    try {
      return await _ch.invokeMethod<String>(method, args);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> hasSms() => _bool('hasSmsPermission');
  static Future<bool> requestSms() => _bool('requestSmsPermission');
  static Future<bool> ensureSmsReceive() => _bool('ensureSmsReceive');
  static Future<bool> requestNotifications() => _bool('requestNotificationPermission');
  static Future<bool> openSettings() => _bool('openAppSettings');
  static Future<bool> canBiometric() => _bool('canBiometric');
  static Future<bool> authenticate(String reason) => _bool('authenticate', {'reason': reason});
  static Future<bool> saveDocument(String name, String mime, Uint8List bytes) =>
      _bool('saveDocument', {'name': name, 'mime': mime, 'bytes': bytes});
  static Future<bool> shareImage(Uint8List bytes, String name, String text) =>
      _bool('shareImage', {'bytes': bytes, 'name': name, 'text': text});
  static Future<bool> shareText(String text) => _bool('shareText', {'text': text});
  static Future<bool> getSmsAlerts() => _bool('getSmsAlerts');
  static Future<bool> setSmsAlerts(bool v) => _bool('setSmsAlerts', {'on': v});
  static Future<bool> notify(String title, String body, {int id = 9999}) =>
      _bool('notify', {'title': title, 'body': body, 'id': id});
  static Future<bool> openUrl(String url) => _bool('openUrl', {'url': url});
  static Future<bool> batteryOptimized() => _bool('batteryOptimized');
  static Future<bool> openBatterySettings() => _bool('openBatterySettings');
  static Future<bool> refreshWidget() => _bool('refreshWidget');

  /// Returns the spoken text, "" if cancelled, or "__unavailable__" if no speech service.
  static Future<String?> voice(String prompt) => _str('voice', {'prompt': prompt});
  static Future<String?> ocr(String path) => _str('ocr', {'path': path});
  static Future<String?> takeLaunchAction() => _str('takeLaunchAction');

  static Future<Uint8List?> openDocument() async {
    try {
      return await _ch.invokeMethod<Uint8List>('openDocument');
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, int>> pendingCategories() async {
    try {
      final m = await _ch.invokeMethod<Map<dynamic, dynamic>>('pendingCategories');
      if (m == null) return {};
      return m.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  static Future<void> clearPendingCategories(List<String> keys) async {
    try {
      await _ch.invokeMethod('clearPending', {'keys': keys});
    } catch (_) {}
  }

  static Future<(String, int)> appInfo() async {
    try {
      final m = await _ch.invokeMethod<Map<dynamic, dynamic>>('appInfo');
      return ((m?['name'] ?? '').toString(), (m?['code'] as num?)?.toInt() ?? 0);
    } catch (_) {
      return ('', 0);
    }
  }

  static Future<List<RawSms>> readSms(int sinceMs) async {
    final raw = await _ch.invokeMethod<List<dynamic>>('readSms', {'since': sinceMs});
    if (raw == null) return [];
    return raw.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return RawSms('${m['id']}', '${m['address'] ?? ''}', '${m['body'] ?? ''}',
          (m['date'] as num).toInt());
    }).toList();
  }

  static Future<void> scheduleReminder(int hour, int minute, bool enabled) async {
    try {
      await _ch.invokeMethod('scheduleReminder', {'hour': hour, 'minute': minute, 'enabled': enabled});
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
