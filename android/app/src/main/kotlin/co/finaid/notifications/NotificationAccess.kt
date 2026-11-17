package co.finaid.notifications

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import android.service.notification.NotificationListenerService

object NotificationAccess {

    /** Comprueba si nuestro listener aparece en `enabled_notification_listeners`. */
    fun isGranted(context: Context): Boolean {
        val flat = Settings.Secure.getString(
            context.contentResolver, "enabled_notification_listeners"
        ) ?: return false
        return flat.split(":").any { entry ->
            ComponentName.unflattenFromString(entry)?.packageName == context.packageName
        }
    }

    fun openSettings(context: Context) {
        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    }

    /** Pide al sistema volver a enlazar el servicio (tras conceder permiso). */
    fun requestRebind(context: Context) {
        NotificationListenerService.requestRebind(
            ComponentName(context, FinaidNotificationListenerService::class.java)
        )
    }

    /** true si la app está fuera de la optimización de batería (no la "duermen"). */
    fun isBatteryUnrestricted(context: Context): Boolean {
        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        return pm.isIgnoringBatteryOptimizations(context.packageName)
    }

    /**
     * Abre el diálogo del sistema para excluir a Finaid de la optimización de batería;
     * si el fabricante no lo permite, abre la ficha de la app.
     */
    fun openBatterySettings(context: Context) {
        val packageUri = Uri.parse("package:${context.packageName}")
        try {
            context.startActivity(
                Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                    .setData(packageUri)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
        } catch (e: Exception) {
            context.startActivity(
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                    .setData(packageUri)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
        }
    }
}
