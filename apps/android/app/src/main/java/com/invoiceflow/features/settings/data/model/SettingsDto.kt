package com.invoiceflow.features.settings.data.model

import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass
import com.invoiceflow.features.clients.data.model.AddressDto

@JsonClass(generateAdapter = true)
data class UserSettingsDto(
    val id: String,
    @Json(name = "user_id") val userId: String,
    @Json(name = "default_currency") val defaultCurrency: String = "KRW",
    @Json(name = "default_tax_rate") val defaultTaxRate: Double = 10.0,
    @Json(name = "invoice_prefix") val invoicePrefix: String = "INV",
    @Json(name = "next_invoice_number") val nextInvoiceNumber: Int = 1,
    @Json(name = "payment_terms_days") val paymentTermsDays: Int = 30,
    @Json(name = "business_name") val businessName: String? = null,
    @Json(name = "business_address") val businessAddress: AddressDto? = null,
    @Json(name = "business_tax_id") val businessTaxId: String? = null,
    @Json(name = "logo_url") val logoUrl: String? = null,
    @Json(name = "updated_at") val updatedAt: String,
)

@JsonClass(generateAdapter = true)
data class UserSettingsRequest(
    @Json(name = "default_currency") val defaultCurrency: String? = null,
    @Json(name = "default_tax_rate") val defaultTaxRate: Double? = null,
    @Json(name = "invoice_prefix") val invoicePrefix: String? = null,
    @Json(name = "payment_terms_days") val paymentTermsDays: Int? = null,
    @Json(name = "business_name") val businessName: String? = null,
    @Json(name = "business_tax_id") val businessTaxId: String? = null,
)
