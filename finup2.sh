#!/usr/bin/env bash
set -euo pipefail
cd app
mkdir -p lib/sms lib/widgets lib/screens lib/data lib/state branding android/app/src/main/kotlin/com/yash/finup

############################ BRANDING ############################
cat > branding/icon_full.svg <<'__END__'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200">
<rect width="200" height="200" rx="46" fill="#2D2A6E"/>
<ellipse cx="100" cy="104" rx="78" ry="30" fill="none" stroke="#8E8BEA" stroke-opacity="0.45" stroke-width="3" transform="rotate(-28 100 104)"/>
<circle cx="169" cy="67" r="8" fill="#EBB9D6"/>
<path d="M78 148 V80 Q78 62 96 59 L128 51" fill="none" stroke="#8E8BEA" stroke-width="17" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M78 104 H112" fill="none" stroke="#8E8BEA" stroke-width="17" stroke-linecap="round"/>
<path d="M112 40 L134 50 L118 68" fill="none" stroke="#EBB9D6" stroke-width="17" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
__END__

cat > branding/icon_fg.svg <<'__END__'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="-42 -51 290 290">
<ellipse cx="100" cy="104" rx="78" ry="30" fill="none" stroke="#8E8BEA" stroke-opacity="0.45" stroke-width="3" transform="rotate(-28 100 104)"/>
<circle cx="169" cy="67" r="8" fill="#EBB9D6"/>
<path d="M78 148 V80 Q78 62 96 59 L128 51" fill="none" stroke="#8E8BEA" stroke-width="17" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M78 104 H112" fill="none" stroke="#8E8BEA" stroke-width="17" stroke-linecap="round"/>
<path d="M112 40 L134 50 L118 68" fill="none" stroke="#EBB9D6" stroke-width="17" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
__END__

cat > branding/icon_stat.svg <<'__END__'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="41 29 130 130">
<path d="M78 148 V80 Q78 62 96 59 L128 51" fill="none" stroke="#FFFFFF" stroke-width="17" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M78 104 H112" fill="none" stroke="#FFFFFF" stroke-width="17" stroke-linecap="round"/>
<path d="M112 40 L134 50 L118 68" fill="none" stroke="#FFFFFF" stroke-width="17" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
__END__

cat > branding/make_icons.sh <<'__END__'
#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/.."
RES=android/app/src/main/res
for d in mdpi:48:108:24 hdpi:72:162:36 xhdpi:96:216:48 xxhdpi:144:324:72 xxxhdpi:192:432:96; do
  IFS=: read -r n s f t <<< "$d"
  mkdir -p "$RES/mipmap-$n" "$RES/drawable-$n"
  rsvg-convert -w "$s" -h "$s" branding/icon_full.svg -o "$RES/mipmap-$n/ic_launcher.png"
  rsvg-convert -w "$f" -h "$f" branding/icon_fg.svg -o "$RES/mipmap-$n/ic_launcher_foreground.png"
  rsvg-convert -w "$t" -h "$t" branding/icon_stat.svg -o "$RES/drawable-$n/ic_stat_finup.png"
done
mkdir -p "$RES/mipmap-anydpi-v26" "$RES/values" "$RES/drawable" "$RES/drawable-v21"
cat > "$RES/mipmap-anydpi-v26/ic_launcher.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
XML
cat > "$RES/values/ic_launcher_background.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<resources><color name="ic_launcher_background">#2D2A6E</color></resources>
XML
for dir in drawable drawable-v21; do
cat > "$RES/$dir/launch_background.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@android:color/black" />
    <item><bitmap android:gravity="center" android:src="@mipmap/ic_launcher" /></item>
</layer-list>
XML
done
echo "Icons generated."
__END__

############################ ANDROID MANIFEST ############################
cat > android/app/src/main/AndroidManifest.xml <<'__END__'
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.READ_SMS"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>

    <application
        android:label="FinUp"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:taskAffinity=""
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <meta-data
                android:name="io.flutter.embedding.android.NormalTheme"
                android:resource="@style/NormalTheme" />
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        <receiver android:name=".ReminderReceiver" android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
            </intent-filter>
        </receiver>
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>

    <queries>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT"/>
            <data android:mimeType="text/plain"/>
        </intent>
    </queries>
</manifest>
__END__

############################ KOTLIN: MainActivity ############################
cat > android/app/src/main/kotlin/com/yash/finup/MainActivity.kt <<'__END__'
package com.yash.finup

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "finup/native"
    private val permRequestCode = 4242
    private var pendingResult: MethodChannel.Result? = null
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

############################ KOTLIN: Reminder ############################
cat > android/app/src/main/kotlin/com/yash/finup/Reminder.kt <<'__END__'
package com.yash.finup

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import java.util.Calendar

object Reminder {
    private const val PREFS = "finup_reminder"
    private const val CHANNEL = "finup_daily"

    private fun flags(): Int =
        if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        else PendingIntent.FLAG_UPDATE_CURRENT

    fun save(ctx: Context, hour: Int, minute: Int, enabled: Boolean) {
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putInt("h", hour).putInt("m", minute).putBoolean("on", enabled).apply()
    }

    fun schedule(ctx: Context) {
        val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = PendingIntent.getBroadcast(ctx, 7001, Intent(ctx, ReminderReceiver::class.java), flags())
        am.cancel(pi)
        if (!prefs.getBoolean("on", true)) return
        val cal = Calendar.getInstance()
        cal.set(Calendar.HOUR_OF_DAY, prefs.getInt("h", 21))
        cal.set(Calendar.MINUTE, prefs.getInt("m", 0))
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        if (cal.timeInMillis <= System.currentTimeMillis() + 1000) cal.add(Calendar.DAY_OF_YEAR, 1)
        if (Build.VERSION.SDK_INT >= 23) {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, cal.timeInMillis, pi)
        } else {
            am.set(AlarmManager.RTC_WAKEUP, cal.timeInMillis, pi)
        }
    }

    fun show(ctx: Context) {
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {
            nm.createNotificationChannel(NotificationChannel(CHANNEL, "Daily review", NotificationManager.IMPORTANCE_DEFAULT))
        }
        val launch = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName) ?: Intent()
        val content = PendingIntent.getActivity(ctx, 7002, launch, flags())
        var icon = ctx.resources.getIdentifier("ic_stat_finup", "drawable", ctx.packageName)
        if (icon == 0) icon = android.R.drawable.ic_popup_reminder
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(ctx, CHANNEL) else Notification.Builder(ctx)
        builder.setSmallIcon(icon)
            .setContentTitle("Time for your FinUp review")
            .setContentText("Open FinUp and categorise today's transactions.")
            .setColor(0xFF8E8BEA.toInt())
            .setAutoCancel(true)
            .setContentIntent(content)
        nm.notify(7003, builder.build())
    }
}

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) Reminder.show(context)
        Reminder.schedule(context)
    }
}
__END__

############################ lib/native.dart ############################
cat > lib/native.dart <<'__END__'
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

  static Future<bool> _bool(String method) async {
    try {
      return await _ch.invokeMethod<bool>(method) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> hasSms() => _bool('hasSmsPermission');
  static Future<bool> requestSms() => _bool('requestSmsPermission');
  static Future<bool> requestNotifications() =>
      _bool('requestNotificationPermission');
  static Future<bool> openSettings() => _bool('openAppSettings');

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

  static Future<void> scheduleReminder(
      int hour, int minute, bool enabled) async {
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

############################ lib/sms/parser.dart ############################
cat > lib/sms/parser.dart <<'__END__'
class ParsedSms {
  final double amount;
  final bool isDebit;
  final String? last4;
  final String? counterparty;
  final String? ref;
  final double? balance;
  final DateTime when;
  final bool isAtm;
  final String bankName;
  final bool knownBank;

  const ParsedSms({
    required this.amount,
    required this.isDebit,
    required this.last4,
    required this.counterparty,
    required this.ref,
    required this.balance,
    required this.when,
    required this.isAtm,
    required this.bankName,
    required this.knownBank,
  });
}

class SmsParser {
  static final RegExp _skip = RegExp(
      r'\b(otp|one time password|verification code|requested|request money|will be debited|failed|declined|unsuccessful)\b',
      caseSensitive: false);
  static final RegExp _promo = RegExp(
      r'\b(offer|apply now|pre-approved|preapproved|loan|win|congratulations|voucher|discount)\b',
      caseSensitive: false);
  static final RegExp _amount = RegExp(
      r'(?:rs\.?|inr|₹)\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)',
      caseSensitive: false);
  static final RegExp _drcr = RegExp(
      r'(?:rs\.?|inr|₹)\s*[0-9][0-9,]*(?:\.[0-9]{1,2})?\s*(dr|cr)\b',
      caseSensitive: false);
  static final RegExp _acct = RegExp(
      r'(?:a/c|acct|account)\.?\s*(?:no\.?\s*)?[x*.\-\s]*([0-9]{3,6})',
      caseSensitive: false);
  static final RegExp _vpa =
      RegExp(r'[a-z0-9][a-z0-9.\-_]+@[a-z][a-z0-9]+', caseSensitive: false);
  static final RegExp _ref = RegExp(
      r'(?:ref(?:erence)?|utr|rrn|txn\s*id)(?:\s*no)?[\s.:#-]*([0-9]{6,})',
      caseSensitive: false);
  static final RegExp _bal = RegExp(
      r'(?:avl\.?\s*bal(?:ance)?|available\s+bal(?:ance)?|\bbal(?:ance)?)\s*(?:is)?[\s:.-]*(?:rs\.?|inr|₹)?\s*(-?[0-9][0-9,]*(?:\.[0-9]{1,2})?)',
      caseSensitive: false);
  static final RegExp _date = RegExp(
      r'(\d{4})[:\-/](\d{2})[:\-/](\d{2})[\sT]+(\d{2}):(\d{2})(?::(\d{2}))?');
  static final RegExp _merchant = RegExp(
      r'\b(?:at|to|towards|from|by)\s+([A-Za-z][A-Za-z0-9&\s.\-]{2,30}?)(?=\s+on\b|\.|,|\s+ref|\s+avl|$)',
      caseSensitive: false);
  static final RegExp _badParty =
      RegExp(r'a/c|your|account', caseSensitive: false);

  static String? _bankName(String up) {
    if (up.contains('BOB')) return 'Bank of Baroda';
    if (up.contains('HDFC')) return 'HDFC Bank';
    if (up.contains('ICICI')) return 'ICICI Bank';
    if (up.contains('SBI')) return 'State Bank of India';
    if (up.contains('AXIS')) return 'Axis Bank';
    if (up.contains('KOTAK')) return 'Kotak Bank';
    if (up.contains('PNB')) return 'Punjab National Bank';
    return null;
  }

  static ParsedSms? parse(String address, String body, DateTime received) {
    final text = body.replaceAll('\n', ' ');
    if (_skip.hasMatch(text)) return null;
    final am = _amount.firstMatch(text);
    if (am == null) return null;
    final amount = double.tryParse(am.group(1)!.replaceAll(',', ''));
    if (amount == null || amount <= 0) return null;
    final lower = text.toLowerCase();

    final bool debit;
    final dc = _drcr.firstMatch(text);
    if (dc != null) {
      debit = dc.group(1)!.toLowerCase() == 'dr';
    } else {
      int first(List<String> words) {
        var best = -1;
        for (final w in words) {
          final i = lower.indexOf(w);
          if (i >= 0 && (best < 0 || i < best)) best = i;
        }
        return best;
      }

      final d = first(const ['debited', 'spent', 'paid', 'sent', 'withdrawn', 'purchase', 'debit', ' dr ']);
      final c = first(const ['credited', 'received', 'deposited', 'refund', 'credit', ' cr ']);
      if (d < 0 && c < 0) return null;
      debit = c < 0 || (d >= 0 && d < c);
    }

    String? last4;
    final acct = _acct.firstMatch(text);
    if (acct != null) {
      final g = acct.group(1)!;
      last4 = g.length > 4 ? g.substring(g.length - 4) : g;
    }

    final vpa = _vpa.firstMatch(text)?.group(0);
    String? party = vpa;
    if (party == null) {
      final cand = _merchant.firstMatch(text)?.group(1)?.trim();
      if (cand != null && cand.isNotEmpty && !_badParty.hasMatch(cand)) {
        party = cand;
      }
    }

    final ref = _ref.firstMatch(text)?.group(1);
    final bm = _bal.firstMatch(text);
    final balance =
        bm == null ? null : double.tryParse(bm.group(1)!.replaceAll(',', ''));

    var when = received;
    final dm = _date.firstMatch(text);
    if (dm != null) {
      final y = int.parse(dm.group(1)!);
      final mo = int.parse(dm.group(2)!);
      final d = int.parse(dm.group(3)!);
      if (y > 2000 && y < 2100 && mo >= 1 && mo <= 12 && d >= 1 && d <= 31) {
        when = DateTime(y, mo, d, int.parse(dm.group(4)!),
            int.parse(dm.group(5)!), int.parse(dm.group(6) ?? '0'));
      }
    }

    final bank = _bankName(address.toUpperCase());
    final known = bank != null;
    if (last4 == null && (_promo.hasMatch(text) || (!known && vpa == null))) {
      return null;
    }
    final atm = debit &&
        (lower.contains('atm') ||
            lower.contains('cash withdrawal') ||
            lower.contains('withdrawn'));

    return ParsedSms(
      amount: amount,
      isDebit: debit,
      last4: last4,
      counterparty: atm ? 'ATM withdrawal' : party,
      ref: ref,
      balance: balance,
      when: when,
      isAtm: atm,
      bankName: bank ?? 'Bank',
      knownBank: known,
    );
  }
}
__END__

############################ lib/data/repo.dart ############################
cat > lib/data/repo.dart <<'__END__'
import 'package:sqflite/sqflite.dart';

import 'db.dart';

extension Repo on AppDatabase {
  Future<void> ensureSchema() async {
    final cols = await db.rawQuery('PRAGMA table_info(transactions)');
    final has = cols.any((c) => c['name'] == 'affects_balance');
    if (!has) {
      await db.execute(
          'ALTER TABLE transactions ADD COLUMN affects_balance INTEGER NOT NULL DEFAULT 1');
    }
  }

  Future<bool> txnExists(String ref) async {
    final n = Sqflite.firstIntValue(await db
            .rawQuery('SELECT COUNT(*) FROM transactions WHERE ref = ?', [ref])) ??
        0;
    return n > 0;
  }

  /// balanceMode: 0 = no balance change, 1 = full, 2 = only the receiving account (transfers)
  Future<int> addTxn(Txn t, {int balanceMode = 1}) async {
    final id = await db.insert('transactions', {
      ...t.toMap(),
      'affects_balance': balanceMode,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    await _apply(t, 1, balanceMode);
    return id;
  }

  Future<void> editTxn(Txn old, Txn neu) async {
    final mode = await _modeOf(old.id!);
    await _apply(old, -1, mode);
    var newMode = mode;
    if (mode == 2 && neu.type != TxnType.transfer) newMode = 0;
    await db.update('transactions', {...neu.toMap(), 'affects_balance': newMode},
        where: 'id = ?', whereArgs: [old.id]);
    await _apply(neu, 1, newMode);
  }

  Future<void> deleteTxn(Txn t) async {
    final mode = await _modeOf(t.id!);
    await _apply(t, -1, mode);
    await db.delete('transactions', where: 'id = ?', whereArgs: [t.id]);
  }

  Future<int> _modeOf(int id) async {
    final r = await db.query('transactions',
        columns: ['affects_balance'], where: 'id = ?', whereArgs: [id]);
    if (r.isEmpty) return 0;
    return (r.first['affects_balance'] as int?) ?? 1;
  }

  Future<void> _apply(Txn t, int sign, int mode) async {
    if (mode == 0) return;
    final a = t.amount * sign;
    Future<void> bump(int? id, double d) async {
      if (id == null) return;
      await db.rawUpdate(
          'UPDATE accounts SET balance = balance + ? WHERE id = ?', [d, id]);
    }

    switch (t.type) {
      case TxnType.expense:
        if (mode == 1) await bump(t.accountId, -a);
      case TxnType.income:
        if (mode == 1) await bump(t.accountId, a);
      case TxnType.transfer:
        if (mode == 1) await bump(t.accountId, -a);
        await bump(t.toAccountId, a);
    }
  }

  Future<void> setAccountBalance(int id, double balance, DateTime at) async {
    await db.update(
        'accounts',
        {'balance': balance, 'balance_updated_at': at.millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [id]);
  }

  Future<List<Txn>> txns({
    String? type,
    String? status,
    String? search,
    DateTime? from,
    DateTime? to,
    int? accountId,
    int? categoryId,
    int? personId,
    int limit = 300,
  }) async {
    final where = <String>[];
    final args = <Object?>[];
    if (type != null) {
      where.add('type = ?');
      args.add(type);
    }
    if (status != null) {
      where.add('status = ?');
      args.add(status);
    }
    if (from != null) {
      where.add('occurred_at >= ?');
      args.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      where.add('occurred_at < ?');
      args.add(to.millisecondsSinceEpoch);
    }
    if (accountId != null) {
      where.add('(account_id = ? OR to_account_id = ?)');
      args.addAll([accountId, accountId]);
    }
    if (categoryId != null) {
      where.add('category_id = ?');
      args.add(categoryId);
    }
    if (personId != null) {
      where.add('person_id = ?');
      args.add(personId);
    }
    if (search != null && search.trim().isNotEmpty) {
      where.add(
          "(LOWER(COALESCE(counterparty, '')) LIKE ? OR LOWER(COALESCE(note, '')) LIKE ?)");
      final q = '%${search.trim().toLowerCase()}%';
      args.addAll([q, q]);
    }
    final rows = await db.query('transactions',
        where: where.isEmpty ? null : where.join(' AND '),
        whereArgs: args.isEmpty ? null : args,
        orderBy: 'occurred_at DESC',
        limit: limit);
    return rows.map(Txn.fromMap).toList();
  }

  Future<void> markReviewed(int id, int? categoryId) async {
    await db.update(
        'transactions',
        {'status': 'done', if (categoryId != null) 'category_id': categoryId},
        where: 'id = ?',
        whereArgs: [id]);
  }

  Future<void> markAllReviewed() async {
    await db.update('transactions', {'status': 'done'},
        where: 'status = ?', whereArgs: ['review']);
  }

  Future<List<(String, int)>> rules() async {
    final rows = await db.query('rules', where: 'category_id IS NOT NULL');
    return rows
        .map((r) => ((r['keyword'] as String), (r['category_id'] as int)))
        .toList();
  }

  Future<void> addRule(String keyword, int categoryId) async {
    final k = keyword.trim().toLowerCase();
    if (k.isEmpty) return;
    await db.delete('rules', where: 'keyword = ?', whereArgs: [k]);
    await db.insert('rules', {
      'keyword': k,
      'category_id': categoryId,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> applyRuleToPending(String keyword, int categoryId) async {
    await db.rawUpdate(
        "UPDATE transactions SET category_id = ?, status = 'done' "
        "WHERE status = 'review' AND LOWER(COALESCE(counterparty, '')) = ?",
        [categoryId, keyword.trim().toLowerCase()]);
  }

  Future<void> insertCategory(
      String name, String iconKey, int color, String kind) async {
    final maxSort = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COALESCE(MAX(sort), 0) FROM categories')) ??
        0;
    await db.insert('categories', {
      'name': name,
      'icon': iconKey,
      'color': color,
      'kind': kind,
      'sort': maxSort + 1,
    });
  }

  Future<void> updateCategory(Category c) async {
    await db.update(
        'categories', {'name': c.name, 'icon': c.iconKey, 'color': c.color},
        where: 'id = ?', whereArgs: [c.id]);
  }

  Future<void> deleteCategory(int id) async {
    await db.update('transactions', {'category_id': null},
        where: 'category_id = ?', whereArgs: [id]);
    await db.delete('rules', where: 'category_id = ?', whereArgs: [id]);
    await db.delete('budgets', where: 'category_id = ?', whereArgs: [id]);
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }
}
__END__

############################ lib/sms/sync.dart ############################
cat > lib/sms/sync.dart <<'__END__'
import 'package:shared_preferences/shared_preferences.dart';

import '../data/db.dart';
import '../data/repo.dart';
import '../native.dart';
import 'parser.dart';

class SmsSync {
  static Account? _byId(List<Account> list, int? id) {
    for (final a in list) {
      if (a.id == id) return a;
    }
    return null;
  }

  static Account? _firstCash(List<Account> list) {
    for (final a in list) {
      if (a.type == AccountType.cash) return a;
    }
    return null;
  }

  static Account? _match(List<Account> list, ParsedSms p) {
    if (p.last4 != null) {
      for (final a in list) {
        if (a.last4 == p.last4) return a;
      }
      return null;
    }
    if (!p.knownBank) return null;
    for (final a in list) {
      if (a.type == AccountType.bank) return a;
    }
    return null;
  }

  static Future<int> run({int? sinceMs}) async {
    if (!await Native.hasSms()) return 0;
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt('smsLastSync');
    final since = sinceMs ??
        last ??
        DateTime.now()
            .subtract(const Duration(days: 30))
            .millisecondsSinceEpoch;
    final msgs = await Native.readSms(since);
    final db = AppDatabase.instance;
    var accounts = await db.accounts();
    final rules = await db.rules();
    var added = 0;
    var maxDate = last ?? since;
    final latest = <int, (DateTime, double)>{};

    for (final sms in msgs) {
      if (sms.date > maxDate) maxDate = sms.date;
      final p = SmsParser.parse(
          sms.address, sms.body, DateTime.fromMillisecondsSinceEpoch(sms.date));
      if (p == null) continue;
      final key = p.ref != null ? 'ref:${p.ref}' : 'sms:${sms.id}';
      if (await db.txnExists(key)) continue;

      var acc = _match(accounts, p);
      if (acc == null) {
        if (p.last4 == null) continue;
        final id = await db.insertAccount(Account(
          name: p.bankName,
          type: AccountType.bank,
          bank: p.bankName,
          last4: p.last4,
          colorIndex: accounts.length % 4,
          balance: p.balance ?? 0,
          balanceUpdatedAt: p.balance == null ? null : p.when,
        ));
        accounts = await db.accounts();
        acc = _byId(accounts, id);
        if (acc == null) continue;
      }
      final accId = acc.id!;
      final fresh = acc.balanceUpdatedAt == null ||
          p.when.isAfter(acc.balanceUpdatedAt!);

      if (p.balance != null) {
        final prev = latest[accId];
        if (prev == null || p.when.isAfter(prev.$1)) {
          latest[accId] = (p.when, p.balance!);
        }
      }

      if (p.isAtm) {
        var cash = _firstCash(accounts);
        if (cash == null) {
          final cid = await db.insertAccount(const Account(
              name: 'Cash', type: AccountType.cash, colorIndex: 2));
          accounts = await db.accounts();
          cash = _byId(accounts, cid);
        }
        final mode = !fresh ? 0 : (p.balance == null ? 1 : 2);
        await db.addTxn(
          Txn(
            accountId: accId,
            toAccountId: cash?.id,
            type: TxnType.transfer,
            amount: p.amount,
            counterparty: 'ATM withdrawal',
            ref: key,
            smsBody: sms.body,
            status: 'done',
            occurredAt: p.when,
          ),
          balanceMode: mode,
        );
      } else {
        final party = p.counterparty;
        int? cat;
        if (party != null) {
          final l = party.toLowerCase();
          for (final r in rules) {
            if (l == r.$1 || l.contains(r.$1)) {
              cat = r.$2;
              break;
            }
          }
        }
        await db.addTxn(
          Txn(
            accountId: accId,
            type: p.isDebit ? TxnType.expense : TxnType.income,
            amount: p.amount,
            categoryId: cat,
            counterparty: party,
            ref: key,
            smsBody: sms.body,
            status: cat == null ? 'review' : 'done',
            occurredAt: p.when,
          ),
          balanceMode: (p.balance == null && fresh) ? 1 : 0,
        );
      }
      added++;
    }

    for (final e in latest.entries) {
      final acc = _byId(accounts, e.key);
      if (acc == null) continue;
      final upd = acc.balanceUpdatedAt;
      if (upd == null || acc.balance == 0 || !e.value.$1.isBefore(upd)) {
        await db.setAccountBalance(e.key, e.value.$2, e.value.$1);
      }
    }
    await prefs.setInt('smsLastSync', maxDate);
    return added;
  }
}
__END__

############################ lib/state/txn_state.dart ############################
cat > lib/state/txn_state.dart <<'__END__'
import 'package:flutter/material.dart';

import '../data/db.dart';
import '../data/repo.dart';
import '../native.dart';
import '../sms/sync.dart';
import 'app_state.dart';

class TxnState extends ChangeNotifier {
  final AppDatabase _db = AppDatabase.instance;
  List<Category> categories = [];
  List<Txn> recent = [];
  int reviewCount = 0;
  double todaySpent = 0;
  bool smsEnabled = false;
  bool syncing = false;
  int version = 0;

  Category? category(int? id) {
    if (id == null) return null;
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  List<Category> byKind(String kind) =>
      categories.where((c) => c.kind == kind).toList();

  Future<void> load() async {
    categories = await _db.categories();
    recent = await _db.txns(limit: 6);
    reviewCount = await _db.reviewCount();
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    todaySpent =
        await _db.expenseBetween(start, start.add(const Duration(days: 1)));
    smsEnabled = await Native.hasSms();
    version++;
    notifyListeners();
  }

  Future<int> sync(AccountsState accounts, {int? sinceMs}) async {
    if (syncing) return 0;
    syncing = true;
    notifyListeners();
    var n = 0;
    try {
      n = await SmsSync.run(sinceMs: sinceMs);
    } catch (_) {}
    syncing = false;
    await accounts.load();
    await load();
    return n;
  }

  Future<void> save(AccountsState accounts, Txn t, {Txn? old}) async {
    if (old == null) {
      await _db.addTxn(t);
    } else {
      await _db.editTxn(old, t);
    }
    await accounts.load();
    await load();
  }

  Future<void> delete(AccountsState accounts, Txn t) async {
    await _db.deleteTxn(t);
    await accounts.load();
    await load();
  }

  Future<void> categorize(Txn t, int categoryId, {bool remember = true}) async {
    await _db.markReviewed(t.id!, categoryId);
    final key = t.counterparty?.trim().toLowerCase();
    if (remember && key != null && key.isNotEmpty) {
      await _db.addRule(key, categoryId);
      await _db.applyRuleToPending(key, categoryId);
    }
    await load();
  }

  Future<void> rememberRule(String payee, int categoryId) async {
    await _db.addRule(payee, categoryId);
    await _db.applyRuleToPending(payee, categoryId);
    await load();
  }

  Future<void> markAllReviewed() async {
    await _db.markAllReviewed();
    await load();
  }
}
__END__

############################ lib/widgets/logo.dart ############################
cat > lib/widgets/logo.dart <<'__END__'
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

class FinUpLogo extends StatelessWidget {
  final double size;
  final bool withBackground;

  const FinUpLogo({super.key, this.size = 64, this.withBackground = true});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
        size: Size.square(size), painter: _LogoPainter(withBackground));
  }
}

class _LogoPainter extends CustomPainter {
  final bool bg;
  _LogoPainter(this.bg);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 200);
    if (bg) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(0, 0, 200, 200), const Radius.circular(46)),
        Paint()..color = AppColors.indigo,
      );
    }
    canvas.save();
    canvas.translate(100, 104);
    canvas.rotate(-28 * math.pi / 180);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 156, height: 60),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = AppColors.lavender.withValues(alpha: 0.45),
    );
    canvas.restore();
    canvas.drawCircle(const Offset(169, 67), 8, Paint()..color = AppColors.pink);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 17
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = AppColors.lavender;
    final f = Path()
      ..moveTo(78, 148)
      ..lineTo(78, 80)
      ..quadraticBezierTo(78, 62, 96, 59)
      ..lineTo(128, 51);
    canvas.drawPath(f, stroke);
    canvas.drawLine(const Offset(78, 104), const Offset(112, 104), stroke);
    final arrow = Path()
      ..moveTo(112, 40)
      ..lineTo(134, 50)
      ..lineTo(118, 68);
    stroke.color = AppColors.pink;
    canvas.drawPath(arrow, stroke);
  }

  @override
  bool shouldRepaint(covariant _LogoPainter oldDelegate) => oldDelegate.bg != bg;
}
__END__

############################ lib/widgets/coming_soon.dart ############################
cat > lib/widgets/coming_soon.dart <<'__END__'
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

class ComingSoon extends StatelessWidget {
  final String title;
  final IconData icon;
  final String note;

  const ComingSoon(
      {super.key, required this.title, required this.icon, required this.note});

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value:
          context.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                      colors: [AppColors.lavender, AppColors.pink]),
                ),
                child: Icon(icon, size: 44, color: AppColors.ink),
              ),
              const SizedBox(height: 20),
              Text(title, style: AppText.display(size: 24, color: fin.text)),
              const SizedBox(height: 10),
              Text(note,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: fin.subtext, height: 1.5)),
              const SizedBox(height: 80),
            ]),
          ),
        ),
      ),
    );
  }
}
__END__

############################ lib/widgets/txn_tile.dart ############################
cat > lib/widgets/txn_tile.dart <<'__END__'
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/db.dart';
import '../state/app_state.dart';
import '../state/txn_state.dart';
import '../theme.dart';

String prettyParty(String? s) {
  if (s == null || s.trim().isEmpty) return '';
  var v = s.trim();
  if (v.contains('@')) v = v.split('@').first;
  return v.length > 28 ? '${v.substring(0, 28)}…' : v;
}

Color typeColor(TxnType t) => switch (t) {
      TxnType.expense => AppColors.expense,
      TxnType.income => AppColors.income,
      TxnType.transfer => AppColors.lavender,
    };

String dayLabel(DateTime d) {
  final n = DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final diff = today.difference(DateTime(d.year, d.month, d.day)).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return DateFormat(d.year == n.year ? 'EEE, d MMM' : 'd MMM yyyy').format(d);
}

class TxnTile extends StatelessWidget {
  final Txn txn;
  final bool hide;
  final bool showDate;
  final VoidCallback? onTap;

  const TxnTile({
    super.key,
    required this.txn,
    this.hide = false,
    this.showDate = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    final cat = context.read<TxnState>().category(txn.categoryId);
    final accounts = context.read<AccountsState>().accounts;
    String accName(int? id) {
      for (final a in accounts) {
        if (a.id == id) return a.name;
      }
      return 'Account';
    }

    final isTransfer = txn.type == TxnType.transfer;
    final color = cat?.colorValue ?? typeColor(txn.type);
    final icon = isTransfer
        ? Icons.swap_horiz_rounded
        : (cat?.icon ??
            (txn.type == TxnType.income
                ? Icons.south_west_rounded
                : Icons.north_east_rounded));
    final party = prettyParty(txn.counterparty);
    final title = isTransfer
        ? '${accName(txn.accountId)} → ${accName(txn.toAccountId)}'
        : (party.isNotEmpty
            ? party
            : (cat?.name ??
                (txn.type == TxnType.income ? 'Income' : 'Expense')));
    final time = DateFormat(showDate ? 'd MMM, h:mm a' : 'h:mm a')
        .format(txn.occurredAt);
    final label = isTransfer
        ? (party.isNotEmpty ? party : 'Transfer')
        : (cat?.name ?? 'Needs review');
    final sign = txn.type == TxnType.expense
        ? '-'
        : (txn.type == TxnType.income ? '+' : '');
    final amountColor = txn.type == TxnType.income
        ? AppColors.income
        : (isTransfer ? AppColors.lavender : fin.text);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: fin.text,
                        fontWeight: FontWeight.w600,
                        fontSize: 15)),
                const SizedBox(height: 3),
                Text('$label · $time',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: txn.status == 'review'
                            ? AppColors.lavender
                            : fin.subtext,
                        fontSize: 12.5)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            hide ? '₹ ••••' : '$sign${inr(txn.amount)}',
            style: TextStyle(
                color: amountColor, fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ]),
      ),
    );
  }
}
__END__

############################ lib/screens/add_txn_screen.dart ############################
cat > lib/screens/add_txn_screen.dart <<'__END__'
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/db.dart';
import '../state/app_state.dart';
import '../state/txn_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/txn_tile.dart';
import 'categories_screen.dart';

Future<int?> pickAccount(BuildContext context,
    {int? exclude, String title = 'Choose account'}) {
  final fin = context.fin;
  final accounts = context
      .read<AccountsState>()
      .accounts
      .where((a) => a.id != exclude)
      .toList();
  return showModalBottomSheet<int>(
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
            const SizedBox(height: 12),
            for (final a in accounts)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                      gradient: AppColors.gradientAt(a.colorIndex),
                      shape: BoxShape.circle),
                  child: Icon(a.type.icon, color: Colors.white, size: 20),
                ),
                title: Text(a.name),
                subtitle: Text(inr(a.balance)),
                onTap: () => Navigator.pop(c, a.id),
              ),
            if (accounts.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('No other accounts yet. Add one from Home.',
                    style: TextStyle(color: fin.subtext)),
              ),
          ],
        ),
      ),
    ),
  );
}

Future<int?> pickCategory(BuildContext context, String kind) {
  final fin = context.fin;
  final cats = context.read<TxnState>().byKind(kind);
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: fin.card,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (c) => SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.8),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          children: [
            Row(children: [
              Expanded(
                  child: Text('Choose category',
                      style: AppText.display(size: 18, color: fin.text))),
              TextButton(
                onPressed: () {
                  Navigator.pop(c);
                  Navigator.of(context)
                      .push(fadeRoute(const CategoriesScreen()));
                },
                child: const Text('Manage'),
              ),
            ]),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 0.78,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                for (final cat in cats)
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.pop(c, cat.id),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: cat.colorValue.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(cat.icon, color: cat.colorValue),
                        ),
                        const SizedBox(height: 6),
                        Text(cat.name,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: fin.text,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class AddTxnScreen extends StatefulWidget {
  final TxnType type;
  final Txn? editing;

  const AddTxnScreen({super.key, this.type = TxnType.expense, this.editing});

  @override
  State<AddTxnScreen> createState() => _AddTxnScreenState();
}

class _AddTxnScreenState extends State<AddTxnScreen> {
  late TxnType _type;
  String _amount = '0';
  int? _accountId;
  int? _toAccountId;
  int? _categoryId;
  late DateTime _when;
  final _note = TextEditingController();
  final _payee = TextEditingController();
  bool _remember = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _type = e?.type ?? widget.type;
    _when = e?.occurredAt ?? DateTime.now();
    if (e != null) {
      _amount = e.amount == e.amount.roundToDouble()
          ? e.amount.toStringAsFixed(0)
          : e.amount.toStringAsFixed(2);
      _accountId = e.accountId;
      _toAccountId = e.toAccountId;
      _categoryId = e.categoryId;
      _note.text = e.note ?? '';
      _payee.text = e.counterparty ?? '';
    } else {
      final accounts = context.read<AccountsState>().accounts;
      Account? bank;
      Account? cash;
      for (final a in accounts) {
        if (bank == null && a.type != AccountType.cash) bank = a;
        if (cash == null && a.type == AccountType.cash) cash = a;
      }
      _accountId = (bank ?? cash)?.id;
      if (_type == TxnType.transfer) _toAccountId = cash?.id;
    }
  }

  @override
  void dispose() {
    _note.dispose();
    _payee.dispose();
    super.dispose();
  }

  double get _value => double.tryParse(_amount) ?? 0;

  bool get _valid =>
      !_saving &&
      _value > 0 &&
      _accountId != null &&
      (_type != TxnType.transfer ||
          (_toAccountId != null && _toAccountId != _accountId));

  void _key(String k) {
    HapticFeedback.selectionClick();
    setState(() {
      if (k == '<') {
        _amount =
            _amount.length <= 1 ? '0' : _amount.substring(0, _amount.length - 1);
        return;
      }
      if (k == '.') {
        if (!_amount.contains('.')) _amount = '$_amount.';
        return;
      }
      if (_amount.contains('.') && _amount.split('.')[1].length >= 2) return;
      if (_amount.replaceAll('.', '').length >= 9) return;
      _amount = _amount == '0' ? k : '$_amount$k';
    });
  }

  String _accName(int? id) {
    for (final a in context.read<AccountsState>().accounts) {
      if (a.id == id) return a.name;
    }
    return 'Choose';
  }

  Future<void> _pickWhen() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(_when));
    setState(() {
      _when = DateTime(d.year, d.month, d.day, t?.hour ?? _when.hour,
          t?.minute ?? _when.minute);
    });
  }

  Future<void> _save() async {
    final txns = context.read<TxnState>();
    final accounts = context.read<AccountsState>();
    final nav = Navigator.of(context);
    setState(() => _saving = true);
    final e = widget.editing;
    final isTransfer = _type == TxnType.transfer;
    final payee = _payee.text.trim();
    final note = _note.text.trim();
    final t = Txn(
      id: e?.id,
      accountId: _accountId,
      toAccountId: isTransfer ? _toAccountId : null,
      type: _type,
      amount: _value,
      categoryId: isTransfer ? null : _categoryId,
      personId: e?.personId,
      counterparty: payee.isEmpty ? null : payee,
      note: note.isEmpty ? null : note,
      ref: e?.ref,
      smsBody: e?.smsBody,
      status: (isTransfer || _categoryId != null) ? 'done' : 'review',
      occurredAt: _when,
    );
    await txns.save(accounts, t, old: e);
    if (_remember &&
        !isTransfer &&
        _categoryId != null &&
        payee.isNotEmpty &&
        e?.smsBody != null) {
      await txns.rememberRule(payee, _categoryId!);
    }
    nav.pop();
  }

  Future<void> _delete() async {
    final txns = context.read<TxnState>();
    final accounts = context.read<AccountsState>();
    final nav = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: const Text('Account balances will be adjusted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Delete',
                  style: TextStyle(color: AppColors.expense))),
        ],
      ),
    );
    if (ok == true) {
      await txns.delete(accounts, widget.editing!);
      nav.pop();
    }
  }

  Widget _typeSwitch(FinColors fin) {
    Widget item(TxnType t, String label) {
      final sel = _type == t;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() {
            _type = t;
            _categoryId = null;
            if (t == TxnType.transfer && _toAccountId == null) {
              for (final a in context.read<AccountsState>().accounts) {
                if (a.type == AccountType.cash && a.id != _accountId) {
                  _toAccountId = a.id;
                  break;
                }
              }
            }
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: sel ? typeColor(t) : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
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

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: fin.card, borderRadius: BorderRadius.circular(18)),
      child: Row(children: [
        item(TxnType.expense, 'Expense'),
        item(TxnType.income, 'Income'),
        item(TxnType.transfer, 'Transfer'),
      ]),
    );
  }

  Widget _field(FinColors fin, IconData icon, Color color, String label,
      String value, VoidCallback onTap) {
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
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(color: fin.subtext, fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(value,
                        style: TextStyle(
                            color: fin.text,
                            fontWeight: FontWeight.w600,
                            fontSize: 15)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: fin.subtext),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _keypad(FinColors fin) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['.', '0', '<'],
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      decoration: BoxDecoration(
        color: fin.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          for (final r in rows)
            Row(children: [
              for (final k in r)
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _key(k),
                    child: SizedBox(
                      height: 52,
                      child: Center(
                        child: k == '<'
                            ? Icon(Icons.backspace_outlined, color: fin.text)
                            : Text(k,
                                style: TextStyle(
                                    color: fin.text,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ),
            ]),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    final e = widget.editing;
    final isTransfer = _type == TxnType.transfer;
    final kind = _type == TxnType.income ? 'income' : 'expense';
    final cat = context.watch<TxnState>().category(_categoryId);
    final color = typeColor(_type);

    return Scaffold(
      appBar: AppBar(
        title: Text(e == null ? 'New transaction' : 'Edit transaction'),
        actions: [
          if (e != null)
            IconButton(
                onPressed: _delete, icon: const Icon(Icons.delete_rounded)),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            children: [
              _typeSwitch(fin),
              const SizedBox(height: 22),
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: FittedBox(
                    key: ValueKey('$_amount$_type'),
                    fit: BoxFit.scaleDown,
                    child: Text('₹$_amount',
                        style: AppText.display(size: 46, color: color)),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              _field(
                fin,
                Icons.account_balance_wallet_rounded,
                AppColors.lavender,
                isTransfer ? 'From account' : 'Account',
                _accName(_accountId),
                () async {
                  final id = await pickAccount(context);
                  if (id != null) setState(() => _accountId = id);
                },
              ),
              if (isTransfer)
                _field(
                  fin,
                  Icons.south_rounded,
                  AppColors.pink,
                  'To account',
                  _accName(_toAccountId),
                  () async {
                    final id = await pickAccount(context,
                        exclude: _accountId, title: 'Move money to');
                    if (id != null) setState(() => _toAccountId = id);
                  },
                ),
              if (!isTransfer)
                _field(
                  fin,
                  cat?.icon ?? Icons.category_rounded,
                  cat?.colorValue ?? AppColors.pink,
                  'Category',
                  cat?.name ?? 'Choose category',
                  () async {
                    final id = await pickCategory(context, kind);
                    if (id != null) setState(() => _categoryId = id);
                  },
                ),
              _field(
                fin,
                Icons.calendar_month_rounded,
                AppColors.income,
                'Date and time',
                DateFormat('EEE, d MMM yyyy · h:mm a').format(_when),
                _pickWhen,
              ),
              TextField(
                controller: _payee,
                decoration: InputDecoration(
                  hintText: isTransfer
                      ? 'Label (optional)'
                      : (_type == TxnType.income
                          ? 'Received from (optional)'
                          : 'Paid to (optional)'),
                  prefixIcon: const Icon(Icons.storefront_rounded),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _note,
                decoration: const InputDecoration(
                  hintText: 'Note (optional)',
                  prefixIcon: Icon(Icons.edit_note_rounded),
                ),
              ),
              if (e?.smsBody != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.lavender.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.lavender.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [
                        Icon(Icons.sms_rounded,
                            size: 16, color: AppColors.lavender),
                        SizedBox(width: 6),
                        Text('From bank SMS',
                            style: TextStyle(
                                color: AppColors.lavender,
                                fontWeight: FontWeight.w700,
                                fontSize: 12)),
                      ]),
                      const SizedBox(height: 6),
                      Text(e!.smsBody!,
                          style: TextStyle(
                              color: fin.subtext, fontSize: 12.5, height: 1.4)),
                    ],
                  ),
                ),
                if (!isTransfer && _payee.text.trim().isNotEmpty)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _remember,
                    onChanged: (v) => setState(() => _remember = v ?? true),
                    title: Text(
                        'Always use this category for ${prettyParty(_payee.text)}',
                        style: TextStyle(color: fin.text, fontSize: 14)),
                  ),
              ],
            ],
          ),
        ),
        _keypad(fin),
        Container(
          color: fin.card,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: SafeArea(
            top: false,
            child: PrimaryButton(
              label: e == null ? 'Save' : 'Update',
              icon: Icons.check_rounded,
              onPressed: _valid ? _save : null,
            ),
          ),
        ),
      ]),
    );
  }
}
__END__

############################ lib/screens/categories_screen.dart ############################
cat > lib/screens/categories_screen.dart <<'__END__'
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/db.dart';
import '../data/repo.dart';
import '../state/txn_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

const List<int> kPalette = [
  0xFFF4A261, 0xFF7BC67E, 0xFF8E8BEA, 0xFF5DADE2, 0xFFE76F51, 0xFFF6C85F, 0xFF9B7EDE,
  0xFFEF7C8E, 0xFFEBB9D6, 0xFF4FB3A9, 0xFF6C8EF5, 0xFFD78FD3, 0xFF34B892, 0xFF9AA0B4,
];

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final txns = context.watch<TxnState>();
    final fin = context.fin;

    Widget section(String title, List<Category> cats) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 20, 6, 8),
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
            child: Column(children: [
              for (final c in cats)
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: c.colorValue.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(c.icon, color: c.colorValue, size: 20),
                  ),
                  title: Text(c.name),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context)
                      .push(fadeRoute(CategoryEditor(category: c))),
                ),
            ]),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            Navigator.of(context).push(fadeRoute(const CategoryEditor())),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New category'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
        children: [
          section('Expense', txns.byKind('expense')),
          section('Income', txns.byKind('income')),
        ],
      ),
    );
  }
}

class CategoryEditor extends StatefulWidget {
  final Category? category;

  const CategoryEditor({super.key, this.category});

  @override
  State<CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<CategoryEditor> {
  late final TextEditingController _name;
  late String _icon;
  late int _color;
  late String _kind;

  @override
  void initState() {
    super.initState();
    final c = widget.category;
    _name = TextEditingController(text: c?.name ?? '');
    _icon = c?.iconKey ?? 'other';
    _color = c?.color ?? kPalette.first;
    _kind = c?.kind ?? 'expense';
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final txns = context.read<TxnState>();
    final nav = Navigator.of(context);
    final db = AppDatabase.instance;
    final c = widget.category;
    final name = _name.text.trim();
    if (c == null) {
      await db.insertCategory(name, _icon, _color, _kind);
    } else {
      await db.updateCategory(Category(
          id: c.id,
          name: name,
          iconKey: _icon,
          color: _color,
          kind: c.kind,
          sort: c.sort));
    }
    await txns.load();
    nav.pop();
  }

  Future<void> _delete() async {
    final txns = context.read<TxnState>();
    final nav = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete category?'),
        content: const Text(
            'Transactions in this category will move to Needs review.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Delete',
                  style: TextStyle(color: AppColors.expense))),
        ],
      ),
    );
    if (ok == true) {
      await AppDatabase.instance.deleteCategory(widget.category!.id!);
      await txns.load();
      nav.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    final color = Color(_color);
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category == null ? 'New category' : 'Edit category'),
        actions: [
          if (widget.category != null)
            IconButton(
                onPressed: _delete, icon: const Icon(Icons.delete_rounded)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(26),
              ),
              child: Icon(kCategoryIcons[_icon] ?? Icons.category_rounded,
                  color: color, size: 40),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Category name'),
            onChanged: (_) => setState(() {}),
          ),
          if (widget.category == null) ...[
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'expense', label: Text('Expense')),
                ButtonSegment(value: 'income', label: Text('Income')),
              ],
              selected: {_kind},
              showSelectedIcon: false,
              onSelectionChanged: (v) => setState(() => _kind = v.first),
            ),
          ],
          const SizedBox(height: 20),
          Text('Icon',
              style: TextStyle(color: fin.subtext, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final e in kCategoryIcons.entries)
                GestureDetector(
                  onTap: () => setState(() => _icon = e.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: fin.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: _icon == e.key ? primary : fin.divider,
                          width: _icon == e.key ? 2.5 : 1),
                    ),
                    child: Icon(e.value, color: color),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Colour',
              style: TextStyle(color: fin.subtext, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final p in kPalette)
                GestureDetector(
                  onTap: () => setState(() => _color = p),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Color(p),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: _color == p ? primary : Colors.transparent,
                          width: 3),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 28),
          PrimaryButton(
            label: 'Save category',
            icon: Icons.check_rounded,
            onPressed: _name.text.trim().isEmpty ? null : _save,
          ),
        ],
      ),
    );
  }
}
__END__

############################ lib/screens/review_screen.dart ############################
cat > lib/screens/review_screen.dart <<'__END__'
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/db.dart';
import '../data/repo.dart';
import '../state/app_state.dart';
import '../state/txn_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/txn_tile.dart';
import 'add_txn_screen.dart';

class ReviewBanner extends StatelessWidget {
  final int count;
  const ReviewBanner({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(fadeRoute(const ReviewScreen())),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient:
              const LinearGradient(colors: [AppColors.lavender, AppColors.pink]),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(children: [
          const Icon(Icons.inbox_rounded, color: AppColors.ink),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$count to review',
                    style: const TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 16)),
                Text('Tap a category for each one',
                    style: TextStyle(
                        color: AppColors.ink.withValues(alpha: 0.7),
                        fontSize: 12.5)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_rounded, color: AppColors.ink),
        ]),
      ),
    );
  }
}

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  Future<List<Txn>>? _future;
  int _version = -1;

  Future<void> _markAll(TxnState txns) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Mark all as reviewed?'),
        content: const Text(
            'They will stay uncategorised. You can still edit them later.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Mark all')),
        ],
      ),
    );
    if (ok == true) await txns.markAllReviewed();
  }

  @override
  Widget build(BuildContext context) {
    final txns = context.watch<TxnState>();
    final hide = context.watch<SettingsState>().hideAmounts;
    if (_future == null || _version != txns.version) {
      _version = txns.version;
      _future = AppDatabase.instance.txns(status: 'review', limit: 500);
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review'),
        actions: [
          if (txns.reviewCount > 0)
            TextButton(
                onPressed: () => _markAll(txns),
                child: const Text('Mark all done')),
        ],
      ),
      body: FutureBuilder<List<Txn>>(
        future: _future,
        builder: (context, snap) {
          final list = snap.data ?? const <Txn>[];
          if (snap.connectionState != ConnectionState.done && list.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (list.isEmpty) return const _AllDone();
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) =>
                _ReviewCard(key: ValueKey(list[i].id), txn: list[i], hide: hide),
          );
        },
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Txn txn;
  final bool hide;

  const _ReviewCard({super.key, required this.txn, required this.hide});

  Future<void> _pick(BuildContext context, int categoryId) async {
    final txns = context.read<TxnState>();
    final messenger = ScaffoldMessenger.of(context);
    final party = prettyParty(txn.counterparty);
    final catName = txns.category(categoryId)?.name ?? '';
    await txns.categorize(txn, categoryId);
    if (party.isNotEmpty) {
      messenger.showSnackBar(SnackBar(
          content: Text('Saved. FinUp will file $party under $catName next time.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    final txns = context.read<TxnState>();
    final kind = txn.type == TxnType.income ? 'income' : 'expense';
    final cats = txns.byKind(kind);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 14),
      decoration: BoxDecoration(
          color: fin.card, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TxnTile(
            txn: txn,
            hide: hide,
            showDate: true,
            onTap: () => Navigator.of(context)
                .push(fadeRoute(AddTxnScreen(editing: txn))),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text('Pick a category',
                style: TextStyle(color: fin.subtext, fontSize: 12)),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in cats.take(8))
                ActionChip(
                  avatar: Icon(c.icon, size: 16, color: c.colorValue),
                  label: Text(c.name),
                  onPressed: () => _pick(context, c.id!),
                ),
              ActionChip(
                avatar: const Icon(Icons.more_horiz_rounded, size: 16),
                label: const Text('More'),
                onPressed: () async {
                  final id = await pickCategory(context, kind);
                  if (id != null && context.mounted) await _pick(context, id);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AllDone extends StatelessWidget {
  const _AllDone();

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Looping(
          duration: const Duration(milliseconds: 2200),
          builder: (context, t) {
            final s = 1 + 0.06 * (t < 0.5 ? t * 2 : (1 - t) * 2);
            return Transform.scale(
              scale: s,
              child: Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                    color: AppColors.income, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 52),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        Text('All caught up',
            style: AppText.display(size: 22, color: fin.text)),
        const SizedBox(height: 8),
        Text('New bank SMS will show up here.',
            style: TextStyle(color: fin.subtext)),
      ]),
    );
  }
}
__END__

############################ lib/screens/activity_screen.dart ############################
cat > lib/screens/activity_screen.dart <<'__END__'
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/db.dart';
import '../data/repo.dart';
import '../state/app_state.dart';
import '../state/txn_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/txn_tile.dart';
import 'add_txn_screen.dart';
import 'review_screen.dart';

class _Day {
  final DateTime day;
  final double spent;
  const _Day(this.day, this.spent);
}

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  String _filter = 'all';
  final _search = TextEditingController();
  bool _searching = false;
  Future<List<Txn>>? _future;
  int _version = -1;
  String _key = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Object> _group(List<Txn> list) {
    final totals = <DateTime, double>{};
    for (final t in list) {
      final d = DateTime(t.occurredAt.year, t.occurredAt.month, t.occurredAt.day);
      if (t.type == TxnType.expense) totals[d] = (totals[d] ?? 0) + t.amount;
    }
    final out = <Object>[];
    DateTime? cur;
    for (final t in list) {
      final d = DateTime(t.occurredAt.year, t.occurredAt.month, t.occurredAt.day);
      if (cur == null || d != cur) {
        cur = d;
        out.add(_Day(d, totals[d] ?? 0));
      }
      out.add(t);
    }
    return out;
  }

  Widget _pills(FinColors fin) {
    final dark = context.isDark;
    Widget item(String value, String label) {
      final sel = _filter == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _filter = value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: sel
                  ? (dark ? AppColors.lavender : AppColors.ink)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(label,
                  style: TextStyle(
                      color: sel
                          ? (dark ? AppColors.ink : Colors.white)
                          : fin.text,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: fin.card, borderRadius: BorderRadius.circular(18)),
      child: Row(children: [
        item('all', 'All'),
        item('expense', 'Spending'),
        item('income', 'Income'),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    final txns = context.watch<TxnState>();
    final hide = context.watch<SettingsState>().hideAmounts;
    final key = '$_filter|${_search.text}';
    if (_future == null || _version != txns.version || key != _key) {
      _version = txns.version;
      _key = key;
      _future = AppDatabase.instance.txns(
          type: _filter == 'all' ? null : _filter,
          search: _search.text,
          limit: 400);
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value:
          context.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
            child: Row(children: [
              Expanded(
                child: _searching
                    ? TextField(
                        controller: _search,
                        autofocus: true,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: 'Search payee or note',
                          prefixIcon: Icon(Icons.search_rounded),
                          isDense: true,
                        ),
                      )
                    : Text('Activity',
                        style: AppText.display(size: 26, color: fin.text)),
              ),
              if (txns.syncing)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              IconButton(
                onPressed: () => setState(() {
                  _searching = !_searching;
                  if (!_searching) _search.clear();
                }),
                icon: Icon(
                    _searching ? Icons.close_rounded : Icons.search_rounded),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _pills(fin)),
          if (txns.reviewCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: ReviewBanner(count: txns.reviewCount),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await txns.sync(context.read<AccountsState>());
              },
              child: FutureBuilder<List<Txn>>(
                future: _future,
                builder: (context, snap) {
                  final list = snap.data ?? const <Txn>[];
                  if (list.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 90),
                        Icon(Icons.receipt_long_rounded,
                            size: 48, color: fin.subtext),
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            snap.connectionState == ConnectionState.done
                                ? 'No transactions yet'
                                : 'Loading…',
                            style: TextStyle(color: fin.subtext),
                          ),
                        ),
                      ],
                    );
                  }
                  final items = _group(list);
                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final it = items[i];
                      if (it is _Day) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
                          child: Row(children: [
                            Text(dayLabel(it.day),
                                style: TextStyle(
                                    color: fin.subtext,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13)),
                            const Spacer(),
                            if (it.spent > 0)
                              Text(hide ? '' : '-${inr(it.spent)}',
                                  style: TextStyle(
                                      color: fin.subtext, fontSize: 12.5)),
                          ]),
                        );
                      }
                      final t = it as Txn;
                      return TxnTile(
                        txn: t,
                        hide: hide,
                        onTap: () => Navigator.of(context)
                            .push(fadeRoute(AddTxnScreen(editing: t))),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
__END__

############################ lib/screens/sms_setup_screen.dart ############################
cat > lib/screens/sms_setup_screen.dart <<'__END__'
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../native.dart';
import '../state/app_state.dart';
import '../state/txn_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/logo.dart';
import 'home_shell.dart';
import 'intro_screen.dart';

class SmsSetupScreen extends StatefulWidget {
  final bool fromOnboarding;
  const SmsSetupScreen({super.key, this.fromOnboarding = false});

  @override
  State<SmsSetupScreen> createState() => _SmsSetupScreenState();
}

class _SmsSetupScreenState extends State<SmsSetupScreen> {
  int _months = 3;
  int _phase = 0; // 0 intro, 1 scanning, 2 done, 3 denied
  int _found = 0;

  Future<void> _start() async {
    final txns = context.read<TxnState>();
    final accounts = context.read<AccountsState>();
    final settings = context.read<SettingsState>();
    final ok = await Native.requestSms();
    if (!mounted) return;
    if (!ok) {
      setState(() => _phase = 3);
      return;
    }
    setState(() => _phase = 1);
    final since = DateTime.now()
        .subtract(Duration(days: 30 * _months))
        .millisecondsSinceEpoch;
    final n = await txns.sync(accounts, sinceMs: since);
    await Native.requestNotifications();
    await Native.scheduleReminder(settings.reminderTime.hour,
        settings.reminderTime.minute, await ReminderPrefs.isOn());
    if (!mounted) return;
    setState(() {
      _found = n;
      _phase = 2;
    });
  }

  void _finish() {
    if (widget.fromOnboarding) {
      Navigator.of(context)
          .pushAndRemoveUntil(fadeRoute(const HomeShell()), (r) => false);
    } else {
      Navigator.of(context).pop();
    }
  }

  Widget _chip(int months) {
    final sel = _months == months;
    return GestureDetector(
      onTap: () => setState(() => _months = months),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          gradient: sel
              ? const LinearGradient(colors: [AppColors.lavender, AppColors.pink])
              : null,
          color: sel ? null : const Color(0xFF1B1B25),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: sel ? Colors.transparent : Colors.white12),
        ),
        child: Text('$months ${months == 1 ? 'month' : 'months'}',
            style: TextStyle(
                color: sel ? AppColors.ink : Colors.white70,
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _body() {
    const white60 = TextStyle(color: Colors.white60, fontSize: 15, height: 1.5);
    switch (_phase) {
      case 1:
        return Column(
          key: const ValueKey(1),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Looping(
              duration: const Duration(milliseconds: 1600),
              builder: (context, t) => Transform.rotate(
                angle: t * 2 * math.pi,
                child: const FinUpLogo(size: 96),
              ),
            ),
            const SizedBox(height: 28),
            Text('Reading your bank SMS…',
                style: AppText.display(size: 22, color: Colors.white)),
            const SizedBox(height: 8),
            const Text('Everything stays on this phone.', style: white60),
          ],
        );
      case 2:
        return Column(
          key: const ValueKey(2),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutBack,
              builder: (context, v, child) =>
                  Transform.scale(scale: v, child: child),
              child: Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                    color: AppColors.income, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 52),
              ),
            ),
            const SizedBox(height: 24),
            Text('Found $_found transactions',
                textAlign: TextAlign.center,
                style: AppText.display(size: 24, color: Colors.white)),
            const SizedBox(height: 8),
            const Text(
                'They are waiting in your review inbox. Your bank balance is updated too.',
                textAlign: TextAlign.center,
                style: white60),
            const SizedBox(height: 32),
            PrimaryButton(
                label: 'Continue',
                icon: Icons.arrow_forward_rounded,
                onPressed: _finish),
          ],
        );
      case 3:
        return Column(
          key: const ValueKey(3),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sms_failed_rounded, color: AppColors.pink, size: 64),
            const SizedBox(height: 20),
            Text('SMS access was denied',
                style: AppText.display(size: 22, color: Colors.white)),
            const SizedBox(height: 8),
            const Text(
                'Open settings, tap Permissions, then allow SMS for FinUp. You can still add entries by hand.',
                textAlign: TextAlign.center,
                style: white60),
            const SizedBox(height: 28),
            PrimaryButton(
                label: 'Open settings',
                icon: Icons.settings_rounded,
                onPressed: () => Native.openSettings()),
            const SizedBox(height: 8),
            TextButton(
                onPressed: () => setState(() => _phase = 0),
                child: const Text('Try again',
                    style: TextStyle(color: Colors.white70))),
            TextButton(
                onPressed: _finish,
                child: const Text('Skip for now',
                    style: TextStyle(color: Colors.white38))),
          ],
        );
      default:
        return Column(
          key: const ValueKey(0),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
                child: Center(
                    child: FittedBox(fit: BoxFit.scaleDown, child: SmsArt()))),
            Text('Turn on\nauto-tracking',
                style: AppText.display(size: 30, color: Colors.white)),
            const SizedBox(height: 12),
            const Text(
                'FinUp reads only bank transaction SMS, on this phone, to log amount, time, account and balance. Nothing is uploaded.',
                style: white60),
            const SizedBox(height: 20),
            const Text('Import past messages from',
                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Row(children: [
              _chip(1),
              const SizedBox(width: 8),
              _chip(3),
              const SizedBox(width: 8),
              _chip(6),
            ]),
            const SizedBox(height: 24),
            PrimaryButton(
                label: 'Allow SMS access',
                icon: Icons.sms_rounded,
                onPressed: _start),
            Center(
              child: TextButton(
                onPressed: _finish,
                child: const Text('Skip for now',
                    style: TextStyle(color: Colors.white38)),
              ),
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [
          const Positioned.fill(
            child: Opacity(
                opacity: 0.3,
                child: OrbitBackground(center: Alignment(0.3, -0.7))),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 12),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: _body(),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
__END__

############################ lib/screens/people_screen.dart (placeholder until Part 4) ############################
cat > lib/screens/people_screen.dart <<'__END__'
import 'package:flutter/material.dart';

import '../widgets/coming_soon.dart';

class PeopleScreen extends StatelessWidget {
  const PeopleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoon(
      title: 'People',
      icon: Icons.people_alt_rounded,
      note: 'Your personal ledger for friends and family arrives in Part 4.',
    );
  }
}

void openPeopleEntry(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('The people ledger arrives in Part 4.')));
}
__END__

############################ lib/screens/insights_screen.dart (placeholder until Part 3) ############################
cat > lib/screens/insights_screen.dart <<'__END__'
import 'package:flutter/material.dart';

import '../widgets/coming_soon.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoon(
      title: 'Insights',
      icon: Icons.pie_chart_rounded,
      note: 'Charts, budgets and goals arrive in Part 3.',
    );
  }
}
__END__

############################ lib/screens/home_screen.dart ############################
cat > lib/screens/home_screen.dart <<'__END__'
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/db.dart';
import '../state/app_state.dart';
import '../state/txn_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/logo.dart';
import '../widgets/txn_tile.dart';
import 'account_editor.dart';
import 'add_txn_screen.dart';
import 'review_screen.dart';
import 'settings_screen.dart';
import 'sms_setup_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onSeeAll;
  const HomeScreen({super.key, this.onSeeAll});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _pc = PageController(viewportFraction: 0.86);

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _open(Widget page) => Navigator.of(context).push(fadeRoute(page));

  Widget _quick(FinColors fin, IconData icon, String label, Color color,
      TxnType type) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _open(AddTxnScreen(type: type)),
        child: Column(children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                  color: fin.text, fontWeight: FontWeight.w600, fontSize: 13)),
        ]),
      ),
    );
  }

  Widget _stat(FinColors fin, IconData icon, Color color, String label,
      String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: fin.card, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(label, style: TextStyle(color: fin.subtext, fontSize: 13)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: AppText.display(size: 20, color: fin.text)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    final settings = context.watch<SettingsState>();
    final accounts = context.watch<AccountsState>();
    final txns = context.watch<TxnState>();
    final hide = settings.hideAmounts;
    final top = MediaQuery.of(context).padding.top;
    final list = accounts.accounts;
    final greeting =
        settings.userName.isEmpty ? 'Hello there' : 'Hi, ${settings.userName}';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: RefreshIndicator(
        onRefresh: () async {
          await txns.sync(accounts);
        },
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Container(
              padding: EdgeInsets.only(top: top + 8, bottom: 26),
              decoration: BoxDecoration(
                color: fin.hero,
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(36)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(children: [
                      const SizedBox(width: 8),
                      const FinUpLogo(size: 34),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(greeting,
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 15,
                                fontWeight: FontWeight.w500)),
                      ),
                      if (txns.syncing)
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white)),
                        ),
                      IconButton(
                        onPressed: () => settings.setHideAmounts(!hide),
                        icon: Icon(
                            hide
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: Colors.white),
                      ),
                      IconButton(
                        onPressed: () => _open(const SettingsScreen()),
                        icon: const Icon(Icons.settings_rounded,
                            color: Colors.white),
                      ),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(inr(accounts.total, hide: hide),
                              style: AppText.display(
                                  size: 38, color: Colors.white)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                            'Total balance · ${list.length} ${list.length == 1 ? 'account' : 'accounts'}',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 14)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Padding(
                    padding: const EdgeInsets.only(left: 20, right: 8),
                    child: Row(children: [
                      const Expanded(
                        child: Text('My Accounts',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700)),
                      ),
                      TextButton.icon(
                        onPressed: () => _open(const AccountEditor()),
                        icon: const Icon(Icons.add_rounded,
                            color: Colors.white, size: 18),
                        label: const Text('Add',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 190,
                    child: PageView.builder(
                      controller: _pc,
                      padEnds: false,
                      itemCount: list.length + 1,
                      itemBuilder: (context, i) => Padding(
                        padding: EdgeInsets.only(
                            left: i == 0 ? 20 : 6, right: 6, bottom: 4),
                        child: i < list.length
                            ? AccountCard(
                                account: list[i],
                                hide: hide,
                                onTap: () =>
                                    _open(AccountEditor(account: list[i])))
                            : AddAccountCard(
                                onTap: () => _open(const AccountEditor())),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!txns.smsEnabled) ...[
                    GestureDetector(
                      onTap: () => _open(const SmsSetupScreen()),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: fin.card,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.lavender, width: 1.5),
                        ),
                        child: Row(children: [
                          const Icon(Icons.sms_rounded, color: AppColors.lavender),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Turn on SMS auto-tracking',
                                    style: TextStyle(
                                        color: fin.text,
                                        fontWeight: FontWeight.w700)),
                                Text('Log every bank transaction automatically',
                                    style: TextStyle(
                                        color: fin.subtext, fontSize: 12.5)),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_rounded, color: fin.subtext),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (txns.reviewCount > 0) ...[
                    ReviewBanner(count: txns.reviewCount),
                    const SizedBox(height: 16),
                  ],
                  Row(children: [
                    _quick(fin, Icons.north_east_rounded, 'Expense',
                        AppColors.expense, TxnType.expense),
                    _quick(fin, Icons.south_west_rounded, 'Income',
                        AppColors.income, TxnType.income),
                    _quick(fin, Icons.swap_horiz_rounded, 'Transfer',
                        AppColors.lavender, TxnType.transfer),
                  ]),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(
                        child: _stat(fin, Icons.north_east_rounded,
                            AppColors.expense, 'Spent today',
                            inr(txns.todaySpent, hide: hide))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _stat(fin, Icons.inbox_rounded,
                            AppColors.lavender, 'To review',
                            '${txns.reviewCount}')),
                  ]),
                  const SizedBox(height: 24),
                  Row(children: [
                    Text('Recent',
                        style: TextStyle(
                            color: fin.text,
                            fontSize: 20,
                            fontWeight: FontWeight.w700)),
                    const Spacer(),
                    TextButton(
                        onPressed: widget.onSeeAll,
                        child: const Text('See all')),
                  ]),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                        color: fin.card,
                        borderRadius: BorderRadius.circular(24)),
                    child: txns.recent.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(20),
                            child: Center(
                              child: Text(
                                  'No transactions yet. Tap + or turn on SMS tracking.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: fin.subtext)),
                            ),
                          )
                        : Column(children: [
                            for (final t in txns.recent)
                              TxnTile(
                                  txn: t,
                                  hide: hide,
                                  showDate: true,
                                  onTap: () => _open(AddTxnScreen(editing: t))),
                          ]),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                        color: fin.card,
                        borderRadius: BorderRadius.circular(24)),
                    child: Column(children: [
                      const Icon(Icons.insights_rounded,
                          size: 40, color: AppColors.lavender),
                      const SizedBox(height: 12),
                      Text('Statistic charts arrive in Part 3',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: fin.text, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 130),
          ],
        ),
      ),
    );
  }
}
__END__

############################ lib/screens/home_shell.dart ############################
cat > lib/screens/home_shell.dart <<'__END__'
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/db.dart';
import '../state/app_state.dart';
import '../state/txn_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'account_editor.dart';
import 'activity_screen.dart';
import 'add_txn_screen.dart';
import 'home_screen.dart';
import 'insights_screen.dart';
import 'people_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _sync();
  }

  Future<void> _sync() async {
    if (!mounted) return;
    final txns = context.read<TxnState>();
    final accounts = context.read<AccountsState>();
    await txns.load();
    if (txns.smsEnabled) await txns.sync(accounts);
  }

  void _openAdd() {
    final fin = context.fin;
    void go(Widget page) {
      Navigator.pop(context);
      Navigator.of(context).push(fadeRoute(page));
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: fin.card,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add new', style: AppText.display(size: 20, color: fin.text)),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.0,
                children: [
                  _AddTile(
                      icon: Icons.north_east_rounded,
                      label: 'Expense',
                      color: AppColors.expense,
                      onTap: () => go(const AddTxnScreen(type: TxnType.expense))),
                  _AddTile(
                      icon: Icons.south_west_rounded,
                      label: 'Income',
                      color: AppColors.income,
                      onTap: () => go(const AddTxnScreen(type: TxnType.income))),
                  _AddTile(
                      icon: Icons.swap_horiz_rounded,
                      label: 'Transfer',
                      color: AppColors.lavender,
                      onTap: () => go(const AddTxnScreen(type: TxnType.transfer))),
                  _AddTile(
                      icon: Icons.people_alt_rounded,
                      label: 'Lend / Borrow',
                      color: const Color(0xFFF4A261),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        openPeopleEntry(context);
                      }),
                  _AddTile(
                      icon: Icons.account_balance_wallet_rounded,
                      label: 'Account',
                      color: AppColors.pink,
                      onTap: () => go(const AccountEditor())),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _tab,
        children: [
          HomeScreen(onSeeAll: () => setState(() => _tab = 1)),
          const ActivityScreen(),
          const PeopleScreen(),
          const InsightsScreen(),
        ],
      ),
      bottomNavigationBar: _BottomBar(
        index: _tab,
        onTap: (i) => setState(() => _tab = i),
        onAdd: _openAdd,
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AddTile(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 8),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: fin.text, fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final VoidCallback onAdd;

  const _BottomBar(
      {required this.index, required this.onTap, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        height: 72,
        decoration: BoxDecoration(
          color: fin.card,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: context.isDark ? 0.45 : 0.08),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(children: [
          _item(context, 0, Icons.grid_view_rounded),
          _item(context, 1, Icons.receipt_long_rounded),
          Expanded(
            child: Center(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onAdd();
                },
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                        colors: [AppColors.lavender, AppColors.pink]),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.lavender.withValues(alpha: 0.45),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child:
                      const Icon(Icons.add_rounded, color: AppColors.ink, size: 30),
                ),
              ),
            ),
          ),
          _item(context, 2, Icons.people_alt_rounded),
          _item(context, 3, Icons.pie_chart_rounded),
        ]),
      ),
    );
  }

  Widget _item(BuildContext context, int i, IconData icon) {
    final fin = context.fin;
    final selected = i == index;
    final active = Theme.of(context).colorScheme.primary;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap(i);
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: selected ? 1.12 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(icon, color: selected ? active : fin.subtext, size: 26),
            ),
            const SizedBox(height: 5),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: selected ? 18 : 0,
              height: 4,
              decoration: BoxDecoration(
                  color: active, borderRadius: BorderRadius.circular(4)),
            ),
          ],
        ),
      ),
    );
  }
}
__END__

############################ lib/screens/settings_screen.dart ############################
cat > lib/screens/settings_screen.dart <<'__END__'
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/db.dart';
import '../native.dart';
import '../state/app_state.dart';
import '../state/txn_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'account_editor.dart';
import 'categories_screen.dart';
import 'sms_setup_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _remOn = true;

  @override
  void initState() {
    super.initState();
    ReminderPrefs.isOn().then((v) {
      if (mounted) setState(() => _remOn = v);
    });
  }

  Future<void> _editName(SettingsState s) async {
    final c = TextEditingController(text: s.userName);
    final result = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(
            controller: c,
            autofocus: true,
            textCapitalization: TextCapitalization.words),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(d, c.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) await s.setUserName(result);
  }

  Future<void> _pickTime(SettingsState s) async {
    final picked =
        await showTimePicker(context: context, initialTime: s.reminderTime);
    if (picked == null) return;
    await s.setReminderTime(picked);
    await Native.requestNotifications();
    await Native.scheduleReminder(picked.hour, picked.minute, _remOn);
  }

  Future<void> _toggleReminder(SettingsState s, bool v) async {
    setState(() => _remOn = v);
    await ReminderPrefs.setOn(v);
    if (v) await Native.requestNotifications();
    await Native.scheduleReminder(
        s.reminderTime.hour, s.reminderTime.minute, v);
  }

  Future<void> _rescan() async {
    final txns = context.read<TxnState>();
    final accounts = context.read<AccountsState>();
    final messenger = ScaffoldMessenger.of(context);
    final since = DateTime.now()
        .subtract(const Duration(days: 90))
        .millisecondsSinceEpoch;
    final n = await txns.sync(accounts, sinceMs: since);
    messenger.showSnackBar(SnackBar(
        content: Text(n == 0
            ? 'No new transactions found.'
            : 'Added $n new transactions.')));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsState>();
    final txns = context.watch<TxnState>();
    final accounts = context.watch<AccountsState>().accounts;
    void open(Widget page) => Navigator.of(context).push(fadeRoute(page));

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
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
          _Section(title: 'SMS tracking', children: [
            ListTile(
              leading: Icon(Icons.sms_rounded,
                  color: txns.smsEnabled ? AppColors.income : null),
              title: Text(txns.smsEnabled ? 'Auto-tracking is on' : 'Turn on auto-tracking'),
              subtitle: Text(txns.smsEnabled
                  ? 'New bank SMS are imported each time you open FinUp'
                  : 'Allow FinUp to read bank SMS'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => open(const SmsSetupScreen()),
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
              onTap: () => open(const CategoriesScreen()),
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
                onTap: () => open(AccountEditor(account: a)),
              ),
            ListTile(
              leading: const Icon(Icons.add_circle_outline_rounded),
              title: const Text('Add account'),
              onTap: () => open(const AccountEditor()),
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
          _Section(title: 'Privacy', children: [
            SwitchListTile(
              secondary: const Icon(Icons.visibility_off_rounded),
              title: const Text('Hide amounts on Home'),
              value: s.hideAmounts,
              onChanged: s.setHideAmounts,
            ),
          ]),
          const _Section(title: 'About', children: [
            ListTile(
              leading: Icon(Icons.info_outline_rounded),
              title: Text('FinUp'),
              subtitle: Text('Version 1.1.0 · Part 2'),
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

############################ lib/screens/splash_screen.dart ############################
cat > lib/screens/splash_screen.dart <<'__END__'
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/logo.dart';
import 'home_shell.dart';
import 'intro_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..forward();
    Future.delayed(const Duration(milliseconds: 2200), _go);
  }

  void _go() {
    if (!mounted) return;
    final onboarded = context.read<SettingsState>().onboarded;
    Navigator.of(context).pushReplacement(
        fadeRoute(onboarded ? const HomeShell() : const IntroScreen()));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [
          const Positioned.fill(child: OrbitBackground()),
          Positioned(
            left: 28,
            right: 28,
            bottom: 90,
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final v = Curves.easeOutCubic.transform(_c.value);
                final pop = Curves.easeOutBack
                    .transform((_c.value * 1.4).clamp(0.0, 1.0).toDouble());
                return Opacity(
                  opacity: v,
                  child: Transform.translate(
                    offset: Offset(0, 30 * (1 - v)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Transform.scale(
                            scale: pop,
                            alignment: Alignment.bottomLeft,
                            child: const FinUpLogo(size: 76)),
                        const SizedBox(height: 18),
                        ShaderMask(
                          shaderCallback: (r) => const LinearGradient(
                                  colors: [AppColors.lavender, AppColors.pink])
                              .createShader(r),
                          child: Text('FinUp',
                              style:
                                  AppText.display(size: 56, color: Colors.white)),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Your money, auto-tracked.\nPrivate. Offline. Yours.',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 17, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
__END__

############################ lib/main.dart ############################
cat > lib/main.dart <<'__END__'
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/db.dart';
import 'data/repo.dart';
import 'native.dart';
import 'screens/splash_screen.dart';
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
    final themeMode =
        context.select<SettingsState, ThemeMode>((s) => s.themeMode);
    return MaterialApp(
      title: 'FinUp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: const SplashScreen(),
    );
  }
}
__END__

############################ onboarding now ends with SMS setup ############################
sed -i "s#import 'home_shell.dart';#import 'home_shell.dart';\nimport 'sms_setup_screen.dart';#" lib/screens/setup_screen.dart
sed -i "s#fadeRoute(const HomeShell())#fadeRoute(const SmsSetupScreen(fromOnboarding: true))#" lib/screens/setup_screen.dart

echo "FinUp Part 2 applied."