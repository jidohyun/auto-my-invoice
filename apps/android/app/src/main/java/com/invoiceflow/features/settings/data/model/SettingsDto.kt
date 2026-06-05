package com.invoiceflow.features.settings.data.model

import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass

@JsonClass(generateAdapter = true)
data class UserSettingsDto(
    val id: String,
    val plan: String? = null,
    val email: String? = null,
    @Json(name = "inserted_at") val insertedAt: String? = null,
    val timezone: String? = null,
    @Json(name = "avatar_url") val avatarUrl: String? = null,
    @Json(name = "brand_tone") val brandTone: String? = null,
    // Backend returns the business name as `company_name`; the settings screen reads it via `businessName`.
    @Json(name = "company_name") val businessName: String? = null,
    // Write-only on the backend (PUT /settings accepts these but GET /settings omits them),
    // so they must default for the read screen.
    @Json(name = "default_currency") val defaultCurrency: String = "KRW",
    @Json(name = "payment_terms_days") val paymentTermsDays: Int = 30,
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
