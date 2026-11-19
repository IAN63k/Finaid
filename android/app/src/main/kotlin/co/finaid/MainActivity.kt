package co.finaid

import android.content.Intent
import co.finaid.notifications.NotificationChannels
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * Expone a Flutter:
 *
 *  - MethodChannel `co.finaid/notifications`: permisos, estado del servicio, drenar
 *    pendientes, apps detectadas, packages permitidos, aviso de captura.
 *  - EventChannel `co.finaid/notifications/events`: notificaciones en vivo.
 *  - MethodChannel `co.finaid/documents`: guardar y abrir archivos (respaldo, CSV).
 *
 * Los canales de notificaciones también se registran en el motor en segundo plano
 * (BackgroundProcessor).
 */
class MainActivity : FlutterActivity() {

    private val documents by lazy { DocumentChannel(this) }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        NotificationChannels.registerMethodChannel(this, messenger) { this }
        NotificationChannels.registerEventChannel(messenger)
        documents.register(messenger)
    }

    @Deprecated("Activity result API clásico; FlutterActivity no es ComponentActivity")
    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (!documents.onActivityResult(requestCode, resultCode, data)) {
            super.onActivityResult(requestCode, resultCode, data)
        }
    }
}
