package com.invoiceflow.core.util

import java.text.NumberFormat
import java.util.Currency
import java.util.Locale

/**
 * Shared currency formatting for the invoice screens. The API renders money as
 * Decimal-backed strings (e.g. "1500000.00") with a separate currency code, so
 * we parse the string and format per the invoice's own currency. KRW shows no
 * fraction digits ("₩1,500,000"); other currencies keep two.
 *
 * This replaces the per-screen `formatKrw` copies that drifted apart and the
 * raw "${currency} ${amount}" rendering on the invoice list/detail.
 */
object MoneyFormatter {
    fun format(raw: String?, currency: String?): String {
        val code = (currency ?: "KRW").uppercase()
        val n = raw?.toBigDecimalOrNull() ?: return "$code 0"

        val fmt = NumberFormat.getCurrencyInstance(localeFor(code))
        runCatching { fmt.currency = Currency.getInstance(code) }
        fmt.maximumFractionDigits = if (code == "KRW" || code == "JPY") 0 else 2
        return fmt.format(n)
    }

    private fun localeFor(code: String): Locale =
        when (code) {
            "KRW" -> Locale.KOREA
            "JPY" -> Locale.JAPAN
            "USD" -> Locale.US
            "GBP" -> Locale.UK
            "EUR" -> Locale.GERMANY
            else -> Locale.getDefault()
        }
}
