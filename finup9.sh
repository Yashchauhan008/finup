#!/usr/bin/env bash
# FinUp Part 9 — widget visual refresh (ink glass + role accents)
set -euo pipefail
cd app
mkdir -p \
  android/app/src/main/res/drawable \
  android/app/src/main/res/layout \
  android/app/src/main/kotlin/com/yash/finup

############################ Drawables ############################
cat > android/app/src/main/res/drawable/finup_widget_bg.xml <<'__END__'
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <gradient
        android:startColor="#1B1E2A"
        android:centerColor="#171925"
        android:endColor="#14161F"
        android:angle="160"/>
    <corners android:radius="26dp"/>
    <stroke android:width="1dp" android:color="#26FFFFFF"/>
</shape>
__END__

cat > android/app/src/main/res/drawable/finup_widget_btn.xml <<'__END__'
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="#1AFFFFFF"/>
    <corners android:radius="16dp"/>
    <stroke android:width="1dp" android:color="#1FFFFFFF"/>
</shape>
__END__

cat > android/app/src/main/res/drawable/finup_widget_btn_primary.xml <<'__END__'
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="#F3EFFF"/>
    <corners android:radius="16dp"/>
</shape>
__END__

cat > android/app/src/main/res/drawable/finup_widget_btn_ghost.xml <<'__END__'
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="#1AFFFFFF"/>
    <corners android:radius="16dp"/>
    <stroke android:width="1dp" android:color="#1FFFFFFF"/>
</shape>
__END__

cat > android/app/src/main/res/drawable/finup_chip.xml <<'__END__'
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="#1AFFFFFF"/>
    <corners android:radius="999dp"/>
</shape>
__END__

cat > android/app/src/main/res/drawable/finup_chip_ok.xml <<'__END__'
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="#2E6DCFB4"/>
    <corners android:radius="999dp"/>
</shape>
__END__

cat > android/app/src/main/res/drawable/finup_chip_warn.xml <<'__END__'
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="#2EF0816C"/>
    <corners android:radius="999dp"/>
</shape>
__END__

cat > android/app/src/main/res/drawable/finup_chip_soft.xml <<'__END__'
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="#338B86E8"/>
    <corners android:radius="999dp"/>
</shape>
__END__

cat > android/app/src/main/res/drawable/finup_avatar.xml <<'__END__'
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <gradient android:startColor="#E7A0C4" android:endColor="#8B86E8" android:angle="135"/>
    <corners android:radius="10dp"/>
</shape>
__END__

cat > android/app/src/main/res/drawable/finup_brand_mark.xml <<'__END__'
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <gradient android:startColor="#E7A0C4" android:centerColor="#8B86E8" android:endColor="#6DCFB4" android:angle="210"/>
    <corners android:radius="10dp"/>
</shape>
__END__

cat > android/app/src/main/res/drawable/finup_review_panel.xml <<'__END__'
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="#14FFFFFF"/>
    <corners android:radius="16dp"/>
</shape>
__END__

cat > android/app/src/main/res/drawable/finup_accent_gold.xml <<'__END__'
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="#E6B35A"/>
    <corners android:radius="99dp"/>
</shape>
__END__

cat > android/app/src/main/res/drawable/finup_accent_mint.xml <<'__END__'
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="#6DCFB4"/>
    <corners android:radius="99dp"/>
</shape>
__END__

cat > android/app/src/main/res/drawable/finup_accent_pink.xml <<'__END__'
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="#E7A0C4"/>
    <corners android:radius="99dp"/>
</shape>
__END__

cat > android/app/src/main/res/drawable/finup_accent_coral.xml <<'__END__'
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="#F0816C"/>
    <corners android:radius="99dp"/>
</shape>
__END__

cat > android/app/src/main/res/drawable/finup_accent_lav.xml <<'__END__'
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="#8B86E8"/>
    <corners android:radius="99dp"/>
</shape>
__END__

cat > android/app/src/main/res/drawable/finup_prog_gold.xml <<'__END__'
<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:id="@android:id/background">
        <shape android:shape="rectangle">
            <corners android:radius="99dp"/>
            <solid android:color="#1AFFFFFF"/>
        </shape>
    </item>
    <item android:id="@android:id/progress">
        <clip>
            <shape android:shape="rectangle">
                <corners android:radius="99dp"/>
                <solid android:color="#E6B35A"/>
            </shape>
        </clip>
    </item>
</layer-list>
__END__

cat > android/app/src/main/res/drawable/finup_prog_mint.xml <<'__END__'
<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:id="@android:id/background">
        <shape android:shape="rectangle">
            <corners android:radius="99dp"/>
            <solid android:color="#1AFFFFFF"/>
        </shape>
    </item>
    <item android:id="@android:id/progress">
        <clip>
            <shape android:shape="rectangle">
                <corners android:radius="99dp"/>
                <gradient android:startColor="#8B86E8" android:endColor="#E7A0C4" android:angle="0"/>
            </shape>
        </clip>
    </item>
</layer-list>
__END__

cat > android/app/src/main/res/drawable/finup_prog_coral.xml <<'__END__'
<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:id="@android:id/background">
        <shape android:shape="rectangle">
            <corners android:radius="99dp"/>
            <solid android:color="#1AFFFFFF"/>
        </shape>
    </item>
    <item android:id="@android:id/progress">
        <clip>
            <shape android:shape="rectangle">
                <corners android:radius="99dp"/>
                <solid android:color="#F0816C"/>
            </shape>
        </clip>
    </item>
</layer-list>
__END__

############################ Hero: Spent today ############################
cat > android/app/src/main/res/layout/finup_widget.xml <<'__END__'
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/w_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="horizontal"
    android:background="@drawable/finup_widget_bg">

    <ImageView
        android:layout_width="4dp"
        android:layout_height="match_parent"
        android:layout_marginTop="14dp"
        android:layout_marginBottom="14dp"
        android:layout_marginStart="8dp"
        android:src="@drawable/finup_accent_lav"
        android:contentDescription="@null"/>

    <LinearLayout
        android:layout_width="0dp"
        android:layout_height="match_parent"
        android:layout_weight="1"
        android:orientation="vertical"
        android:padding="14dp">

        <LinearLayout
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:orientation="horizontal"
            android:gravity="center_vertical">
            <ImageView
                android:layout_width="28dp"
                android:layout_height="28dp"
                android:src="@drawable/finup_brand_mark"
                android:contentDescription="FinUp"/>
            <TextView
                android:layout_width="0dp"
                android:layout_height="wrap_content"
                android:layout_weight="1"
                android:layout_marginStart="8dp"
                android:text="SPENT TODAY"
                android:textColor="#9EFFFFFF"
                android:textSize="11sp"
                android:textStyle="bold"
                android:letterSpacing="0.04"/>
            <TextView
                android:id="@+id/w_review"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:background="@drawable/finup_chip_ok"
                android:paddingStart="10dp"
                android:paddingEnd="10dp"
                android:paddingTop="4dp"
                android:paddingBottom="4dp"
                android:text="All reviewed"
                android:textColor="#9AEBCF"
                android:textSize="11sp"
                android:textStyle="bold"/>
        </LinearLayout>

        <TextView
            android:id="@+id/w_spent"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:layout_marginTop="10dp"
            android:text="₹0"
            android:textColor="#FFFFFF"
            android:textSize="32sp"
            android:textStyle="bold"/>

        <TextView
            android:id="@+id/w_balance"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:text="Total balance · ₹0"
            android:textColor="#94FFFFFF"
            android:textSize="12sp"/>

        <LinearLayout
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:layout_marginTop="12dp"
            android:orientation="horizontal">
            <TextView
                android:id="@+id/w_add"
                android:layout_width="0dp"
                android:layout_height="wrap_content"
                android:layout_weight="1.2"
                android:background="@drawable/finup_widget_btn_primary"
                android:gravity="center"
                android:paddingTop="11dp"
                android:paddingBottom="11dp"
                android:text="+ Expense"
                android:textColor="#17141F"
                android:textSize="12sp"
                android:textStyle="bold"/>
            <TextView
                android:id="@+id/w_voice"
                android:layout_width="0dp"
                android:layout_height="wrap_content"
                android:layout_weight="1"
                android:layout_marginStart="7dp"
                android:background="@drawable/finup_widget_btn_ghost"
                android:gravity="center"
                android:paddingTop="11dp"
                android:paddingBottom="11dp"
                android:text="Voice"
                android:textColor="#F5F2FF"
                android:textSize="12sp"
                android:textStyle="bold"/>
            <TextView
                android:id="@+id/w_scan"
                android:layout_width="0dp"
                android:layout_height="wrap_content"
                android:layout_weight="1"
                android:layout_marginStart="7dp"
                android:background="@drawable/finup_widget_btn_ghost"
                android:gravity="center"
                android:paddingTop="11dp"
                android:paddingBottom="11dp"
                android:text="Scan"
                android:textColor="#F5F2FF"
                android:textSize="12sp"
                android:textStyle="bold"/>
        </LinearLayout>
    </LinearLayout>
</LinearLayout>
__END__

############################ Budgets ############################
cat > android/app/src/main/res/layout/finup_w_budget.xml <<'__END__'
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/w_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="horizontal"
    android:background="@drawable/finup_widget_bg">

    <ImageView
        android:layout_width="4dp"
        android:layout_height="match_parent"
        android:layout_margin="12dp"
        android:src="@drawable/finup_accent_gold"
        android:contentDescription="@null"/>

    <LinearLayout
        android:layout_width="0dp"
        android:layout_height="match_parent"
        android:layout_weight="1"
        android:orientation="vertical"
        android:paddingTop="12dp"
        android:paddingBottom="12dp"
        android:paddingEnd="12dp">

        <LinearLayout
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:orientation="horizontal"
            android:gravity="center_vertical">
            <TextView
                android:layout_width="0dp"
                android:layout_height="wrap_content"
                android:layout_weight="1"
                android:text="BUDGETS"
                android:textColor="#9EFFFFFF"
                android:textSize="11sp"
                android:textStyle="bold"
                android:letterSpacing="0.04"/>
            <TextView
                android:id="@+id/w_chip"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:background="@drawable/finup_chip_soft"
                android:paddingStart="8dp"
                android:paddingEnd="8dp"
                android:paddingTop="3dp"
                android:paddingBottom="3dp"
                android:text="Empty"
                android:textColor="#C9C5FF"
                android:textSize="11sp"
                android:textStyle="bold"/>
        </LinearLayout>

        <TextView
            android:id="@+id/w_empty"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:layout_marginTop="10dp"
            android:text="No budgets yet"
            android:textColor="#94FFFFFF"
            android:textSize="13sp"
            android:visibility="gone"/>

        <LinearLayout
            android:id="@+id/w_row1"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:layout_marginTop="10dp"
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
                    android:textSize="13sp"
                    android:textStyle="bold"/>
                <TextView
                    android:id="@+id/w_amt1"
                    android:layout_width="wrap_content"
                    android:layout_height="wrap_content"
                    android:textColor="#E6B35A"
                    android:textSize="11sp"
                    android:textStyle="bold"/>
            </LinearLayout>
            <ProgressBar
                android:id="@+id/w_prog1"
                style="?android:attr/progressBarStyleHorizontal"
                android:layout_width="match_parent"
                android:layout_height="6dp"
                android:layout_marginTop="5dp"
                android:max="100"
                android:progress="0"
                android:progressDrawable="@drawable/finup_prog_gold"/>
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
                    android:textSize="13sp"
                    android:textStyle="bold"/>
                <TextView
                    android:id="@+id/w_amt2"
                    android:layout_width="wrap_content"
                    android:layout_height="wrap_content"
                    android:textColor="#E6B35A"
                    android:textSize="11sp"
                    android:textStyle="bold"/>
            </LinearLayout>
            <ProgressBar
                android:id="@+id/w_prog2"
                style="?android:attr/progressBarStyleHorizontal"
                android:layout_width="match_parent"
                android:layout_height="6dp"
                android:layout_marginTop="5dp"
                android:max="100"
                android:progress="0"
                android:progressDrawable="@drawable/finup_prog_gold"/>
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
                    android:textSize="13sp"
                    android:textStyle="bold"/>
                <TextView
                    android:id="@+id/w_amt3"
                    android:layout_width="wrap_content"
                    android:layout_height="wrap_content"
                    android:textColor="#E6B35A"
                    android:textSize="11sp"
                    android:textStyle="bold"/>
            </LinearLayout>
            <ProgressBar
                android:id="@+id/w_prog3"
                style="?android:attr/progressBarStyleHorizontal"
                android:layout_width="match_parent"
                android:layout_height="6dp"
                android:layout_marginTop="5dp"
                android:max="100"
                android:progress="0"
                android:progressDrawable="@drawable/finup_prog_gold"/>
        </LinearLayout>
    </LinearLayout>
</LinearLayout>
__END__

############################ Accounts ############################
cat > android/app/src/main/res/layout/finup_w_accounts.xml <<'__END__'
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/w_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="horizontal"
    android:background="@drawable/finup_widget_bg">

    <ImageView
        android:layout_width="4dp"
        android:layout_height="match_parent"
        android:layout_margin="12dp"
        android:src="@drawable/finup_accent_mint"
        android:contentDescription="@null"/>

    <LinearLayout
        android:layout_width="0dp"
        android:layout_height="match_parent"
        android:layout_weight="1"
        android:orientation="vertical"
        android:paddingTop="12dp"
        android:paddingBottom="12dp"
        android:paddingEnd="12dp">

        <LinearLayout
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:orientation="horizontal"
            android:gravity="center_vertical">
            <TextView
                android:layout_width="0dp"
                android:layout_height="wrap_content"
                android:layout_weight="1"
                android:text="ACCOUNTS"
                android:textColor="#9EFFFFFF"
                android:textSize="11sp"
                android:textStyle="bold"
                android:letterSpacing="0.04"/>
            <TextView
                android:id="@+id/w_total"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:textColor="#FFFFFF"
                android:textSize="14sp"
                android:textStyle="bold"/>
        </LinearLayout>

        <TextView
            android:id="@+id/w_empty"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:layout_marginTop="10dp"
            android:text="No accounts yet"
            android:textColor="#94FFFFFF"
            android:textSize="13sp"
            android:visibility="gone"/>

        <LinearLayout android:id="@+id/w_row1" android:layout_width="match_parent" android:layout_height="wrap_content" android:layout_marginTop="10dp" android:orientation="vertical" android:visibility="gone">
            <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content" android:orientation="horizontal">
                <TextView android:id="@+id/w_name1" android:layout_width="0dp" android:layout_height="wrap_content" android:layout_weight="1" android:ellipsize="end" android:maxLines="1" android:textColor="#FFFFFF" android:textSize="13sp" android:textStyle="bold"/>
                <TextView android:id="@+id/w_amt1" android:layout_width="wrap_content" android:layout_height="wrap_content" android:textColor="#FFFFFF" android:textSize="13sp" android:textStyle="bold"/>
            </LinearLayout>
            <ProgressBar android:id="@+id/w_track1" style="?android:attr/progressBarStyleHorizontal" android:layout_width="match_parent" android:layout_height="5dp" android:layout_marginTop="5dp" android:max="100" android:progress="0" android:progressDrawable="@drawable/finup_prog_mint"/>
        </LinearLayout>
        <LinearLayout android:id="@+id/w_row2" android:layout_width="match_parent" android:layout_height="wrap_content" android:layout_marginTop="8dp" android:orientation="vertical" android:visibility="gone">
            <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content" android:orientation="horizontal">
                <TextView android:id="@+id/w_name2" android:layout_width="0dp" android:layout_height="wrap_content" android:layout_weight="1" android:ellipsize="end" android:maxLines="1" android:textColor="#FFFFFF" android:textSize="13sp" android:textStyle="bold"/>
                <TextView android:id="@+id/w_amt2" android:layout_width="wrap_content" android:layout_height="wrap_content" android:textColor="#FFFFFF" android:textSize="13sp" android:textStyle="bold"/>
            </LinearLayout>
            <ProgressBar android:id="@+id/w_track2" style="?android:attr/progressBarStyleHorizontal" android:layout_width="match_parent" android:layout_height="5dp" android:layout_marginTop="5dp" android:max="100" android:progress="0" android:progressDrawable="@drawable/finup_prog_mint"/>
        </LinearLayout>
        <LinearLayout android:id="@+id/w_row3" android:layout_width="match_parent" android:layout_height="wrap_content" android:layout_marginTop="8dp" android:orientation="vertical" android:visibility="gone">
            <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content" android:orientation="horizontal">
                <TextView android:id="@+id/w_name3" android:layout_width="0dp" android:layout_height="wrap_content" android:layout_weight="1" android:ellipsize="end" android:maxLines="1" android:textColor="#FFFFFF" android:textSize="13sp" android:textStyle="bold"/>
                <TextView android:id="@+id/w_amt3" android:layout_width="wrap_content" android:layout_height="wrap_content" android:textColor="#FFFFFF" android:textSize="13sp" android:textStyle="bold"/>
            </LinearLayout>
            <ProgressBar android:id="@+id/w_track3" style="?android:attr/progressBarStyleHorizontal" android:layout_width="match_parent" android:layout_height="5dp" android:layout_marginTop="5dp" android:max="100" android:progress="0" android:progressDrawable="@drawable/finup_prog_mint"/>
        </LinearLayout>
        <LinearLayout android:id="@+id/w_row4" android:layout_width="match_parent" android:layout_height="wrap_content" android:layout_marginTop="8dp" android:orientation="vertical" android:visibility="gone">
            <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content" android:orientation="horizontal">
                <TextView android:id="@+id/w_name4" android:layout_width="0dp" android:layout_height="wrap_content" android:layout_weight="1" android:ellipsize="end" android:maxLines="1" android:textColor="#FFFFFF" android:textSize="13sp" android:textStyle="bold"/>
                <TextView android:id="@+id/w_amt4" android:layout_width="wrap_content" android:layout_height="wrap_content" android:textColor="#FFFFFF" android:textSize="13sp" android:textStyle="bold"/>
            </LinearLayout>
            <ProgressBar android:id="@+id/w_track4" style="?android:attr/progressBarStyleHorizontal" android:layout_width="match_parent" android:layout_height="5dp" android:layout_marginTop="5dp" android:max="100" android:progress="0" android:progressDrawable="@drawable/finup_prog_mint"/>
        </LinearLayout>
    </LinearLayout>
</LinearLayout>
__END__

############################ People ############################
cat > android/app/src/main/res/layout/finup_w_people.xml <<'__END__'
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/w_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="horizontal"
    android:background="@drawable/finup_widget_bg">

    <ImageView
        android:layout_width="4dp"
        android:layout_height="match_parent"
        android:layout_margin="12dp"
        android:src="@drawable/finup_accent_pink"
        android:contentDescription="@null"/>

    <LinearLayout
        android:layout_width="0dp"
        android:layout_height="match_parent"
        android:layout_weight="1"
        android:orientation="vertical"
        android:paddingTop="12dp"
        android:paddingBottom="12dp"
        android:paddingEnd="12dp">

        <LinearLayout
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:orientation="horizontal"
            android:gravity="center_vertical">
            <TextView
                android:layout_width="0dp"
                android:layout_height="wrap_content"
                android:layout_weight="1"
                android:text="PEOPLE"
                android:textColor="#9EFFFFFF"
                android:textSize="11sp"
                android:textStyle="bold"
                android:letterSpacing="0.04"/>
            <TextView
                android:id="@+id/w_chip"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:background="@drawable/finup_chip"
                android:paddingStart="8dp"
                android:paddingEnd="8dp"
                android:paddingTop="3dp"
                android:paddingBottom="3dp"
                android:text="0 open"
                android:textColor="#EFEAFC"
                android:textSize="11sp"
                android:textStyle="bold"/>
        </LinearLayout>

        <TextView
            android:id="@+id/w_empty"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:layout_marginTop="10dp"
            android:text="All settled"
            android:textColor="#94FFFFFF"
            android:textSize="13sp"
            android:visibility="gone"/>

        <LinearLayout android:id="@+id/w_row1" android:layout_width="match_parent" android:layout_height="wrap_content" android:layout_marginTop="10dp" android:orientation="horizontal" android:gravity="center_vertical" android:visibility="gone">
            <TextView android:id="@+id/w_av1" android:layout_width="28dp" android:layout_height="28dp" android:background="@drawable/finup_avatar" android:gravity="center" android:text="?" android:textColor="#1A1420" android:textSize="12sp" android:textStyle="bold"/>
            <LinearLayout android:layout_width="0dp" android:layout_height="wrap_content" android:layout_weight="1" android:layout_marginStart="8dp" android:orientation="vertical">
                <TextView android:id="@+id/w_name1" android:layout_width="match_parent" android:layout_height="wrap_content" android:ellipsize="end" android:maxLines="1" android:textColor="#FFFFFF" android:textSize="13sp" android:textStyle="bold"/>
                <TextView android:id="@+id/w_sub1" android:layout_width="match_parent" android:layout_height="wrap_content" android:textColor="#94FFFFFF" android:textSize="11sp"/>
            </LinearLayout>
            <TextView android:id="@+id/w_amt1" android:layout_width="wrap_content" android:layout_height="wrap_content" android:textColor="#9AEBCF" android:textSize="13sp" android:textStyle="bold"/>
        </LinearLayout>
        <LinearLayout android:id="@+id/w_row2" android:layout_width="match_parent" android:layout_height="wrap_content" android:layout_marginTop="8dp" android:orientation="horizontal" android:gravity="center_vertical" android:visibility="gone">
            <TextView android:id="@+id/w_av2" android:layout_width="28dp" android:layout_height="28dp" android:background="@drawable/finup_avatar" android:gravity="center" android:text="?" android:textColor="#1A1420" android:textSize="12sp" android:textStyle="bold"/>
            <LinearLayout android:layout_width="0dp" android:layout_height="wrap_content" android:layout_weight="1" android:layout_marginStart="8dp" android:orientation="vertical">
                <TextView android:id="@+id/w_name2" android:layout_width="match_parent" android:layout_height="wrap_content" android:ellipsize="end" android:maxLines="1" android:textColor="#FFFFFF" android:textSize="13sp" android:textStyle="bold"/>
                <TextView android:id="@+id/w_sub2" android:layout_width="match_parent" android:layout_height="wrap_content" android:textColor="#94FFFFFF" android:textSize="11sp"/>
            </LinearLayout>
            <TextView android:id="@+id/w_amt2" android:layout_width="wrap_content" android:layout_height="wrap_content" android:textColor="#9AEBCF" android:textSize="13sp" android:textStyle="bold"/>
        </LinearLayout>
        <LinearLayout android:id="@+id/w_row3" android:layout_width="match_parent" android:layout_height="wrap_content" android:layout_marginTop="8dp" android:orientation="horizontal" android:gravity="center_vertical" android:visibility="gone">
            <TextView android:id="@+id/w_av3" android:layout_width="28dp" android:layout_height="28dp" android:background="@drawable/finup_avatar" android:gravity="center" android:text="?" android:textColor="#1A1420" android:textSize="12sp" android:textStyle="bold"/>
            <LinearLayout android:layout_width="0dp" android:layout_height="wrap_content" android:layout_weight="1" android:layout_marginStart="8dp" android:orientation="vertical">
                <TextView android:id="@+id/w_name3" android:layout_width="match_parent" android:layout_height="wrap_content" android:ellipsize="end" android:maxLines="1" android:textColor="#FFFFFF" android:textSize="13sp" android:textStyle="bold"/>
                <TextView android:id="@+id/w_sub3" android:layout_width="match_parent" android:layout_height="wrap_content" android:textColor="#94FFFFFF" android:textSize="11sp"/>
            </LinearLayout>
            <TextView android:id="@+id/w_amt3" android:layout_width="wrap_content" android:layout_height="wrap_content" android:textColor="#9AEBCF" android:textSize="13sp" android:textStyle="bold"/>
        </LinearLayout>
        <LinearLayout android:id="@+id/w_row4" android:layout_width="match_parent" android:layout_height="wrap_content" android:layout_marginTop="8dp" android:orientation="horizontal" android:gravity="center_vertical" android:visibility="gone">
            <TextView android:id="@+id/w_av4" android:layout_width="28dp" android:layout_height="28dp" android:background="@drawable/finup_avatar" android:gravity="center" android:text="?" android:textColor="#1A1420" android:textSize="12sp" android:textStyle="bold"/>
            <LinearLayout android:layout_width="0dp" android:layout_height="wrap_content" android:layout_weight="1" android:layout_marginStart="8dp" android:orientation="vertical">
                <TextView android:id="@+id/w_name4" android:layout_width="match_parent" android:layout_height="wrap_content" android:ellipsize="end" android:maxLines="1" android:textColor="#FFFFFF" android:textSize="13sp" android:textStyle="bold"/>
                <TextView android:id="@+id/w_sub4" android:layout_width="match_parent" android:layout_height="wrap_content" android:textColor="#94FFFFFF" android:textSize="11sp"/>
            </LinearLayout>
            <TextView android:id="@+id/w_amt4" android:layout_width="wrap_content" android:layout_height="wrap_content" android:textColor="#9AEBCF" android:textSize="13sp" android:textStyle="bold"/>
        </LinearLayout>
    </LinearLayout>
</LinearLayout>
__END__

############################ Week ############################
cat > android/app/src/main/res/layout/finup_w_week.xml <<'__END__'
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/w_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="horizontal"
    android:background="@drawable/finup_widget_bg">

    <ImageView
        android:layout_width="4dp"
        android:layout_height="match_parent"
        android:layout_margin="12dp"
        android:src="@drawable/finup_accent_coral"
        android:contentDescription="@null"/>

    <LinearLayout
        android:layout_width="0dp"
        android:layout_height="match_parent"
        android:layout_weight="1"
        android:orientation="vertical"
        android:paddingTop="12dp"
        android:paddingBottom="12dp"
        android:paddingEnd="12dp">

        <TextView
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:text="THIS WEEK"
            android:textColor="#9EFFFFFF"
            android:textSize="11sp"
            android:textStyle="bold"
            android:letterSpacing="0.04"/>

        <TextView
            android:id="@+id/w_this"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:layout_marginTop="6dp"
            android:text="₹0"
            android:textColor="#FFFFFF"
            android:textSize="28sp"
            android:textStyle="bold"/>

        <ProgressBar
            android:id="@+id/w_compare"
            style="?android:attr/progressBarStyleHorizontal"
            android:layout_width="match_parent"
            android:layout_height="6dp"
            android:layout_marginTop="8dp"
            android:max="100"
            android:progress="0"
            android:progressDrawable="@drawable/finup_prog_coral"/>

        <TextView
            android:id="@+id/w_last"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:layout_marginTop="8dp"
            android:text="Last week ₹0"
            android:textColor="#94FFFFFF"
            android:textSize="12sp"/>

        <TextView
            android:id="@+id/w_delta"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:layout_marginTop="8dp"
            android:background="@drawable/finup_chip_warn"
            android:paddingStart="10dp"
            android:paddingEnd="10dp"
            android:paddingTop="4dp"
            android:paddingBottom="4dp"
            android:text="—"
            android:textColor="#FFB5A5"
            android:textSize="11sp"
            android:textStyle="bold"/>
    </LinearLayout>
</LinearLayout>
__END__

############################ Review ############################
cat > android/app/src/main/res/layout/finup_w_review.xml <<'__END__'
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/w_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="horizontal"
    android:background="@drawable/finup_widget_bg">

    <ImageView
        android:layout_width="4dp"
        android:layout_height="match_parent"
        android:layout_margin="12dp"
        android:src="@drawable/finup_accent_mint"
        android:contentDescription="@null"/>

    <LinearLayout
        android:layout_width="0dp"
        android:layout_height="match_parent"
        android:layout_weight="1"
        android:orientation="vertical"
        android:paddingTop="12dp"
        android:paddingBottom="12dp"
        android:paddingEnd="12dp">

        <LinearLayout
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:orientation="horizontal"
            android:gravity="center_vertical">
            <TextView
                android:layout_width="0dp"
                android:layout_height="wrap_content"
                android:layout_weight="1"
                android:text="REVIEW"
                android:textColor="#9EFFFFFF"
                android:textSize="11sp"
                android:textStyle="bold"
                android:letterSpacing="0.04"/>
            <TextView
                android:id="@+id/w_chip"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:background="@drawable/finup_chip_ok"
                android:paddingStart="8dp"
                android:paddingEnd="8dp"
                android:paddingTop="3dp"
                android:paddingBottom="3dp"
                android:text="Clear"
                android:textColor="#9AEBCF"
                android:textSize="11sp"
                android:textStyle="bold"/>
        </LinearLayout>

        <LinearLayout
            android:layout_width="match_parent"
            android:layout_height="0dp"
            android:layout_weight="1"
            android:layout_marginTop="8dp"
            android:background="@drawable/finup_review_panel"
            android:gravity="center"
            android:orientation="vertical"
            android:padding="10dp">
            <TextView
                android:id="@+id/w_count"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:text="✓"
                android:textColor="#FFFFFF"
                android:textSize="28sp"
                android:textStyle="bold"/>
            <TextView
                android:id="@+id/w_sub"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:layout_marginTop="2dp"
                android:text="Inbox zero — nice."
                android:textColor="#94FFFFFF"
                android:textSize="12sp"/>
        </LinearLayout>
    </LinearLayout>
</LinearLayout>
__END__

############################ Kotlin binders ############################
# Hero chip / balance label (literal replacements only — avoid perl ${})
if [ -f android/app/src/main/kotlin/com/yash/finup/FinUpWidget.kt ]; then
  sed -i 's/All reviewed ✓/All reviewed/g' \
    android/app/src/main/kotlin/com/yash/finup/FinUpWidget.kt
  sed -i 's/Total balance \${fmt.format(balance)}/Total balance · ${fmt.format(balance)}/g' \
    android/app/src/main/kotlin/com/yash/finup/FinUpWidget.kt
fi

# Budget chip
if [ -f android/app/src/main/kotlin/com/yash/finup/BudgetPulseWidget.kt ]; then
  python3 - <<'PY'
from pathlib import Path
p = Path("android/app/src/main/kotlin/com/yash/finup/BudgetPulseWidget.kt")
s = p.read_text()
old = """            if (rows.isEmpty()) {
                FinUpWidgets.setVisible(v, R.id.w_empty)
            } else {
                FinUpWidgets.setGone(v, R.id.w_empty)
"""
new = """            if (rows.isEmpty()) {
                FinUpWidgets.setVisible(v, R.id.w_empty)
                v.setTextViewText(R.id.w_chip, "Empty")
            } else {
                FinUpWidgets.setGone(v, R.id.w_empty)
                v.setTextViewText(R.id.w_chip, "${rows.size} live")
"""
if old not in s:
    raise SystemExit("BudgetPulseWidget empty-branch patch failed")
p.write_text(s.replace(old, new, 1))
print("BudgetPulseWidget chip patched")
PY
fi

# Accounts share tracks
cat > android/app/src/main/kotlin/com/yash/finup/AccountsWidget.kt <<'__END__'
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
__END__

# People avatars + colors
cat > android/app/src/main/kotlin/com/yash/finup/PeopleBalanceWidget.kt <<'__END__'
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
__END__

# Week compare bar + chip colors via text only
cat > android/app/src/main/kotlin/com/yash/finup/WeekCompareWidget.kt <<'__END__'
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
__END__

# Review chip
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
__END__

############################ Checks ############################
for file in \
  android/app/src/main/res/drawable/finup_widget_btn_primary.xml \
  android/app/src/main/res/drawable/finup_prog_gold.xml \
  android/app/src/main/res/drawable/finup_brand_mark.xml \
  android/app/src/main/res/layout/finup_widget.xml \
  android/app/src/main/res/layout/finup_w_budget.xml \
  android/app/src/main/res/layout/finup_w_accounts.xml \
  android/app/src/main/res/layout/finup_w_people.xml \
  android/app/src/main/res/layout/finup_w_week.xml \
  android/app/src/main/res/layout/finup_w_review.xml \
  android/app/src/main/kotlin/com/yash/finup/AccountsWidget.kt \
  android/app/src/main/kotlin/com/yash/finup/PeopleBalanceWidget.kt \
  android/app/src/main/kotlin/com/yash/finup/WeekCompareWidget.kt \
  android/app/src/main/kotlin/com/yash/finup/ReviewInboxWidget.kt
do
  if [ ! -f "$file" ]; then
    echo "ERROR: finup9 missing $file"
    exit 1
  fi
done
for check in \
  "w_chip|android/app/src/main/res/layout/finup_w_budget.xml" \
  "w_track1|android/app/src/main/res/layout/finup_w_accounts.xml" \
  "w_av1|android/app/src/main/res/layout/finup_w_people.xml" \
  "w_compare|android/app/src/main/res/layout/finup_w_week.xml" \
  "Inbox zero|android/app/src/main/kotlin/com/yash/finup/ReviewInboxWidget.kt" \
  "w_track1|android/app/src/main/kotlin/com/yash/finup/AccountsWidget.kt" \
  "w_av1|android/app/src/main/kotlin/com/yash/finup/PeopleBalanceWidget.kt" \
  "finup_widget_btn_primary|android/app/src/main/res/layout/finup_widget.xml"
do
  pat="${check%%|*}"; file="${check#*|}"
  if ! grep -qF "$pat" "$file"; then
    echo "ERROR: finup9 failed in $file ($pat)"
    exit 1
  fi
done

echo "FinUp Part 9 (finup9.sh) applied — widget visual refresh."
