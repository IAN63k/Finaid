package co.finaid.notifications

import android.content.ComponentName
import android.content.Context
import android.content.Intent
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
}
