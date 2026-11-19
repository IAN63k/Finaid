package co.finaid

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Guardar y abrir archivos con el selector del sistema (Storage Access Framework),
 * sin pedir permisos de almacenamiento. El usuario elige el destino: Descargas,
 * Google Drive, una memoria USB, etc.
 *
 * Canal `co.finaid/documents`:
 *  - `saveDocument(fileName, mimeType, bytes)` → uri o null si se canceló.
 *  - `openDocument(mimeTypes)` → {name, bytes} o null si se canceló.
 */
class DocumentChannel(private val activity: Activity) {

    private val mainHandler = Handler(Looper.getMainLooper())
    private var pendingResult: MethodChannel.Result? = null
    private var pendingBytes: ByteArray? = null

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveDocument" -> {
                    if (!claim(result)) return@setMethodCallHandler
                    pendingBytes = call.argument<ByteArray>("bytes") ?: ByteArray(0)
                    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT)
                        .addCategory(Intent.CATEGORY_OPENABLE)
                        .setType(call.argument<String>("mimeType") ?: "application/octet-stream")
                        .putExtra(Intent.EXTRA_TITLE, call.argument<String>("fileName") ?: "finaid")
                    launch(intent, REQUEST_SAVE)
                }
                "openDocument" -> {
                    if (!claim(result)) return@setMethodCallHandler
                    val types = call.argument<List<String>>("mimeTypes") ?: emptyList()
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT)
                        .addCategory(Intent.CATEGORY_OPENABLE)
                        .setType("*/*")
                    if (types.isNotEmpty()) {
                        intent.putExtra(Intent.EXTRA_MIME_TYPES, types.toTypedArray())
                    }
                    launch(intent, REQUEST_OPEN)
                }
                else -> result.notImplemented()
            }
        }
    }

    /** Llamar desde Activity.onActivityResult. Devuelve true si la petición era nuestra. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_SAVE && requestCode != REQUEST_OPEN) return false
        val result = pendingResult
        val bytes = pendingBytes
        pendingResult = null
        pendingBytes = null
        val uri = data?.data
        if (result == null) return true
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return true
        }
        Thread {
            try {
                if (requestCode == REQUEST_SAVE) {
                    activity.contentResolver.openOutputStream(uri, "w")?.use { out ->
                        out.write(bytes ?: ByteArray(0))
                    } ?: throw IllegalStateException("No se pudo escribir en el destino")
                    post { result.success(uri.toString()) }
                } else {
                    val name = displayName(uri)
                    val content = activity.contentResolver.openInputStream(uri)?.use { input ->
                        val data = input.readBytes()
                        if (data.size > MAX_OPEN_BYTES) {
                            throw IllegalStateException("El archivo es demasiado grande")
                        }
                        data
                    } ?: throw IllegalStateException("No se pudo leer el archivo")
                    post { result.success(mapOf("name" to name, "bytes" to content)) }
                }
            } catch (e: Exception) {
                post { result.error("io_error", e.message, null) }
            }
        }.start()
        return true
    }

    private fun claim(result: MethodChannel.Result): Boolean {
        if (pendingResult != null) {
            result.error("busy", "Ya hay un selector de archivos abierto", null)
            return false
        }
        pendingResult = result
        return true
    }

    private fun launch(intent: Intent, requestCode: Int) {
        try {
            @Suppress("DEPRECATION")
            activity.startActivityForResult(intent, requestCode)
        } catch (e: Exception) {
            val r = pendingResult
            pendingResult = null
            pendingBytes = null
            r?.error("no_picker", "No hay un selector de archivos disponible", null)
        }
    }

    private fun displayName(uri: Uri): String? = try {
        activity.contentResolver.query(
            uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null
        )?.use { c -> if (c.moveToFirst()) c.getString(0) else null }
    } catch (e: Exception) {
        null
    }

    private fun post(block: () -> Unit) {
        mainHandler.post(block)
    }

    companion object {
        const val CHANNEL = "co.finaid/documents"
        private const val REQUEST_SAVE = 7201
        private const val REQUEST_OPEN = 7202
        private const val MAX_OPEN_BYTES = 50 * 1024 * 1024
    }
}
