package co.finaid.notifications

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/**
 * Puente en memoria entre el servicio de escucha y el EventChannel de Flutter.
 * Si Flutter no está escuchando, la notificación simplemente queda en el
 * buffer SQLite y se drena después.
 */
object NotificationEventBus {

    @Volatile
    var sink: EventChannel.EventSink? = null

    private val mainHandler = Handler(Looper.getMainLooper())

    fun emit(notification: PendingNotification) {
        if (sink == null) return
        mainHandler.post {
            try {
                sink?.success(notification.toMap())
            } catch (_: Exception) {
                // El motor pudo haberse ido; el buffer sigue teniendo la fila.
            }
        }
    }
}
