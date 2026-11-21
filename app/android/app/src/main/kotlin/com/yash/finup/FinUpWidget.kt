package com.yash.finup

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.widget.RemoteViews
import java.text.NumberFormat
import java.util.Calendar
import java.util.Locale

class FinUpWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        val views = build(context)
        for (id in appWidgetIds) appWidgetManager.updateAppWidget(id, views)
    }

    companion object {
        fun updateAll(ctx: Context) {
            FinUpWidgets.refreshAll(ctx)
        }

        private fun action(ctx: Context, action: String, req: Int): PendingIntent {
            val i = Intent(ctx, MainActivity::class.java)
            i.action = "finup.$action"
            i.putExtra("finup_action", action)
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            return PendingIntent.getActivity(ctx, req, i, Notifier.flags())
        }

        fun build(ctx: Context): RemoteViews {
            var spent = 0.0
            var review = 0
            var balance = 0.0
            val f = ctx.getDatabasePath("finup.db")
            if (f.exists()) {
                try {
                    SQLiteDatabase.openDatabase(f.path, null, SQLiteDatabase.OPEN_READONLY).use { db ->
                        val cal = Calendar.getInstance()
                        cal.set(Calendar.HOUR_OF_DAY, 0)
                        cal.set(Calendar.MINUTE, 0)
                        cal.set(Calendar.SECOND, 0)
                        cal.set(Calendar.MILLISECOND, 0)
                        val start = cal.timeInMillis
                        val end = start + 86400000L
                        db.rawQuery(
                            "SELECT COALESCE(SUM(amount), 0) FROM transactions WHERE type = 'expense' AND person_id IS NULL AND occurred_at >= ? AND occurred_at < ?",
                            arrayOf(start.toString(), end.toString())
                        ).use { c -> if (c.moveToFirst()) spent = c.getDouble(0) }
                        db.rawQuery("SELECT COUNT(*) FROM transactions WHERE status = 'review'", null).use { c ->
                            if (c.moveToFirst()) review = c.getInt(0)
                        }
                        db.rawQuery("SELECT COALESCE(SUM(balance), 0) FROM accounts WHERE archived = 0", null).use { c ->
                            if (c.moveToFirst()) balance = c.getDouble(0)
                        }
                    }
                } catch (e: Exception) {
                }
            }
            val hide = FlutterPrefs.bool(ctx, "hideAmounts", false)
            val fmt = NumberFormat.getCurrencyInstance(Locale("en", "IN"))
            fmt.maximumFractionDigits = 0
            val v = RemoteViews(ctx.packageName, R.layout.finup_widget)
            v.setTextViewText(R.id.w_spent, if (hide) "₹ ••••" else fmt.format(spent))
            v.setTextViewText(R.id.w_balance, if (hide) "Balance hidden" else "Total balance · ${fmt.format(balance)}")
            v.setTextViewText(R.id.w_review, if (review == 0) "All reviewed" else "$review to review")
            v.setOnClickPendingIntent(R.id.w_root, action(ctx, "open", 801))
            v.setOnClickPendingIntent(R.id.w_add, action(ctx, "add_expense", 802))
            v.setOnClickPendingIntent(R.id.w_voice, action(ctx, "voice", 803))
            v.setOnClickPendingIntent(R.id.w_scan, action(ctx, "scan", 804))
            v.setOnClickPendingIntent(R.id.w_review, action(ctx, "review", 805))
            return v
        }
    }
}
