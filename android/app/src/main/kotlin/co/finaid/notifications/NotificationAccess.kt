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

    /** Ficha de la app en Ajustes (para "Permitir ajustes restringidos", batería, etc.). */
    fun openAppDetails(context: Context) {
        context.startActivity(
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                .setData(Uri.parse("package:${context.packageName}"))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )
    }

    /**
     * Pantallas de "Inicio automático" / "Apps protegidas" de cada fabricante.
     * Cambian entre versiones, así que se prueban en orden; si ninguna existe
     * se abre la ficha de la app.
     */
    private val AUTOSTART_SCREENS = listOf(
        // Xiaomi / Redmi / POCO (MIUI, HyperOS)
        ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity"),
        // Huawei / Honor
        ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"),
        ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.optimize.process.ProtectActivity"),
        ComponentName("com.hihonor.systemmanager", "com.hihonor.systemmanager.startupmgr.ui.StartupNormalAppListActivity"),
        // OPPO / realme / OnePlus (ColorOS)
        ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity"),
        ComponentName("com.coloros.safecenter", "com.coloros.safecenter.startupapp.StartupAppListActivity"),
        ComponentName("com.oplus.safecenter", "com.oplus.safecenter.permission.startup.StartupAppListActivity"),
        ComponentName("com.oneplus.security", "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity"),
        // vivo / iQOO
        ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"),
        ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity"),
    )

    /** @return true si se abrió la pantalla del fabricante; false si se abrió la ficha de la app. */
    fun openAutostartSettings(context: Context): Boolean {
        for (component in AUTOSTART_SCREENS) {
            val intent = Intent().setComponent(component).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            try {
                context.startActivity(intent)
                return true
            } catch (_: Exception) {
                // No existe en este teléfono o no está exportada: probar la siguiente.
            }
        }
        openAppDetails(context)
        return false
    }
}
