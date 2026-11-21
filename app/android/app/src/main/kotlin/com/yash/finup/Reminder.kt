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
