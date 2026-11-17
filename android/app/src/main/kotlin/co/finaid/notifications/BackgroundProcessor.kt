package co.finaid.notifications

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * Motor Flutter sin interfaz que procesa las notificaciones capturadas cuando la app
 * no está abierta. Ejecuta el entrypoint Dart `backgroundMain` (lib/background.dart),
 * que drena el buffer, parsea, guarda y pide el aviso de captura.
 *
 * El motor se crea una sola vez por proceso y se reutiliza.
 */
object BackgroundProcessor {

    private const val TAG = "FinaidBackground"
    private const val ENTRYPOINT = "backgroundMain"
    private const val CHANNEL = "co.finaid/background"

    private val mainHandler = Handler(Looper.getMainLooper())
    private var engine: FlutterEngine? = null
    private var channel: MethodChannel? = null
    private var ready = false
    private var requestPending = false

    fun process(context: Context) {
        val appContext = context.applicationContext
        mainHandler.post {
            try {
                ensureEngine(appContext)
            } catch (e: Exception) {
                Log.w(TAG, "No se pudo iniciar el motor en segundo plano", e)
                return@post
            }
            if (ready) {
                channel?.invokeMethod("processPending", null)
            } else {
                requestPending = true
            }
        }
    }

    private fun ensureEngine(context: Context) {
        if (engine != null) return
        val loader = FlutterInjector.instance().flutterLoader()
        if (!loader.initialized()) {
            loader.startInitialization(context)
        }
        loader.ensureInitializationComplete(context, null)

        val newEngine = FlutterEngine(context)
        val messenger = newEngine.dartExecutor.binaryMessenger
        NotificationChannels.registerMethodChannel(context, messenger) { null }
        channel = MethodChannel(messenger, CHANNEL).also { ch ->
            ch.setMethodCallHandler { call, result ->
                when (call.method) {
                    "ready" -> {
                        ready = true
                        result.success(null)
                        if (requestPending) {
                            requestPending = false
                            ch.invokeMethod("processPending", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }
        val entrypoint = DartExecutor.DartEntrypoint(loader.findAppBundlePath(), ENTRYPOINT)
        newEngine.dartExecutor.executeDartEntrypoint(entrypoint)
        engine = newEngine
        Log.i(TAG, "Motor en segundo plano iniciado")
    }
}
