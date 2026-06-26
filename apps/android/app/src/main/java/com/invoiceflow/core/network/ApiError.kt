package com.invoiceflow.core.network

import com.squareup.moshi.JsonClass
import java.io.IOException

@JsonClass(generateAdapter = true)
data class ApiErrorResponse(val error: ApiErrorBody)

@JsonClass(generateAdapter = true)
data class ApiErrorBody(
    val code: String,
    val message: String,
)

/**
 * Carries the server-supplied error code and a human-readable message. Thrown
 * by [ErrorMappingInterceptor] so that ViewModels can surface the API's own
 * "Invalid credentials" / "Not found" copy instead of Retrofit's raw
 * "HTTP 401 Unauthorized" string.
 *
 * Extends [IOException] on purpose: an OkHttp interceptor that throws a plain
 * Exception crashes the dispatcher thread instead of propagating to the suspend
 * call site. IOExceptions are the contract OkHttp expects, so Retrofit surfaces
 * this to the coroutine where the repository's try/catch can handle it.
 */
class ApiException(val code: String, message: String) : IOException(message)
