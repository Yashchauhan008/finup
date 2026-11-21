package com.yash.finup

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.os.Build
import android.provider.Telephony
import org.json.JSONObject
import java.text.NumberFormat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object FlutterPrefs {
    private fun p(ctx: Context) = ctx.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
    fun long(ctx: Context, key: String): Long = try { p(ctx).getLong("flutter.$key", 0L) } catch (e: Exception) { 0L }
    fun bool(ctx: Context, key: String, def: Boolean): Boolean = try { p(ctx).getBoolean("flutter.$key", def) } catch (e: Exception) { def }
}

object AlertPrefs {
    private const val PREFS = "finup_native"
    fun smsAlerts(ctx: Context): Boolean =
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean("smsAlerts", true)
    fun setSmsAlerts(ctx: Context, v: Boolean) {
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean("smsAlerts", v).apply()
    }
}

object Pending {
    private const val PREFS = "finup_native"
    private fun read(ctx: Context): JSONObject = try {
        JSONObject(ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("pending", "{}") ?: "{}")
    } catch (e: Exception) { JSONObject() }
    private fun write(ctx: Context, o: JSONObject) {
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString("pending", o.toString()).apply()
    }
    fun save(ctx: Context, key: String, cat: Int) {
        val o = read(ctx)
        o.put(key, cat)
        write(ctx, o)
    }
    fun all(ctx: Context): HashMap<String, Int> {
        val o = read(ctx)
        val m = HashMap<String, Int>()
        val it = o.keys()
        while (it.hasNext()) {
            val k = it.next()
            m[k] = o.optInt(k, -1)
        }
        return m
    }
    fun remove(ctx: Context, keys: List<String>) {
        val o = read(ctx)
        for (k in keys) o.remove(k)
        write(ctx, o)
    }
}

object SmsParse {
    data class Result(
        val amount: Double,
        val debit: Boolean,
        val last4: String?,
        val party: String?,
        val ref: String?,
        val atm: Boolean
    )

    private val skip = Regex("\\b(otp|one time password|verification code|requested|request money|will be debited|failed|declined|unsuccessful)\\b", RegexOption.IGNORE_CASE)
    private val promo = Regex("\\b(offer|apply now|pre-approved|preapproved|loan|win|congratulations|voucher|discount)\\b", RegexOption.IGNORE_CASE)
    private val amountRx = Regex("(?:rs\\.?|inr|₹)\\s*([0-9][0-9,]*(?:\\.[0-9]{1,2})?)", RegexOption.IGNORE_CASE)
    private val drcr = Regex("(?:rs\\.?|inr|₹)\\s*[0-9][0-9,]*(?:\\.[0-9]{1,2})?\\s*(dr|cr)\\b", RegexOption.IGNORE_CASE)
    private val acct = Regex("(?:a/c|acct|account)\\.?\\s*(?:no\\.?\\s*)?[x*.\\-\\s]*([0-9]{3,6})", RegexOption.IGNORE_CASE)
    private val vpa = Regex("[a-z0-9][a-z0-9.\\-_]+@[a-z][a-z0-9]+", RegexOption.IGNORE_CASE)
    private val refRx = Regex("(?:ref(?:erence)?|utr|rrn|txn\\s*id)(?:\\s*no)?[\\s.:#-]*([0-9]{6,})", RegexOption.IGNORE_CASE)

    private fun knownBank(sender: String): Boolean {
        val u = sender.uppercase()
        return listOf("BOB", "HDFC", "ICICI", "SBI", "AXIS", "KOTAK", "PNB").any { u.contains(it) }
    }

    private fun firstIndex(lower: String, words: List<String>): Int {
        var best = -1
        for (w in words) {
            val i = lower.indexOf(w)
            if (i >= 0 && (best < 0 || i < best)) best = i
        }
        return best
    }

    fun parse(sender: String, body: String): Result? {
        val text = body.replace('\n', ' ')
        if (skip.containsMatchIn(text)) return null
        val am = amountRx.find(text) ?: return null
        val amount = am.groupValues[1].replace(",", "").toDoubleOrNull() ?: return null
        if (amount <= 0) return null
        val lower = text.lowercase()
        val debit: Boolean
        val dc = drcr.find(text)
        if (dc != null) {
            debit = dc.groupValues[1].lowercase() == "dr"
        } else {
            val d = firstIndex(lower, listOf("debited", "spent", "paid", "sent", "withdrawn", "purchase", "debit", " dr "))
            val c = firstIndex(lower, listOf("credited", "received", "deposited", "refund", "credit", " cr "))
            if (d < 0 && c < 0) return null
            debit = c < 0 || (d >= 0 && d < c)
        }
        val raw4 = acct.find(text)?.groupValues?.get(1)
        val last4 = if (raw4 == null) null else if (raw4.length > 4) raw4.substring(raw4.length - 4) else raw4
        val v = vpa.find(text)?.value
        if (last4 == null && (promo.containsMatchIn(text) || (!knownBank(sender) && v == null))) return null
        val atm = debit && (lower.contains("atm") || lower.contains("cash withdrawal") || lower.contains("withdrawn"))
        val ref = refRx.find(text)?.groupValues?.get(1)
        return Result(amount, debit, last4, if (atm) "ATM withdrawal" else v, ref, atm)
    }
}

object Suggest {
    fun categories(ctx: Context, party: String?, kind: String): List<Pair<Int, String>> {
        val out = ArrayList<Pair<Int, String>>()
        val f = ctx.getDatabasePath("finup.db")
        if (!f.exists()) return out
        try {
            SQLiteDatabase.openDatabase(f.path, null, SQLiteDatabase.OPEN_READONLY).use { db ->
                val ids = LinkedHashSet<Int>()
                if (party != null) {
                    val l = party.lowercase()
                    db.rawQuery("SELECT keyword, category_id FROM rules WHERE category_id IS NOT NULL", null).use { c ->
                        while (c.moveToNext()) {
                            val k = c.getString(0) ?: ""
                            if (k.isNotEmpty() && (l == k || l.contains(k))) {
                                ids.add(c.getInt(1))
                                break
                            }
                        }
                    }
                }
                db.rawQuery(
                    "SELECT t.category_id, COUNT(*) AS n FROM transactions t JOIN categories c ON c.id = t.category_id " +
                        "WHERE c.kind = ? GROUP BY t.category_id ORDER BY n DESC LIMIT 5",
                    arrayOf(kind)
                ).use { c -> while (c.moveToNext()) ids.add(c.getInt(0)) }
                db.rawQuery("SELECT id FROM categories WHERE kind = ? ORDER BY sort LIMIT 5", arrayOf(kind)).use { c ->
                    while (c.moveToNext()) ids.add(c.getInt(0))
                }
                for (id in ids) {
                    if (out.size >= 2) break
                    db.rawQuery("SELECT name FROM categories WHERE id = ? AND kind = ?", arrayOf(id.toString(), kind)).use { c ->
                        if (c.moveToFirst()) out.add(Pair(id, c.getString(0)))
                    }
                }
            }
        } catch (e: Exception) {
        }
        return out
    }
}

object Notifier {
    const val CH_TXN = "finup_txn"
    const val CH_DAILY = "finup_daily"
    const val CH_ALERT = "finup_alerts"

    private fun nm(ctx: Context) = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    private fun ensureChannels(ctx: Context) {
        if (Build.VERSION.SDK_INT >= 26) {
            val m = nm(ctx)
            m.createNotificationChannel(NotificationChannel(CH_TXN, "Bank transactions", NotificationManager.IMPORTANCE_HIGH))
            m.createNotificationChannel(NotificationChannel(CH_DAILY, "Daily review", NotificationManager.IMPORTANCE_DEFAULT))
            m.createNotificationChannel(NotificationChannel(CH_ALERT, "Budget alerts", NotificationManager.IMPORTANCE_HIGH))
        }
    }

    fun flags(): Int =
        if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        else PendingIntent.FLAG_UPDATE_CURRENT

    private fun icon(ctx: Context): Int {
        val i = ctx.resources.getIdentifier("ic_stat_finup", "drawable", ctx.packageName)
        return if (i == 0) android.R.drawable.ic_popup_reminder else i
    }

    private fun openApp(ctx: Context, req: Int): PendingIntent {
        val launch = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName) ?: Intent()
        return PendingIntent.getActivity(ctx, req, launch, flags())
    }

    private fun builder(ctx: Context, ch: String): Notification.Builder {
        ensureChannels(ctx)
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(ctx, ch) else Notification.Builder(ctx)
        b.setSmallIcon(icon(ctx)).setColor(0xFF8E8BEA.toInt()).setAutoCancel(true)
        return b
    }

    private fun money(v: Double): String = NumberFormat.getCurrencyInstance(Locale("en", "IN")).format(v)

    fun simple(ctx: Context, ch: String, id: Int, title: String, text: String) {
        val b = builder(ctx, ch)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(Notification.BigTextStyle().bigText(text))
            .setContentIntent(openApp(ctx, id))
        nm(ctx).notify(id, b.build())
    }

    fun showTxn(ctx: Context, p: SmsParse.Result, body: String) {
        val key = if (p.ref != null) "ref:${p.ref}" else "body:$body"
        val nid = key.hashCode() and 0x7fffffff
        val acct = if (p.last4 != null) " · ••${p.last4}" else ""
        val title = when {
            p.atm -> "${money(p.amount)} ATM withdrawal$acct"
            p.debit -> "${money(p.amount)} debited$acct"
            else -> "${money(p.amount)} received$acct"
        }
        val time = SimpleDateFormat("h:mm a", Locale.getDefault()).format(Date())
        val b = builder(ctx, CH_TXN).setContentTitle(title).setContentIntent(openApp(ctx, nid))
        if (p.atm) {
            b.setContentText("Moved from bank to Cash · $time")
            nm(ctx).notify(nid, b.build())
            return
        }
        val party = p.party?.substringBefore('@') ?: "Bank transaction"
        val sugg = Suggest.categories(ctx, p.party, if (p.debit) "expense" else "income")
        val lead = if (p.debit) "To" else "From"
        val hint = if (sugg.isEmpty()) "" else "\nTap a category to file it"
        val text = "$lead $party · $time$hint"
        b.setContentText(text).setStyle(Notification.BigTextStyle().bigText(text))
        sugg.forEachIndexed { i, s ->
            val intent = Intent(ctx, NotifActionReceiver::class.java)
                .putExtra("key", key)
                .putExtra("cat", s.first)
                .putExtra("catName", s.second)
                .putExtra("nid", nid)
                .putExtra("title", title)
            val pi = PendingIntent.getBroadcast(ctx, nid + i + 1, intent, flags())
            b.addAction(Notification.Action.Builder(icon(ctx), s.second, pi).build())
        }
        b.addAction(Notification.Action.Builder(icon(ctx), "More…", openApp(ctx, nid + 9)).build())
        nm(ctx).notify(nid, b.build())
    }

    fun showSaved(ctx: Context, nid: Int, title: String, catName: String) {
        val b = builder(ctx, CH_TXN)
            .setContentTitle(title)
            .setContentText("Filed under $catName ✓")
            .setOnlyAlertOnce(true)
            .setContentIntent(openApp(ctx, nid))
        if (Build.VERSION.SDK_INT >= 26) b.setTimeoutAfter(5000)
        nm(ctx).notify(nid, b.build())
    }
}

class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        if (!AlertPrefs.smsAlerts(context)) return
        if (!FlutterPrefs.bool(context, "onboarded", false)) return
        try {
            val msgs = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return
            if (msgs.isEmpty()) return
            val sender = msgs[0].originatingAddress ?: ""
            val body = msgs.joinToString("") { it.messageBody ?: "" }
            val p = SmsParse.parse(sender, body) ?: return
            Notifier.showTxn(context, p, body)
        } catch (e: Exception) {
        }
    }
}

class NotifActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val key = intent.getStringExtra("key") ?: return
        val cat = intent.getIntExtra("cat", -1)
        if (cat < 0) return
        Pending.save(context, key, cat)
        Notifier.showSaved(
            context,
            intent.getIntExtra("nid", 0),
            intent.getStringExtra("title") ?: "FinUp",
            intent.getStringExtra("catName") ?: "category"
        )
    }
}
