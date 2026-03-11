package com.invoiceflow.features.invoices.data.model

import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass
import com.invoiceflow.features.clients.data.model.ClientDto

@JsonClass(generateAdapter = true)
data class InvoiceDto(
    val id: String,
    @Json(name = "invoice_number") val invoiceNumber: String,
    val status: String,
    val client: ClientDto?,
    @Json(name = "line_items") val lineItems: List<InvoiceLineItemDto> = emptyList(),
    val subtotal: Long = 0,
    @Json(name = "tax_amount") val taxAmount: Long = 0,
    val total: Long = 0,
    val currency: String,
    @Json(name = "issued_at") val issuedAt: String?,
    @Json(name = "due_at") val dueAt: String?,
    @Json(name = "paid_at") val paidAt: String?,
    @Json(name = "payment_method") val paymentMethod: String?,
    val notes: String?,
    @Json(name = "inserted_at") val insertedAt: String,
    @Json(name = "updated_at") val updatedAt: String,
)

@JsonClass(generateAdapter = true)
data class InvoiceLineItemDto(
    val id: String? = null,
    val description: String,
    val quantity: Double,
    @Json(name = "unit_price") val unitPrice: Long,
    @Json(name = "tax_rate") val taxRate: Double = 0.0,
    val amount: Long? = null,
)

@JsonClass(generateAdapter = true)
data class InvoiceCreateRequest(
    @Json(name = "client_id") val clientId: String,
    @Json(name = "line_items") val lineItems: List<InvoiceLineItemDto>,
    val currency: String = "KRW",
    @Json(name = "issued_at") val issuedAt: String? = null,
    @Json(name = "due_at") val dueAt: String? = null,
    val notes: String? = null,
)

@JsonClass(generateAdapter = true)
data class InvoiceUpdateRequest(
    @Json(name = "client_id") val clientId: String? = null,
    @Json(name = "line_items") val lineItems: List<InvoiceLineItemDto>? = null,
    val currency: String? = null,
    @Json(name = "issued_at") val issuedAt: String? = null,
    @Json(name = "due_at") val dueAt: String? = null,
    val notes: String? = null,
)

@JsonClass(generateAdapter = true)
data class SendInvoiceRequest(val message: String? = null)

@JsonClass(generateAdapter = true)
data class MarkPaidRequest(
    @Json(name = "paid_at") val paidAt: String? = null,
    @Json(name = "payment_method") val paymentMethod: String? = null,
    @Json(name = "payment_reference") val paymentReference: String? = null,
)
