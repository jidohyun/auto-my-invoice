package com.invoiceflow.features.analytics.data.model

import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass

/**
 * `GET /dashboard/analytics` → `{data: {...}}`. Mirrors
 * AutoMyInvoiceWeb.Api.AnalyticsController.dashboard/2.
 */
@JsonClass(generateAdapter = true)
data class DashboardAnalyticsDto(
    @Json(name = "monthly_collections") val monthlyCollections: List<MonthlyCollectionDto> = emptyList(),
    @Json(name = "status_distribution") val statusDistribution: List<StatusDistributionDto> = emptyList(),
    @Json(name = "invoice_aging") val invoiceAging: Map<String, AgingBucketDto> = emptyMap(),
)

/** One month from Analytics.monthly_collections/2. Money fields are decimal strings. */
@JsonClass(generateAdapter = true)
data class MonthlyCollectionDto(
    val month: String,
    val invoiced: String,
    val collected: String,
    val count: Int,
)

/** One status bucket from Analytics.status_distribution/1. */
@JsonClass(generateAdapter = true)
data class StatusDistributionDto(
    val status: String,
    val count: Int,
    val total: String,
)

/** One aging bucket (`0-30`, `31-60`, `61-90`, `90+`) from Analytics.invoice_aging/1. */
@JsonClass(generateAdapter = true)
data class AgingBucketDto(
    val count: Int,
    val total: String,
)

/** `GET /analytics/reminders` → `{data: {...}}`. Subset of reminder_effectiveness/1. */
@JsonClass(generateAdapter = true)
data class ReminderEffectivenessDto(
    @Json(name = "total_sent") val totalSent: Int,
    @Json(name = "total_opened") val totalOpened: Int,
    @Json(name = "total_clicked") val totalClicked: Int,
    @Json(name = "overall_open_rate") val overallOpenRate: Double,
    @Json(name = "overall_click_rate") val overallClickRate: Double,
    @Json(name = "overall_conversion_rate") val overallConversionRate: Double? = null,
    // Backend reminder_effectiveness/1 sends this as an ARRAY of per-step rows
    // (@spec :: [map()]), NOT a scalar — modeling it as Double? crashed Moshi
    // with "Expected a double but was BEGIN_ARRAY". Default emptyList() so the
    // common empty response (and any future absence) parses cleanly.
    @Json(name = "avg_days_to_payment") val avgDaysToPayment: List<AvgDaysToPaymentEntryDto> = emptyList(),
)

/** One per-step avg-days-to-payment row from reminder_effectiveness/1. */
@JsonClass(generateAdapter = true)
data class AvgDaysToPaymentEntryDto(
    val step: Int,
    @Json(name = "avg_days") val avgDays: Double,
    @Json(name = "sample_size") val sampleSize: Int,
)

/**
 * `GET /clients/:id/analytics` → `{data: {...}}`. Mirrors
 * Clients.client_analytics/1 — the per-client payment-behaviour summary.
 */
@JsonClass(generateAdapter = true)
data class ClientAnalyticsDto(
    @Json(name = "avg_payment_days") val avgPaymentDays: Double? = null,
    @Json(name = "total_invoiced") val totalInvoiced: String,
    @Json(name = "total_paid") val totalPaid: String,
    @Json(name = "on_time_rate") val onTimeRate: Double? = null,
    @Json(name = "invoice_count") val invoiceCount: Int,
    @Json(name = "paid_count") val paidCount: Int,
    @Json(name = "outstanding_amount") val outstandingAmount: String,
)

/** One client from Clients.client_ranking/1 (`GET /clients/ranking`). */
@JsonClass(generateAdapter = true)
data class ClientRankingDto(
    val id: String,
    val name: String,
    @Json(name = "avg_payment_days") val avgPaymentDays: Double? = null,
    @Json(name = "total_invoiced") val totalInvoiced: String,
    @Json(name = "total_paid") val totalPaid: String,
    @Json(name = "on_time_rate") val onTimeRate: Double? = null,
)
