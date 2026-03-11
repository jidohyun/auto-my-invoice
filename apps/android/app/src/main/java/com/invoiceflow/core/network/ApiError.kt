package com.invoiceflow.core.network

import com.squareup.moshi.JsonClass

@JsonClass(generateAdapter = true)
data class ApiErrorResponse(val error: ApiErrorBody)

@JsonClass(generateAdapter = true)
data class ApiErrorBody(
    val code: String,
    val message: String,
)

class ApiException(val code: String, message: String) : Exception(message)
