package co.finaid.notifications

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

/**
 * Programa los recordatorios de pagos recurrentes que calcula Dart
 * (ReminderPlanner) con AlarmManager, para que lleguen aunque la app esté
 * cerrada. Usa alarmas inexactas que respetan el ahorro de batería
 * (setAndAllowWhileIdle): no requieren el permiso de alarmas exactas y pueden
 * llegar unos minutos tarde, lo que basta para un aviso de "mañana se cobra".
 *
 * La lista se guarda para reprogramarla tras reiniciar el teléfono o
 * actualizar la app (ReminderBootReceiver).
 */
object ReminderScheduler {

    private const val TAG = "FinaidReminders"
    private const val PREFS = "finaid_reminders"
    private const val KEY_ITEMS = "items"

    const val EXTRA_ID = "co.finaid.REMINDER_ID"
    const val EXTRA_TITLE = "co.finaid.REMINDER_TITLE"
    const val EXTRA_BODY = "co.finaid.REMINDER_BODY"
    const val EXTRA_PRIVATE = "co.finaid.REMINDER_PRIVATE"

    /** Reemplaza todos los recordatorios programados por [items]. */
    fun schedule(context: Context, items: List<Map<String, Any?>>) {
        val app = context.applicationContext
        cancelStored(app)
        val array = JSONArray()
        for (item in items) {
            val json = JSONObject()
            json.put("id", (item["id"] as Number).toInt())
            json.put("at", (item["at"] as Number).toLong())
            json.put("title", item["title"] as? String ?: "Finaid")
            json.put("body", item["body"] as? String ?: "")
            json.put("private", item["private"] == true)
            array.put(json)
        }
        prefs(app).edit().putString(KEY_ITEMS, array.toString()).apply()
        val scheduled = setAlarms(app, array)
        Log.i(TAG, "Recordatorios programados: $scheduled")
    }

    /** Vuelve a programar lo guardado (tras reiniciar o actualizar). */
    fun reschedule(context: Context) {
        val app = context.applicationContext
        val array = stored(app)
        val scheduled = setAlarms(app, array)
        Log.i(TAG, "Recordatorios reprogramados: $scheduled")
    }

    private fun setAlarms(context: Context, array: JSONArray): Int {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val now = System.currentTimeMillis()
        var count = 0
        for (i in 0 until array.length()) {
            val o = array.getJSONObject(i)
            val at = o.getLong("at")
            if (at <= now) continue
            val pending = pendingIntent(
                context,
                o.getInt("id"),
                o.optString("title"),
                o.optString("body"),
                o.optBoolean("private"),
                PendingIntent.FLAG_UPDATE_CURRENT,
            ) ?: continue
            manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending)
            count++
        }
        return count
    }

    private fun cancelStored(context: Context) {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val array = stored(context)
        for (i in 0 until array.length()) {
            val id = array.getJSONObject(i).getInt("id")
            pendingIntent(context, id, null, null, false, PendingIntent.FLAG_NO_CREATE)?.let {
                manager.cancel(it)
                it.cancel()
            }
        }
    }

    private fun pendingIntent(
        context: Context,
        id: Int,
        title: String?,
        body: String?,
        hidden: Boolean,
        flags: Int,
    ): PendingIntent? {
        val intent = Intent(context, ReminderReceiver::class.java)
            .setAction(ACTION_REMIND)
            .putExtra(EXTRA_ID, id)
            .putExtra(EXTRA_TITLE, title)
            .putExtra(EXTRA_BODY, body)
            .putExtra(EXTRA_PRIVATE, hidden)
        return PendingIntent.getBroadcast(
            context, id, intent, flags or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun stored(context: Context): JSONArray = try {
        JSONArray(prefs(context).getString(KEY_ITEMS, "[]"))
    } catch (e: Exception) {
        JSONArray()
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    const val ACTION_REMIND = "co.finaid.action.REMIND"
}

/** Muestra el recordatorio cuando llega la alarma. */
class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ReminderScheduler.ACTION_REMIND) return
        CaptureNotifier.showReminder(
            context,
            intent.getIntExtra(ReminderScheduler.EXTRA_ID, 0),
            intent.getStringExtra(ReminderScheduler.EXTRA_TITLE) ?: "Finaid",
            intent.getStringExtra(ReminderScheduler.EXTRA_BODY) ?: "",
            intent.getBooleanExtra(ReminderScheduler.EXTRA_PRIVATE, false),
        )
    }
}

/** Las alarmas se borran al reiniciar el teléfono o actualizar la app: se reprograman. */
class ReminderBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED -> ReminderScheduler.reschedule(context)
        }
    }
}
