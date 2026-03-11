package com.invoiceflow.features.dashboard.data.model

import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass

@JsonClass(generateAdapter = true)
data class KpiSummaryDto(
    val period: String,
    @Json(name = "total_invoiced") val totalInvoiced: Long,
    @Json(name = "total_paid") val totalPaid: Long,
    @Json(name = "total_outstanding") val totalOutstanding: Long,
    @Json(name = "total_overdue") val totalOverdue: Long,
    @Json(name = "invoice_count") val invoiceCount: Int,
    @Json(name = "paid_count") val paidCount: Int,
    @Json(name = "overdue_count") val overdueCount: Int,
    val currency: String,
)
