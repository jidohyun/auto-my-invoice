package com.invoiceflow.core.util

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.util.Locale

/**
 * Human-readable dates for the invoice screens. The API sends two shapes:
 *  - due_date as a plain calendar date ("2026-07-10")
 *  - sent_at / paid_at as UTC ISO-8601 instants ("2026-06-10T07:25:11Z")
 *
 * The detail screen used to print the raw instant ("Paid on: 2026-06-10T07:25:11Z").
 * These helpers render both in the device locale and time zone instead.
 */
object DateFormat {

    private val dateStyle: DateTimeFormatter =
        DateTimeFormatter.ofLocalizedDate(FormatStyle.LONG).withLocale(Locale.getDefault())

    private val dateTimeStyle: DateTimeFormatter =
        DateTimeFormatter.ofLocalizedDate(FormatStyle.LONG).withLocale(Locale.getDefault())

    /** Formats a UTC ISO-8601 instant in the device's zone, e.g. "2026년 6월 10일". */
    fun instant(raw: String?): String? {
        val value = raw?.takeIf { it.isNotBlank() } ?: return null
        return runCatching {
            Instant.parse(value).atZone(ZoneId.systemDefault()).format(dateTimeStyle)
        }.getOrElse { value }
    }

    /** Formats a plain "yyyy-MM-dd" date, e.g. "2026년 7월 10일". */
    fun date(raw: String?): String? {
        val value = raw?.takeIf { it.isNotBlank() } ?: return null
        return runCatching {
            LocalDate.parse(value).format(dateStyle)
        }.getOrElse { value }
    }
}
