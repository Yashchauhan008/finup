package com.yash.finup

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import kotlin.math.roundToInt

class AccountsWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        val views = build(context)
        for (id in appWidgetIds) appWidgetManager.updateAppWidget(id, views)
    }

    companion object {
        fun build(ctx: Context): RemoteViews {
            val v = RemoteViews(ctx.packageName, R.layout.finup_w_accounts)
            val hide = FinUpWidgets.hideAmounts(ctx)
            val fmt = FinUpWidgets.currency()
            var rows = emptyList<FinUpWidgets.NamedAmount>()
            var total = 0.0
            FinUpWidgets.openDb(ctx)?.use { db ->
                val pair = FinUpWidgets.accountRows(db, 4)
                rows = pair.first
                total = pair.second
            }
            v.setTextViewText(R.id.w_total, if (rows.isEmpty()) "" else FinUpWidgets.money(fmt, hide, total))
            val rowIds = intArrayOf(R.id.w_row1, R.id.w_row2, R.id.w_row3, R.id.w_row4)
            val nameIds = intArrayOf(R.id.w_name1, R.id.w_name2, R.id.w_name3, R.id.w_name4)
            val amtIds = intArrayOf(R.id.w_amt1, R.id.w_amt2, R.id.w_amt3, R.id.w_amt4)
            val trackIds = intArrayOf(R.id.w_track1, R.id.w_track2, R.id.w_track3, R.id.w_track4)
            for (i in rowIds.indices) FinUpWidgets.setGone(v, rowIds[i])
            if (rows.isEmpty()) {
                FinUpWidgets.setVisible(v, R.id.w_empty)
            } else {
                FinUpWidgets.setGone(v, R.id.w_empty)
                rows.forEachIndexed { i, r ->
                    FinUpWidgets.setVisible(v, rowIds[i])
                    v.setTextViewText(nameIds[i], r.name)
                    v.setTextViewText(amtIds[i], FinUpWidgets.money(fmt, hide, r.amount))
                    val pct = if (total > 0.009) ((r.amount / total) * 100.0).roundToInt().coerceIn(0, 100) else 0
                    v.setProgressBar(trackIds[i], 100, pct, false)
                }
            }
            v.setOnClickPendingIntent(R.id.w_root, FinUpWidgets.action(ctx, "open", 821))
            return v
        }
    }
}
