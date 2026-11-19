package co.finaid.notifications

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import java.util.UUID

/**
 * Recibe todas las notificaciones del sistema, filtra las de las apps permitidas
 * (bancos, SMS, apps que parecen bancarias) y las guarda en un buffer SQLite local.
 *
 * El servicio vive aunque la app esté cerrada: Android lo enlaza mientras el usuario
 * mantenga el permiso de "Acceso a notificaciones". Al conectarse (o cuando Flutter lo
 * pide) también revisa las notificaciones que siguen en la bandeja, por si el sistema
 * lo suspendió mientras llegaban (One UI de Samsung lo hace con apps "en reposo").
 *
 * También acepta la notificación de autoprueba que publica Finaid ("Probar captura"),
 * para verificar el camino completo sin hacer un pago real. Nada sale del teléfono.
 */
class FinaidNotificationListenerService : NotificationListenerService() {

    override fun onListenerConnected() {
        super.onListenerConnected()
        instance = this
        Log.i(TAG, "Listener conectado")
        try {
            val found = scanActiveNotifications()
            if (found > 0) Log.i(TAG, "Recuperadas $found notificaciones activas")
        } catch (e: Exception) {
            Log.w(TAG, "No se pudo escanear la bandeja", e)
        }
    }

    override fun onListenerDisconnected() {
        if (instance === this) instance = null
        Log.i(TAG, "Listener desconectado")
        super.onListenerDisconnected()
    }

    override fun onDestroy() {
        if (instance === this) instance = null
        super.onDestroy()
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        try {
            handle(sbn)
        } catch (e: Exception) {
            Log.w(TAG, "Error procesando notificación", e)
        }
    }

    /**
     * Revisa lo que sigue en la bandeja. Devuelve cuántas notificaciones nuevas entraron
     * al buffer (las ya vistas se ignoran por su clave).
     */
    fun scanActiveNotifications(): Int {
        val active = activeNotifications ?: return 0
        var inserted = 0
        for (sbn in active) {
            try {
                if (handle(sbn)) inserted++
            } catch (e: Exception) {
                Log.w(TAG, "Error escaneando notificación activa", e)
            }
        }
        return inserted
    }

    /** @return true si la notificación entró al buffer (era nueva y de una app permitida). */
    private fun handle(sbn: StatusBarNotification): Boolean {
        val pkg = sbn.packageName ?: return false
        val notification = sbn.notification ?: return false
        val extras = notification.extras ?: return false

        val isSelfTest = pkg == packageName && extras.getBoolean(SelfTest.EXTRA, false)
        if (pkg == packageName && !isSelfTest) return false
        if (sbn.isOngoing) return false
        if (notification.flags and Notification.FLAG_GROUP_SUMMARY != 0) return false

        val store = NotificationStore.get(applicationContext)
        if (!isSelfTest) {
            store.recordSeen(pkg, sbn.postTime)
            if (!store.isAllowed(pkg)) {
                Log.d(TAG, "Ignorada: $pkg no está entre las fuentes")
                return false
            }
        }

        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim()
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()
        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()
        val lines = extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)
            ?.joinToString("\n") { it.toString() }

        val body = listOfNotNull(bigText, text, lines)
            .map { it.trim() }
            .filter { it.isNotEmpty() }
            .maxByOrNull { it.length } ?: return false

        val source = if (isSelfTest) SelfTest.SOURCE_PACKAGE else pkg
        val dedupeKey = "$source|${sbn.id}|${sbn.postTime}|${body.hashCode()}"
        val pending = PendingNotification(
            id = UUID.randomUUID().toString(),
            packageName = source,
            title = title,
            text = body,
            postedAt = sbn.postTime,
            dedupeKey = dedupeKey,
        )
        if (!store.insert(pending)) return false
        Log.i(TAG, "Capturada notificación de $source")

        if (NotificationEventBus.hasListener) {
            NotificationEventBus.emit(pending)
        } else {
            BackgroundProcessor.process(applicationContext)
        }
        return true
    }

    companion object {
        private const val TAG = "FinaidListener"

        @Volatile
        var instance: FinaidNotificationListenerService? = null
            private set

        val isConnected: Boolean get() = instance != null
    }
}

/** Autoprueba de captura: una notificación de Finaid que el listener acepta. */
object SelfTest {
    const val EXTRA = "co.finaid.SELF_TEST"

    /** Package lógico con el que la autoprueba llega a Dart. */
    const val SOURCE_PACKAGE = "co.finaid.selftest"
}
