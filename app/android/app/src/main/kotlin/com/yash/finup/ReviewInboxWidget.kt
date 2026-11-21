package com.yash.finup

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews

class ReviewInboxWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        val views = build(context)
        for (id in appWidgetIds) appWidgetManager.updateAppWidget(id, views)
    }

    companion object {
        fun build(ctx: Context): RemoteViews {
            val v = RemoteViews(ctx.packageName, R.layout.finup_w_review)
            var count = 0
            FinUpWidgets.openDb(ctx)?.use { db ->
                count = FinUpWidgets.reviewCount(db)
            }
            if (count == 0) {
                v.setTextViewText(R.id.w_count, "✓")
                v.setTextViewText(R.id.w_sub, "Inbox zero — nice.")
                v.setTextViewText(R.id.w_chip, "Clear")
            } else {
                v.setTextViewText(R.id.w_count, count.toString())
                v.setTextViewText(R.id.w_sub, if (count == 1) "1 to review" else "$count to review")
                v.setTextViewText(R.id.w_chip, "Open")
            }
            v.setOnClickPendingIntent(R.id.w_root, FinUpWidgets.action(ctx, "review", 851))
            return v
        }
    }
}
