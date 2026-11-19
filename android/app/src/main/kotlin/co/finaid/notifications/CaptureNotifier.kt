package co.finaid.notifications

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import co.finaid.R

/** Avisos propios de Finaid: movimiento registrado y autoprueba de captura. */
object CaptureNotifier {

    private const val CHANNEL_ID = "finaid_captures"
    private const val BUDGET_CHANNEL_ID = "finaid_budget"
    private const val REMINDER_CHANNEL_ID = "finaid_reminders"
    private const val SELF_TEST_ID = 0x5E1F

    fun hasPermission(context: Context): Boolean =
        Build.VERSION.SDK_INT < 33 ||
            context.checkSelfPermission("android.permission.POST_NOTIFICATIONS") ==
            PackageManager.PERMISSION_GRANTED

    private fun ensureChannels(manager: NotificationManager) {
        if (Build.VERSION.SDK_INT < 26) return
        if (manager.getNotificationChannel(CHANNEL_ID) == null) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID, "Movimientos detectados", NotificationManager.IMPORTANCE_DEFAULT
                ).apply { description = "Aviso cuando Finaid registra una compra, pago o ingreso" }
            )
        }
        if (manager.getNotificationChannel(BUDGET_CHANNEL_ID) == null) {
            manager.createNotificationChannel(
                NotificationChannel(
                    BUDGET_CHANNEL_ID, "Alertas de presupuesto", NotificationManager.IMPORTANCE_HIGH
                ).apply { description = "Cuando un gasto te lleva al 80% o al 100% del presupuesto" }
            )
        }
        if (manager.getNotificationChannel(REMINDER_CHANNEL_ID) == null) {
            manager.createNotificationChannel(
                NotificationChannel(
                    REMINDER_CHANNEL_ID, "Recordatorios de pagos", NotificationManager.IMPORTANCE_DEFAULT
                ).apply { description = "Avisos antes de pagos mensuales: suscripciones, servicios, arriendo" }
            )
        }
    }

    private fun builder(
        context: Context,
        manager: NotificationManager,
        channelId: String = CHANNEL_ID,
    ): Notification.Builder {
        ensureChannels(manager)
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val pending = if (launch == null) null else PendingIntent.getActivity(
            context, 0, launch, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        @Suppress("DEPRECATION")
        val b = if (Build.VERSION.SDK_INT >= 26) {
            Notification.Builder(context, channelId)
        } else {
            Notification.Builder(context).setPriority(Notification.PRIORITY_DEFAULT)
        }
        b.setSmallIcon(R.drawable.ic_stat_finaid)
            .setColor(0xFF0E7C6B.toInt())
            .setAutoCancel(true)
        if (pending != null) b.setContentIntent(pending)
        return b
    }

    /**
     * @param hideOnLockScreen con el bloqueo de Finaid activo, en la pantalla de
     *   bloqueo del teléfono solo se ve "Nuevo movimiento registrado", sin montos.
     */
    fun show(
        context: Context,
        title: String,
        body: String,
        budget: Boolean = false,
        hideOnLockScreen: Boolean = false,
    ) {
        if (!hasPermission(context)) return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = if (budget) BUDGET_CHANNEL_ID else CHANNEL_ID
        val b = builder(context, manager, channel)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
        if (hideOnLockScreen) {
            val publicVersion = builder(context, manager, channel)
                .setContentTitle("Finaid")
                .setContentText(if (budget) "Alerta de presupuesto" else "Nuevo movimiento registrado")
                .build()
            b.setVisibility(Notification.VISIBILITY_PRIVATE).setPublicVersion(publicVersion)
        }
        val notification = b.build()
        val id = (System.currentTimeMillis() and 0x7fffffff).toInt()
        manager.notify(id, notification)
    }

    /** Recordatorio de un pago recurrente (lo dispara ReminderReceiver). */
    fun showReminder(context: Context, id: Int, title: String, body: String, hideOnLockScreen: Boolean) {
        if (!hasPermission(context)) return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val b = builder(context, manager, REMINDER_CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
        if (hideOnLockScreen) {
            val publicVersion = builder(context, manager, REMINDER_CHANNEL_ID)
                .setContentTitle("Finaid")
                .setContentText("Recordatorio de pago")
                .build()
            b.setVisibility(Notification.VISIBILITY_PRIVATE).setPublicVersion(publicVersion)
        }
        manager.notify(id, b.build())
    }

    /**
     * Publica la notificación de autoprueba. El listener la reconoce por el extra
     * [SelfTest.EXTRA] y la procesa como si viniera de un banco.
     * @return false si no hay permiso para publicar notificaciones.
     */
    fun showSelfTest(context: Context): Boolean {
        if (!hasPermission(context)) return false
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val body = "Compraste \$1.000 en PRUEBA FINAID con tu tarjeta *0000."
        val b = builder(context, manager)
            .setContentTitle("Finaid · prueba de captura")
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .addExtras(Bundle().apply { putBoolean(SelfTest.EXTRA, true) })
        if (Build.VERSION.SDK_INT >= 26) b.setTimeoutAfter(15_000)
        manager.notify(SELF_TEST_ID, b.build())
        return true
    }
}
