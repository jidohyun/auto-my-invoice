package com.invoiceflow.features.clients.data.model

import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass

@JsonClass(generateAdapter = true)
data class ClientDto(
    val id: String,
    val name: String,
    val email: String?,
    val phone: String?,
    val company: String?,
    val address: AddressDto? = null,
    @Json(name = "tax_id") val taxId: String? = null,
    val notes: String? = null,
    @Json(name = "invoice_count") val invoiceCount: Int = 0,
    @Json(name = "total_billed") val totalBilled: Long = 0,
    @Json(name = "inserted_at") val insertedAt: String? = null,
)

@JsonClass(generateAdapter = true)
data class AddressDto(
    val line1: String? = null,
    val line2: String? = null,
    val city: String? = null,
    val state: String? = null,
    @Json(name = "postal_code") val postalCode: String? = null,
    val country: String? = null,
)

@JsonClass(generateAdapter = true)
data class ClientRequest(
    val name: String,
    val email: String? = null,
    val phone: String? = null,
    val company: String? = null,
    val address: AddressDto? = null,
    @Json(name = "tax_id") val taxId: String? = null,
    val notes: String? = null,
)
