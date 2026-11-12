package co.finaid.notifications

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
        "com.bbva.nxt_colombia",            // BBVA
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
