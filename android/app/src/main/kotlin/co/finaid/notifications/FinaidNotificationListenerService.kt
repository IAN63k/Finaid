package co.finaid.notifications

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import java.util.UUID

/**
 * Recibe todas las notificaciones del sistema, filtra las de las apps
 * permitidas (bancos, SMS) y las guarda en un buffer SQLite local.
 *
 * El servicio vive aunque la app esté cerrada: Android lo enlaza mientras el
 * usuario mantenga el permiso de "Acceso a notificaciones". Nada sale del
 * teléfono.
 */
class FinaidNotificationListenerService : NotificationListenerService() {

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.i(TAG, "Listener conectado")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        try {
            handle(sbn)
        } catch (e: Exception) {
            Log.w(TAG, "Error procesando notificación", e)
        }
    }

    private fun handle(sbn: StatusBarNotification) {
        val pkg = sbn.packageName ?: return
        if (pkg == packageName) return
        val store = NotificationStore.get(applicationContext)
        if (!store.isAllowed(pkg)) return

        val notification = sbn.notification ?: return
        if (sbn.isOngoing) return
        if (notification.flags and Notification.FLAG_GROUP_SUMMARY != 0) return

        val extras = notification.extras ?: return
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim()
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()
        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()
        val lines = extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)
            ?.joinToString("\n") { it.toString() }

        val body = listOfNotNull(bigText, text, lines)
            .map { it.trim() }
            .filter { it.isNotEmpty() }
            .maxByOrNull { it.length } ?: return

        val dedupeKey = "$pkg|${sbn.id}|${sbn.postTime}|${body.hashCode()}"
        val pending = PendingNotification(
            id = UUID.randomUUID().toString(),
            packageName = pkg,
            title = title,
            text = body,
            postedAt = sbn.postTime,
            dedupeKey = dedupeKey,
        )
        if (store.insert(pending)) {
            NotificationEventBus.emit(pending)
        }
    }

    companion object {
        private const val TAG = "FinaidListener"
    }
}
