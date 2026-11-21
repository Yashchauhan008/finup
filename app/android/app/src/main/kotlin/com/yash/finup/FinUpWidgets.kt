package com.yash.finup

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.view.View
import android.widget.RemoteViews
import java.text.NumberFormat
import java.util.Calendar
import java.util.Locale
import kotlin.math.abs
import kotlin.math.min
import kotlin.math.roundToInt

object FinUpWidgets {
    data class NamedAmount(val name: String, val amount: Double)
    data class BudgetRow(val name: String, val spent: Double, val budget: Double)
    data class PersonRow(val name: String, val net: Double)

    fun refreshAll(ctx: Context) {
        try {
            val m = AppWidgetManager.getInstance(ctx)
            fun push(cls: Class<*>, views: RemoteViews) {
                val ids = m.getAppWidgetIds(ComponentName(ctx, cls))
                for (id in ids) m.updateAppWidget(id, views)
            }
            push(FinUpWidget::class.java, FinUpWidget.build(ctx))
            push(BudgetPulseWidget::class.java, BudgetPulseWidget.build(ctx))
            push(AccountsWidget::class.java, AccountsWidget.build(ctx))
            push(PeopleBalanceWidget::class.java, PeopleBalanceWidget.build(ctx))
            push(WeekCompareWidget::class.java, WeekCompareWidget.build(ctx))
            push(ReviewInboxWidget::class.java, ReviewInboxWidget.build(ctx))
        } catch (_: Exception) {
        }
    }

    fun action(ctx: Context, action: String, req: Int): PendingIntent {
        val i = Intent(ctx, MainActivity::class.java)
        i.action = "finup.$action"
        i.putExtra("finup_action", action)
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        return PendingIntent.getActivity(ctx, req, i, Notifier.flags())
    }

    fun hideAmounts(ctx: Context): Boolean = FlutterPrefs.bool(ctx, "hideAmounts", false)

    fun currency(): NumberFormat {
        val fmt = NumberFormat.getCurrencyInstance(Locale("en", "IN"))
        fmt.maximumFractionDigits = 0
        return fmt
    }

    fun money(fmt: NumberFormat, hide: Boolean, v: Double): String =
        if (hide) "₹ ••••" else fmt.format(v)

    fun openDb(ctx: Context): SQLiteDatabase? {
        val f = ctx.getDatabasePath("finup.db")
        if (!f.exists()) return null
        return try {
            SQLiteDatabase.openDatabase(f.path, null, SQLiteDatabase.OPEN_READONLY)
        } catch (_: Exception) {
            null
        }
    }

    fun dayStart(cal: Calendar = Calendar.getInstance()): Long {
        val c = cal.clone() as Calendar
        c.set(Calendar.HOUR_OF_DAY, 0)
        c.set(Calendar.MINUTE, 0)
        c.set(Calendar.SECOND, 0)
        c.set(Calendar.MILLISECOND, 0)
        return c.timeInMillis
    }

    /** Monday 00:00 of the week containing [now]. */
    fun weekStart(now: Calendar = Calendar.getInstance()): Long {
        val c = now.clone() as Calendar
        c.set(Calendar.HOUR_OF_DAY, 0)
        c.set(Calendar.MINUTE, 0)
        c.set(Calendar.SECOND, 0)
        c.set(Calendar.MILLISECOND, 0)
        val dow = c.get(Calendar.DAY_OF_WEEK)
        val daysFromMon = (dow + 5) % 7
        c.add(Calendar.DAY_OF_MONTH, -daysFromMon)
        return c.timeInMillis
    }

    fun monthRange(now: Calendar = Calendar.getInstance()): Pair<Long, Long> {
        val start = now.clone() as Calendar
        start.set(Calendar.DAY_OF_MONTH, 1)
        start.set(Calendar.HOUR_OF_DAY, 0)
        start.set(Calendar.MINUTE, 0)
        start.set(Calendar.SECOND, 0)
        start.set(Calendar.MILLISECOND, 0)
        val end = start.clone() as Calendar
        end.add(Calendar.MONTH, 1)
        return start.timeInMillis to end.timeInMillis
    }

    fun expenseSum(db: SQLiteDatabase, start: Long, end: Long): Double {
        db.rawQuery(
            "SELECT COALESCE(SUM(amount), 0) FROM transactions WHERE type = 'expense' AND person_id IS NULL AND occurred_at >= ? AND occurred_at < ?",
            arrayOf(start.toString(), end.toString())
        ).use { c -> return if (c.moveToFirst()) c.getDouble(0) else 0.0 }
    }

    fun accountRows(db: SQLiteDatabase, limit: Int = 4): Pair<List<NamedAmount>, Double> {
        val rows = mutableListOf<NamedAmount>()
        var total = 0.0
        db.rawQuery(
            "SELECT COALESCE(SUM(balance), 0) FROM accounts WHERE archived = 0",
            null
        ).use { c -> if (c.moveToFirst()) total = c.getDouble(0) }
        db.rawQuery(
            "SELECT name, balance FROM accounts WHERE archived = 0 ORDER BY balance DESC LIMIT ?",
            arrayOf(limit.toString())
        ).use { c ->
            while (c.moveToNext()) rows.add(NamedAmount(c.getString(0), c.getDouble(1)))
        }
        return rows to total
    }

    fun budgetRows(db: SQLiteDatabase, start: Long, end: Long, limit: Int = 3): List<BudgetRow> {
        val rows = mutableListOf<BudgetRow>()
        db.rawQuery(
            """
            SELECT c.name, b.amount AS budget,
              COALESCE((
                SELECT SUM(t.amount) FROM transactions t
                WHERE t.category_id = b.category_id AND t.type = 'expense'
                  AND t.person_id IS NULL AND t.occurred_at >= ? AND t.occurred_at < ?
              ), 0) AS spent
            FROM budgets b
            JOIN categories c ON c.id = b.category_id
            WHERE b.amount > 0
            ORDER BY (spent * 1.0 / b.amount) DESC
            LIMIT ?
            """.trimIndent(),
            arrayOf(start.toString(), end.toString(), limit.toString())
        ).use { c ->
            while (c.moveToNext()) {
                rows.add(BudgetRow(c.getString(0), c.getDouble(2), c.getDouble(1)))
            }
        }
        return rows
    }

    fun peopleRows(db: SQLiteDatabase, limit: Int = 4): List<PersonRow> {
        val nets = mutableMapOf<Long, Double>()
        val names = mutableMapOf<Long, String>()
        db.rawQuery("SELECT id, name FROM people", null).use { c ->
            while (c.moveToNext()) names[c.getLong(0)] = c.getString(1)
        }
        db.rawQuery("SELECT person_id, type, amount FROM ledger", null).use { c ->
            while (c.moveToNext()) {
                val id = c.getLong(0)
                val type = c.getString(1)
                val amt = c.getDouble(2)
                val delta = if (type == "gave") amt else -amt
                nets[id] = (nets[id] ?: 0.0) + delta
            }
        }
        return nets.entries
            .filter { abs(it.value) > 0.009 }
            .map { PersonRow(names[it.key] ?: "Person", it.value) }
            .sortedByDescending { abs(it.net) }
            .take(limit)
    }

    fun reviewCount(db: SQLiteDatabase): Int {
        db.rawQuery("SELECT COUNT(*) FROM transactions WHERE status = 'review'", null).use { c ->
            return if (c.moveToFirst()) c.getInt(0) else 0
        }
    }

    fun setGone(v: RemoteViews, id: Int) {
        v.setViewVisibility(id, View.GONE)
    }

    fun setVisible(v: RemoteViews, id: Int) {
        v.setViewVisibility(id, View.VISIBLE)
    }

    fun budgetPct(spent: Double, budget: Double): Int {
        if (budget <= 0) return 0
        return min(100, ((spent / budget) * 100.0).roundToInt())
    }
}
