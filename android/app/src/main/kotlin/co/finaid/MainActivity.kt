package co.finaid

import co.finaid.notifications.NotificationChannels
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * Expone a Flutter el servicio de escucha de notificaciones:
 *
 *  - MethodChannel `co.finaid/notifications`: permisos, estado del servicio, drenar
 *    pendientes, apps detectadas, packages permitidos, aviso de captura.
 *  - EventChannel `co.finaid/notifications/events`: notificaciones en vivo.
 *
 * Los mismos canales se registran en el motor en segundo plano (BackgroundProcessor).
 */
class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        NotificationChannels.registerMethodChannel(this, messenger) { this }
        NotificationChannels.registerEventChannel(messenger)
    }
}
