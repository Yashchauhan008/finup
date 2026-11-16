#!/usr/bin/env bash
set -euo pipefail
cd app
mkdir -p \
  android/app/src/main/kotlin/com/yash/finup \
  android/app/src/main/res/layout \
  android/app/src/main/res/xml \
  android/app/src/main/res/values \
  lib/actions

############################ Strings ############################
if [ -f android/app/src/main/res/values/finup_strings.xml ]; then
  perl -0777 -pi -e 's#</resources>#    <string name="finup_w_budget_desc">Category budgets vs this month</string>\n    <string name="finup_w_accounts_desc">Balances for each account</string>\n    <string name="finup_w_people_desc">Who owes you and whom you owe</string>\n    <string name="finup_w_week_desc">This week vs last week spending</string>\n    <string name="finup_w_review_desc">Transactions waiting for review</string>\n</resources>#' \
    android/app/src/main/res/values/finup_strings.xml
fi

############################ Layouts ############################
cat > android/app/src/main/res/layout/finup_w_budget.xml <<'__END__'
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/w_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical"
    android:padding="12dp"
    android:background="@drawable/finup_widget_bg">

    <TextView
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:text="Budgets"
        android:textColor="#B3FFFFFF"
        android:textSize="12sp"
        android:textStyle="bold"/>

    <TextView
        android:id="@+id/w_empty"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="8dp"
        android:text="No budgets yet"
        android:textColor="#99FFFFFF"
        android:textSize="13sp"
        android:visibility="gone"/>

    <LinearLayout
        android:id="@+id/w_row1"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="8dp"
        android:orientation="vertical"
        android:visibility="gone">
        <LinearLayout
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:orientation="horizontal">
            <TextView
                android:id="@+id/w_name1"
                android:layout_width="0dp"
                android:layout_height="wrap_content"
                android:layout_weight="1"
                android:ellipsize="end"
                android:maxLines="1"
                android:textColor="#FFFFFF"
                android:textSize="12sp"/>
            <TextView
                android:id="@+id/w_amt1"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:textColor="#EBB9D6"
                android:textSize="11sp"
                android:textStyle="bold"/>
        </LinearLayout>
        <ProgressBar
            android:id="@+id/w_prog1"
            style="?android:attr/progressBarStyleHorizontal"
            android:layout_width="match_parent"
            android:layout_height="6dp"
            android:layout_marginTop="3dp"
            android:max="100"
            android:progress="0"
            android:progressTint="#EBB9D6"
            android:progressBackgroundTint="#33FFFFFF"/>
    </LinearLayout>

    <LinearLayout
        android:id="@+id/w_row2"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="8dp"
        android:orientation="vertical"
        android:visibility="gone">
        <LinearLayout
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:orientation="horizontal">
            <TextView
                android:id="@+id/w_name2"
                android:layout_width="0dp"
                android:layout_height="wrap_content"
                android:layout_weight="1"
                android:ellipsize="end"
                android:maxLines="1"
                android:textColor="#FFFFFF"
                android:textSize="12sp"/>
            <TextView
                android:id="@+id/w_amt2"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:textColor="#EBB9D6"
                android:textSize="11sp"
                android:textStyle="bold"/>
        </LinearLayout>
        <ProgressBar
            android:id="@+id/w_prog2"
            style="?android:attr/progressBarStyleHorizontal"
            android:layout_width="match_parent"
            android:layout_height="6dp"
            android:layout_marginTop="3dp"
            android:max="100"
            android:progress="0"
            android:progressTint="#EBB9D6"
            android:progressBackgroundTint="#33FFFFFF"/>
    </LinearLayout>

    <LinearLayout
        android:id="@+id/w_row3"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="8dp"
        android:orientation="vertical"
        android:visibility="gone">
        <LinearLayout
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:orientation="horizontal">
            <TextView
                android:id="@+id/w_name3"
                android:layout_width="0dp"
                android:layout_height="wrap_content"
                android:layout_weight="1"
                android:ellipsize="end"
                android:maxLines="1"
                android:textColor="#FFFFFF"
                android:textSize="12sp"/>
            <TextView
                android:id="@+id/w_amt3"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:textColor="#EBB9D6"
                android:textSize="11sp"
                android:textStyle="bold"/>
        </LinearLayout>
        <ProgressBar
            android:id="@+id/w_prog3"
            style="?android:attr/progressBarStyleHorizontal"
            android:layout_width="match_parent"
            android:layout_height="6dp"
            android:layout_marginTop="3dp"
            android:max="100"
            android:progress="0"
            android:progressTint="#EBB9D6"
            android:progressBackgroundTint="#33FFFFFF"/>
    </LinearLayout>
</LinearLayout>
__END__

cat > android/app/src/main/res/layout/finup_w_accounts.xml <<'__END__'
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/w_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical"
    android:padding="12dp"
    android:background="@drawable/finup_widget_bg">

    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:orientation="horizontal"
        android:gravity="center_vertical">
        <TextView
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:text="Accounts"
            android:textColor="#B3FFFFFF"
            android:textSize="12sp"
            android:textStyle="bold"/>
        <TextView
            android:id="@+id/w_total"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:textColor="#EBB9D6"
            android:textSize="12sp"
            android:textStyle="bold"/>
    </LinearLayout>

    <TextView
        android:id="@+id/w_empty"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="8dp"
        android:text="No accounts yet"
        android:textColor="#99FFFFFF"
        android:textSize="13sp"
        android:visibility="gone"/>

    <LinearLayout
        android:id="@+id/w_row1"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="8dp"
        android:orientation="horizontal"
        android:visibility="gone">
        <TextView
            android:id="@+id/w_name1"
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:ellipsize="end"
            android:maxLines="1"
            android:textColor="#FFFFFF"
            android:textSize="13sp"/>
        <TextView
            android:id="@+id/w_amt1"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:textColor="#FFFFFF"
            android:textSize="13sp"
            android:textStyle="bold"/>
    </LinearLayout>
    <LinearLayout
        android:id="@+id/w_row2"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="6dp"
        android:orientation="horizontal"
        android:visibility="gone">
        <TextView
            android:id="@+id/w_name2"
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:ellipsize="end"
            android:maxLines="1"
            android:textColor="#FFFFFF"
            android:textSize="13sp"/>
        <TextView
            android:id="@+id/w_amt2"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:textColor="#FFFFFF"
            android:textSize="13sp"
            android:textStyle="bold"/>
    </LinearLayout>
    <LinearLayout
        android:id="@+id/w_row3"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="6dp"
        android:orientation="horizontal"
        android:visibility="gone">
        <TextView
            android:id="@+id/w_name3"
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:ellipsize="end"
            android:maxLines="1"
            android:textColor="#FFFFFF"
            android:textSize="13sp"/>
        <TextView
            android:id="@+id/w_amt3"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:textColor="#FFFFFF"
            android:textSize="13sp"
            android:textStyle="bold"/>
    </LinearLayout>
    <LinearLayout
        android:id="@+id/w_row4"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="6dp"
        android:orientation="horizontal"
        android:visibility="gone">
        <TextView
            android:id="@+id/w_name4"
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:ellipsize="end"
            android:maxLines="1"
            android:textColor="#FFFFFF"
            android:textSize="13sp"/>
        <TextView
            android:id="@+id/w_amt4"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:textColor="#FFFFFF"
            android:textSize="13sp"
            android:textStyle="bold"/>
    </LinearLayout>
</LinearLayout>
__END__

cat > android/app/src/main/res/layout/finup_w_people.xml <<'__END__'
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/w_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical"
    android:padding="12dp"
    android:background="@drawable/finup_widget_bg">

    <TextView
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:text="People"
        android:textColor="#B3FFFFFF"
        android:textSize="12sp"
        android:textStyle="bold"/>

    <TextView
        android:id="@+id/w_empty"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="8dp"
        android:text="No people balances"
        android:textColor="#99FFFFFF"
        android:textSize="13sp"
        android:visibility="gone"/>

    <LinearLayout
        android:id="@+id/w_row1"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="8dp"
        android:orientation="horizontal"
        android:visibility="gone">
        <LinearLayout
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:orientation="vertical">
            <TextView
                android:id="@+id/w_name1"
                android:layout_width="match_parent"
                android:layout_height="wrap_content"
                android:ellipsize="end"
                android:maxLines="1"
                android:textColor="#FFFFFF"
                android:textSize="13sp"/>
            <TextView
                android:id="@+id/w_sub1"
                android:layout_width="match_parent"
                android:layout_height="wrap_content"
                android:textColor="#99FFFFFF"
                android:textSize="11sp"/>
        </LinearLayout>
        <TextView
            android:id="@+id/w_amt1"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:gravity="end"
            android:textColor="#FFFFFF"
            android:textSize="13sp"
            android:textStyle="bold"/>
    </LinearLayout>
    <LinearLayout
        android:id="@+id/w_row2"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="6dp"
        android:orientation="horizontal"
        android:visibility="gone">
        <LinearLayout
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:orientation="vertical">
            <TextView
                android:id="@+id/w_name2"
                android:layout_width="match_parent"
                android:layout_height="wrap_content"
                android:ellipsize="end"
                android:maxLines="1"
                android:textColor="#FFFFFF"
                android:textSize="13sp"/>
            <TextView
                android:id="@+id/w_sub2"
                android:layout_width="match_parent"
                android:layout_height="wrap_content"
                android:textColor="#99FFFFFF"
                android:textSize="11sp"/>
        </LinearLayout>
        <TextView
            android:id="@+id/w_amt2"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:gravity="end"
            android:textColor="#FFFFFF"
            android:textSize="13sp"
            android:textStyle="bold"/>
    </LinearLayout>
    <LinearLayout
        android:id="@+id/w_row3"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="6dp"
        android:orientation="horizontal"
        android:visibility="gone">
        <LinearLayout
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:orientation="vertical">
            <TextView
                android:id="@+id/w_name3"
                android:layout_width="match_parent"
                android:layout_height="wrap_content"
                android:ellipsize="end"
                android:maxLines="1"
                android:textColor="#FFFFFF"
                android:textSize="13sp"/>
            <TextView
                android:id="@+id/w_sub3"
                android:layout_width="match_parent"
                android:layout_height="wrap_content"
                android:textColor="#99FFFFFF"
                android:textSize="11sp"/>
        </LinearLayout>
        <TextView
            android:id="@+id/w_amt3"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:gravity="end"
            android:textColor="#FFFFFF"
            android:textSize="13sp"
            android:textStyle="bold"/>
    </LinearLayout>
    <LinearLayout
        android:id="@+id/w_row4"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="6dp"
        android:orientation="horizontal"
        android:visibility="gone">
        <LinearLayout
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:orientation="vertical">
            <TextView
                android:id="@+id/w_name4"
                android:layout_width="match_parent"
                android:layout_height="wrap_content"
                android:ellipsize="end"
                android:maxLines="1"
                android:textColor="#FFFFFF"
                android:textSize="13sp"/>
            <TextView
                android:id="@+id/w_sub4"
                android:layout_width="match_parent"
                android:layout_height="wrap_content"
                android:textColor="#99FFFFFF"
                android:textSize="11sp"/>
        </LinearLayout>
        <TextView
            android:id="@+id/w_amt4"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:gravity="end"
            android:textColor="#FFFFFF"
            android:textSize="13sp"
            android:textStyle="bold"/>
    </LinearLayout>
</LinearLayout>
__END__

cat > android/app/src/main/res/layout/finup_w_week.xml <<'__END__'
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/w_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical"
    android:padding="14dp"
    android:background="@drawable/finup_widget_bg">

    <TextView
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:text="This week"
        android:textColor="#B3FFFFFF"
        android:textSize="12sp"
        android:textStyle="bold"/>

    <TextView
        android:id="@+id/w_this"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:layout_marginTop="4dp"
        android:text="₹0"
        android:textColor="#FFFFFF"
        android:textSize="24sp"
        android:textStyle="bold"/>

    <TextView
        android:id="@+id/w_last"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="6dp"
        android:text="Last week ₹0"
        android:textColor="#99FFFFFF"
        android:textSize="12sp"/>

    <TextView
        android:id="@+id/w_delta"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:layout_marginTop="8dp"
        android:background="@drawable/finup_widget_btn"
        android:paddingStart="10dp"
        android:paddingEnd="10dp"
        android:paddingTop="4dp"
        android:paddingBottom="4dp"
        android:text="—"
        android:textColor="#EBB9D6"
        android:textSize="12sp"
        android:textStyle="bold"/>
</LinearLayout>
__END__

cat > android/app/src/main/res/layout/finup_w_review.xml <<'__END__'
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/w_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical"
    android:padding="14dp"
    android:gravity="center_vertical"
    android:background="@drawable/finup_widget_bg">

    <TextView
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:text="Review inbox"
        android:textColor="#B3FFFFFF"
        android:textSize="12sp"
        android:textStyle="bold"/>

    <TextView
        android:id="@+id/w_count"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:layout_marginTop="4dp"
        android:text="0"
        android:textColor="#FFFFFF"
        android:textSize="28sp"
        android:textStyle="bold"/>

    <TextView
        android:id="@+id/w_sub"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="2dp"
        android:text="All clear ✓"
        android:textColor="#EBB9D6"
        android:textSize="12sp"/>
</LinearLayout>
__END__

############################ AppWidget provider XML ############################
cat > android/app/src/main/res/xml/finup_w_budget_info.xml <<'__END__'
<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:minWidth="110dp"
    android:minHeight="110dp"
    android:targetCellWidth="2"
    android:targetCellHeight="2"
    android:updatePeriodMillis="1800000"
    android:initialLayout="@layout/finup_w_budget"
    android:resizeMode="horizontal|vertical"
    android:widgetCategory="home_screen"
    android:description="@string/finup_w_budget_desc"/>
__END__

cat > android/app/src/main/res/xml/finup_w_accounts_info.xml <<'__END__'
<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:minWidth="250dp"
    android:minHeight="110dp"
    android:targetCellWidth="4"
    android:targetCellHeight="2"
    android:updatePeriodMillis="1800000"
    android:initialLayout="@layout/finup_w_accounts"
    android:resizeMode="horizontal|vertical"
    android:widgetCategory="home_screen"
    android:description="@string/finup_w_accounts_desc"/>
__END__

cat > android/app/src/main/res/xml/finup_w_people_info.xml <<'__END__'
<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:minWidth="110dp"
    android:minHeight="110dp"
    android:targetCellWidth="2"
    android:targetCellHeight="2"
    android:updatePeriodMillis="1800000"
    android:initialLayout="@layout/finup_w_people"
    android:resizeMode="horizontal|vertical"
    android:widgetCategory="home_screen"
    android:description="@string/finup_w_people_desc"/>
__END__

cat > android/app/src/main/res/xml/finup_w_week_info.xml <<'__END__'
<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:minWidth="110dp"
    android:minHeight="110dp"
    android:targetCellWidth="2"
    android:targetCellHeight="2"
    android:updatePeriodMillis="1800000"
    android:initialLayout="@layout/finup_w_week"
    android:resizeMode="horizontal|vertical"
    android:widgetCategory="home_screen"
    android:description="@string/finup_w_week_desc"/>
__END__

cat > android/app/src/main/res/xml/finup_w_review_info.xml <<'__END__'
<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:minWidth="110dp"
    android:minHeight="40dp"
    android:targetCellWidth="2"
    android:targetCellHeight="1"
    android:updatePeriodMillis="1800000"
    android:initialLayout="@layout/finup_w_review"
    android:resizeMode="horizontal|vertical"
    android:widgetCategory="home_screen"
    android:description="@string/finup_w_review_desc"/>
__END__

############################ Shared Kotlin helpers ############################
cat > android/app/src/main/kotlin/com/yash/finup/FinUpWidgets.kt <<'__END__'
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
__END__

############################ Widget providers ############################
cat > android/app/src/main/kotlin/com/yash/finup/BudgetPulseWidget.kt <<'__END__'
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
            } else {
                FinUpWidgets.setGone(v, R.id.w_empty)
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
__END__

cat > android/app/src/main/kotlin/com/yash/finup/AccountsWidget.kt <<'__END__'
package com.yash.finup

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews

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
            for (i in rowIds.indices) FinUpWidgets.setGone(v, rowIds[i])
            if (rows.isEmpty()) {
                FinUpWidgets.setVisible(v, R.id.w_empty)
            } else {
                FinUpWidgets.setGone(v, R.id.w_empty)
                rows.forEachIndexed { i, r ->
                    FinUpWidgets.setVisible(v, rowIds[i])
                    v.setTextViewText(nameIds[i], r.name)
                    v.setTextViewText(amtIds[i], FinUpWidgets.money(fmt, hide, r.amount))
                }
            }
            v.setOnClickPendingIntent(R.id.w_root, FinUpWidgets.action(ctx, "open", 821))
            return v
        }
    }
}
__END__

cat > android/app/src/main/kotlin/com/yash/finup/PeopleBalanceWidget.kt <<'__END__'
package com.yash.finup

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
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
            val rowIds = intArrayOf(R.id.w_row1, R.id.w_row2, R.id.w_row3, R.id.w_row4)
            val nameIds = intArrayOf(R.id.w_name1, R.id.w_name2, R.id.w_name3, R.id.w_name4)
            val subIds = intArrayOf(R.id.w_sub1, R.id.w_sub2, R.id.w_sub3, R.id.w_sub4)
            val amtIds = intArrayOf(R.id.w_amt1, R.id.w_amt2, R.id.w_amt3, R.id.w_amt4)
            for (i in rowIds.indices) FinUpWidgets.setGone(v, rowIds[i])
            if (rows.isEmpty()) {
                FinUpWidgets.setVisible(v, R.id.w_empty)
            } else {
                FinUpWidgets.setGone(v, R.id.w_empty)
                rows.forEachIndexed { i, r ->
                    FinUpWidgets.setVisible(v, rowIds[i])
                    v.setTextViewText(nameIds[i], r.name)
                    v.setTextViewText(subIds[i], if (r.net >= 0) "owes you" else "you owe")
                    v.setTextViewText(amtIds[i], FinUpWidgets.money(fmt, hide, abs(r.net)))
                }
            }
            v.setOnClickPendingIntent(R.id.w_root, FinUpWidgets.action(ctx, "people", 831))
            return v
        }
    }
}
__END__

cat > android/app/src/main/kotlin/com/yash/finup/WeekCompareWidget.kt <<'__END__'
package com.yash.finup

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
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
            val deltaText = when {
                hide -> "Hidden"
                lastWeek <= 0.009 && thisWeek <= 0.009 -> "No spend yet"
                lastWeek <= 0.009 -> "New spend this week"
                else -> {
                    val pct = (((thisWeek - lastWeek) / lastWeek) * 100.0).roundToInt()
                    val arrow = if (pct > 0) "▲" else if (pct < 0) "▼" else "•"
                    "$arrow ${abs(pct)}% vs last week"
                }
            }
            v.setTextViewText(R.id.w_delta, deltaText)
            v.setOnClickPendingIntent(R.id.w_root, FinUpWidgets.action(ctx, "insights", 841))
            return v
        }
    }
}
__END__

cat > android/app/src/main/kotlin/com/yash/finup/ReviewInboxWidget.kt <<'__END__'
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
                v.setTextViewText(R.id.w_sub, "All clear")
            } else {
                v.setTextViewText(R.id.w_count, count.toString())
                v.setTextViewText(R.id.w_sub, if (count == 1) "1 to review" else "$count to review")
            }
            v.setOnClickPendingIntent(R.id.w_root, FinUpWidgets.action(ctx, "review", 851))
            return v
        }
    }
}
__END__

############################ Manifest: register five receivers ############################
MANIFEST=android/app/src/main/AndroidManifest.xml
if [ -f "$MANIFEST" ]; then
  if ! grep -q "BudgetPulseWidget" "$MANIFEST"; then
    perl -0777 -pi -e 's{(<receiver android:name="\.FinUpWidget" android:exported="false">.*?</receiver>)}{$1
        <receiver android:name=".BudgetPulseWidget" android:exported="false">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE"/>
            </intent-filter>
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="\@xml/finup_w_budget_info"/>
        </receiver>
        <receiver android:name=".AccountsWidget" android:exported="false">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE"/>
            </intent-filter>
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="\@xml/finup_w_accounts_info"/>
        </receiver>
        <receiver android:name=".PeopleBalanceWidget" android:exported="false">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE"/>
            </intent-filter>
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="\@xml/finup_w_people_info"/>
        </receiver>
        <receiver android:name=".WeekCompareWidget" android:exported="false">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE"/>
            </intent-filter>
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="\@xml/finup_w_week_info"/>
        </receiver>
        <receiver android:name=".ReviewInboxWidget" android:exported="false">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE"/>
            </intent-filter>
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="\@xml/finup_w_review_info"/>
        </receiver>}s' "$MANIFEST"
  fi
fi

############################ Refresh: all widgets on Native.refreshWidget ############################
# MainActivity channel → FinUpWidgets.refreshAll
if [ -f android/app/src/main/kotlin/com/yash/finup/MainActivity.kt ]; then
  perl -pi -e 's#FinUpWidget\.updateAll\(this\)#FinUpWidgets.refreshAll(this)#' \
    android/app/src/main/kotlin/com/yash/finup/MainActivity.kt
fi

# FinUpWidget.updateAll → refresh every widget type (avoid duplicating only dashboard)
if [ -f android/app/src/main/kotlin/com/yash/finup/FinUpWidget.kt ]; then
  perl -0777 -pi -e 's#fun updateAll\(ctx: Context\) \{\s*try \{.*?\} catch \(e: Exception\) \{\s*\}\s*\}#fun updateAll(ctx: Context) {\n            FinUpWidgets.refreshAll(ctx)\n        }#s' \
    android/app/src/main/kotlin/com/yash/finup/FinUpWidget.kt
fi

############################ Flutter deep links ############################
QA=lib/actions/quick_actions.dart
if [ -f "$QA" ]; then
  if ! grep -q "budgets_screen.dart" "$QA"; then
    perl -pi -e "s#import '../screens/review_screen.dart';#import '../screens/review_screen.dart';\nimport '../screens/budgets_screen.dart';\nimport '../screens/insights_screen.dart';\nimport '../screens/people_screen.dart';#" "$QA"
  fi
  if ! grep -q "case 'budgets':" "$QA"; then
    perl -0777 -pi -e "s#case 'review':\n      Navigator.of\(context\).push\(fadeRoute\(const ReviewScreen\(\)\)\);\n    default:#case 'review':\n      Navigator.of(context).push(fadeRoute(const ReviewScreen()));\n    case 'budgets':\n      Navigator.of(context).push(fadeRoute(const BudgetsScreen()));\n    case 'people':\n      Navigator.of(context).push(fadeRoute(const PeopleScreen()));\n    case 'insights':\n      Navigator.of(context).push(fadeRoute(const InsightsScreen()));\n    default:#s" "$QA"
  fi
fi

############################ Docs ############################
if [ -f USER_GUIDE.md ]; then
  if ! grep -q "## 21. More home screen widgets" USER_GUIDE.md; then
    cat >> USER_GUIDE.md <<'__END__'

## 21. More home screen widgets
Long-press the home screen → Widgets → FinUp to add any of these:

- **Budgets** — top category budgets for this month with progress bars. Tap to open Budgets.
- **Accounts** — each account balance and the total. Tap to open FinUp.
- **People** — who owes you and whom you owe. Tap to open People.
- **This week** — this week's spending vs last week. Tap to open Insights.
- **Review inbox** — how many SMS or imported transactions still need review. Tap to open Review.

All widgets refresh when FinUp saves a change and about every 30 minutes. If you hide amounts in Settings, widgets show masked values too.
__END__
  fi
fi

############################ Fail-fast checks ############################
# Use | as separator so patterns may contain ':' and '@'
for check in \
  "FinUpWidgets.refreshAll|android/app/src/main/kotlin/com/yash/finup/MainActivity.kt" \
  "FinUpWidgets.refreshAll|android/app/src/main/kotlin/com/yash/finup/FinUpWidget.kt" \
  "BudgetPulseWidget|android/app/src/main/AndroidManifest.xml" \
  "@xml/finup_w_budget_info|android/app/src/main/AndroidManifest.xml" \
  "@xml/finup_w_accounts_info|android/app/src/main/AndroidManifest.xml" \
  "@xml/finup_w_people_info|android/app/src/main/AndroidManifest.xml" \
  "@xml/finup_w_week_info|android/app/src/main/AndroidManifest.xml" \
  "@xml/finup_w_review_info|android/app/src/main/AndroidManifest.xml" \
  "AccountsWidget|android/app/src/main/AndroidManifest.xml" \
  "PeopleBalanceWidget|android/app/src/main/AndroidManifest.xml" \
  "WeekCompareWidget|android/app/src/main/AndroidManifest.xml" \
  "ReviewInboxWidget|android/app/src/main/AndroidManifest.xml" \
  "case 'budgets':|lib/actions/quick_actions.dart" \
  "case 'people':|lib/actions/quick_actions.dart" \
  "case 'insights':|lib/actions/quick_actions.dart" \
  "w_prog1|android/app/src/main/res/layout/finup_w_budget.xml" \
  "w_name4|android/app/src/main/res/layout/finup_w_accounts.xml" \
  "More home screen widgets|USER_GUIDE.md"
do
  pat="${check%%|*}"; file="${check#*|}"
  if [ ! -f "$file" ] || ! grep -qF "$pat" "$file"; then
    echo "ERROR: patch failed in $file ($pat)"
    exit 1
  fi
done

echo "FinUp Part 8 (finup8.sh) applied — five home widgets."
