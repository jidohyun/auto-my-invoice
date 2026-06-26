package com.invoiceflow.core.network

import android.content.Context
import com.invoiceflow.R
import com.squareup.moshi.Moshi
import dagger.hilt.android.qualifiers.ApplicationContext
import okhttp3.Interceptor
import okhttp3.Response
import java.io.IOException
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Translates failed HTTP responses into [ApiException] carrying a human-readable
 * message. Retrofit otherwise throws an HttpException whose `.message` is the raw
 * "HTTP 401 Unauthorized" status line, which leaked all the way to the login
 * snackbar ("HTTP 401"). We prefer the server's own `{"error":{"message":...}}`
 * copy and fall back to localized per-status text when the body is empty.
 *
 * Runs as an application interceptor so every Retrofit call benefits without each
 * repository/ViewModel having to map errors itself.
 */
@Singleton
class ErrorMappingInterceptor @Inject constructor(
    @ApplicationContext private val context: Context,
    moshi: Moshi,
) : Interceptor {

    private val errorAdapter = moshi.adapter(ApiErrorResponse::class.java)

    override fun intercept(chain: Interceptor.Chain): Response {
        val response = try {
            chain.proceed(chain.request())
        } catch (e: IOException) {
            // No response at all: DNS failure, timeout, airplane mode, etc.
            throw ApiException("network_error", context.getString(R.string.error_network))
        }

        if (response.isSuccessful) return response

        // Peek the body without consuming it for the caller. The error path
        // short-circuits with an exception, so the body is read here only.
        val raw = runCatching { response.peekBody(Long.MAX_VALUE).string() }.getOrNull()
        val serverMessage = raw
            ?.takeIf { it.isNotBlank() }
            ?.let { body -> runCatching { errorAdapter.fromJson(body) }.getOrNull() }
            ?.error

        val code = serverMessage?.code ?: "http_${response.code}"
        val message = serverMessage?.message?.takeIf { it.isNotBlank() }
            ?: fallbackMessageFor(response.code)

        response.close()
        throw ApiException(code, message)
    }

    private fun fallbackMessageFor(status: Int): String = when (status) {
        401 -> context.getString(R.string.error_unauthorized)
        403 -> context.getString(R.string.error_forbidden)
        404 -> context.getString(R.string.error_not_found)
        in 500..599 -> context.getString(R.string.error_server)
        else -> context.getString(R.string.error_unknown)
    }
}
