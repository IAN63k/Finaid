package co.finaid.notifications

import android.app.Activity
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Canales que exponen el servicio de notificaciones a Flutter. Se registran tanto en el
 * motor de la interfaz (MainActivity) como en el motor en segundo plano
 * (BackgroundProcessor), por eso viven aquí y no en la Activity.
 */
object NotificationChannels {

    const val METHOD_CHANNEL = "co.finaid/notifications"
    const val EVENT_CHANNEL = "co.finaid/notifications/events"
    const val POST_NOTIFICATIONS_REQUEST = 7101

    private val mainHandler = Handler(Looper.getMainLooper())

    fun registerMethodChannel(
        context: Context,
        messenger: BinaryMessenger,
        activityProvider: () -> Activity?,
    ): MethodChannel {
        val appContext = context.applicationContext
        val store = NotificationStore.get(appContext)
        val channel = MethodChannel(messenger, METHOD_CHANNEL)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isPermissionGranted" -> result.success(NotificationAccess.isGranted(appContext))
                "isListenerConnected" -> result.success(FinaidNotificationListenerService.isConnected)
                "openSettings" -> {
                    NotificationAccess.openSettings(activityProvider() ?: appContext)
                    result.success(null)
                }
                "isBatteryUnrestricted" ->
                    result.success(NotificationAccess.isBatteryUnrestricted(appContext))
                "openBatterySettings" -> {
                    NotificationAccess.openBatterySettings(activityProvider() ?: appContext)
                    result.success(null)
                }
                "requestRebind" -> {
                    NotificationAccess.requestRebind(appContext)
                    result.success(null)
                }
                "scanActiveNotifications" -> {
                    val service = FinaidNotificationListenerService.instance
                    if (service == null) {
                        result.success(-1)
                    } else {
                        Thread {
                            val n = try {
                                service.scanActiveNotifications()
                            } catch (e: Exception) {
                                0
                            }
                            mainHandler.post { result.success(n) }
                        }.start()
                    }
                }
                "drainPending" -> Thread {
                    val rows = try {
                        store.drainAll()
                    } catch (e: Exception) {
                        emptyList()
                    }
                    mainHandler.post { result.success(rows) }
                }.start()
                "pendingCount" -> result.success(store.pendingCount())
                "getAllowedPackages" -> result.success(store.allowedPackages().toList())
                "setAllowedPackages" -> {
                    val packages = call.argument<List<String>>("packages") ?: emptyList()
                    store.setAllowedPackages(packages.toSet())
                    result.success(null)
                }
                "setDisabledPackages" -> {
                    val packages = call.argument<List<String>>("packages") ?: emptyList()
                    store.setDisabledPackages(packages.toSet())
                    result.success(null)
                }
                "getSeenPackages" -> Thread {
                    val rows = try {
                        store.seenPackages()
                    } catch (e: Exception) {
                        emptyList()
                    }
                    mainHandler.post { result.success(rows) }
                }.start()
                "hasPostNotificationPermission" ->
                    result.success(CaptureNotifier.hasPermission(appContext))
                "requestPostNotificationPermission" -> {
                    val activity = activityProvider()
                    if (Build.VERSION.SDK_INT >= 33 && activity != null &&
                        !CaptureNotifier.hasPermission(appContext)
                    ) {
                        activity.requestPermissions(
                            arrayOf("android.permission.POST_NOTIFICATIONS"),
                            POST_NOTIFICATIONS_REQUEST,
                        )
                    }
                    result.success(null)
                }
                "showCaptureNotification" -> {
                    CaptureNotifier.show(
                        appContext,
                        call.argument<String>("title") ?: "Finaid",
                        call.argument<String>("body") ?: "",
                    )
                    result.success(null)
                }
                "postSelfTest" -> result.success(CaptureNotifier.showSelfTest(appContext))
                "deviceInfo" -> result.success(
                    mapOf(
                        "manufacturer" to Build.MANUFACTURER,
                        "model" to Build.MODEL,
                        "sdk" to Build.VERSION.SDK_INT,
                        "release" to Build.VERSION.RELEASE,
                    )
                )
                else -> result.notImplemented()
            }
        }
        return channel
    }

    fun registerEventChannel(messenger: BinaryMessenger) {
        EventChannel(messenger, EVENT_CHANNEL).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                NotificationEventBus.sink = events
            }

            override fun onCancel(arguments: Any?) {
                NotificationEventBus.sink = null
            }
        })
    }
}
