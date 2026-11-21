package com.yash.finup

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews

class BudgetPulseWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        val views = build(context)
        for (id in appWidgetIds) appWidgetManager.updateAppWidget(id, views)
    }

    companion object {
        fun build(ctx: Context): RemoteViews {
            val v = RemoteViews(ctx.packageName, R.layout.finup_w_budget)
            val hide = FinUpWidgets.hideAmounts(ctx)
            val fmt = FinUpWidgets.currency()
            val rows = mutableListOf<FinUpWidgets.BudgetRow>()
            FinUpWidgets.openDb(ctx)?.use { db ->
                val (start, end) = FinUpWidgets.monthRange()
                rows.addAll(FinUpWidgets.budgetRows(db, start, end, 3))
            }
            val rowIds = intArrayOf(R.id.w_row1, R.id.w_row2, R.id.w_row3)
            val nameIds = intArrayOf(R.id.w_name1, R.id.w_name2, R.id.w_name3)
            val amtIds = intArrayOf(R.id.w_amt1, R.id.w_amt2, R.id.w_amt3)
            val progIds = intArrayOf(R.id.w_prog1, R.id.w_prog2, R.id.w_prog3)
            for (i in rowIds.indices) FinUpWidgets.setGone(v, rowIds[i])
            if (rows.isEmpty()) {
                FinUpWidgets.setVisible(v, R.id.w_empty)
                v.setTextViewText(R.id.w_chip, "Empty")
            } else {
                FinUpWidgets.setGone(v, R.id.w_empty)
                v.setTextViewText(R.id.w_chip, "${rows.size} live")
                rows.forEachIndexed { i, r ->
                    FinUpWidgets.setVisible(v, rowIds[i])
                    v.setTextViewText(nameIds[i], r.name)
                    val label = if (hide) "••• / •••" else
                        "${fmt.format(r.spent)} / ${fmt.format(r.budget)}"
                    v.setTextViewText(amtIds[i], label)
                    v.setProgressBar(progIds[i], 100, FinUpWidgets.budgetPct(r.spent, r.budget), false)
                }
            }
            v.setOnClickPendingIntent(R.id.w_root, FinUpWidgets.action(ctx, "budgets", 811))
            return v
        }
    }
}
