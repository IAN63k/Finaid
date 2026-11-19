package co.finaid.notifications

import java.text.Normalizer

/**
 * Packages escuchados por defecto hasta que Flutter sincronice la lista del
 * usuario. Debe coincidir con `KnownBanks` en Dart.
 */
object BankPackages {
    val DEFAULTS: Set<String> = setOf(
        // Bancos y billeteras (Colombia)
        "com.todo1.mobile",                 // Bancolombia Personas
        "com.bancolombia.personas",
        "com.nequi.MobileApp",              // Nequi
        "com.davivienda.daviplataapp",      // DaviPlata
        "com.davivienda.daviviendaapp",     // Davivienda
        "com.davivienda.mobileapp",
        "com.nu.production",                // Nu
        "co.com.bbva.mb",                   // BBVA Colombia | Banca Móvil
        "co.com.bancodebogota.bancamovil",  // Banco de Bogotá
        "com.bancodebogota.bancamovil",
        "co.lulobank.app",                  // Lulo Bank
        "com.lulobank.app",
        "com.rappi.pay",                    // RappiPay
        "com.scotiabankcolpatria.app",      // Scotiabank Colpatria
        "co.com.scotiabankcolpatria",
        // Apps de SMS (los bancos también avisan por mensaje de texto)
        "com.google.android.apps.messaging",
        "com.samsung.android.messaging",
        "com.android.mms",
        "com.android.messaging",
    )
}

/**
 * Reconoce apps bancarias por su package o su nombre visible, para escucharlas
 * aunque su package no esté en la lista (los bancos cambian de package y no
 * siempre se conoce el correcto). Debe coincidir con `BankDetector` en Dart.
 */
object BankDetector {

    private val KEYWORDS = listOf(
        "bbva", "bancolombia", "todo1", "nequi", "davivienda", "daviplata", "nubank",
        "bancodebogota", "banco de bogota", "lulobank", "lulo bank", "rappipay", "rappi pay",
        "scotiabank", "colpatria", "itau", "avvillas", "av villas", "bancoomeva",
        "bancodeoccidente", "banco de occidente", "bancopopular", "banco popular",
        "bancofalabella", "banco falabella", "cajasocial", "caja social", "pichincha",
        "movii", "bancoagrario", "banco agrario", "finandina", "serfinanza", "sudameris",
        "bancamia", "coopcentral", "uala", "global66", "tpaga",
        // Genéricos
        "banco", "bank", "banca movil", "bancamovil",
    )

    fun looksLikeBank(pkg: String, label: String?): Boolean {
        val hay = normalize("$pkg ${label ?: ""}")
        return KEYWORDS.any { hay.contains(it) }
    }

    private fun normalize(s: String): String =
        Normalizer.normalize(s, Normalizer.Form.NFD)
            .replace(Regex("\\p{Mn}+"), "")
            .lowercase()
}
