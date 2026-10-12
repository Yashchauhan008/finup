#!/usr/bin/env bash
set -euo pipefail
cd app
mkdir -p lib/notify lib/update lib/screens android/app/src/main/kotlin/com/yash/finup

############################ ANDROID MANIFEST (complete) ############################
cat > android/app/src/main/AndroidManifest.xml <<'__END__'
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.READ_SMS"/>
    <uses-permission android:name="android.permission.RECEIVE_SMS"/>
    <uses-permission android:name="android.permission.USE_BIOMETRIC"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" android:maxSdkVersion="32"/>
    <uses-permission android:name="android.permission.USE_EXACT_ALARM" tools:ignore="ExactAlarm,ProtectedPermissions"/>
    <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>
    <uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" tools:ignore="BatteryLife"/>

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
        <receiver
            android:name=".SmsReceiver"
            android:exported="true"
            android:permission="android.permission.BROADCAST_SMS">
            <intent-filter android:priority="999">
                <action android:name="android.provider.Telephony.SMS_RECEIVED"/>
            </intent-filter>
        </receiver>
        <receiver android:name=".NotifActionReceiver" android:exported="false"/>
        <receiver android:name=".InstallReceiver" android:exported="false"/>
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

############################ KOTLIN: Alerts.kt ############################
cat > android/app/src/main/kotlin/com/yash/finup/Alerts.kt <<'__END__'
package com.yash.finup

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.os.Build
import android.provider.Telephony
import org.json.JSONObject
import java.text.NumberFormat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object FlutterPrefs {
    private fun p(ctx: Context) = ctx.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
    fun long(ctx: Context, key: String): Long = try { p(ctx).getLong("flutter.$key", 0L) } catch (e: Exception) { 0L }
    fun bool(ctx: Context, key: String, def: Boolean): Boolean = try { p(ctx).getBoolean("flutter.$key", def) } catch (e: Exception) { def }
}

object AlertPrefs {
    private const val PREFS = "finup_native"
    fun smsAlerts(ctx: Context): Boolean =
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean("smsAlerts", true)
    fun setSmsAlerts(ctx: Context, v: Boolean) {
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean("smsAlerts", v).apply()
    }
}

object Pending {
    private const val PREFS = "finup_native"
    private fun read(ctx: Context): JSONObject = try {
        JSONObject(ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("pending", "{}") ?: "{}")
    } catch (e: Exception) { JSONObject() }
    private fun write(ctx: Context, o: JSONObject) {
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString("pending", o.toString()).apply()
    }
    fun save(ctx: Context, key: String, cat: Int) {
        val o = read(ctx)
        o.put(key, cat)
        write(ctx, o)
    }
    fun all(ctx: Context): HashMap<String, Int> {
        val o = read(ctx)
        val m = HashMap<String, Int>()
        val it = o.keys()
        while (it.hasNext()) {
            val k = it.next()
            m[k] = o.optInt(k, -1)
        }
        return m
    }
    fun remove(ctx: Context, keys: List<String>) {
        val o = read(ctx)
        for (k in keys) o.remove(k)
        write(ctx, o)
    }
}

object SmsParse {
    data class Result(
        val amount: Double,
        val debit: Boolean,
        val last4: String?,
        val party: String?,
        val ref: String?,
        val atm: Boolean
    )

    private val skip = Regex("\\b(otp|one time password|verification code|requested|request money|will be debited|failed|declined|unsuccessful)\\b", RegexOption.IGNORE_CASE)
    private val promo = Regex("\\b(offer|apply now|pre-approved|preapproved|loan|win|congratulations|voucher|discount)\\b", RegexOption.IGNORE_CASE)
    private val amountRx = Regex("(?:rs\\.?|inr|₹)\\s*([0-9][0-9,]*(?:\\.[0-9]{1,2})?)", RegexOption.IGNORE_CASE)
    private val drcr = Regex("(?:rs\\.?|inr|₹)\\s*[0-9][0-9,]*(?:\\.[0-9]{1,2})?\\s*(dr|cr)\\b", RegexOption.IGNORE_CASE)
    private val acct = Regex("(?:a/c|acct|account)\\.?\\s*(?:no\\.?\\s*)?[x*.\\-\\s]*([0-9]{3,6})", RegexOption.IGNORE_CASE)
    private val vpa = Regex("[a-z0-9][a-z0-9.\\-_]+@[a-z][a-z0-9]+", RegexOption.IGNORE_CASE)
    private val refRx = Regex("(?:ref(?:erence)?|utr|rrn|txn\\s*id)(?:\\s*no)?[\\s.:#-]*([0-9]{6,})", RegexOption.IGNORE_CASE)

    private fun knownBank(sender: String): Boolean {
        val u = sender.uppercase()
        return listOf("BOB", "HDFC", "ICICI", "SBI", "AXIS", "KOTAK", "PNB").any { u.contains(it) }
    }

    private fun firstIndex(lower: String, words: List<String>): Int {
        var best = -1
        for (w in words) {
            val i = lower.indexOf(w)
            if (i >= 0 && (best < 0 || i < best)) best = i
        }
        return best
    }

    fun parse(sender: String, body: String): Result? {
        val text = body.replace('\n', ' ')
        if (skip.containsMatchIn(text)) return null
        val am = amountRx.find(text) ?: return null
        val amount = am.groupValues[1].replace(",", "").toDoubleOrNull() ?: return null
        if (amount <= 0) return null
        val lower = text.lowercase()
        val debit: Boolean
        val dc = drcr.find(text)
        if (dc != null) {
            debit = dc.groupValues[1].lowercase() == "dr"
        } else {
            val d = firstIndex(lower, listOf("debited", "spent", "paid", "sent", "withdrawn", "purchase", "debit", " dr "))
            val c = firstIndex(lower, listOf("credited", "received", "deposited", "refund", "credit", " cr "))
            if (d < 0 && c < 0) return null
            debit = c < 0 || (d >= 0 && d < c)
        }
        val raw4 = acct.find(text)?.groupValues?.get(1)
        val last4 = if (raw4 == null) null else if (raw4.length > 4) raw4.substring(raw4.length - 4) else raw4
        val v = vpa.find(text)?.value
        if (last4 == null && (promo.containsMatchIn(text) || (!knownBank(sender) && v == null))) return null
        val atm = debit && (lower.contains("atm") || lower.contains("cash withdrawal") || lower.contains("withdrawn"))
        val ref = refRx.find(text)?.groupValues?.get(1)
        return Result(amount, debit, last4, if (atm) "ATM withdrawal" else v, ref, atm)
    }
}

object Suggest {
    fun categories(ctx: Context, party: String?, kind: String): List<Pair<Int, String>> {
        val out = ArrayList<Pair<Int, String>>()
        val f = ctx.getDatabasePath("finup.db")
        if (!f.exists()) return out
        try {
            SQLiteDatabase.openDatabase(f.path, null, SQLiteDatabase.OPEN_READONLY).use { db ->
                val ids = LinkedHashSet<Int>()
                if (party != null) {
                    val l = party.lowercase()
                    db.rawQuery("SELECT keyword, category_id FROM rules WHERE category_id IS NOT NULL", null).use { c ->
                        while (c.moveToNext()) {
                            val k = c.getString(0) ?: ""
                            if (k.isNotEmpty() && (l == k || l.contains(k))) {
                                ids.add(c.getInt(1))
                                break
                            }
                        }
                    }
                }
                db.rawQuery(
                    "SELECT t.category_id, COUNT(*) AS n FROM transactions t JOIN categories c ON c.id = t.category_id " +
                        "WHERE c.kind = ? GROUP BY t.category_id ORDER BY n DESC LIMIT 5",
                    arrayOf(kind)
                ).use { c -> while (c.moveToNext()) ids.add(c.getInt(0)) }
                db.rawQuery("SELECT id FROM categories WHERE kind = ? ORDER BY sort LIMIT 5", arrayOf(kind)).use { c ->
                    while (c.moveToNext()) ids.add(c.getInt(0))
                }
                for (id in ids) {
                    if (out.size >= 2) break
                    db.rawQuery("SELECT name FROM categories WHERE id = ? AND kind = ?", arrayOf(id.toString(), kind)).use { c ->
                        if (c.moveToFirst()) out.add(Pair(id, c.getString(0)))
                    }
                }
            }
        } catch (e: Exception) {
        }
        return out
    }
}

object Notifier {
    const val CH_TXN = "finup_txn"
    const val CH_DAILY = "finup_daily"
    const val CH_ALERT = "finup_alerts"

    private fun nm(ctx: Context) = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    private fun ensureChannels(ctx: Context) {
        if (Build.VERSION.SDK_INT >= 26) {
            val m = nm(ctx)
            m.createNotificationChannel(NotificationChannel(CH_TXN, "Bank transactions", NotificationManager.IMPORTANCE_HIGH))
            m.createNotificationChannel(NotificationChannel(CH_DAILY, "Daily review", NotificationManager.IMPORTANCE_DEFAULT))
            m.createNotificationChannel(NotificationChannel(CH_ALERT, "Budget alerts", NotificationManager.IMPORTANCE_HIGH))
        }
    }

    fun flags(): Int =
        if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        else PendingIntent.FLAG_UPDATE_CURRENT

    private fun icon(ctx: Context): Int {
        val i = ctx.resources.getIdentifier("ic_stat_finup", "drawable", ctx.packageName)
        return if (i == 0) android.R.drawable.ic_popup_reminder else i
    }

    private fun openApp(ctx: Context, req: Int): PendingIntent {
        val launch = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName) ?: Intent()
        return PendingIntent.getActivity(ctx, req, launch, flags())
    }

    private fun builder(ctx: Context, ch: String): Notification.Builder {
        ensureChannels(ctx)
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(ctx, ch) else Notification.Builder(ctx)
        b.setSmallIcon(icon(ctx)).setColor(0xFF8E8BEA.toInt()).setAutoCancel(true)
        return b
    }

    private fun money(v: Double): String = NumberFormat.getCurrencyInstance(Locale("en", "IN")).format(v)

    fun simple(ctx: Context, ch: String, id: Int, title: String, text: String) {
        val b = builder(ctx, ch)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(Notification.BigTextStyle().bigText(text))
            .setContentIntent(openApp(ctx, id))
        nm(ctx).notify(id, b.build())
    }

    fun showTxn(ctx: Context, p: SmsParse.Result, body: String) {
        val key = if (p.ref != null) "ref:${p.ref}" else "body:$body"
        val nid = key.hashCode() and 0x7fffffff
        val acct = if (p.last4 != null) " · ••${p.last4}" else ""
        val title = when {
            p.atm -> "${money(p.amount)} ATM withdrawal$acct"
            p.debit -> "${money(p.amount)} debited$acct"
            else -> "${money(p.amount)} received$acct"
        }
        val time = SimpleDateFormat("h:mm a", Locale.getDefault()).format(Date())
        val b = builder(ctx, CH_TXN).setContentTitle(title).setContentIntent(openApp(ctx, nid))
        if (p.atm) {
            b.setContentText("Moved from bank to Cash · $time")
            nm(ctx).notify(nid, b.build())
            return
        }
        val party = p.party?.substringBefore('@') ?: "Bank transaction"
        val sugg = Suggest.categories(ctx, p.party, if (p.debit) "expense" else "income")
        val lead = if (p.debit) "To" else "From"
        val hint = if (sugg.isEmpty()) "" else "\nTap a category to file it"
        val text = "$lead $party · $time$hint"
        b.setContentText(text).setStyle(Notification.BigTextStyle().bigText(text))
        sugg.forEachIndexed { i, s ->
            val intent = Intent(ctx, NotifActionReceiver::class.java)
                .putExtra("key", key)
                .putExtra("cat", s.first)
                .putExtra("catName", s.second)
                .putExtra("nid", nid)
                .putExtra("title", title)
            val pi = PendingIntent.getBroadcast(ctx, nid + i + 1, intent, flags())
            b.addAction(Notification.Action.Builder(icon(ctx), s.second, pi).build())
        }
        b.addAction(Notification.Action.Builder(icon(ctx), "More…", openApp(ctx, nid + 9)).build())
        nm(ctx).notify(nid, b.build())
    }

    fun showSaved(ctx: Context, nid: Int, title: String, catName: String) {
        val b = builder(ctx, CH_TXN)
            .setContentTitle(title)
            .setContentText("Filed under $catName ✓")
            .setOnlyAlertOnce(true)
            .setContentIntent(openApp(ctx, nid))
        if (Build.VERSION.SDK_INT >= 26) b.setTimeoutAfter(5000)
        nm(ctx).notify(nid, b.build())
    }
}

class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        if (!AlertPrefs.smsAlerts(context)) return
        if (!FlutterPrefs.bool(context, "onboarded", false)) return
        try {
            val msgs = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return
            if (msgs.isEmpty()) return
            val sender = msgs[0].originatingAddress ?: ""
            val body = msgs.joinToString("") { it.messageBody ?: "" }
            val p = SmsParse.parse(sender, body) ?: return
            Notifier.showTxn(context, p, body)
        } catch (e: Exception) {
        }
    }
}

class NotifActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val key = intent.getStringExtra("key") ?: return
        val cat = intent.getIntExtra("cat", -1)
        if (cat < 0) return
        Pending.save(context, key, cat)
        Notifier.showSaved(
            context,
            intent.getIntExtra("nid", 0),
            intent.getStringExtra("title") ?: "FinUp",
            intent.getStringExtra("catName") ?: "category"
        )
    }
}
__END__

############################ KOTLIN: Reminder.kt (smart daily reminder) ############################
cat > android/app/src/main/kotlin/com/yash/finup/Reminder.kt <<'__END__'
package com.yash.finup

import android.Manifest
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.database.sqlite.SQLiteDatabase
import android.net.Uri
import android.os.Build
import java.util.Calendar

object Reminder {
    private const val PREFS = "finup_reminder"

    fun save(ctx: Context, hour: Int, minute: Int, enabled: Boolean) {
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putInt("h", hour).putInt("m", minute).putBoolean("on", enabled).apply()
    }

    fun schedule(ctx: Context) {
        val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = PendingIntent.getBroadcast(ctx, 7001, Intent(ctx, ReminderReceiver::class.java), Notifier.flags())
        am.cancel(pi)
        if (!prefs.getBoolean("on", true)) return
        val cal = Calendar.getInstance()
        cal.set(Calendar.HOUR_OF_DAY, prefs.getInt("h", 21))
        cal.set(Calendar.MINUTE, prefs.getInt("m", 0))
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        if (cal.timeInMillis <= System.currentTimeMillis() + 1000) cal.add(Calendar.DAY_OF_YEAR, 1)
        val t = cal.timeInMillis
        try {
            if (Build.VERSION.SDK_INT >= 31 && !am.canScheduleExactAlarms()) {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, t, pi)
            } else if (Build.VERSION.SDK_INT >= 23) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, t, pi)
            } else {
                am.setExact(AlarmManager.RTC_WAKEUP, t, pi)
            }
        } catch (e: SecurityException) {
            if (Build.VERSION.SDK_INT >= 23) am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, t, pi)
            else am.set(AlarmManager.RTC_WAKEUP, t, pi)
        }
    }

    private fun count(ctx: Context): Int {
        var n = 0
        val f = ctx.getDatabasePath("finup.db")
        if (f.exists()) {
            try {
                SQLiteDatabase.openDatabase(f.path, null, SQLiteDatabase.OPEN_READONLY).use { db ->
                    db.rawQuery("SELECT COUNT(*) FROM transactions WHERE status = 'review'", null).use { c ->
                        if (c.moveToFirst()) n += c.getInt(0)
                    }
                }
            } catch (e: Exception) {
            }
        }
        val last = FlutterPrefs.long(ctx, "smsLastSync")
        val granted = if (Build.VERSION.SDK_INT >= 23)
            ctx.checkSelfPermission(Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED
        else true
        if (last > 0 && granted) {
            try {
                ctx.contentResolver.query(
                    Uri.parse("content://sms/inbox"), arrayOf("address", "body"),
                    "date > ?", arrayOf(last.toString()), null
                )?.use { c ->
                    while (c.moveToNext()) {
                        val p = SmsParse.parse(c.getString(0) ?: "", c.getString(1) ?: "")
                        if (p != null && !p.atm) n++
                    }
                }
            } catch (e: Exception) {
            }
        }
        return maxOf(0, n - Pending.all(ctx).size)
    }

    fun show(ctx: Context) {
        val n = count(ctx)
        if (n <= 0) return
        val title = if (n == 1) "1 transaction to review" else "$n transactions to review"
        Notifier.simple(ctx, Notifier.CH_DAILY, 7003, title, "Open FinUp and file them in a few taps.")
    }
}

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) Reminder.show(context)
        Reminder.schedule(context)
    }
}
__END__

############################ KOTLIN: MainActivity.kt (complete) ############################
cat > android/app/src/main/kotlin/com/yash/finup/MainActivity.kt <<'__END__'
package com.yash.finup

import android.Manifest
import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.content.pm.PackageManager
import android.hardware.biometrics.BiometricManager
import android.hardware.biometrics.BiometricPrompt
import android.net.Uri
import android.os.Build
import android.os.CancellationSignal
import android.os.PowerManager
import android.provider.MediaStore
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.net.HttpURLConnection
import java.net.URL

class MainActivity : FlutterActivity() {
    private val channelName = "finup/native"
    private val permRequestCode = 4242
    private val createDocCode = 5151
    private val openDocCode = 5252
    private var channel: MethodChannel? = null
    private var pendingResult: MethodChannel.Result? = null
    private var pendingDocResult: MethodChannel.Result? = null
    private var pendingBytes: ByteArray? = null
    private val moneyRegex = Regex("(?i)(rs\\.?|inr|₹)\\s*[0-9]")

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        channel = ch
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "hasSmsPermission" -> result.success(hasPermission(Manifest.permission.READ_SMS))
                "requestSmsPermission" -> askPermissions(arrayOf(Manifest.permission.READ_SMS, Manifest.permission.RECEIVE_SMS), result)
                "ensureSmsReceive" -> {
                    if (hasPermission(Manifest.permission.READ_SMS) && !hasPermission(Manifest.permission.RECEIVE_SMS)) {
                        askPermissions(arrayOf(Manifest.permission.RECEIVE_SMS), result)
                    } else {
                        result.success(hasPermission(Manifest.permission.RECEIVE_SMS))
                    }
                }
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
                "getSmsAlerts" -> result.success(AlertPrefs.smsAlerts(this))
                "setSmsAlerts" -> {
                    AlertPrefs.setSmsAlerts(this, call.argument<Boolean>("on") ?: true)
                    result.success(true)
                }
                "notify" -> {
                    val id = call.argument<Int>("id") ?: 9999
                    Notifier.simple(this, Notifier.CH_ALERT, id, call.argument<String>("title") ?: "FinUp", call.argument<String>("body") ?: "")
                    result.success(true)
                }
                "pendingCategories" -> result.success(Pending.all(this))
                "clearPending" -> {
                    Pending.remove(this, call.argument<List<String>>("keys") ?: emptyList())
                    result.success(true)
                }
                "appInfo" -> {
                    val info = packageManager.getPackageInfo(packageName, 0)
                    val code = if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong()
                    result.success(mapOf("name" to (info.versionName ?: ""), "code" to code))
                }
                "openUrl" -> {
                    try {
                        val i = Intent(Intent.ACTION_VIEW, Uri.parse(call.argument<String>("url") ?: "https://yashchauhan.pro"))
                        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(i)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "batteryOptimized" -> {
                    if (Build.VERSION.SDK_INT >= 23) {
                        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                        result.success(!pm.isIgnoringBatteryOptimizations(packageName))
                    } else {
                        result.success(false)
                    }
                }
                "openBatterySettings" -> {
                    if (Build.VERSION.SDK_INT >= 23) {
                        try {
                            startActivity(Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:$packageName")))
                        } catch (e: Exception) {
                            try { startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)) } catch (x: Exception) {}
                        }
                    }
                    result.success(true)
                }
                "downloadAndInstall" -> downloadAndInstall(call.argument<String>("url") ?: "", result)
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
            val ok = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
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

    private fun progress(p: Int) {
        runOnUiThread { channel?.invokeMethod("updateProgress", p) }
    }

    private fun downloadAndInstall(url: String, result: MethodChannel.Result) {
        if (url.isEmpty()) { result.success("error"); return }
        if (Build.VERSION.SDK_INT >= 26 && !packageManager.canRequestPackageInstalls()) {
            val i = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName"))
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(i)
            result.success("needs_permission")
            return
        }
        result.success("started")
        Thread {
            try {
                val file = File(cacheDir, "finup-update.apk")
                var conn = URL(url).openConnection() as HttpURLConnection
                conn.instanceFollowRedirects = true
                conn.connectTimeout = 15000
                conn.readTimeout = 30000
                conn.setRequestProperty("User-Agent", "FinUp")
                var hops = 0
                while (conn.responseCode in 301..308 && hops < 5) {
                    val loc = conn.getHeaderField("Location") ?: break
                    conn.disconnect()
                    conn = URL(loc).openConnection() as HttpURLConnection
                    conn.setRequestProperty("User-Agent", "FinUp")
                    hops++
                }
                if (conn.responseCode != 200) throw Exception("HTTP ${conn.responseCode}")
                val total = conn.contentLength.toLong()
                conn.inputStream.use { input ->
                    file.outputStream().use { out ->
                        val buf = ByteArray(64 * 1024)
                        var read = 0
                        var done = 0L
                        var last = -1
                        while (input.read(buf).also { read = it } != -1) {
                            out.write(buf, 0, read)
                            done += read
                            if (total > 0) {
                                val pct = (done * 99 / total).toInt()
                                if (pct != last) { last = pct; progress(pct) }
                            }
                        }
                    }
                }
                installApk(file)
                progress(100)
            } catch (e: Exception) {
                progress(-1)
            }
        }.start()
    }

    private fun installApk(file: File) {
        val installer = packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
        val sessionId = installer.createSession(params)
        installer.openSession(sessionId).use { session ->
            session.openWrite("finup", 0, file.length()).use { out ->
                file.inputStream().use { it.copyTo(out) }
                session.fsync(out)
            }
            val flags = if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            else PendingIntent.FLAG_UPDATE_CURRENT
            val pi = PendingIntent.getBroadcast(this, sessionId, Intent(this, InstallReceiver::class.java), flags)
            session.commit(pi.intentSender)
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

class InstallReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val status = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, -999)
        if (status == PackageInstaller.STATUS_PENDING_USER_ACTION) {
            @Suppress("DEPRECATION")
            val confirm = intent.getParcelableExtra<Intent>(Intent.EXTRA_INTENT) ?: return
            confirm.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(confirm)
        }
    }
}
__END__

############################ lib/native.dart (complete) ############################
cat > lib/native.dart <<'__END__'
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
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

  /// Download progress for in-app updates: 0..99 downloading, 100 installing, -1 failed.
  static final ValueNotifier<int?> updateProgress = ValueNotifier<int?>(null);

  static void init() {
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'updateProgress') {
        updateProgress.value = (call.arguments as num?)?.toInt();
      }
      return null;
    });
  }

  static Future<bool> _bool(String method, [Map<String, Object?>? args]) async {
    try {
      return await _ch.invokeMethod<bool>(method, args) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> hasSms() => _bool('hasSmsPermission');
  static Future<bool> requestSms() => _bool('requestSmsPermission');
  static Future<bool> ensureSmsReceive() => _bool('ensureSmsReceive');
  static Future<bool> requestNotifications() => _bool('requestNotificationPermission');
  static Future<bool> openSettings() => _bool('openAppSettings');
  static Future<bool> canBiometric() => _bool('canBiometric');
  static Future<bool> authenticate(String reason) =>
      _bool('authenticate', {'reason': reason});
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

  static Future<String> downloadAndInstall(String url) async {
    try {
      return await _ch.invokeMethod<String>('downloadAndInstall', {'url': url}) ?? 'error';
    } catch (_) {
      return 'error';
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
      await _ch.invokeMethod(
          'scheduleReminder', {'hour': hour, 'minute': minute, 'enabled': enabled});
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

############################ lib/notify/notify_sync.dart ############################
cat > lib/notify/notify_sync.dart <<'__END__'
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/db.dart';
import '../data/repo.dart';
import '../data/stats.dart';
import '../native.dart';
import '../state/txn_state.dart';
import '../theme.dart';

/// Applies categories chosen from SMS notification buttons.
Future<void> applyPendingCategories() async {
  final pending = await Native.pendingCategories();
  if (pending.isEmpty) return;
  final db = AppDatabase.instance;
  final done = <String>[];
  for (final e in pending.entries) {
    List<Map<String, Object?>> rows;
    if (e.key.startsWith('ref:')) {
      rows = await db.db.query('transactions',
          where: 'ref = ?', whereArgs: [e.key], limit: 1);
    } else if (e.key.startsWith('body:')) {
      rows = await db.db.query('transactions',
          where: 'sms_body = ?', whereArgs: [e.key.substring(5)], limit: 1);
    } else {
      done.add(e.key);
      continue;
    }
    if (rows.isEmpty || e.value < 0) continue;
    final t = Txn.fromMap(rows.first);
    await db.markReviewed(t.id!, e.value);
    final k = t.counterparty?.trim().toLowerCase();
    if (k != null && k.isNotEmpty) {
      await db.addRule(k, e.value);
      await db.applyRuleToPending(k, e.value);
    }
    done.add(e.key);
  }
  if (done.isNotEmpty) await Native.clearPendingCategories(done);
}

class BudgetAlerts {
  static bool _running = false;

  static Future<void> check(TxnState s) async {
    if (_running) return;
    _running = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool('budgetAlerts') ?? true)) return;
      if (!(prefs.getBool('onboarded') ?? false)) return;
      final db = AppDatabase.instance;
      final budgets = await db.budgets();
      if (budgets.isEmpty) return;
      final now = DateTime.now();
      final (start, end) = monthRange(now);
      final spent = await db.categoryTotals(start, end, 'expense');
      final ym = '${now.year}-${now.month}';
      for (final b in budgets) {
        if (b.amount <= 0) continue;
        final used = spent[b.categoryId] ?? 0;
        final pct = used / b.amount;
        final level = pct >= 1 ? 2 : (pct >= 0.8 ? 1 : 0);
        if (level == 0) continue;
        final key = 'budgetAlert:${b.categoryId}:$ym';
        if ((prefs.getInt(key) ?? 0) >= level) continue;
        await prefs.setInt(key, level);
        final name = s.category(b.categoryId)?.name ?? 'A budget';
        final month = DateFormat('MMMM').format(now);
        if (level == 2) {
          await Native.notify(
            '$name budget used up',
            'You have spent ${inr(used, decimals: 0)} of ${inr(b.amount, decimals: 0)} in $month.',
            id: 9000 + b.categoryId,
          );
        } else {
          await Native.notify(
            '$name budget at ${(pct * 100).round()}%',
            '${inr(used, decimals: 0)} of ${inr(b.amount, decimals: 0)} used. ${inr(b.amount - used, decimals: 0)} left for $month.',
            id: 9000 + b.categoryId,
          );
        }
      }
    } catch (_) {
    } finally {
      _running = false;
    }
  }
}
__END__

############################ lib/update/updater.dart ############################
cat > lib/update/updater.dart <<'__END__'
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../native.dart';
import '../screens/update_screen.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/logo.dart';

class UpdateInfo {
  final int build;
  final String name;
  final String notes;
  final String apkUrl;
  const UpdateInfo(this.build, this.name, this.notes, this.apkUrl);
}

class UpdateService {
  static const repo = 'Yashchauhan008/finup-releases';
  static const pageUrl = 'https://github.com/$repo/releases/latest';
  static const shareText =
      'FinUp - my private, offline expense manager. Download the latest APK: $pageUrl';

  static Future<UpdateInfo?> latest() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client
          .getUrl(Uri.parse('https://api.github.com/repos/$repo/releases/latest'));
      req.headers.set('Accept', 'application/vnd.github+json');
      req.headers.set('User-Agent', 'FinUp');
      final res = await req.close();
      if (res.statusCode != 200) return null;
      final body = await res.transform(utf8.decoder).join();
      final j = jsonDecode(body) as Map<String, dynamic>;
      final tag = (j['tag_name'] ?? '').toString();
      final build = int.tryParse(tag.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      String? url;
      final assets = j['assets'];
      if (assets is List) {
        for (final a in assets) {
          if (a is Map) {
            final n = (a['name'] ?? '').toString().toLowerCase();
            if (n.endsWith('.apk')) {
              url = a['browser_download_url']?.toString();
              break;
            }
          }
        }
      }
      if (url == null) return null;
      return UpdateInfo(build, (j['name'] ?? tag).toString(),
          (j['body'] ?? '').toString(), url);
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  static Future<void> autoCheck(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt('lastUpdateCheck') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - last < const Duration(hours: 20).inMilliseconds) return;
    await prefs.setInt('lastUpdateCheck', now);
    final info = await latest();
    if (info == null) return;
    final (_, cur) = await Native.appInfo();
    if (info.build <= cur || !context.mounted) return;
    final fin = context.fin;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: fin.card,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const FinUpLogo(size: 60),
            const SizedBox(height: 14),
            Text('Update available', style: AppText.display(size: 20, color: fin.text)),
            const SizedBox(height: 6),
            Text('${info.name} is ready. Your data stays safe.',
                textAlign: TextAlign.center, style: TextStyle(color: fin.subtext)),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Update now',
              icon: Icons.system_update_rounded,
              onPressed: () {
                Navigator.pop(c);
                Navigator.of(context).push(fadeRoute(const UpdateScreen()));
              },
            ),
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Later')),
          ]),
        ),
      ),
    );
  }
}
__END__

############################ lib/screens/update_screen.dart ############################
cat > lib/screens/update_screen.dart <<'__END__'
import 'package:flutter/material.dart';

import '../native.dart';
import '../security/lock.dart';
import '../theme.dart';
import '../update/updater.dart';
import '../widgets/common.dart';
import '../widgets/logo.dart';

class UpdateScreen extends StatefulWidget {
  const UpdateScreen({super.key});

  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> {
  bool _checking = true;
  UpdateInfo? _info;
  String _curName = '';
  int _cur = 0;
  String? _msg;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    Native.updateProgress.value = null;
    _check();
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _msg = null;
    });
    final (name, code) = await Native.appInfo();
    final info = await UpdateService.latest();
    if (!mounted) return;
    setState(() {
      _curName = name;
      _cur = code;
      _info = info;
      _checking = false;
      if (info == null) {
        _msg = 'Could not reach the updates page. Check your internet connection and that the finup-releases repo is set up.';
      }
    });
  }

  bool get _hasUpdate => _info != null && _info!.build > _cur;

  Future<void> _update() async {
    final r = await AppLockGate.suspendWhile(
        () => Native.downloadAndInstall(_info!.apkUrl));
    if (!mounted) return;
    setState(() {
      if (r == 'needs_permission') {
        _msg = 'Allow "Install unknown apps" for FinUp on the screen that opened, come back, then tap Update again.';
      } else if (r == 'started') {
        _started = true;
        _msg = null;
      } else {
        _msg = 'Could not start the download. Please try again.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    return Scaffold(
      appBar: AppBar(title: const Text('Updates')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        children: [
          const Center(child: FinUpLogo(size: 84)),
          const SizedBox(height: 16),
          Center(
            child: Text(
              _checking
                  ? 'Checking for updates…'
                  : (_hasUpdate ? 'Update available' : (_info == null ? 'Could not check' : 'You are up to date')),
              style: AppText.display(size: 22, color: fin.text),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'Installed: ${_curName.isEmpty ? '-' : _curName} (build $_cur)',
              style: TextStyle(color: fin.subtext),
            ),
          ),
          const SizedBox(height: 24),
          if (_checking) const Center(child: CircularProgressIndicator()),
          if (_hasUpdate) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                  color: fin.card, borderRadius: BorderRadius.circular(22)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_info!.name,
                      style: TextStyle(
                          color: fin.text, fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('Build ${_info!.build}', style: TextStyle(color: fin.subtext)),
                  if (_info!.notes.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text("What's new",
                        style: TextStyle(color: fin.text, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(_info!.notes, style: TextStyle(color: fin.subtext, height: 1.5)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            ValueListenableBuilder<int?>(
              valueListenable: Native.updateProgress,
              builder: (context, p, _) {
                if (!_started) {
                  return PrimaryButton(
                      label: 'Download and install',
                      icon: Icons.system_update_rounded,
                      onPressed: _update);
                }
                if (p == -1) {
                  return Column(children: [
                    const Text('Download failed.',
                        style: TextStyle(color: AppColors.expense)),
                    const SizedBox(height: 10),
                    PrimaryButton(
                        label: 'Try again',
                        icon: Icons.refresh_rounded,
                        onPressed: _update),
                  ]);
                }
                final v = (p ?? 0).clamp(0, 100).toDouble() / 100;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                          value: p == null ? null : v,
                          minHeight: 10,
                          backgroundColor: fin.divider,
                          color: AppColors.lavender),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      p == 100
                          ? 'Downloaded. Tap Update on the Android screen to finish.'
                          : 'Downloading… ${(v * 100).round()}%',
                      style: TextStyle(color: fin.text, fontWeight: FontWeight.w600),
                    ),
                  ],
                );
              },
            ),
          ],
          if (_msg != null) ...[
            const SizedBox(height: 16),
            Text(_msg!,
                textAlign: TextAlign.center,
                style: TextStyle(color: fin.subtext, height: 1.5)),
          ],
          const SizedBox(height: 24),
          if (!_checking && !_started)
            Center(
              child: TextButton.icon(
                  onPressed: _check,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Check again')),
            ),
          Center(
            child: TextButton.icon(
              onPressed: () =>
                  AppLockGate.suspendWhile(() => Native.shareText(UpdateService.shareText)),
              icon: const Icon(Icons.share_rounded),
              label: const Text('Share FinUp'),
            ),
          ),
        ],
      ),
    );
  }
}
__END__

############################ lib/screens/about_screen.dart ############################
cat > lib/screens/about_screen.dart <<'__END__'
import 'package:flutter/material.dart';

import '../native.dart';
import '../security/lock.dart';
import '../theme.dart';
import '../update/updater.dart';
import '../widgets/common.dart';
import '../widgets/logo.dart';
import 'legal_screen.dart';
import 'update_screen.dart';

const kPortfolio = 'https://yashchauhan.pro';

class AboutScreenV2 extends StatefulWidget {
  const AboutScreenV2({super.key});

  @override
  State<AboutScreenV2> createState() => _AboutScreenV2State();
}

class _AboutScreenV2State extends State<AboutScreenV2> {
  String _ver = '';

  @override
  void initState() {
    super.initState();
    Native.appInfo().then((v) {
      if (mounted) setState(() => _ver = v.$2 > 0 ? '${v.$1} (build ${v.$2})' : v.$1);
    });
  }

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
          if (_ver.isNotEmpty)
            Center(child: Text('Version $_ver', style: TextStyle(color: fin.subtext))),
          const SizedBox(height: 10),
          Center(
            child: Text('Your money, auto-tracked. Private. Offline. Yours.',
                textAlign: TextAlign.center,
                style: TextStyle(color: fin.subtext, height: 1.5)),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              gradient: AppColors.cardGradients[0],
              borderRadius: BorderRadius.circular(26),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: Stack(children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: OrbitPainter(0.2,
                        line: Colors.white.withValues(alpha: 0.18),
                        showDots: false,
                        center: const Alignment(0.8, -0.2)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Made by Yash with ❤️',
                          style: AppText.display(size: 20, color: Colors.white)),
                      const SizedBox(height: 6),
                      const Text('Designed and developed FinUp',
                          style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 16),
                      Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => Native.openUrl(kPortfolio),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.language_rounded, color: AppColors.ink, size: 20),
                              SizedBox(width: 8),
                              Text('yashchauhan.pro',
                                  style: TextStyle(
                                      color: AppColors.ink, fontWeight: FontWeight.w700)),
                              SizedBox(width: 6),
                              Icon(Icons.open_in_new_rounded, color: AppColors.ink, size: 16),
                            ]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          Material(
            color: fin.card,
            borderRadius: BorderRadius.circular(22),
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.system_update_rounded),
                title: const Text('Check for updates'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => open(const UpdateScreen()),
              ),
              ListTile(
                leading: const Icon(Icons.share_rounded),
                title: const Text('Share FinUp'),
                onTap: () => AppLockGate.suspendWhile(
                    () => Native.shareText(UpdateService.shareText)),
              ),
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
          const SizedBox(height: 24),
          Center(
            child: Text('© 2026 Yash Chauhan',
                style: TextStyle(color: fin.subtext, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
__END__

############################ lib/screens/extra_settings.dart ############################
cat > lib/screens/extra_settings.dart <<'__END__'
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../native.dart';
import '../security/lock.dart';
import '../theme.dart';
import '../update/updater.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import 'about_screen.dart';
import 'update_screen.dart';

class ExtraSettings extends StatefulWidget {
  const ExtraSettings({super.key});

  @override
  State<ExtraSettings> createState() => _ExtraSettingsState();
}

class _ExtraSettingsState extends State<ExtraSettings> with WidgetsBindingObserver {
  bool _sms = true;
  bool _budget = true;
  bool _restricted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final sms = await Native.getSmsAlerts();
    final p = await SharedPreferences.getInstance();
    final b = p.getBool('budgetAlerts') ?? true;
    final r = await Native.batteryOptimized();
    if (!mounted) return;
    setState(() {
      _sms = sms;
      _budget = b;
      _restricted = r;
    });
  }

  Widget _section(FinColors fin, String title, List<Widget> children) {
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

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    void open(Widget p) => Navigator.of(context).push(fadeRoute(p));
    return Column(children: [
      _section(fin, 'Smart alerts', [
        SwitchListTile(
          secondary: const Icon(Icons.sms_rounded),
          title: const Text('Instant SMS alerts'),
          subtitle: const Text('Notify on every bank SMS with category buttons'),
          value: _sms,
          onChanged: (v) async {
            setState(() => _sms = v);
            await Native.setSmsAlerts(v);
            if (v) {
              await Native.ensureSmsReceive();
              await Native.requestNotifications();
            }
          },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.warning_amber_rounded),
          title: const Text('Budget alerts'),
          subtitle: const Text('Notify at 80% and 100% of a budget'),
          value: _budget,
          onChanged: (v) async {
            setState(() => _budget = v);
            final p = await SharedPreferences.getInstance();
            await p.setBool('budgetAlerts', v);
            if (v) await Native.requestNotifications();
          },
        ),
        ListTile(
          leading: Icon(Icons.battery_charging_full_rounded,
              color: _restricted ? kAmber : AppColors.income),
          title: const Text('Background reliability'),
          subtitle: Text(_restricted
              ? 'Battery saver may delay alerts. Tap to let FinUp run in the background.'
              : 'FinUp is allowed to run in the background'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => Native.openBatterySettings(),
        ),
      ]),
      _section(fin, 'Updates', [
        ListTile(
          leading: const Icon(Icons.system_update_rounded),
          title: const Text('Check for updates'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => open(const UpdateScreen()),
        ),
        ListTile(
          leading: const Icon(Icons.share_rounded),
          title: const Text('Share FinUp'),
          subtitle: const Text('Send the download link to a friend'),
          onTap: () =>
              AppLockGate.suspendWhile(() => Native.shareText(UpdateService.shareText)),
        ),
      ]),
      _section(fin, 'Developer', [
        ListTile(
          leading: const Text('❤️', style: TextStyle(fontSize: 22)),
          title: const Text('Made by Yash with ❤️'),
          subtitle: const Text('yashchauhan.pro'),
          trailing: const Icon(Icons.open_in_new_rounded),
          onTap: () => Native.openUrl(kPortfolio),
        ),
      ]),
    ]);
  }
}
__END__

############################ Patches to earlier parts ############################
# main: register native callbacks (update progress)
sed -i "s#WidgetsFlutterBinding.ensureInitialized();#WidgetsFlutterBinding.ensureInitialized();\n  Native.init();#" lib/main.dart

# TxnState: apply notification categories after sync, budget alerts after every refresh
sed -i "s#import '../data/people_repo.dart';#import '../data/people_repo.dart';\nimport '../notify/notify_sync.dart';#" lib/state/txn_state.dart
sed -i "s#await AppDatabase.instance.autoLinkPeople();#await AppDatabase.instance.autoLinkPeople();\n      await applyPendingCategories();#" lib/state/txn_state.dart
sed -i "s#version++;#version++;\n    BudgetAlerts.check(this);#" lib/state/txn_state.dart

# HomeShell: make sure SMS alerts permission is active + daily update check
sed -i "s#import '../theme.dart';#import '../native.dart';\nimport '../theme.dart';\nimport '../update/updater.dart';#" lib/screens/home_shell.dart
sed -i "s#if (txns.smsEnabled) await txns.sync(accounts);#if (txns.smsEnabled) {\n      await Native.ensureSmsReceive();\n      await txns.sync(accounts);\n    }\n    if (mounted) UpdateService.autoCheck(context);#" lib/screens/home_shell.dart

# Settings: new sections + new About screen
perl -0777 -pi -e 's{\n(\s*)_Section\(title: \x27About\x27}{\n$1const ExtraSettings(),\n$1_Section(title: \x27About\x27}' lib/screens/settings_screen.dart
sed -i "s#const AboutFinUpScreen()#const AboutScreenV2()#" lib/screens/settings_screen.dart
sed -i "s#import 'account_editor.dart';#import 'about_screen.dart';\nimport 'account_editor.dart';\nimport 'extra_settings.dart';#" lib/screens/settings_screen.dart

for check in "Native.init:lib/main.dart" "applyPendingCategories:lib/state/txn_state.dart" "BudgetAlerts.check:lib/state/txn_state.dart" "UpdateService.autoCheck:lib/screens/home_shell.dart" "ExtraSettings():lib/screens/settings_screen.dart" "AboutScreenV2:lib/screens/settings_screen.dart"; do
  pat="${check%%:*}"; file="${check#*:}"
  if ! grep -q "$pat" "$file"; then echo "ERROR: Part 5 patch failed in $file ($pat)"; exit 1; fi
done

############################ Docs ############################
cat >> USER_GUIDE.md <<'__END__'

## 13. Smart notifications
- **Instant SMS alerts**: every bank SMS shows a notification with the amount, account and payee, plus two suggested category buttons. Tap one to file the transaction without opening the app. FinUp also remembers that UPI ID for next time. **More…** opens the app.
- **Daily reminder**: at your chosen time, FinUp tells you how many transactions are waiting, or stays silent if there are none.
- **Budget alerts**: a notification when a category reaches 80% and again at 100% of its monthly budget.
- Turn these on or off in Settings → Smart alerts.
- On Xiaomi, Redmi, Vivo, Oppo, Realme and some Samsung phones, open Settings → Smart alerts → **Background reliability** and allow FinUp. Also enable **Autostart** for FinUp in the phone's own Security or Apps settings, otherwise alerts can be delayed.

## 14. Updates and sharing
- Settings → **Check for updates** (FinUp also checks once a day).
- Tap **Download and install**. The first time, Android asks you to allow "Install unknown apps" for FinUp. Then confirm Android's "Update" screen. Your data is kept.
- **Share FinUp** sends the download link. Each person's data stays on their own phone.

## 15. About
Settings → About shows the version, Terms, Privacy Policy and the developer: made by Yash with ❤️ (yashchauhan.pro).
__END__

cat >> SETUP.md <<'__END__'

## In-app updates (Part 5)

- Builds are numbered with the GitHub run number (`--build-number`), so each build is newer than the last.
- The workflow publishes `FinUp.apk` to the **public** repo `Yashchauhan008/finup-releases` using the secret `RELEASES_TOKEN`.
  The private repo keeps the source zip and signing key.
- The app reads `https://api.github.com/repos/Yashchauhan008/finup-releases/releases/latest`,
  compares the tag number with its own version code, downloads the APK and installs it with Android's PackageInstaller.
- When running the workflow, fill in **What's new**. It is shown on the in-app update screen.

### One-time setup
1. Create the public repo `finup-releases` (with a README so it is not empty).
2. Create a fine-grained token with **Contents: Read and write** on that repo only.
3. Add it to the private `finup` repo as the Actions secret `RELEASES_TOKEN`.

## Native files (Part 5)
- `Alerts.kt`: SMS receiver, native SMS parser, category suggestions, notification buttons.
- `Reminder.kt`: exact daily reminder with the pending count.
- `MainActivity.kt`: method channel, downloads and installs updates, files, sharing, fingerprint.
__END__

echo "FinUp Part 5 applied."