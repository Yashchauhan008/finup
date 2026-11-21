package com.yash.finup

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.graphics.Color
import android.widget.RemoteViews
import kotlin.math.abs

class PeopleBalanceWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        val views = build(context)
        for (id in appWidgetIds) appWidgetManager.updateAppWidget(id, views)
    }

    companion object {
        fun build(ctx: Context): RemoteViews {
            val v = RemoteViews(ctx.packageName, R.layout.finup_w_people)
            val hide = FinUpWidgets.hideAmounts(ctx)
            val fmt = FinUpWidgets.currency()
            var rows = emptyList<FinUpWidgets.PersonRow>()
            FinUpWidgets.openDb(ctx)?.use { db ->
                rows = FinUpWidgets.peopleRows(db, 4)
            }
            v.setTextViewText(R.id.w_chip, if (rows.isEmpty()) "Settled" else "${rows.size} open")
            val rowIds = intArrayOf(R.id.w_row1, R.id.w_row2, R.id.w_row3, R.id.w_row4)
            val nameIds = intArrayOf(R.id.w_name1, R.id.w_name2, R.id.w_name3, R.id.w_name4)
            val subIds = intArrayOf(R.id.w_sub1, R.id.w_sub2, R.id.w_sub3, R.id.w_sub4)
            val amtIds = intArrayOf(R.id.w_amt1, R.id.w_amt2, R.id.w_amt3, R.id.w_amt4)
            val avIds = intArrayOf(R.id.w_av1, R.id.w_av2, R.id.w_av3, R.id.w_av4)
            for (i in rowIds.indices) FinUpWidgets.setGone(v, rowIds[i])
            if (rows.isEmpty()) {
                FinUpWidgets.setVisible(v, R.id.w_empty)
            } else {
                FinUpWidgets.setGone(v, R.id.w_empty)
                rows.forEachIndexed { i, r ->
                    FinUpWidgets.setVisible(v, rowIds[i])
                    val initial = r.name.trim().firstOrNull()?.uppercaseChar()?.toString() ?: "?"
                    v.setTextViewText(avIds[i], initial)
                    v.setTextViewText(nameIds[i], r.name)
                    v.setTextViewText(subIds[i], if (r.net >= 0) "owes you" else "you owe")
                    v.setTextViewText(amtIds[i], FinUpWidgets.money(fmt, hide, abs(r.net)))
                    v.setTextColor(amtIds[i], if (r.net >= 0) Color.parseColor("#9AEBCF") else Color.parseColor("#FFB5A5"))
                }
            }
            v.setOnClickPendingIntent(R.id.w_root, FinUpWidgets.action(ctx, "people", 831))
            return v
        }
    }
}
