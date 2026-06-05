package com.invoiceflow.core.network

import com.invoiceflow.core.data.TokenRepository
import kotlinx.coroutines.runBlocking
import okhttp3.Interceptor
import okhttp3.Response
import java.net.HttpURLConnection
import javax.inject.Inject

class AuthInterceptor @Inject constructor(
    private val tokenRepository: TokenRepository,
) : Interceptor {
    override fun intercept(chain: Interceptor.Chain): Response {
        val token = runBlocking { tokenRepository.getAccessToken() }
        val request = if (token != null) {
            chain.request().newBuilder()
                .addHeader("Authorization", "Bearer $token")
                .build()
        } else {
            chain.request()
        }
        val response = chain.proceed(request)

        // Self-heal on a stale/invalid token: if we DID send a bearer token and
        // the server still rejects it (401), clear the token. Because isLoggedIn
        // observes the token flow, clearing it routes the app back to the login
        // screen instead of stranding the user on a dead "로그인이 필요합니다" shell.
        // A 401 on an unauthenticated request (login/register) is a normal
        // credential error and must NOT clear anything.
        if (token != null && response.code == HttpURLConnection.HTTP_UNAUTHORIZED) {
            runBlocking { tokenRepository.clearTokens() }
        }
        return response
    }
}
