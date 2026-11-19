package co.finaid.notifications

import android.content.ContentValues
import android.content.Context
import android.content.pm.PackageManager
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import java.util.concurrent.ConcurrentHashMap

data class PendingNotification(
    val id: String,
    val packageName: String,
    val title: String?,
    val text: String,
    val postedAt: Long,
    val dedupeKey: String,
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "id" to id,
        "package" to packageName,
        "title" to title,
        "text" to text,
        "postedAt" to postedAt,
        "dedupeKey" to dedupeKey,
    )
}

/**
 * Buffer nativo de notificaciones pendientes, memoria de claves ya vistas (para no
 * re-entregar lo que sigue en la bandeja), apps detectadas y listas de packages
 * permitidos / desactivados por el usuario. Flutter lo drena cuando la app abre,
 * vuelve a primer plano o desde el motor en segundo plano.
 */
class NotificationStore private constructor(context: Context) :
    SQLiteOpenHelper(context.applicationContext, DB_NAME, null, DB_VERSION) {

    private val appContext = context.applicationContext
    private val prefs = appContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private val labelCache = ConcurrentHashMap<String, String>()

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE pending (
                id TEXT PRIMARY KEY,
                pkg TEXT NOT NULL,
                title TEXT,
                body TEXT NOT NULL,
                posted_at INTEGER NOT NULL,
                dedupe_key TEXT NOT NULL UNIQUE
            )
            """.trimIndent()
        )
        createV2Tables(db)
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        if (oldVersion < 2) createV2Tables(db)
    }

    private fun createV2Tables(db: SQLiteDatabase) {
        db.execSQL(
            "CREATE TABLE IF NOT EXISTS seen_keys (dedupe_key TEXT PRIMARY KEY, ts INTEGER NOT NULL)"
        )
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS seen_packages (
                pkg TEXT PRIMARY KEY,
                count INTEGER NOT NULL DEFAULT 0,
                last_seen INTEGER NOT NULL
            )
            """.trimIndent()
        )
    }

    /**
     * Inserta la notificación si su clave no se había visto antes.
     * @return false si ya estaba en el buffer o ya fue entregada.
     */
    fun insert(n: PendingNotification): Boolean {
        val db = writableDatabase
        db.beginTransaction()
        try {
            val seen = ContentValues().apply {
                put("dedupe_key", n.dedupeKey)
                put("ts", n.postedAt)
            }
            val seenRow = db.insertWithOnConflict(
                "seen_keys", null, seen, SQLiteDatabase.CONFLICT_IGNORE
            )
            if (seenRow == -1L) {
                db.setTransactionSuccessful()
                return false
            }
            val values = ContentValues().apply {
                put("id", n.id)
                put("pkg", n.packageName)
                put("title", n.title)
                put("body", n.text)
                put("posted_at", n.postedAt)
                put("dedupe_key", n.dedupeKey)
            }
            val row = db.insertWithOnConflict(
                "pending", null, values, SQLiteDatabase.CONFLICT_IGNORE
            )
            db.setTransactionSuccessful()
            return row != -1L
        } finally {
            db.endTransaction()
        }
    }

    /** Devuelve y borra todo lo pendiente, de forma atómica. */
    fun drainAll(): List<Map<String, Any?>> {
        val db = writableDatabase
        val out = mutableListOf<Map<String, Any?>>()
        db.beginTransaction()
        try {
            db.query("pending", null, null, null, null, null, "posted_at ASC").use { c ->
                val idIdx = c.getColumnIndexOrThrow("id")
                val pkgIdx = c.getColumnIndexOrThrow("pkg")
                val titleIdx = c.getColumnIndexOrThrow("title")
                val bodyIdx = c.getColumnIndexOrThrow("body")
                val postedIdx = c.getColumnIndexOrThrow("posted_at")
                val keyIdx = c.getColumnIndexOrThrow("dedupe_key")
                while (c.moveToNext()) {
                    out.add(
                        PendingNotification(
                            id = c.getString(idIdx),
                            packageName = c.getString(pkgIdx),
                            title = if (c.isNull(titleIdx)) null else c.getString(titleIdx),
                            text = c.getString(bodyIdx),
                            postedAt = c.getLong(postedIdx),
                            dedupeKey = c.getString(keyIdx),
                        ).toMap()
                    )
                }
            }
            db.delete("pending", null, null)
            // Olvida claves viejas para que la tabla no crezca sin límite.
            val cutoff = System.currentTimeMillis() - SEEN_KEYS_TTL_MS
            db.delete("seen_keys", "ts < ?", arrayOf(cutoff.toString()))
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
        return out
    }

    fun pendingCount(): Int {
        readableDatabase.rawQuery("SELECT COUNT(*) FROM pending", null).use { c ->
            return if (c.moveToFirst()) c.getInt(0) else 0
        }
    }

    /** Registra que una app emitió una notificación (solo package y conteo, sin contenido). */
    fun recordSeen(pkg: String, at: Long) {
        val db = writableDatabase
        val values = ContentValues().apply {
            put("pkg", pkg)
            put("count", 0)
            put("last_seen", at)
        }
        db.insertWithOnConflict("seen_packages", null, values, SQLiteDatabase.CONFLICT_IGNORE)
        db.execSQL(
            "UPDATE seen_packages SET count = count + 1, last_seen = ? WHERE pkg = ?",
            arrayOf<Any>(at, pkg)
        )
    }

    fun seenPackages(): List<Map<String, Any?>> {
        val out = mutableListOf<Map<String, Any?>>()
        readableDatabase.query(
            "seen_packages", null, null, null, null, null, "last_seen DESC", "200"
        ).use { c ->
            val pkgIdx = c.getColumnIndexOrThrow("pkg")
            val countIdx = c.getColumnIndexOrThrow("count")
            val lastIdx = c.getColumnIndexOrThrow("last_seen")
            while (c.moveToNext()) {
                val pkg = c.getString(pkgIdx)
                out.add(
                    mapOf(
                        "package" to pkg,
                        "label" to appLabel(pkg),
                        "count" to c.getInt(countIdx),
                        "lastSeen" to c.getLong(lastIdx),
                        "allowed" to isAllowed(pkg),
                    )
                )
            }
        }
        return out
    }

    /** Nombre visible de la app (cacheado). */
    fun appLabel(pkg: String): String = labelCache.getOrPut(pkg) {
        try {
            val pm = appContext.packageManager
            pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
        } catch (e: PackageManager.NameNotFoundException) {
            pkg
        } catch (e: Exception) {
            pkg
        }
    }

    fun allowedPackages(): Set<String> =
        prefs.getStringSet(KEY_ALLOWED, null) ?: BankPackages.DEFAULTS

    fun setAllowedPackages(packages: Set<String>) {
        prefs.edit().putStringSet(KEY_ALLOWED, HashSet(packages)).apply()
    }

    /** Packages que el usuario desactivó explícitamente (ganan sobre la detección). */
    fun disabledPackages(): Set<String> =
        prefs.getStringSet(KEY_DISABLED, null) ?: emptySet()

    fun setDisabledPackages(packages: Set<String>) {
        prefs.edit().putStringSet(KEY_DISABLED, HashSet(packages)).apply()
    }

    /**
     * Se escucha una app si el usuario la activó, o si parece una app bancaria y
     * el usuario no la desactivó.
     */
    fun isAllowed(pkg: String): Boolean {
        if (allowedPackages().contains(pkg)) return true
        if (disabledPackages().contains(pkg)) return false
        return BankDetector.looksLikeBank(pkg, appLabel(pkg))
    }

    companion object {
        private const val DB_NAME = "finaid_native.db"
        private const val DB_VERSION = 2
        private const val PREFS_NAME = "finaid_native"
        private const val KEY_ALLOWED = "allowed_packages"
        private const val KEY_DISABLED = "disabled_packages"
        private const val SEEN_KEYS_TTL_MS = 14L * 24 * 60 * 60 * 1000

        @Volatile
        private var instance: NotificationStore? = null

        fun get(context: Context): NotificationStore =
            instance ?: synchronized(this) {
                instance ?: NotificationStore(context).also { instance = it }
            }
    }
}
