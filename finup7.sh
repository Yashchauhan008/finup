#!/usr/bin/env bash
set -euo pipefail
cd app
mkdir -p lib/actions lib/data lib/screens post_create \
  android/app/src/main/kotlin/com/yash/finup \
  android/app/src/main/res/layout android/app/src/main/res/xml \
  android/app/src/main/res/drawable android/app/src/main/res/values

############################ pubspec: camera/gallery + app folder ############################
if ! grep -q "image_picker:" pubspec.yaml; then
  sed -i "s#  crypto: ^3.0.3#  crypto: ^3.0.3\n  image_picker: ^1.1.2\n  path_provider: ^2.1.4#" pubspec.yaml
fi
grep -q "image_picker:" pubspec.yaml || { echo "ERROR: pubspec patch failed"; exit 1; }

############################ Post-create hook: on-device text recognition (ML Kit) ############################
cat > post_create/10_mlkit.sh <<'__END__'
#!/usr/bin/env bash
set -e
if [ -f android/app/build.gradle.kts ]; then
  if ! grep -q "text-recognition" android/app/build.gradle.kts; then
    printf '\ndependencies {\n    implementation("com.google.mlkit:text-recognition:16.0.0")\n}\n' >> android/app/build.gradle.kts
  fi
elif [ -f android/app/build.gradle ]; then
  if ! grep -q "text-recognition" android/app/build.gradle; then
    printf "\ndependencies {\n    implementation 'com.google.mlkit:text-recognition:16.0.0'\n}\n" >> android/app/build.gradle
  fi
fi
echo "ML Kit text recognition added."
__END__
cat >> branding/make_icons.sh <<'__END__'

# Run post-create hooks (gradle tweaks etc.)
for f in post_create/*.sh; do
  if [ -f "$f" ]; then bash "$f"; fi
done
__END__

############################ Android resources: widget + shortcuts ############################
cat > android/app/src/main/res/values/finup_strings.xml <<'__END__'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="finup_widget_desc">Today\'s spending, review count and quick add</string>
    <string name="sc_add_short">Add expense</string>
    <string name="sc_add_long">Add an expense</string>
    <string name="sc_voice_short">Voice entry</string>
    <string name="sc_voice_long">Add by voice</string>
    <string name="sc_scan_short">Scan receipt</string>
    <string name="sc_scan_long">Scan a receipt</string>
    <string name="sc_review_short">Review</string>
    <string name="sc_review_long">Review transactions</string>
</resources>
__END__

cat > android/app/src/main/res/drawable/finup_widget_bg.xml <<'__END__'
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <gradient android:startColor="#2D2A6E" android:endColor="#5B57C9" android:angle="315"/>
    <corners android:radius="24dp"/>
</shape>
__END__

cat > android/app/src/main/res/drawable/finup_widget_btn.xml <<'__END__'
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="#29FFFFFF"/>
    <corners android:radius="14dp"/>
</shape>
__END__

cat > android/app/src/main/res/layout/finup_widget.xml <<'__END__'
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/w_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical"
    android:padding="14dp"
    android:background="@drawable/finup_widget_bg">

    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:orientation="horizontal"
        android:gravity="center_vertical">
        <ImageView
            android:layout_width="26dp"
            android:layout_height="26dp"
            android:src="@mipmap/ic_launcher"
            android:contentDescription="FinUp"/>
        <TextView
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:layout_marginStart="8dp"
            android:text="Spent today"
            android:textColor="#B3FFFFFF"
            android:textSize="13sp"/>
        <TextView
            android:id="@+id/w_review"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:background="@drawable/finup_widget_btn"
            android:paddingStart="10dp"
            android:paddingEnd="10dp"
            android:paddingTop="4dp"
            android:paddingBottom="4dp"
            android:text="Review"
            android:textColor="#EBB9D6"
            android:textSize="12sp"
            android:textStyle="bold"/>
    </LinearLayout>

    <TextView
        android:id="@+id/w_spent"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:layout_marginTop="6dp"
        android:text="₹0"
        android:textColor="#FFFFFF"
        android:textSize="26sp"
        android:textStyle="bold"/>

    <TextView
        android:id="@+id/w_balance"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="Balance"
        android:textColor="#99FFFFFF"
        android:textSize="12sp"/>

    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="10dp"
        android:orientation="horizontal">
        <TextView
            android:id="@+id/w_add"
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:background="@drawable/finup_widget_btn"
            android:gravity="center"
            android:padding="8dp"
            android:text="+ Expense"
            android:textColor="#FFFFFF"
            android:textSize="13sp"
            android:textStyle="bold"/>
        <TextView
            android:id="@+id/w_voice"
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:layout_marginStart="6dp"
            android:background="@drawable/finup_widget_btn"
            android:gravity="center"
            android:padding="8dp"
            android:text="🎙 Voice"
            android:textColor="#FFFFFF"
            android:textSize="13sp"
            android:textStyle="bold"/>
        <TextView
            android:id="@+id/w_scan"
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:layout_marginStart="6dp"
            android:background="@drawable/finup_widget_btn"
            android:gravity="center"
            android:padding="8dp"
            android:text="📷 Scan"
            android:textColor="#FFFFFF"
            android:textSize="13sp"
            android:textStyle="bold"/>
    </LinearLayout>
</LinearLayout>
__END__

cat > android/app/src/main/res/xml/finup_widget_info.xml <<'__END__'
<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:minWidth="250dp"
    android:minHeight="110dp"
    android:targetCellWidth="4"
    android:targetCellHeight="2"
    android:updatePeriodMillis="1800000"
    android:initialLayout="@layout/finup_widget"
    android:resizeMode="horizontal|vertical"
    android:widgetCategory="home_screen"
    android:description="@string/finup_widget_desc"/>
__END__

for spec in "sc_add:M19,13h-6v6h-2v-6H5v-2h6V5h2v6h6v2z" \
            "sc_voice:M12,14c1.66,0 2.99,-1.34 2.99,-3L15,5c0,-1.66 -1.34,-3 -3,-3S9,3.34 9,5v6c0,1.66 1.34,3 3,3zM17.3,11c0,3 -2.54,5.1 -5.3,5.1S6.7,14 6.7,11L5,11c0,3.41 2.72,6.23 6,6.72L11,21h2v-3.28c3.28,-0.48 6,-3.3 6,-6.72h-1.7z" \
            "sc_scan:M9,2L7.17,4L4,4c-1.1,0 -2,0.9 -2,2v12c0,1.1 0.9,2 2,2h16c1.1,0 2,-0.9 2,-2L22,6c0,-1.1 -0.9,-2 -2,-2h-3.17L15,2L9,2zM12,17c-2.76,0 -5,-2.24 -5,-5s2.24,-5 5,-5 5,2.24 5,5 -2.24,5 -5,5z" \
            "sc_review:M19,3H4.99c-1.11,0 -1.98,0.89 -1.98,2L3,19c0,1.1 0.88,2 1.99,2H19c1.1,0 2,-0.9 2,-2V5c0,-1.11 -0.9,-2 -2,-2zM19,15h-4c0,1.66 -1.35,3 -3,3s-3,-1.34 -3,-3H4.99V5H19v10z"; do
  name="${spec%%:*}"; path="${spec#*:}"
  cat > "android/app/src/main/res/drawable/${name}.xml" <<XML
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="48dp" android:height="48dp"
    android:viewportWidth="48" android:viewportHeight="48">
    <path android:fillColor="#2D2A6E" android:pathData="M0,24a24,24 0,1 0,48 0a24,24 0,1 0,-48 0"/>
    <group android:translateX="12" android:translateY="12">
        <path android:fillColor="#EBB9D6" android:pathData="${path}"/>
    </group>
</vector>
XML
done

cat > android/app/src/main/res/xml/shortcuts.xml <<'__END__'
<?xml version="1.0" encoding="utf-8"?>
<shortcuts xmlns:android="http://schemas.android.com/apk/res/android">
    <shortcut android:shortcutId="add_expense" android:enabled="true" android:icon="@drawable/sc_add"
        android:shortcutShortLabel="@string/sc_add_short" android:shortcutLongLabel="@string/sc_add_long">
        <intent android:action="finup.add_expense" android:targetPackage="com.yash.finup"
            android:targetClass="com.yash.finup.MainActivity">
            <extra android:name="finup_action" android:value="add_expense"/>
        </intent>
    </shortcut>
    <shortcut android:shortcutId="voice" android:enabled="true" android:icon="@drawable/sc_voice"
        android:shortcutShortLabel="@string/sc_voice_short" android:shortcutLongLabel="@string/sc_voice_long">
        <intent android:action="finup.voice" android:targetPackage="com.yash.finup"
            android:targetClass="com.yash.finup.MainActivity">
            <extra android:name="finup_action" android:value="voice"/>
        </intent>
    </shortcut>
    <shortcut android:shortcutId="scan" android:enabled="true" android:icon="@drawable/sc_scan"
        android:shortcutShortLabel="@string/sc_scan_short" android:shortcutLongLabel="@string/sc_scan_long">
        <intent android:action="finup.scan" android:targetPackage="com.yash.finup"
            android:targetClass="com.yash.finup.MainActivity">
            <extra android:name="finup_action" android:value="scan"/>
        </intent>
    </shortcut>
    <shortcut android:shortcutId="review" android:enabled="true" android:icon="@drawable/sc_review"
        android:shortcutShortLabel="@string/sc_review_short" android:shortcutLongLabel="@string/sc_review_long">
        <intent android:action="finup.review" android:targetPackage="com.yash.finup"
            android:targetClass="com.yash.finup.MainActivity">
            <extra android:name="finup_action" android:value="review"/>
        </intent>
    </shortcut>
</shortcuts>
__END__

############################ ANDROID MANIFEST (complete) ############################
cat > android/app/src/main/AndroidManifest.xml <<'__END__'
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.READ_SMS"/>
    <uses-permission android:name="android.permission.RECEIVE_SMS"/>
    <uses-permission android:name="android.permission.USE_BIOMETRIC"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" android:maxSdkVersion="32"/>
    <uses-permission android:name="android.permission.USE_EXACT_ALARM" tools:ignore="ExactAlarm,ProtectedPermissions"/>

    <queries>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT"/>
            <data android:mimeType="text/plain"/>
        </intent>
        <intent>
            <action android:name="android.speech.action.RECOGNIZE_SPEECH"/>
        </intent>
        <intent>
            <action android:name="android.media.action.IMAGE_CAPTURE"/>
        </intent>
    </queries>

    <application
        android:label="FinUp"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:taskAffinity=""
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <meta-data
                android:name="io.flutter.embedding.android.NormalTheme"
                android:resource="@style/NormalTheme" />
            <meta-data
                android:name="android.app.shortcuts"
                android:resource="@xml/shortcuts" />
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        <receiver android:name=".ReminderReceiver" android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
            </intent-filter>
        </receiver>
        <receiver
            android:name=".SmsReceiver"
            android:exported="true"
            android:permission="android.permission.BROADCAST_SMS">
            <intent-filter>
                <action android:name="android.provider.Telephony.SMS_RECEIVED"/>
            </intent-filter>
        </receiver>
        <receiver android:name=".NotifActionReceiver" android:exported="false"/>
        <receiver android:name=".FinUpWidget" android:exported="false">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE"/>
            </intent-filter>
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="@xml/finup_widget_info"/>
        </receiver>
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
</manifest>
__END__

############################ KOTLIN: home screen widget ############################
cat > android/app/src/main/kotlin/com/yash/finup/FinUpWidget.kt <<'__END__'
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
            try {
                val m = AppWidgetManager.getInstance(ctx)
                val ids = m.getAppWidgetIds(ComponentName(ctx, FinUpWidget::class.java))
                if (ids.isEmpty()) return
                val views = build(ctx)
                for (id in ids) m.updateAppWidget(id, views)
            } catch (e: Exception) {
            }
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
            v.setTextViewText(R.id.w_balance, if (hide) "Balance hidden" else "Total balance ${fmt.format(balance)}")
            v.setTextViewText(R.id.w_review, if (review == 0) "All reviewed ✓" else "$review to review")
            v.setOnClickPendingIntent(R.id.w_root, action(ctx, "open", 801))
            v.setOnClickPendingIntent(R.id.w_add, action(ctx, "add_expense", 802))
            v.setOnClickPendingIntent(R.id.w_voice, action(ctx, "voice", 803))
            v.setOnClickPendingIntent(R.id.w_scan, action(ctx, "scan", 804))
            v.setOnClickPendingIntent(R.id.w_review, action(ctx, "review", 805))
            return v
        }
    }
}
__END__

############################ KOTLIN: MainActivity.kt (complete) ############################
cat > android/app/src/main/kotlin/com/yash/finup/MainActivity.kt <<'__END__'
package com.yash.finup

import android.Manifest
import android.app.Activity
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.hardware.biometrics.BiometricManager
import android.hardware.biometrics.BiometricPrompt
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.CancellationSignal
import android.os.PowerManager
import android.provider.MediaStore
import android.provider.Settings
import android.speech.RecognizerIntent
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "finup/native"
    private val permRequestCode = 4242
    private val createDocCode = 5151
    private val openDocCode = 5252
    private val voiceCode = 5353
    private var channel: MethodChannel? = null
    private var pendingResult: MethodChannel.Result? = null
    private var pendingDocResult: MethodChannel.Result? = null
    private var pendingVoice: MethodChannel.Result? = null
    private var pendingBytes: ByteArray? = null
    private var pendingAction: String? = null
    private val moneyRegex = Regex("(?i)(rs\\.?|inr|₹)\\s*[0-9]")

    override fun onCreate(savedInstanceState: Bundle?) {
        captureAction(intent)
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureAction(intent)
    }

    private fun captureAction(i: Intent?) {
        if (i == null) return
        val a = i.getStringExtra("finup_action") ?: return
        pendingAction = a
        i.removeExtra("finup_action")
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        channel = ch
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "takeLaunchAction" -> {
                    result.success(pendingAction)
                    pendingAction = null
                }
                "refreshWidget" -> {
                    FinUpWidget.updateAll(this)
                    result.success(true)
                }
                "voice" -> {
                    pendingVoice?.success("")
                    pendingVoice = result
                    val i = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
                    i.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                    i.putExtra(RecognizerIntent.EXTRA_LANGUAGE, "en-IN")
                    i.putExtra(RecognizerIntent.EXTRA_PROMPT, call.argument<String>("prompt") ?: "Say: Spent 250 on petrol")
                    try {
                        startActivityForResult(i, voiceCode)
                    } catch (e: Exception) {
                        pendingVoice = null
                        result.success("__unavailable__")
                    }
                }
                "ocr" -> {
                    val path = call.argument<String>("path") ?: ""
                    try {
                        val image = InputImage.fromFilePath(this, Uri.fromFile(File(path)))
                        TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
                            .process(image)
                            .addOnSuccessListener { r -> result.success(r.text) }
                            .addOnFailureListener { _ -> result.success(null) }
                    } catch (e: Exception) {
                        result.success(null)
                    }
                }
                "hasSmsPermission" -> result.success(hasPermission(Manifest.permission.READ_SMS))
                "requestSmsPermission" -> askPermissions(arrayOf(Manifest.permission.READ_SMS, Manifest.permission.RECEIVE_SMS), result)
                "ensureSmsReceive" -> {
                    if (hasPermission(Manifest.permission.READ_SMS) && !hasPermission(Manifest.permission.RECEIVE_SMS)) {
                        askPermissions(arrayOf(Manifest.permission.RECEIVE_SMS), result)
                    } else {
                        result.success(hasPermission(Manifest.permission.RECEIVE_SMS))
                    }
                }
                "requestNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= 33) {
                        askPermissions(arrayOf("android.permission.POST_NOTIFICATIONS"), result)
                    } else {
                        result.success(true)
                    }
                }
                "openAppSettings" -> {
                    val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    result.success(true)
                }
                "readSms" -> {
                    val since = (call.argument<Number>("since") ?: 0).toLong()
                    Thread {
                        val list: List<Map<String, Any?>>? = try { readSms(since) } catch (e: Exception) { null }
                        runOnUiThread {
                            if (list == null) result.error("READ_FAILED", "Could not read SMS", null)
                            else result.success(list)
                        }
                    }.start()
                }
                "scheduleReminder" -> {
                    val hour = call.argument<Int>("hour") ?: 21
                    val minute = call.argument<Int>("minute") ?: 0
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    Reminder.save(this, hour, minute, enabled)
                    Reminder.schedule(this)
                    result.success(true)
                }
                "getSmsAlerts" -> result.success(AlertPrefs.smsAlerts(this))
                "setSmsAlerts" -> {
                    AlertPrefs.setSmsAlerts(this, call.argument<Boolean>("on") ?: true)
                    result.success(true)
                }
                "notify" -> {
                    val id = call.argument<Int>("id") ?: 9999
                    Notifier.simple(this, Notifier.CH_ALERT, id, call.argument<String>("title") ?: "FinUp", call.argument<String>("body") ?: "")
                    result.success(true)
                }
                "pendingCategories" -> result.success(Pending.all(this))
                "clearPending" -> {
                    Pending.remove(this, call.argument<List<String>>("keys") ?: emptyList())
                    result.success(true)
                }
                "appInfo" -> {
                    val info = packageManager.getPackageInfo(packageName, 0)
                    val code = if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong()
                    result.success(mapOf("name" to (info.versionName ?: ""), "code" to code))
                }
                "openUrl" -> {
                    try {
                        val i = Intent(Intent.ACTION_VIEW, Uri.parse(call.argument<String>("url") ?: "https://yashchauhan.pro"))
                        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(i)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "batteryOptimized" -> {
                    if (Build.VERSION.SDK_INT >= 23) {
                        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                        result.success(!pm.isIgnoringBatteryOptimizations(packageName))
                    } else {
                        result.success(false)
                    }
                }
                "openBatterySettings" -> {
                    // Open the system list only — do not request the privileged
                    // REQUEST_IGNORE_BATTERY_OPTIMIZATIONS permission (Play Protect signal).
                    if (Build.VERSION.SDK_INT >= 23) {
                        try {
                            startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                        } catch (e: Exception) {
                            try {
                                val i = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
                                i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                startActivity(i)
                            } catch (x: Exception) {}
                        }
                    }
                    result.success(true)
                }
                "canBiometric" -> result.success(canBiometric())
                "authenticate" -> authenticate(call.argument<String>("reason") ?: "Unlock FinUp", result)
                "saveDocument" -> {
                    val name = call.argument<String>("name") ?: "finup.txt"
                    val mime = call.argument<String>("mime") ?: "application/octet-stream"
                    val bytes = call.argument<ByteArray>("bytes")
                    if (bytes == null) {
                        result.success(false)
                    } else {
                        pendingDocResult?.success(null)
                        pendingDocResult = result
                        pendingBytes = bytes
                        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT)
                        intent.addCategory(Intent.CATEGORY_OPENABLE)
                        intent.type = mime
                        intent.putExtra(Intent.EXTRA_TITLE, name)
                        startActivityForResult(intent, createDocCode)
                    }
                }
                "openDocument" -> {
                    pendingDocResult?.success(null)
                    pendingDocResult = result
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT)
                    intent.addCategory(Intent.CATEGORY_OPENABLE)
                    intent.type = "*/*"
                    startActivityForResult(intent, openDocCode)
                }
                "shareImage" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    val name = call.argument<String>("name") ?: "finup.png"
                    val text = call.argument<String>("text") ?: ""
                    result.success(shareImage(bytes, name, text))
                }
                "shareText" -> {
                    shareText(call.argument<String>("text") ?: "")
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun hasPermission(p: String): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        return checkSelfPermission(p) == PackageManager.PERMISSION_GRANTED
    }

    private fun askPermissions(perms: Array<String>, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) { result.success(true); return }
        if (perms.all { hasPermission(it) }) { result.success(true); return }
        pendingResult?.success(false)
        pendingResult = result
        requestPermissions(perms, permRequestCode)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == permRequestCode) {
            val ok = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingResult?.success(ok)
            pendingResult = null
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            voiceCode -> {
                val res = pendingVoice
                pendingVoice = null
                val list = data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
                res?.success(if (resultCode == Activity.RESULT_OK) (list?.firstOrNull() ?: "") else "")
            }
            createDocCode -> {
                val res = pendingDocResult
                pendingDocResult = null
                val bytes = pendingBytes
                pendingBytes = null
                val uri = data?.data
                if (resultCode != Activity.RESULT_OK || uri == null || bytes == null) {
                    res?.success(false)
                    return
                }
                try {
                    contentResolver.openOutputStream(uri)?.use { it.write(bytes) }
                    res?.success(true)
                } catch (e: Exception) {
                    res?.success(false)
                }
            }
            openDocCode -> {
                val res = pendingDocResult
                pendingDocResult = null
                val uri = data?.data
                if (resultCode != Activity.RESULT_OK || uri == null) {
                    res?.success(null)
                    return
                }
                try {
                    val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
                    res?.success(bytes)
                } catch (e: Exception) {
                    res?.success(null)
                }
            }
        }
    }

    private fun canBiometric(): Boolean {
        if (Build.VERSION.SDK_INT >= 29) {
            val bm = getSystemService(BiometricManager::class.java) ?: return false
            return bm.canAuthenticate() == BiometricManager.BIOMETRIC_SUCCESS
        }
        if (Build.VERSION.SDK_INT >= 28) {
            return packageManager.hasSystemFeature(PackageManager.FEATURE_FINGERPRINT)
        }
        return false
    }

    private fun authenticate(reason: String, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 28) { result.success(false); return }
        var replied = false
        fun reply(v: Boolean) {
            if (!replied) { replied = true; result.success(v) }
        }
        val executor = mainExecutor
        val prompt = BiometricPrompt.Builder(this)
            .setTitle("Unlock FinUp")
            .setSubtitle(reason)
            .setNegativeButton("Use PIN", executor) { _, _ -> reply(false) }
            .build()
        prompt.authenticate(CancellationSignal(), executor, object : BiometricPrompt.AuthenticationCallback() {
            override fun onAuthenticationSucceeded(r: BiometricPrompt.AuthenticationResult?) { reply(true) }
            override fun onAuthenticationError(errorCode: Int, errString: CharSequence?) { reply(false) }
        })
    }

    private fun shareImage(bytes: ByteArray?, name: String, text: String): Boolean {
        if (bytes == null) return false
        if (Build.VERSION.SDK_INT < 29) { shareText(text); return true }
        return try {
            val values = ContentValues()
            values.put(MediaStore.Images.Media.DISPLAY_NAME, name)
            values.put(MediaStore.Images.Media.MIME_TYPE, "image/png")
            values.put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/FinUp")
            val uri = contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values) ?: return false
            contentResolver.openOutputStream(uri)?.use { it.write(bytes) }
            val send = Intent(Intent.ACTION_SEND)
            send.type = "image/png"
            send.putExtra(Intent.EXTRA_STREAM, uri)
            send.putExtra(Intent.EXTRA_TEXT, text)
            send.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            startActivity(Intent.createChooser(send, "Share statement"))
            true
        } catch (e: Exception) {
            shareText(text)
            true
        }
    }

    private fun shareText(text: String) {
        val send = Intent(Intent.ACTION_SEND)
        send.type = "text/plain"
        send.putExtra(Intent.EXTRA_TEXT, text)
        startActivity(Intent.createChooser(send, "Share"))
    }

    private fun readSms(since: Long): List<Map<String, Any?>> {
        val out = ArrayList<Map<String, Any?>>()
        if (!hasPermission(Manifest.permission.READ_SMS)) return out
        val cursor = contentResolver.query(
            Uri.parse("content://sms/inbox"),
            arrayOf("_id", "address", "body", "date"),
            "date > ?", arrayOf(since.toString()), "date ASC"
        ) ?: return out
        cursor.use { c ->
            val iId = c.getColumnIndex("_id")
            val iAddr = c.getColumnIndex("address")
            val iBody = c.getColumnIndex("body")
            val iDate = c.getColumnIndex("date")
            while (c.moveToNext()) {
                val body = c.getString(iBody) ?: ""
                if (!moneyRegex.containsMatchIn(body)) continue
                out.add(mapOf(
                    "id" to c.getLong(iId).toString(),
                    "address" to (c.getString(iAddr) ?: ""),
                    "body" to body,
                    "date" to c.getLong(iDate)
                ))
            }
        }
        return out
    }
}
__END__

############################ lib/native.dart (complete) ############################
cat > lib/native.dart <<'__END__'
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RawSms {
  final String id;
  final String address;
  final String body;
  final int date;
  const RawSms(this.id, this.address, this.body, this.date);
}

class Native {
  static const _ch = MethodChannel('finup/native');

  static void init() {
    // Native → Dart callbacks reserved for future use.
  }

  static Future<bool> _bool(String method, [Map<String, Object?>? args]) async {
    try {
      return await _ch.invokeMethod<bool>(method, args) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> _str(String method, [Map<String, Object?>? args]) async {
    try {
      return await _ch.invokeMethod<String>(method, args);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> hasSms() => _bool('hasSmsPermission');
  static Future<bool> requestSms() => _bool('requestSmsPermission');
  static Future<bool> ensureSmsReceive() => _bool('ensureSmsReceive');
  static Future<bool> requestNotifications() => _bool('requestNotificationPermission');
  static Future<bool> openSettings() => _bool('openAppSettings');
  static Future<bool> canBiometric() => _bool('canBiometric');
  static Future<bool> authenticate(String reason) => _bool('authenticate', {'reason': reason});
  static Future<bool> saveDocument(String name, String mime, Uint8List bytes) =>
      _bool('saveDocument', {'name': name, 'mime': mime, 'bytes': bytes});
  static Future<bool> shareImage(Uint8List bytes, String name, String text) =>
      _bool('shareImage', {'bytes': bytes, 'name': name, 'text': text});
  static Future<bool> shareText(String text) => _bool('shareText', {'text': text});
  static Future<bool> getSmsAlerts() => _bool('getSmsAlerts');
  static Future<bool> setSmsAlerts(bool v) => _bool('setSmsAlerts', {'on': v});
  static Future<bool> notify(String title, String body, {int id = 9999}) =>
      _bool('notify', {'title': title, 'body': body, 'id': id});
  static Future<bool> openUrl(String url) => _bool('openUrl', {'url': url});
  static Future<bool> batteryOptimized() => _bool('batteryOptimized');
  static Future<bool> openBatterySettings() => _bool('openBatterySettings');
  static Future<bool> refreshWidget() => _bool('refreshWidget');

  /// Returns the spoken text, "" if cancelled, or "__unavailable__" if no speech service.
  static Future<String?> voice(String prompt) => _str('voice', {'prompt': prompt});
  static Future<String?> ocr(String path) => _str('ocr', {'path': path});
  static Future<String?> takeLaunchAction() => _str('takeLaunchAction');

  static Future<Uint8List?> openDocument() async {
    try {
      return await _ch.invokeMethod<Uint8List>('openDocument');
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, int>> pendingCategories() async {
    try {
      final m = await _ch.invokeMethod<Map<dynamic, dynamic>>('pendingCategories');
      if (m == null) return {};
      return m.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  static Future<void> clearPendingCategories(List<String> keys) async {
    try {
      await _ch.invokeMethod('clearPending', {'keys': keys});
    } catch (_) {}
  }

  static Future<(String, int)> appInfo() async {
    try {
      final m = await _ch.invokeMethod<Map<dynamic, dynamic>>('appInfo');
      return ((m?['name'] ?? '').toString(), (m?['code'] as num?)?.toInt() ?? 0);
    } catch (_) {
      return ('', 0);
    }
  }

  static Future<List<RawSms>> readSms(int sinceMs) async {
    final raw = await _ch.invokeMethod<List<dynamic>>('readSms', {'since': sinceMs});
    if (raw == null) return [];
    return raw.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return RawSms('${m['id']}', '${m['address'] ?? ''}', '${m['body'] ?? ''}',
          (m['date'] as num).toInt());
    }).toList();
  }

  static Future<void> scheduleReminder(int hour, int minute, bool enabled) async {
    try {
      await _ch.invokeMethod('scheduleReminder', {'hour': hour, 'minute': minute, 'enabled': enabled});
    } catch (_) {}
  }
}

class ReminderPrefs {
  static Future<bool> isOn() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool('remOn') ?? true;
  }

  static Future<void> setOn(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('remOn', v);
  }
}
__END__

############################ lib/data/tags_repo.dart ############################
cat > lib/data/tags_repo.dart <<'__END__'
import 'package:sqflite/sqflite.dart';

import 'db.dart';

class Tag {
  final int id;
  final String name;
  final int color;
  final bool isTrip;
  final DateTime? start;
  final DateTime? end;
  final double? budget;
  final bool autoTag;
  final bool archived;

  const Tag({
    required this.id,
    required this.name,
    required this.color,
    this.isTrip = false,
    this.start,
    this.end,
    this.budget,
    this.autoTag = false,
    this.archived = false,
  });

  factory Tag.fromMap(Map<String, Object?> m) => Tag(
        id: m['id'] as int,
        name: m['name'] as String,
        color: (m['color'] as int?) ?? 0xFF8E8BEA,
        isTrip: (m['is_trip'] as int? ?? 0) == 1,
        start: m['start_at'] == null ? null : DateTime.fromMillisecondsSinceEpoch(m['start_at'] as int),
        end: m['end_at'] == null ? null : DateTime.fromMillisecondsSinceEpoch(m['end_at'] as int),
        budget: (m['budget'] as num?)?.toDouble(),
        autoTag: (m['auto_tag'] as int? ?? 0) == 1,
        archived: (m['archived'] as int? ?? 0) == 1,
      );

  bool get isActive {
    if (!isTrip || start == null || end == null) return false;
    final now = DateTime.now();
    return !now.isBefore(start!) && now.isBefore(end!.add(const Duration(days: 1)));
  }
}

extension Tags on AppDatabase {
  Future<void> ensureTagSchema() async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tags(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        color INTEGER NOT NULL DEFAULT 0,
        is_trip INTEGER NOT NULL DEFAULT 0,
        start_at INTEGER,
        end_at INTEGER,
        budget REAL,
        auto_tag INTEGER NOT NULL DEFAULT 0,
        archived INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS txn_tags(
        txn_id INTEGER NOT NULL,
        tag_id INTEGER NOT NULL,
        PRIMARY KEY(txn_id, tag_id)
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS receipts(
        txn_id INTEGER PRIMARY KEY,
        path TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )''');
  }

  Future<List<Tag>> tags() async {
    final rows = await db.query('tags', orderBy: 'is_trip DESC, id DESC');
    return rows.map(Tag.fromMap).toList();
  }

  Future<Tag?> tagById(int id) async {
    final r = await db.query('tags', where: 'id = ?', whereArgs: [id]);
    return r.isEmpty ? null : Tag.fromMap(r.first);
  }

  Future<int> insertTag({
    required String name,
    required int color,
    bool isTrip = false,
    DateTime? start,
    DateTime? end,
    double? budget,
    bool autoTag = false,
  }) {
    return db.insert('tags', {
      'name': name,
      'color': color,
      'is_trip': isTrip ? 1 : 0,
      'start_at': start?.millisecondsSinceEpoch,
      'end_at': end?.millisecondsSinceEpoch,
      'budget': budget,
      'auto_tag': autoTag ? 1 : 0,
      'archived': 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> updateTag(int id,
      {required String name,
      required int color,
      DateTime? start,
      DateTime? end,
      double? budget,
      bool autoTag = false,
      bool archived = false}) async {
    await db.update(
        'tags',
        {
          'name': name,
          'color': color,
          'start_at': start?.millisecondsSinceEpoch,
          'end_at': end?.millisecondsSinceEpoch,
          'budget': budget,
          'auto_tag': autoTag ? 1 : 0,
          'archived': archived ? 1 : 0,
        },
        where: 'id = ?',
        whereArgs: [id]);
  }

  Future<void> deleteTag(int id) async {
    await db.delete('txn_tags', where: 'tag_id = ?', whereArgs: [id]);
    await db.delete('tags', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<int>> tagsOf(int txnId) async {
    final r = await db.query('txn_tags', columns: ['tag_id'], where: 'txn_id = ?', whereArgs: [txnId]);
    return r.map((e) => e['tag_id'] as int).toList();
  }

  Future<void> setTxnTags(int txnId, List<int> tagIds) async {
    await db.delete('txn_tags', where: 'txn_id = ?', whereArgs: [txnId]);
    for (final t in tagIds) {
      await db.insert('txn_tags', {'txn_id': txnId, 'tag_id': t},
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<List<Txn>> txnsForTag(int tagId) async {
    final rows = await db.rawQuery(
        'SELECT t.* FROM transactions t JOIN txn_tags tt ON tt.txn_id = t.id '
        'WHERE tt.tag_id = ? ORDER BY t.occurred_at DESC',
        [tagId]);
    return rows.map(Txn.fromMap).toList();
  }

  Future<Map<int, (double, int)>> tagSummaries() async {
    final rows = await db.rawQuery(
        "SELECT tt.tag_id AS tag_id, "
        "COALESCE(SUM(CASE WHEN t.type = 'expense' AND t.person_id IS NULL THEN t.amount ELSE 0 END), 0) AS spent, "
        "COUNT(*) AS n FROM txn_tags tt JOIN transactions t ON t.id = tt.txn_id GROUP BY tt.tag_id");
    final m = <int, (double, int)>{};
    for (final r in rows) {
      m[r['tag_id'] as int] = ((r['spent'] as num).toDouble(), (r['n'] as num).toInt());
    }
    return m;
  }

  Future<Tag?> activeTrip() async {
    for (final t in await tags()) {
      if (t.isTrip && t.autoTag && !t.archived && t.isActive) return t;
    }
    return null;
  }

  Future<void> autoTagTrips() async {
    for (final t in await tags()) {
      if (!t.isTrip || !t.autoTag || t.archived || t.start == null || t.end == null) continue;
      final from = t.start!.millisecondsSinceEpoch;
      final to = t.end!.add(const Duration(days: 1)).millisecondsSinceEpoch;
      await db.rawInsert(
          "INSERT OR IGNORE INTO txn_tags(txn_id, tag_id) "
          "SELECT id, ? FROM transactions WHERE occurred_at >= ? AND occurred_at < ? AND type != 'transfer'",
          [t.id, from, to]);
    }
  }

  Future<int?> lastTxnId() async {
    return Sqflite.firstIntValue(await db.rawQuery('SELECT MAX(id) FROM transactions'));
  }

  Future<String?> receiptOf(int txnId) async {
    final r = await db.query('receipts', where: 'txn_id = ?', whereArgs: [txnId]);
    return r.isEmpty ? null : r.first['path'] as String;
  }

  Future<void> setReceipt(int txnId, String path) async {
    await db.insert('receipts',
        {'txn_id': txnId, 'path': path, 'created_at': DateTime.now().millisecondsSinceEpoch},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeReceipt(int txnId) async {
    await db.delete('receipts', where: 'txn_id = ?', whereArgs: [txnId]);
  }
}
__END__

############################ lib/actions/quick_actions.dart ############################
cat > lib/actions/quick_actions.dart <<'__END__'
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../data/db.dart';
import '../native.dart';
import '../screens/add_txn_screen.dart';
import '../screens/review_screen.dart';
import '../security/lock.dart';
import '../state/app_state.dart';
import '../state/txn_state.dart';
import '../widgets/common.dart';

/// Handles actions from the home screen widget and long-press shortcuts.
Future<void> handleLaunchAction(BuildContext context) async {
  final a = await Native.takeLaunchAction();
  if (a == null || !context.mounted) return;
  switch (a) {
    case 'add_expense':
      Navigator.of(context).push(fadeRoute(const AddTxnScreen()));
    case 'voice':
      await startVoiceEntry(context);
    case 'scan':
      await startReceiptScan(context);
    case 'review':
      Navigator.of(context).push(fadeRoute(const ReviewScreen()));
    default:
      break;
  }
}

// ---------------- Voice entry ----------------

class VoiceResult {
  final TxnType type;
  final double? amount;
  final int? categoryId;
  final int? accountId;
  final String? payee;
  const VoiceResult(this.type, this.amount, this.categoryId, this.accountId, this.payee);
}

const Map<String, String> _voiceKeywords = {
  'petrol': 'fuel', 'diesel': 'fuel', 'fuel': 'fuel', 'cng': 'fuel',
  'chai': 'food', 'tea': 'food', 'coffee': 'food', 'lunch': 'food', 'dinner': 'food',
  'breakfast': 'food', 'food': 'food', 'swiggy': 'food', 'zomato': 'food', 'pizza': 'food',
  'snacks': 'food', 'restaurant': 'food',
  'grocery': 'grocery', 'groceries': 'grocery', 'vegetables': 'grocery', 'vegetable': 'grocery',
  'milk': 'grocery', 'fruits': 'grocery', 'blinkit': 'grocery', 'zepto': 'grocery',
  'uber': 'transport', 'ola': 'transport', 'auto': 'transport', 'rickshaw': 'transport',
  'bus': 'transport', 'metro': 'transport', 'train': 'transport', 'cab': 'transport',
  'parking': 'transport', 'rapido': 'transport',
  'recharge': 'bills', 'bill': 'bills', 'electricity': 'bills', 'wifi': 'bills', 'internet': 'bills',
  'rent': 'rent',
  'medicine': 'health', 'medicines': 'health', 'doctor': 'health', 'hospital': 'health', 'pharmacy': 'health',
  'movie': 'entertainment', 'netflix': 'entertainment', 'game': 'entertainment',
  'shopping': 'shopping', 'amazon': 'shopping', 'flipkart': 'shopping', 'clothes': 'shopping', 'shoes': 'shopping',
  'book': 'education', 'books': 'education', 'course': 'education', 'fees': 'education',
  'flight': 'travel', 'hotel': 'travel', 'trip': 'travel',
  'haircut': 'care', 'salon': 'care',
  'gift': 'gift', 'donation': 'gift',
  'salary': 'salary', 'refund': 'refund', 'cashback': 'refund', 'interest': 'interest',
};

VoiceResult parseVoice(String raw, List<Category> cats, List<Account> accounts) {
  final s = raw.toLowerCase().replaceAll('₹', ' ').replaceAll(',', '');
  double? amount;
  final m = RegExp(r'(\d+(?:\.\d+)?)\s*(k|thousand|hundred|lakh)?\b').firstMatch(s);
  if (m != null) {
    var v = double.parse(m.group(1)!);
    switch (m.group(2)) {
      case 'k':
      case 'thousand':
        v *= 1000;
      case 'hundred':
        v *= 100;
      case 'lakh':
        v *= 100000;
      default:
        break;
    }
    amount = v;
  }
  bool has(String w) => RegExp('\\b${RegExp.escape(w)}\\b').hasMatch(s);
  final income = ['received', 'got paid', 'salary', 'credited', 'income', 'earned', 'refund', 'cashback']
      .any((w) => s.contains(w));
  final type = income ? TxnType.income : TxnType.expense;
  final kind = income ? 'income' : 'expense';

  int? catId;
  var bestLen = 0;
  for (final c in cats.where((c) => c.kind == kind)) {
    final n = c.name.toLowerCase();
    if (n.length > bestLen && s.contains(n)) {
      catId = c.id;
      bestLen = n.length;
    }
  }
  if (catId == null) {
    for (final e in _voiceKeywords.entries) {
      if (!has(e.key)) continue;
      for (final c in cats) {
        if (c.iconKey == e.value && c.kind == kind) {
          catId = c.id;
          break;
        }
      }
      if (catId != null) break;
    }
  }

  int? accId;
  AccountType? want;
  if (has('cash')) want = AccountType.cash;
  if (has('card') || has('credit card')) want = AccountType.card;
  if (has('wallet') || has('paytm')) want = AccountType.wallet;
  if (want != null) {
    for (final a in accounts) {
      if (a.type == want) {
        accId = a.id;
        break;
      }
    }
  }

  String? payee;
  final pm = RegExp(r'\b(?:at|to|from)\s+([a-z][a-z\s]{1,25}?)(?:\s+(?:for|on|by|using|with|in|via)\b|$)')
      .firstMatch(s);
  if (pm != null) {
    final p = pm.group(1)!.trim();
    if (p.isNotEmpty && !['cash', 'card', 'wallet'].contains(p)) {
      payee = p.split(' ').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');
    }
  }
  return VoiceResult(type, amount, catId, accId, payee);
}

Future<void> startVoiceEntry(BuildContext context) async {
  final txns = context.read<TxnState>();
  final accounts = context.read<AccountsState>().accounts;
  final nav = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final text = await AppLockGate.suspendWhile(
      () => Native.voice('Say something like: Spent 250 on petrol'));
  if (text == '__unavailable__') {
    messenger.showSnackBar(const SnackBar(
        content: Text('Voice input needs the Google app or speech services on this phone.')));
    return;
  }
  if (text == null || text.trim().isEmpty) return;
  final v = parseVoice(text, txns.categories, accounts);
  nav.push(fadeRoute(AddTxnScreen(
    type: v.type,
    initialAmount: v.amount,
    initialCategoryId: v.categoryId,
    initialAccountId: v.accountId,
    initialPayee: v.payee,
    initialNote: text,
    voiceText: text,
  )));
}

// ---------------- Receipts ----------------

class ReceiptResult {
  final double? amount;
  final String? merchant;
  final DateTime? date;
  const ReceiptResult(this.amount, this.merchant, this.date);
}

final RegExp _num = RegExp(r'(\d{1,3}(?:,\d{2,3})+(?:\.\d{1,2})?|\d+\.\d{1,2}|\d+)');

double? _largest(String line) {
  double? best;
  for (final m in _num.allMatches(line)) {
    final v = double.tryParse(m.group(1)!.replaceAll(',', ''));
    if (v != null && v < 10000000 && (best == null || v > best)) best = v;
  }
  return best;
}

ReceiptResult parseReceipt(String text) {
  final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
  double? amount;
  const keys = [
    'grand total', 'net amount', 'net payable', 'amount payable', 'total amount',
    'bill amount', 'amount due', 'to pay', 'total'
  ];
  outer:
  for (final k in keys) {
    for (var i = lines.length - 1; i >= 0; i--) {
      final l = lines[i].toLowerCase();
      if (!l.contains(k)) continue;
      if (k == 'total' && (l.contains('sub') || l.contains('qty') || l.contains('items'))) continue;
      final v = _largest(lines[i]) ?? (i + 1 < lines.length ? _largest(lines[i + 1]) : null);
      if (v != null && v > 0) {
        amount = v;
        break outer;
      }
    }
  }
  if (amount == null) {
    double? best;
    for (final l in lines) {
      if (!l.contains('.')) continue;
      final v = _largest(l);
      if (v != null && (best == null || v > best)) best = v;
    }
    amount = best;
  }
  String? merchant;
  for (final l in lines.take(5)) {
    final letters = l.replaceAll(RegExp(r'[^A-Za-z]'), '');
    if (letters.length >= 3 && l.length <= 40) {
      merchant = l;
      break;
    }
  }
  DateTime? date;
  final dm = RegExp(r'(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})').firstMatch(text);
  if (dm != null) {
    var y = int.parse(dm.group(3)!);
    if (y < 100) y += 2000;
    final mo = int.parse(dm.group(2)!);
    final d = int.parse(dm.group(1)!);
    final now = DateTime.now();
    if (mo >= 1 && mo <= 12 && d >= 1 && d <= 31 && y > 2000 && y < 2100) {
      final candidate = DateTime(y, mo, d, now.hour, now.minute);
      if (!candidate.isAfter(now)) date = candidate;
    }
  }
  return ReceiptResult(amount, merchant, date);
}

Future<String?> pickReceiptImage({bool fromGallery = false}) async {
  try {
    final x = await AppLockGate.suspendWhile(() => ImagePicker().pickImage(
        source: fromGallery ? ImageSource.gallery : ImageSource.camera,
        imageQuality: 75,
        maxWidth: 1800));
    return x?.path;
  } catch (_) {
    return null;
  }
}

Future<String> saveReceiptFile(int txnId, String src) async {
  final dir = await getApplicationDocumentsDirectory();
  final folder = Directory('${dir.path}/receipts');
  if (!await folder.exists()) await folder.create(recursive: true);
  if (src.startsWith(folder.path)) return src;
  final dest = '${folder.path}/receipt_${txnId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
  await File(src).copy(dest);
  return dest;
}

Future<void> deleteReceiptFile(String? path) async {
  if (path == null) return;
  try {
    final f = File(path);
    if (await f.exists()) await f.delete();
  } catch (_) {}
}

Future<void> startReceiptScan(BuildContext context, {bool fromGallery = false}) async {
  final nav = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final path = await pickReceiptImage(fromGallery: fromGallery);
  if (path == null) return;
  final text = await Native.ocr(path) ?? '';
  final r = parseReceipt(text);
  nav.push(fadeRoute(AddTxnScreen(
    type: TxnType.expense,
    initialAmount: r.amount,
    initialPayee: r.merchant,
    initialWhen: r.date,
    receiptPath: path,
  )));
  if (r.amount == null) {
    messenger.showSnackBar(const SnackBar(
        content: Text('Could not read the total. Enter it with the keypad.')));
  }
}
__END__

############################ lib/screens/tags_screen.dart ############################
cat > lib/screens/tags_screen.dart <<'__END__'
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/db.dart';
import '../data/tags_repo.dart';
import '../native.dart';
import '../security/lock.dart';
import '../state/app_state.dart';
import '../state/txn_state.dart';
import '../theme.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/txn_tile.dart';
import 'add_txn_screen.dart';
import 'categories_screen.dart';

class TagsScreen extends StatefulWidget {
  const TagsScreen({super.key});

  @override
  State<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends State<TagsScreen> {
  Future<(List<Tag>, Map<int, (double, int)>)>? _future;
  int _version = -1;

  Future<(List<Tag>, Map<int, (double, int)>)> _load() async {
    final db = AppDatabase.instance;
    return (await db.tags(), await db.tagSummaries());
  }

  void _open(Widget p) => Navigator.of(context).push(fadeRoute(p));

  void _new() {
    final fin = context.fin;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: fin.card,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const Icon(Icons.luggage_rounded, color: Color(0xFFD78FD3)),
              title: const Text('New trip'),
              subtitle: const Text('Dates, budget and auto-tagging'),
              onTap: () {
                Navigator.pop(c);
                _open(const TagEditorScreen(trip: true));
              },
            ),
            ListTile(
              leading: const Icon(Icons.sell_rounded, color: AppColors.lavender),
              title: const Text('New tag'),
              subtitle: const Text('For example: Diwali, Office, Wedding'),
              onTap: () {
                Navigator.pop(c);
                _open(const TagEditorScreen());
              },
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    final txns = context.watch<TxnState>();
    final hide = context.watch<SettingsState>().hideAmounts;
    if (_future == null || _version != txns.version) {
      _version = txns.version;
      _future = _load();
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Trips & tags')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _new,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New'),
      ),
      body: FutureBuilder<(List<Tag>, Map<int, (double, int)>)>(
        future: _future,
        builder: (context, snap) {
          final d = snap.data;
          if (d == null) return const Center(child: CircularProgressIndicator());
          final trips = d.$1.where((t) => t.isTrip).toList();
          final tags = d.$1.where((t) => !t.isTrip).toList();
          if (d.$1.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.luggage_rounded, size: 56, color: Color(0xFFD78FD3)),
                  const SizedBox(height: 14),
                  Text('No trips or tags yet', style: AppText.display(size: 20, color: fin.text)),
                  const SizedBox(height: 8),
                  Text(
                    'Create a trip like "Goa 2026" and every transaction during those dates is grouped automatically.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: fin.subtext, height: 1.5),
                  ),
                ]),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
            children: [
              if (trips.isNotEmpty) ...[
                Text('Trips',
                    style: TextStyle(color: fin.text, fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                for (final t in trips)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _TripCard(
                      tag: t,
                      spent: d.$2[t.id]?.$1 ?? 0,
                      count: d.$2[t.id]?.$2 ?? 0,
                      hide: hide,
                      onTap: () => _open(TagDetailScreen(tagId: t.id)),
                    ),
                  ),
              ],
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Tags',
                    style: TextStyle(color: fin.text, fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Material(
                  color: fin.card,
                  borderRadius: BorderRadius.circular(22),
                  clipBehavior: Clip.antiAlias,
                  child: Column(children: [
                    for (final t in tags)
                      ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                              color: Color(t.color).withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(12)),
                          child: Icon(Icons.sell_rounded, color: Color(t.color), size: 20),
                        ),
                        title: Text(t.name),
                        subtitle: Text('${d.$2[t.id]?.$2 ?? 0} transactions'),
                        trailing: Text(inr(d.$2[t.id]?.$1 ?? 0, hide: hide, decimals: 0),
                            style: TextStyle(color: fin.text, fontWeight: FontWeight.w700)),
                        onTap: () => _open(TagDetailScreen(tagId: t.id)),
                      ),
                  ]),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final Tag tag;
  final double spent;
  final int count;
  final bool hide;
  final VoidCallback onTap;

  const _TripCard(
      {required this.tag,
      required this.spent,
      required this.count,
      required this.hide,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM');
    final pct = (tag.budget != null && tag.budget! > 0) ? spent / tag.budget! : null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(tag.color), Color(tag.color).withValues(alpha: 0.65)]),
          borderRadius: BorderRadius.circular(24),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(children: [
            Positioned.fill(
              child: CustomPaint(
                painter: OrbitPainter(0.25,
                    line: Colors.white.withValues(alpha: 0.18),
                    showDots: false,
                    center: const Alignment(0.8, -0.3)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.luggage_rounded, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(tag.name,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17)),
                    ),
                    if (tag.isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: Colors.white, borderRadius: BorderRadius.circular(20)),
                        child: const Text('Active',
                            style: TextStyle(
                                color: AppColors.ink, fontWeight: FontWeight.w700, fontSize: 12)),
                      ),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    tag.start != null && tag.end != null
                        ? '${df.format(tag.start!)} – ${df.format(tag.end!)} · $count transactions'
                        : '$count transactions',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  Text(inr(spent, hide: hide, decimals: 0),
                      style: AppText.display(size: 26, color: Colors.white)),
                  if (pct != null) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: pct.clamp(0.0, 1.0).toDouble(),
                        minHeight: 8,
                        backgroundColor: Colors.white24,
                        color: pct >= 1 ? AppColors.expense : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hide ? '' : '${(pct * 100).round()}% of ${inr(tag.budget!, decimals: 0)} budget',
                      style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                    ),
                  ],
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class TagEditorScreen extends StatefulWidget {
  final Tag? tag;
  final bool trip;
  const TagEditorScreen({super.key, this.tag, this.trip = false});

  @override
  State<TagEditorScreen> createState() => _TagEditorScreenState();
}

class _TagEditorScreenState extends State<TagEditorScreen> {
  late final TextEditingController _name;
  late final TextEditingController _budget;
  late bool _trip;
  late int _color;
  DateTime? _start;
  DateTime? _end;
  bool _auto = true;

  @override
  void initState() {
    super.initState();
    final t = widget.tag;
    _trip = t?.isTrip ?? widget.trip;
    _name = TextEditingController(text: t?.name ?? '');
    _budget = TextEditingController(
        text: t?.budget == null ? '' : t!.budget!.toStringAsFixed(0));
    _color = t?.color ?? (_trip ? 0xFFD78FD3 : kPalette[2]);
    final today = DateTime.now();
    _start = t?.start ?? (_trip ? DateTime(today.year, today.month, today.day) : null);
    _end = t?.end ?? (_trip ? DateTime(today.year, today.month, today.day).add(const Duration(days: 3)) : null);
    _auto = t?.autoTag ?? _trip;
  }

  @override
  void dispose() {
    _name.dispose();
    _budget.dispose();
    super.dispose();
  }

  bool get _valid {
    if (_name.text.trim().isEmpty) return false;
    if (_trip && (_start == null || _end == null || _end!.isBefore(_start!))) return false;
    return true;
  }

  Future<void> _pickDate(bool start) async {
    final init = (start ? _start : _end) ?? DateTime.now();
    final d = await showDatePicker(
        context: context,
        initialDate: init,
        firstDate: DateTime(2015),
        lastDate: DateTime.now().add(const Duration(days: 3650)));
    if (d == null) return;
    setState(() {
      if (start) {
        _start = d;
        if (_end != null && _end!.isBefore(d)) _end = d;
      } else {
        _end = d;
      }
    });
  }

  Future<void> _save() async {
    final txns = context.read<TxnState>();
    final nav = Navigator.of(context);
    final db = AppDatabase.instance;
    final budget = double.tryParse(_budget.text.replaceAll(',', '').trim());
    final t = widget.tag;
    if (t == null) {
      await db.insertTag(
          name: _name.text.trim(),
          color: _color,
          isTrip: _trip,
          start: _trip ? _start : null,
          end: _trip ? _end : null,
          budget: _trip ? budget : null,
          autoTag: _trip && _auto);
    } else {
      await db.updateTag(t.id,
          name: _name.text.trim(),
          color: _color,
          start: _trip ? _start : null,
          end: _trip ? _end : null,
          budget: _trip ? budget : null,
          autoTag: _trip && _auto,
          archived: t.archived);
    }
    await db.autoTagTrips();
    await txns.load();
    nav.pop();
  }

  Future<void> _delete() async {
    final txns = context.read<TxnState>();
    final nav = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Delete ${widget.tag!.name}?'),
        content: const Text('Transactions stay, only this tag is removed from them.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Delete', style: TextStyle(color: AppColors.expense))),
        ],
      ),
    );
    if (ok != true) return;
    await AppDatabase.instance.deleteTag(widget.tag!.id);
    await txns.load();
    nav.pop();
  }

  Widget _dateTile(FinColors fin, String label, DateTime? d, VoidCallback onTap) {
    return Expanded(
      child: Material(
        color: fin.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(color: fin.subtext, fontSize: 12)),
              const SizedBox(height: 4),
              Text(d == null ? 'Choose' : DateFormat('d MMM yyyy').format(d),
                  style: TextStyle(color: fin.text, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tag == null ? (_trip ? 'New trip' : 'New tag') : 'Edit'),
        actions: [
          if (widget.tag != null)
            IconButton(onPressed: _delete, icon: const Icon(Icons.delete_rounded)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          TextField(
            controller: _name,
            autofocus: widget.tag == null,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
                hintText: _trip ? 'e.g. Goa 2026' : 'e.g. Diwali',
                prefixIcon: Icon(_trip ? Icons.luggage_rounded : Icons.sell_rounded)),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 18),
          Text('Colour', style: TextStyle(color: fin.subtext, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final p in [0xFFD78FD3, ...kPalette])
              GestureDetector(
                onTap: () => setState(() => _color = p),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Color(p),
                    shape: BoxShape.circle,
                    border: Border.all(color: _color == p ? primary : Colors.transparent, width: 3),
                  ),
                ),
              ),
          ]),
          if (_trip) ...[
            const SizedBox(height: 20),
            Row(children: [
              _dateTile(fin, 'Starts', _start, () => _pickDate(true)),
              const SizedBox(width: 10),
              _dateTile(fin, 'Ends', _end, () => _pickDate(false)),
            ]),
            const SizedBox(height: 14),
            TextField(
              controller: _budget,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(prefixText: '₹ ', hintText: 'Trip budget (optional)'),
            ),
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _auto,
              onChanged: (v) => setState(() => _auto = v),
              title: const Text('Auto-tag transactions'),
              subtitle: const Text('Everything between these dates joins this trip'),
            ),
          ],
          const SizedBox(height: 24),
          PrimaryButton(label: 'Save', icon: Icons.check_rounded, onPressed: _valid ? _save : null),
        ],
      ),
    );
  }
}

class TagDetailScreen extends StatefulWidget {
  final int tagId;
  const TagDetailScreen({super.key, required this.tagId});

  @override
  State<TagDetailScreen> createState() => _TagDetailScreenState();
}

class _TagDetailScreenState extends State<TagDetailScreen> {
  Future<(Tag?, List<Txn>)>? _future;
  int _version = -1;

  Future<(Tag?, List<Txn>)> _load() async {
    final db = AppDatabase.instance;
    return (await db.tagById(widget.tagId), await db.txnsForTag(widget.tagId));
  }

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    final txns = context.watch<TxnState>();
    final hide = context.watch<SettingsState>().hideAmounts;
    if (_future == null || _version != txns.version) {
      _version = txns.version;
      _future = _load();
    }
    return FutureBuilder<(Tag?, List<Txn>)>(
      future: _future,
      builder: (context, snap) {
        final tag = snap.data?.$1;
        final list = snap.data?.$2 ?? const <Txn>[];
        if (tag == null) {
          return Scaffold(
              appBar: AppBar(),
              body: const Center(child: CircularProgressIndicator()));
        }
        final spending = list.where((t) => t.type == TxnType.expense && t.personId == null).toList();
        final spent = spending.fold<double>(0, (a, t) => a + t.amount);
        final byCat = <int?, double>{};
        for (final t in spending) {
          byCat[t.categoryId] = (byCat[t.categoryId] ?? 0) + t.amount;
        }
        final cats = byCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        final pct = (tag.budget != null && tag.budget! > 0) ? spent / tag.budget! : null;
        final df = DateFormat('d MMM yyyy');

        String summary() {
          final b = StringBuffer('${tag.name}\n');
          if (tag.start != null && tag.end != null) {
            b.writeln('${df.format(tag.start!)} – ${df.format(tag.end!)}');
          }
          b.writeln('Total spent: ${inr(spent, decimals: 0)}');
          for (final e in cats) {
            b.writeln('• ${txns.category(e.key)?.name ?? 'Other'}: ${inr(e.value, decimals: 0)}');
          }
          b.write('— via FinUp');
          return b.toString();
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(tag.name),
            actions: [
              IconButton(
                onPressed: () => AppLockGate.suspendWhile(() => Native.shareText(summary())),
                icon: const Icon(Icons.share_rounded),
              ),
              IconButton(
                onPressed: () => Navigator.of(context)
                    .push(fadeRoute(TagEditorScreen(tag: tag))),
                icon: const Icon(Icons.edit_rounded),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Color(tag.color).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Color(tag.color).withValues(alpha: 0.5)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tag.isTrip ? 'Trip spending' : 'Total spent',
                      style: TextStyle(color: fin.subtext)),
                  const SizedBox(height: 4),
                  Text(inr(spent, hide: hide, decimals: 0),
                      style: AppText.display(size: 30, color: fin.text)),
                  if (tag.start != null && tag.end != null)
                    Text('${df.format(tag.start!)} – ${df.format(tag.end!)}',
                        style: TextStyle(color: fin.subtext)),
                  Text('${list.length} transactions', style: TextStyle(color: fin.subtext)),
                  if (pct != null) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: pct.clamp(0.0, 1.0).toDouble(),
                        minHeight: 10,
                        backgroundColor: fin.divider,
                        color: statusColor(pct),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hide ? '' : '${(pct * 100).round()}% of ${inr(tag.budget!, decimals: 0)} budget',
                      style: TextStyle(color: statusColor(pct), fontWeight: FontWeight.w600),
                    ),
                  ],
                ]),
              ),
              if (cats.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text('By category',
                    style: TextStyle(color: fin.text, fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                for (final e in cats)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      Icon(txns.category(e.key)?.icon ?? Icons.help_outline_rounded,
                          color: txns.category(e.key)?.colorValue ?? fin.subtext, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(txns.category(e.key)?.name ?? 'Needs review',
                              style: TextStyle(color: fin.text))),
                      Text(inr(e.value, hide: hide, decimals: 0),
                          style: TextStyle(color: fin.text, fontWeight: FontWeight.w700)),
                    ]),
                  ),
              ],
              const SizedBox(height: 18),
              Text('Transactions',
                  style: TextStyle(color: fin.text, fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              if (list.isEmpty)
                Text('No transactions yet.', style: TextStyle(color: fin.subtext)),
              for (final t in list)
                TxnTile(
                  txn: t,
                  hide: hide,
                  showDate: true,
                  onTap: () => Navigator.of(context).push(fadeRoute(AddTxnScreen(editing: t))),
                ),
            ],
          ),
        );
      },
    );
  }
}
__END__

############################ lib/screens/add_txn_screen.dart (tags, receipts, voice/scan prefill) ############################
cat > lib/screens/add_txn_screen.dart <<'__END__'
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../actions/quick_actions.dart';
import '../data/db.dart';
import '../data/people_repo.dart';
import '../data/person_txn.dart';
import '../data/repo.dart';
import '../data/tags_repo.dart';
import '../native.dart';
import '../state/app_state.dart';
import '../state/txn_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/txn_tile.dart';
import 'categories_screen.dart';
import 'people_screen.dart';

Future<int?> pickAccount(BuildContext context, {int? exclude, String title = 'Choose account'}) {
  final fin = context.fin;
  final accounts = context.read<AccountsState>().accounts.where((a) => a.id != exclude).toList();
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: fin.card,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (c) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.75),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          children: [
            Text(title, style: AppText.display(size: 18, color: fin.text)),
            const SizedBox(height: 12),
            for (final a in accounts)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(gradient: AppColors.gradientAt(a.colorIndex), shape: BoxShape.circle),
                  child: Icon(a.type.icon, color: Colors.white, size: 20),
                ),
                title: Text(a.name),
                subtitle: Text(inr(a.balance)),
                onTap: () => Navigator.pop(c, a.id),
              ),
            if (accounts.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('No other accounts yet. Add one from Home.', style: TextStyle(color: fin.subtext)),
              ),
          ],
        ),
      ),
    ),
  );
}

Future<int?> pickCategory(BuildContext context, String kind) {
  final fin = context.fin;
  final cats = context.read<TxnState>().byKind(kind);
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: fin.card,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (c) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.8),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          children: [
            Row(children: [
              Expanded(child: Text('Choose category', style: AppText.display(size: 18, color: fin.text))),
              TextButton(
                onPressed: () {
                  Navigator.pop(c);
                  Navigator.of(context).push(fadeRoute(const CategoriesScreen()));
                },
                child: const Text('Manage'),
              ),
            ]),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 0.78,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                for (final cat in cats)
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.pop(c, cat.id),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: cat.colorValue.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(cat.icon, color: cat.colorValue),
                      ),
                      const SizedBox(height: 6),
                      Text(cat.name,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: fin.text, fontSize: 11.5, fontWeight: FontWeight.w500)),
                    ]),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class AddTxnScreen extends StatefulWidget {
  final TxnType type;
  final Txn? editing;
  final double? initialAmount;
  final int? initialCategoryId;
  final int? initialAccountId;
  final String? initialPayee;
  final String? initialNote;
  final DateTime? initialWhen;
  final String? receiptPath;
  final String? voiceText;

  const AddTxnScreen({
    super.key,
    this.type = TxnType.expense,
    this.editing,
    this.initialAmount,
    this.initialCategoryId,
    this.initialAccountId,
    this.initialPayee,
    this.initialNote,
    this.initialWhen,
    this.receiptPath,
    this.voiceText,
  });

  @override
  State<AddTxnScreen> createState() => _AddTxnScreenState();
}

class _AddTxnScreenState extends State<AddTxnScreen> {
  late TxnType _type;
  String _mode = 'accounts';
  String _amount = '0';
  int? _accountId;
  int? _toAccountId;
  int? _categoryId;
  int? _personId;
  String? _personName;
  late DateTime _when;
  final _note = TextEditingController();
  final _payee = TextEditingController();
  bool _remember = true;
  bool _saving = false;
  List<int> _tagIds = [];
  List<Tag> _allTags = [];
  String? _receipt;
  String? _originalReceipt;
  bool _reading = false;

  String _fmt(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _type = e?.type ?? widget.type;
    _when = e?.occurredAt ?? widget.initialWhen ?? DateTime.now();
    if (e != null) {
      _amount = _fmt(e.amount);
      _accountId = e.accountId;
      _toAccountId = e.toAccountId;
      _categoryId = e.categoryId;
      _note.text = e.note ?? '';
      _payee.text = e.counterparty ?? '';
      if (e.personId != null && e.type != TxnType.transfer) {
        _mode = e.type == TxnType.income ? 'got' : 'gave';
        _type = TxnType.transfer;
        _personId = e.personId;
      }
    } else {
      final accounts = context.read<AccountsState>().accounts;
      Account? bank;
      Account? cash;
      for (final a in accounts) {
        if (bank == null && a.type != AccountType.cash) bank = a;
        if (cash == null && a.type == AccountType.cash) cash = a;
      }
      _accountId = widget.initialAccountId ?? (bank ?? cash)?.id;
      if (_type == TxnType.transfer) _toAccountId = cash?.id;
      if (widget.initialAmount != null && widget.initialAmount! > 0) _amount = _fmt(widget.initialAmount!);
      _categoryId = widget.initialCategoryId;
      _payee.text = widget.initialPayee ?? '';
      _note.text = widget.initialNote ?? '';
      _receipt = widget.receiptPath;
    }
    _loadExtras();
  }

  Future<void> _loadExtras() async {
    final db = AppDatabase.instance;
    final all = await db.tags();
    final e = widget.editing;
    List<int> ids = [];
    String? receipt = _receipt;
    String? pName;
    if (e != null) {
      ids = await db.tagsOf(e.id!);
      receipt = await db.receiptOf(e.id!);
      if (_personId != null) pName = (await db.person(_personId!))?.name;
    } else {
      final trip = await db.activeTrip();
      if (trip != null) ids = [trip.id];
    }
    if (!mounted) return;
    setState(() {
      _allTags = all;
      _tagIds = ids;
      _receipt = receipt;
      if (e != null) _originalReceipt = receipt;
      if (pName != null) _personName = pName;
    });
  }

  @override
  void dispose() {
    _note.dispose();
    _payee.dispose();
    super.dispose();
  }

  bool get _personMode => _type == TxnType.transfer && _mode != 'accounts';
  double get _value => double.tryParse(_amount) ?? 0;

  bool get _valid {
    if (_saving || _value <= 0 || _accountId == null) return false;
    if (_type != TxnType.transfer) return true;
    if (_mode == 'accounts') return _toAccountId != null && _toAccountId != _accountId;
    return _personId != null;
  }

  void _key(String k) {
    HapticFeedback.selectionClick();
    setState(() {
      if (k == '<') {
        _amount = _amount.length <= 1 ? '0' : _amount.substring(0, _amount.length - 1);
        return;
      }
      if (k == '.') {
        if (!_amount.contains('.')) _amount = '$_amount.';
        return;
      }
      if (_amount.contains('.') && _amount.split('.')[1].length >= 2) return;
      if (_amount.replaceAll('.', '').length >= 9) return;
      _amount = _amount == '0' ? k : '$_amount$k';
    });
  }

  String _accName(int? id) {
    for (final a in context.read<AccountsState>().accounts) {
      if (a.id == id) return a.name;
    }
    return 'Choose';
  }

  Future<void> _pickWhen() async {
    final d = await showDatePicker(
        context: context,
        initialDate: _when,
        firstDate: DateTime(2015),
        lastDate: DateTime.now().add(const Duration(days: 365)));
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_when));
    setState(() {
      _when = DateTime(d.year, d.month, d.day, t?.hour ?? _when.hour, t?.minute ?? _when.minute);
    });
  }

  Future<void> _pickPerson() async {
    final id = await pickPerson(context,
        suggestFor: _payee.text.trim().isEmpty ? null : _payee.text.trim(),
        title: _mode == 'gave' ? 'Who did you give it to?' : 'Who gave you the money?');
    if (id == null) return;
    final p = await AppDatabase.instance.person(id);
    if (mounted) {
      setState(() {
        _personId = id;
        _personName = p?.name;
      });
    }
  }

  Future<String?> _askName(BuildContext c) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: c,
      builder: (d) => AlertDialog(
        title: const Text('New tag'),
        content: TextField(
            controller: ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'e.g. Diwali')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(d, ctrl.text.trim().isEmpty ? null : ctrl.text.trim()),
              child: const Text('Add')),
        ],
      ),
    );
  }

  Future<void> _pickTags() async {
    final fin = context.fin;
    final db = AppDatabase.instance;
    var all = await db.tags();
    if (!mounted) return;
    final selected = <int>{..._tagIds};
    final res = await showModalBottomSheet<List<int>>(
      context: context,
      backgroundColor: fin.card,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (c) => StatefulBuilder(
        builder: (c, setLocal) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.75),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              children: [
                Row(children: [
                  Expanded(child: Text('Tags & trips', style: AppText.display(size: 18, color: fin.text))),
                  TextButton(onPressed: () => Navigator.pop(c, selected.toList()), child: const Text('Done')),
                ]),
                for (final t in all.where((t) => !t.archived))
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: selected.contains(t.id),
                    onChanged: (v) => setLocal(() {
                      if (v == true) {
                        selected.add(t.id);
                      } else {
                        selected.remove(t.id);
                      }
                    }),
                    secondary: Icon(t.isTrip ? Icons.luggage_rounded : Icons.sell_rounded, color: Color(t.color)),
                    title: Text(t.name),
                    subtitle: t.isTrip ? const Text('Trip') : null,
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.add_rounded),
                  title: const Text('New tag'),
                  onTap: () async {
                    final name = await _askName(c);
                    if (name == null) return;
                    final id = await db.insertTag(name: name, color: kPalette[all.length % kPalette.length]);
                    all = await db.tags();
                    setLocal(() => selected.add(id));
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (res == null || !mounted) return;
    final fresh = await db.tags();
    if (mounted) {
      setState(() {
        _tagIds = res;
        _allTags = fresh;
      });
    }
  }

  Future<void> _attachReceipt({required bool gallery}) async {
    final path = await pickReceiptImage(fromGallery: gallery);
    if (path == null || !mounted) return;
    setState(() {
      _receipt = path;
      _reading = _value <= 0;
    });
    if (_value > 0) return;
    final text = await Native.ocr(path) ?? '';
    final r = parseReceipt(text);
    if (!mounted) return;
    setState(() {
      _reading = false;
      if (r.amount != null) _amount = _fmt(r.amount!);
      if (_payee.text.trim().isEmpty && r.merchant != null) _payee.text = r.merchant!;
    });
  }

  void _viewReceipt() {
    final p = _receipt;
    if (p == null) return;
    Navigator.of(context).push(fadeRoute(Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: const Text('Receipt')),
      body: Center(child: InteractiveViewer(maxScale: 5, child: Image.file(File(p)))),
    )));
  }

  Future<void> _saveExtras(int? txnId) async {
    if (txnId == null) return;
    final db = AppDatabase.instance;
    await db.setTxnTags(txnId, _tagIds);
    if (_receipt != _originalReceipt) {
      if (_receipt == null) {
        await db.removeReceipt(txnId);
        await deleteReceiptFile(_originalReceipt);
      } else {
        final saved = await saveReceiptFile(txnId, _receipt!);
        await db.setReceipt(txnId, saved);
        if (_originalReceipt != null && _originalReceipt != saved) await deleteReceiptFile(_originalReceipt);
      }
    }
  }

  Future<void> _save() async {
    final txns = context.read<TxnState>();
    final accounts = context.read<AccountsState>();
    final nav = Navigator.of(context);
    final db = AppDatabase.instance;
    setState(() => _saving = true);
    final e = widget.editing;
    final payee = _payee.text.trim();
    final note = _note.text.trim().isEmpty ? null : _note.text.trim();

    if (_personMode) {
      final gave = _mode == 'gave';
      int? id;
      if (e == null) {
        await db.addEntry(
            personId: _personId!,
            type: gave ? 'gave' : 'took',
            amount: _value,
            note: note,
            when: _when,
            accountId: _accountId,
            personName: _personName);
        id = await db.lastTxnId();
      } else {
        final t = Txn(
          id: e.id,
          accountId: _accountId,
          type: gave ? TxnType.expense : TxnType.income,
          amount: _value,
          personId: _personId,
          counterparty: payee.isEmpty ? _personName : payee,
          note: note,
          ref: e.ref,
          smsBody: e.smsBody,
          status: 'done',
          occurredAt: _when,
        );
        await db.editTxn(e, t);
        await db.relinkTxn(t, _personId!);
        id = e.id;
      }
      await _saveExtras(id);
      await accounts.load();
      await txns.load();
      nav.pop();
      return;
    }

    final isTransfer = _type == TxnType.transfer;
    final t = Txn(
      id: e?.id,
      accountId: _accountId,
      toAccountId: isTransfer ? _toAccountId : null,
      type: _type,
      amount: _value,
      categoryId: isTransfer ? null : _categoryId,
      personId: null,
      counterparty: payee.isEmpty ? null : payee,
      note: note,
      ref: e?.ref,
      smsBody: e?.smsBody,
      status: (isTransfer || _categoryId != null) ? 'done' : 'review',
      occurredAt: _when,
    );
    await txns.save(accounts, t, old: e);
    final id = e?.id ?? await db.lastTxnId();
    if (e != null && e.personId != null) await db.unlinkTxnLedger(e.id!);
    await _saveExtras(id);
    if (_remember && !isTransfer && _categoryId != null && payee.isNotEmpty && e?.smsBody != null) {
      await txns.rememberRule(payee, _categoryId!);
    } else {
      await txns.load();
    }
    nav.pop();
  }

  Future<void> _delete() async {
    final txns = context.read<TxnState>();
    final accounts = context.read<AccountsState>();
    final nav = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: const Text('Account balances will be adjusted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Delete', style: TextStyle(color: AppColors.expense))),
        ],
      ),
    );
    if (ok != true) return;
    final e = widget.editing!;
    final db = AppDatabase.instance;
    if (e.personId != null) await db.unlinkTxnLedger(e.id!);
    await db.setTxnTags(e.id!, []);
    await db.removeReceipt(e.id!);
    await deleteReceiptFile(_originalReceipt);
    await txns.delete(accounts, e);
    nav.pop();
  }

  Widget _typeSwitch(FinColors fin) {
    Widget item(TxnType t, String label) {
      final sel = _type == t;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() {
            _type = t;
            _categoryId = null;
            if (t == TxnType.transfer && _toAccountId == null) {
              for (final a in context.read<AccountsState>().accounts) {
                if (a.type == AccountType.cash && a.id != _accountId) {
                  _toAccountId = a.id;
                  break;
                }
              }
            }
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
                color: sel ? typeColor(t) : Colors.transparent, borderRadius: BorderRadius.circular(14)),
            child: Center(
              child: Text(label,
                  style: TextStyle(color: sel ? Colors.white : fin.subtext, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: fin.card, borderRadius: BorderRadius.circular(18)),
      child: Row(children: [
        item(TxnType.expense, 'Expense'),
        item(TxnType.income, 'Income'),
        item(TxnType.transfer, 'Transfer'),
      ]),
    );
  }

  Widget _modeSwitch(FinColors fin) {
    Widget item(String v, IconData icon, String label, Color color) {
      final sel = _mode == v;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _mode = v),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            decoration: BoxDecoration(
              color: sel ? color.withValues(alpha: 0.16) : fin.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: sel ? color : fin.divider, width: sel ? 1.8 : 1),
            ),
            child: Column(children: [
              Icon(icon, color: sel ? color : fin.subtext, size: 22),
              const SizedBox(height: 6),
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: sel ? fin.text : fin.subtext,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      height: 1.25)),
            ]),
          ),
        ),
      );
    }

    return Row(children: [
      item('accounts', Icons.swap_horiz_rounded, 'Between\naccounts', AppColors.lavender),
      item('gave', Icons.north_east_rounded, 'Gave to\na person', AppColors.expense),
      item('got', Icons.south_west_rounded, 'Got from\na person', AppColors.income),
    ]);
  }

  Widget _field(FinColors fin, IconData icon, Color color, String label, String value, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: fin.card,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: TextStyle(color: fin.subtext, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(value, style: TextStyle(color: fin.text, fontWeight: FontWeight.w600, fontSize: 15)),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: fin.subtext),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _tagsField(FinColors fin) {
    final selected = _allTags.where((t) => _tagIds.contains(t.id)).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: fin.card,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _pickTags,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: const Color(0xFFD78FD3).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.sell_rounded, color: Color(0xFFD78FD3), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: selected.isEmpty
                    ? Text('Add tags or trip', style: TextStyle(color: fin.subtext))
                    : Wrap(spacing: 6, runSpacing: 6, children: [
                        for (final t in selected)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                                color: Color(t.color).withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(20)),
                            child: Text(t.isTrip ? '✈ ${t.name}' : '# ${t.name}',
                                style: TextStyle(color: fin.text, fontSize: 12.5, fontWeight: FontWeight.w600)),
                          ),
                      ]),
              ),
              Icon(Icons.chevron_right_rounded, color: fin.subtext),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _receiptField(FinColors fin) {
    final p = _receipt;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: fin.card, borderRadius: BorderRadius.circular(18)),
        child: p == null
            ? Row(children: [
                const Icon(Icons.receipt_long_rounded, color: Color(0xFF7BC67E)),
                const SizedBox(width: 10),
                Expanded(child: Text('Receipt', style: TextStyle(color: fin.subtext))),
                TextButton.icon(
                    onPressed: () => _attachReceipt(gallery: false),
                    icon: const Icon(Icons.photo_camera_rounded, size: 18),
                    label: const Text('Camera')),
                TextButton.icon(
                    onPressed: () => _attachReceipt(gallery: true),
                    icon: const Icon(Icons.photo_rounded, size: 18),
                    label: const Text('Gallery')),
              ])
            : Row(children: [
                GestureDetector(
                  onTap: _viewReceipt,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(File(p), width: 60, height: 60, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                            width: 60, height: 60, color: fin.divider, child: const Icon(Icons.broken_image_rounded))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(_reading ? 'Reading the total…' : 'Receipt attached',
                      style: TextStyle(color: fin.text, fontWeight: FontWeight.w600)),
                ),
                IconButton(onPressed: _viewReceipt, icon: const Icon(Icons.open_in_full_rounded)),
                IconButton(
                    onPressed: () => setState(() => _receipt = null),
                    icon: const Icon(Icons.close_rounded)),
              ]),
      ),
    );
  }

  Widget _keypad(FinColors fin) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['.', '0', '<'],
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      decoration: BoxDecoration(color: fin.card, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
      child: Column(children: [
        for (final r in rows)
          Row(children: [
            for (final k in r)
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _key(k),
                  child: SizedBox(
                    height: 52,
                    child: Center(
                      child: k == '<'
                          ? Icon(Icons.backspace_outlined, color: fin.text)
                          : Text(k, style: TextStyle(color: fin.text, fontSize: 24, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ),
          ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    final e = widget.editing;
    final isTransfer = _type == TxnType.transfer;
    final kind = _type == TxnType.income ? 'income' : 'expense';
    final cat = context.watch<TxnState>().category(_categoryId);
    final color = _personMode ? (_mode == 'gave' ? AppColors.expense : AppColors.income) : typeColor(_type);

    final accountField = _field(
      fin,
      Icons.account_balance_wallet_rounded,
      AppColors.lavender,
      isTransfer ? (_mode == 'got' ? 'To account' : 'From account') : 'Account',
      _accName(_accountId),
      () async {
        final id = await pickAccount(context);
        if (id != null) setState(() => _accountId = id);
      },
    );
    final personField = _field(
      fin,
      Icons.person_rounded,
      _mode == 'gave' ? AppColors.expense : AppColors.income,
      _mode == 'gave' ? 'To person' : 'From person',
      _personName ?? 'Choose person',
      _pickPerson,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(e == null ? 'New transaction' : 'Edit transaction'),
        actions: [
          if (e != null) IconButton(onPressed: _delete, icon: const Icon(Icons.delete_rounded)),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            children: [
              if (widget.voiceText != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: const Color(0xFF5DADE2).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14)),
                  child: Row(children: [
                    const Icon(Icons.mic_rounded, color: Color(0xFF5DADE2)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('"${widget.voiceText}"',
                          style: TextStyle(color: fin.text, fontStyle: FontStyle.italic)),
                    ),
                  ]),
                ),
              _typeSwitch(fin),
              if (isTransfer) ...[
                const SizedBox(height: 12),
                _modeSwitch(fin),
              ],
              const SizedBox(height: 22),
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                  child: FittedBox(
                    key: ValueKey('$_amount$_type$_mode'),
                    fit: BoxFit.scaleDown,
                    child: Text('₹$_amount', style: AppText.display(size: 46, color: color)),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              if (!isTransfer) accountField,
              if (isTransfer && _mode == 'accounts') ...[
                accountField,
                _field(fin, Icons.south_rounded, AppColors.pink, 'To account', _accName(_toAccountId), () async {
                  final id = await pickAccount(context, exclude: _accountId, title: 'Move money to');
                  if (id != null) setState(() => _toAccountId = id);
                }),
              ],
              if (isTransfer && _mode == 'gave') ...[accountField, personField],
              if (isTransfer && _mode == 'got') ...[personField, accountField],
              if (!isTransfer)
                _field(fin, cat?.icon ?? Icons.category_rounded, cat?.colorValue ?? AppColors.pink, 'Category',
                    cat?.name ?? 'Choose category', () async {
                  final id = await pickCategory(context, kind);
                  if (id != null) setState(() => _categoryId = id);
                }),
              _field(fin, Icons.calendar_month_rounded, AppColors.income, 'Date and time',
                  DateFormat('EEE, d MMM yyyy · h:mm a').format(_when), _pickWhen),
              _tagsField(fin),
              _receiptField(fin),
              if (_personMode)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10, left: 4, right: 4),
                  child: Text(
                    _mode == 'gave'
                        ? 'Lending money or paying someone back. Saved in the People ledger, not counted as spending.'
                        : 'Borrowing money or getting paid back. Saved in the People ledger, not counted as income.',
                    style: TextStyle(color: fin.subtext, fontSize: 12.5, height: 1.4),
                  ),
                ),
              TextField(
                controller: _payee,
                decoration: InputDecoration(
                  hintText: isTransfer
                      ? 'Label or UPI ID (optional)'
                      : (_type == TxnType.income ? 'Received from (optional)' : 'Paid to (optional)'),
                  prefixIcon: const Icon(Icons.storefront_rounded),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _note,
                decoration: const InputDecoration(hintText: 'Note (optional)', prefixIcon: Icon(Icons.edit_note_rounded)),
              ),
              if (e?.smsBody != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.lavender.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.lavender.withValues(alpha: 0.3)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Row(children: [
                      Icon(Icons.sms_rounded, size: 16, color: AppColors.lavender),
                      SizedBox(width: 6),
                      Text('From bank SMS',
                          style: TextStyle(color: AppColors.lavender, fontWeight: FontWeight.w700, fontSize: 12)),
                    ]),
                    const SizedBox(height: 6),
                    Text(e!.smsBody!, style: TextStyle(color: fin.subtext, fontSize: 12.5, height: 1.4)),
                  ]),
                ),
                if (!isTransfer && _payee.text.trim().isNotEmpty)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _remember,
                    onChanged: (v) => setState(() => _remember = v ?? true),
                    title: Text('Always use this category for ${prettyParty(_payee.text)}',
                        style: TextStyle(color: fin.text, fontSize: 14)),
                  ),
              ],
            ],
          ),
        ),
        _keypad(fin),
        Container(
          color: fin.card,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: SafeArea(
            top: false,
            child: PrimaryButton(
              label: e == null ? 'Save' : 'Update',
              icon: Icons.check_rounded,
              onPressed: _valid ? _save : null,
            ),
          ),
        ),
      ]),
    );
  }
}
__END__

############################ Patches to earlier parts ############################
# main: create tag/receipt tables
sed -i "s#await AppDatabase.instance.ensureSchema();#await AppDatabase.instance.ensureSchema();\n  await AppDatabase.instance.ensureTagSchema();#" lib/main.dart
sed -i "s#import 'data/repo.dart';#import 'data/repo.dart';\nimport 'data/tags_repo.dart';#" lib/main.dart

# TxnState: auto-tag trips after SMS sync, refresh widget after every change
sed -i "s#import '../data/people_repo.dart';#import '../data/people_repo.dart';\nimport '../data/tags_repo.dart';#" lib/state/txn_state.dart
sed -i "s#await applyPendingCategories();#await applyPendingCategories();\n      await AppDatabase.instance.autoTagTrips();#" lib/state/txn_state.dart
sed -i "s#BudgetAlerts.check(this);#BudgetAlerts.check(this);\n    Native.refreshWidget();#" lib/state/txn_state.dart

# HomeShell: widget/shortcut actions + new tiles in the + sheet
sed -i "s#import 'people_screen.dart';#import 'people_screen.dart';\nimport 'tags_screen.dart';\nimport '../actions/quick_actions.dart';#" lib/screens/home_shell.dart
sed -i "0,/if (!mounted) return;/s//if (!mounted) return;\n    await handleLaunchAction(context);\n    if (!mounted) return;/" lib/screens/home_shell.dart
perl -0777 -pi -e 's{(\s*)_AddTile\(\s*icon: Icons\.account_balance_wallet_rounded,}{$1_AddTile(icon: Icons.mic_rounded, label: \x27Voice\x27, color: const Color(0xFF5DADE2), onTap: () { Navigator.pop(sheetContext); startVoiceEntry(context); }),$1_AddTile(icon: Icons.document_scanner_rounded, label: \x27Scan receipt\x27, color: const Color(0xFF7BC67E), onTap: () { Navigator.pop(sheetContext); startReceiptScan(context); }),$1_AddTile(icon: Icons.luggage_rounded, label: \x27Trips & tags\x27, color: const Color(0xFFD78FD3), onTap: () => go(const TagsScreen())),$1_AddTile(icon: Icons.account_balance_wallet_rounded,}s' lib/screens/home_shell.dart

# Backups include tags and receipts
sed -i "s#'budgets', 'goals'#'budgets', 'goals', 'tags', 'txn_tags', 'receipts'#g" lib/data/backup.dart

for check in "ensureTagSchema:lib/main.dart" "autoTagTrips:lib/state/txn_state.dart" "refreshWidget:lib/state/txn_state.dart" "handleLaunchAction:lib/screens/home_shell.dart" "startReceiptScan:lib/screens/home_shell.dart" "txn_tags:lib/data/backup.dart"; do
  pat="${check%%:*}"; file="${check#*:}"
  if ! grep -q "$pat" "$file"; then echo "ERROR: patch failed in $file ($pat)"; exit 1; fi
done

############################ Docs ############################
cat >> USER_GUIDE.md <<'__END__'

## 16. Home screen widget
Long-press your home screen → Widgets → FinUp. It shows today's spending, total balance and review count, with buttons for Expense, Voice and Scan. It refreshes whenever FinUp changes and every 30 minutes.

## 17. Long-press shortcuts
Long-press the FinUp icon for Add expense, Voice entry, Scan receipt and Review. Drag a shortcut to the home screen to pin it.

## 18. Voice entry
Tap + → Voice (or the widget/shortcut) and say, for example, "Spent 250 on petrol", "Paid 1200 rent in cash" or "Received 5000 salary". FinUp fills in the amount, type, category, account and payee; check and tap Save. Needs the Google app or speech services; works offline only if an offline English pack is installed.

## 19. Receipts
Tap + → Scan receipt to photograph a bill. FinUp reads the total and shop name on the phone and opens a filled-in entry. You can also attach a receipt to any transaction (Camera or Gallery) and tap it to zoom. Receipt photos stay in the app's private folder and are not part of the backup file.

## 20. Trips & tags
Tap + → Trips & tags. A trip has dates, an optional budget and auto-tagging: every transaction between those dates (SMS or manual) joins the trip. Tags (for example Diwali or Office) can be added to any transaction from the Tags field. Open a trip or tag to see total spent, a category breakdown and all its transactions, and share a summary.
__END__

echo "FinUp Part 9 (finup7.sh) applied."