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
                    FinUpWidgets.refreshAll(this)
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
