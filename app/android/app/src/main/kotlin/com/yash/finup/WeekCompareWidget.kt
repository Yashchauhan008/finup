package com.yash.finup

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.graphics.Color
import android.widget.RemoteViews
import kotlin.math.abs
import kotlin.math.roundToInt

class WeekCompareWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        val views = build(context)
        for (id in appWidgetIds) appWidgetManager.updateAppWidget(id, views)
    }

    companion object {
        fun build(ctx: Context): RemoteViews {
            val v = RemoteViews(ctx.packageName, R.layout.finup_w_week)
            val hide = FinUpWidgets.hideAmounts(ctx)
            val fmt = FinUpWidgets.currency()
            var thisWeek = 0.0
            var lastWeek = 0.0
            FinUpWidgets.openDb(ctx)?.use { db ->
                val weekStart = FinUpWidgets.weekStart()
                val weekEnd = weekStart + 7L * 86400000L
                val prevStart = weekStart - 7L * 86400000L
                thisWeek = FinUpWidgets.expenseSum(db, weekStart, weekEnd)
                lastWeek = FinUpWidgets.expenseSum(db, prevStart, weekStart)
            }
            v.setTextViewText(R.id.w_this, FinUpWidgets.money(fmt, hide, thisWeek))
            v.setTextViewText(
                R.id.w_last,
                if (hide) "Last week hidden" else "Last week ${fmt.format(lastWeek)}"
            )
            val max = maxOf(thisWeek, lastWeek, 1.0)
            val pctBar = ((thisWeek / max) * 100.0).roundToInt().coerceIn(0, 100)
            v.setProgressBar(R.id.w_compare, 100, pctBar, false)

            var down = true
            val deltaText = when {
                hide -> {
                    down = false
                    "Hidden"
                }
                lastWeek <= 0.009 && thisWeek <= 0.009 -> "No spend yet"
                lastWeek <= 0.009 -> {
                    down = false
                    "New spend this week"
                }
                else -> {
                    val pct = (((thisWeek - lastWeek) / lastWeek) * 100.0).roundToInt()
                    down = pct <= 0
                    val arrow = if (pct > 0) "▲" else if (pct < 0) "▼" else "•"
                    "$arrow ${abs(pct)}% vs last week"
                }
            }
            v.setTextViewText(R.id.w_delta, deltaText)
            v.setTextColor(R.id.w_delta, if (down) Color.parseColor("#9AEBCF") else Color.parseColor("#FFB5A5"))
            v.setOnClickPendingIntent(R.id.w_root, FinUpWidgets.action(ctx, "insights", 841))
            return v
        }
    }
}
