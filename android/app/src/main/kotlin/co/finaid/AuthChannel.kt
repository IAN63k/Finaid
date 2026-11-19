package co.finaid

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.hardware.biometrics.BiometricManager
import android.hardware.biometrics.BiometricPrompt
import android.os.Build
import android.os.CancellationSignal
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Autenticación del usuario con el bloqueo del teléfono: huella, rostro o PIN,
 * patrón o contraseña. Usa el BiometricPrompt del sistema (Android 10+) y, en
 * versiones anteriores, la pantalla de confirmación de credenciales del sistema.
 * No requiere dependencias externas ni FragmentActivity.
 *
 * Canal `co.finaid/auth`:
 *  - `status` → {available: el teléfono tiene bloqueo seguro, biometric: hay huella/rostro}
 *  - `authenticate(title, subtitle)` → "success" | "cancelled" | "lockout" | "error" | "unavailable"
 */
class AuthChannel(private val activity: Activity) {

    private var pending: MethodChannel.Result? = null
    private var cancellation: CancellationSignal? = null

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> result.success(status())
                "authenticate" -> authenticate(
                    call.argument<String>("title") ?: "Finaid",
                    call.argument<String>("subtitle"),
                    result,
                )
                else -> result.notImplemented()
            }
        }
    }

    private fun keyguard(): KeyguardManager =
        activity.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager

    private fun status(): Map<String, Any> {
        val secure = keyguard().isDeviceSecure
        var biometric = false
        try {
            if (Build.VERSION.SDK_INT >= 30) {
                val bm = activity.getSystemService(BiometricManager::class.java)
                biometric = bm?.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_WEAK) ==
                    BiometricManager.BIOMETRIC_SUCCESS
            } else if (Build.VERSION.SDK_INT == 29) {
                val bm = activity.getSystemService(BiometricManager::class.java)
                @Suppress("DEPRECATION")
                biometric = bm?.canAuthenticate() == BiometricManager.BIOMETRIC_SUCCESS
            }
        } catch (_: Exception) {
            biometric = false
        }
        return mapOf("available" to secure, "biometric" to biometric)
    }

    private fun authenticate(title: String, subtitle: String?, result: MethodChannel.Result) {
        if (pending != null) {
            result.error("busy", "Ya hay una autenticación en curso", null)
            return
        }
        if (!keyguard().isDeviceSecure) {
            result.success("unavailable")
            return
        }
        pending = result
        if (Build.VERSION.SDK_INT >= 29) {
            promptBiometric(title, subtitle)
        } else {
            confirmCredential(title, subtitle)
        }
    }

    private fun promptBiometric(title: String, subtitle: String?) {
        if (Build.VERSION.SDK_INT < 29) return
        try {
            val builder = BiometricPrompt.Builder(activity).setTitle(title)
            if (subtitle != null) builder.setSubtitle(subtitle)
            if (Build.VERSION.SDK_INT >= 30) {
                builder.setAllowedAuthenticators(
                    BiometricManager.Authenticators.BIOMETRIC_WEAK or
                        BiometricManager.Authenticators.DEVICE_CREDENTIAL
                )
            } else {
                @Suppress("DEPRECATION")
                builder.setDeviceCredentialAllowed(true)
            }
            val signal = CancellationSignal()
            cancellation = signal
            builder.build().authenticate(
                signal,
                activity.mainExecutor,
                object : BiometricPrompt.AuthenticationCallback() {
                    override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult?) {
                        finish("success")
                    }

                    override fun onAuthenticationError(errorCode: Int, errString: CharSequence?) {
                        finish(
                            when (errorCode) {
                                BiometricPrompt.BIOMETRIC_ERROR_USER_CANCELED,
                                BiometricPrompt.BIOMETRIC_ERROR_CANCELED,
                                BiometricPrompt.BIOMETRIC_ERROR_NEGATIVE_BUTTON -> "cancelled"
                                BiometricPrompt.BIOMETRIC_ERROR_LOCKOUT,
                                BiometricPrompt.BIOMETRIC_ERROR_LOCKOUT_PERMANENT -> "lockout"
                                else -> "error"
                            }
                        )
                    }
                },
            )
        } catch (e: Exception) {
            finish("error")
        }
    }

    private fun confirmCredential(title: String, subtitle: String?) {
        @Suppress("DEPRECATION")
        val intent = keyguard().createConfirmDeviceCredentialIntent(title, subtitle)
        if (intent == null) {
            finish("unavailable")
            return
        }
        try {
            @Suppress("DEPRECATION")
            activity.startActivityForResult(intent, REQUEST_CREDENTIAL)
        } catch (e: Exception) {
            finish("error")
        }
    }

    /** Llamar desde Activity.onActivityResult. Devuelve true si la petición era nuestra. */
    fun onActivityResult(requestCode: Int, resultCode: Int, @Suppress("UNUSED_PARAMETER") data: Intent?): Boolean {
        if (requestCode != REQUEST_CREDENTIAL) return false
        finish(if (resultCode == Activity.RESULT_OK) "success" else "cancelled")
        return true
    }

    private fun finish(outcome: String) {
        cancellation = null
        val result = pending
        pending = null
        result?.success(outcome)
    }

    companion object {
        const val CHANNEL = "co.finaid/auth"
        private const val REQUEST_CREDENTIAL = 7301
    }
}
