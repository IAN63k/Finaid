package co.finaid

import android.os.Handler
import android.os.Looper
import co.finaid.notifications.NotificationAccess
import co.finaid.notifications.NotificationEventBus
import co.finaid.notifications.NotificationStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Expone a Flutter el servicio de escucha de notificaciones:
 *
 *  - MethodChannel `co.finaid/notifications`: permiso, ajustes, drenar pendientes,
 *    lista de packages permitidos.
 *  - EventChannel `co.finaid/notifications/events`: notificaciones en vivo.
 */
class MainActivity : FlutterActivity() {

    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val store = NotificationStore.get(applicationContext)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isPermissionGranted" -> result.success(NotificationAccess.isGranted(this))
                "openSettings" -> {
                    NotificationAccess.openSettings(this)
                    result.success(null)
                }
                "requestRebind" -> {
                    NotificationAccess.requestRebind(this)
                    result.success(null)
                }
                "drainPending" -> Thread {
                    val rows = try {
                        store.drainAll()
                    } catch (e: Exception) {
                        emptyList()
                    }
                    mainHandler.post { result.success(rows) }
                }.start()
                "getAllowedPackages" -> result.success(store.allowedPackages().toList())
                "setAllowedPackages" -> {
                    val packages = call.argument<List<String>>("packages") ?: emptyList()
                    store.setAllowedPackages(packages.toSet())
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(messenger, EVENT_CHANNEL).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                NotificationEventBus.sink = events
            }

            override fun onCancel(arguments: Any?) {
                NotificationEventBus.sink = null
            }
        })
    }

    companion object {
        const val METHOD_CHANNEL = "co.finaid/notifications"
        const val EVENT_CHANNEL = "co.finaid/notifications/events"
    }
}
