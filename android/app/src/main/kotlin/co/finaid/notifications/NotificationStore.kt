package co.finaid.notifications

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

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
 * Buffer nativo de notificaciones pendientes + lista de packages permitidos.
 * Flutter lo drena cuando la app abre o vuelve a primer plano.
 */
class NotificationStore private constructor(context: Context) :
    SQLiteOpenHelper(context.applicationContext, DB_NAME, null, DB_VERSION) {

    private val prefs = context.applicationContext
        .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

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
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        // v1: sin migraciones todavía.
    }

    /** @return false si ya existía (misma dedupe_key). */
    fun insert(n: PendingNotification): Boolean {
        val values = ContentValues().apply {
            put("id", n.id)
            put("pkg", n.packageName)
            put("title", n.title)
            put("body", n.text)
            put("posted_at", n.postedAt)
            put("dedupe_key", n.dedupeKey)
        }
        val row = writableDatabase.insertWithOnConflict(
            "pending", null, values, SQLiteDatabase.CONFLICT_IGNORE
        )
        return row != -1L
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
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
        return out
    }

    fun allowedPackages(): Set<String> =
        prefs.getStringSet(KEY_ALLOWED, null) ?: BankPackages.DEFAULTS

    fun setAllowedPackages(packages: Set<String>) {
        prefs.edit().putStringSet(KEY_ALLOWED, HashSet(packages)).apply()
    }

    fun isAllowed(pkg: String): Boolean = allowedPackages().contains(pkg)

    companion object {
        private const val DB_NAME = "finaid_native.db"
        private const val DB_VERSION = 1
        private const val PREFS_NAME = "finaid_native"
        private const val KEY_ALLOWED = "allowed_packages"

        @Volatile
        private var instance: NotificationStore? = null

        fun get(context: Context): NotificationStore =
            instance ?: synchronized(this) {
                instance ?: NotificationStore(context).also { instance = it }
            }
    }
}
