package com.invoiceflow.features.notifications.data.model

import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass

/**
 * AMI-41/72: payload for POST /api/v1/devices.
 *
 * Registers (or refreshes) the FCM token for the signed-in user so the
 * backend can target this device with payment / overdue / reminder pushes.
 * The contract pre-agreed with the server team:
 *
 *     POST /api/v1/devices
 *     { "token": "<fcm_token>", "platform": "android" }
 *
 * Idempotent on (user_id, token).
 */
@JsonClass(generateAdapter = true)
data class DeviceRegistrationRequest(
    val token: String,
    val platform: String = "android",
)

@JsonClass(generateAdapter = true)
data class DeviceDto(
    val id: String,
    val token: String,
    val platform: String,
    @Json(name = "inserted_at") val insertedAt: String? = null,
    @Json(name = "updated_at") val updatedAt: String? = null,
)
