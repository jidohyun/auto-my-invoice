package com.invoiceflow.features.qr.data

import java.net.URI

/**
 * AMI-42/72: extracts the invoice id from a scanned pay URL.
 *
 * Supported shapes (backend pay links + deep links):
 *   - https://app.invoiceflow.app/pay/<invoice_id>
 *   - https://app.invoiceflow.app/invoices/<invoice_id>
 *   - https://app.invoiceflow.app/pay?invoice_id=<invoice_id>
 *   - invoiceflow://invoices/<invoice_id>
 *
 * Implemented with [java.net.URI] (not android.net.Uri) so the logic is
 * unit-testable on the JVM. Returns null when the payload is not a
 * recognizable invoice link, so the scanner keeps scanning instead of
 * navigating to a bad route.
 */
object InvoicePayUrlParser {

    private val ID_QUERY_KEYS = listOf("invoice_id", "invoiceId", "id")
    private val PATH_SEGMENTS = setOf("pay", "invoices", "invoice")

    fun parseInvoiceId(raw: String?): String? {
        val value = raw?.trim().orEmpty()
        if (value.isEmpty()) return null

        val uri = runCatching { URI(value) }.getOrNull() ?: return null

        // 1) Query param form: ...?invoice_id=<id>
        queryParam(uri.rawQuery)?.let { return it }

        // 2) Path form: .../pay/<id> or .../invoices/<id>
        // host carries the first segment for scheme://invoices/<id> style links.
        val segments = buildList {
            uri.host?.takeIf { it.isNotBlank() }?.let { add(it) }
            uri.path.orEmpty().split('/').filter { it.isNotBlank() }.forEach { add(it) }
        }
        val idx = segments.indexOfFirst { it.lowercase() in PATH_SEGMENTS }
        if (idx >= 0 && idx + 1 < segments.size) {
            val candidate = segments[idx + 1]
            if (candidate.isNotBlank()) return candidate
        }

        return null
    }

    private fun queryParam(rawQuery: String?): String? {
        if (rawQuery.isNullOrBlank()) return null
        val pairs = rawQuery.split('&').mapNotNull { part ->
            val eq = part.indexOf('=')
            if (eq <= 0) null else part.substring(0, eq) to part.substring(eq + 1)
        }
        ID_QUERY_KEYS.forEach { key ->
            pairs.firstOrNull { it.first == key }?.second?.takeIf { it.isNotBlank() }?.let { return it }
        }
        return null
    }
}
