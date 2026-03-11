package com.invoiceflow.features.auth.data

import com.invoiceflow.core.data.TokenRepository
import com.invoiceflow.core.network.ApiService
import com.invoiceflow.features.auth.data.model.AuthData
import com.invoiceflow.features.auth.data.model.LoginRequest
import com.invoiceflow.features.auth.data.model.RefreshTokenRequest
import com.invoiceflow.features.auth.data.model.RegisterRequest
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class AuthRepository @Inject constructor(
    private val apiService: ApiService,
    private val tokenRepository: TokenRepository,
) {
    suspend fun login(email: String, password: String): AuthData {
        val response = apiService.login(LoginRequest(email, password))
        tokenRepository.saveTokens(response.data.accessToken, response.data.refreshToken)
        return response.data
    }

    suspend fun register(email: String, password: String, name: String): AuthData {
        val response = apiService.register(RegisterRequest(email, password, name))
        tokenRepository.saveTokens(response.data.accessToken, response.data.refreshToken)
        return response.data
    }

    suspend fun refreshToken(): AuthData {
        val refreshToken = tokenRepository.getRefreshToken() ?: throw Exception("No refresh token")
        val response = apiService.refreshToken(RefreshTokenRequest(refreshToken))
        tokenRepository.saveTokens(response.data.accessToken, response.data.refreshToken)
        return response.data
    }

    suspend fun logout() {
        try { apiService.logout() } catch (_: Exception) {}
        tokenRepository.clearTokens()
    }

    fun isLoggedIn(): Flow<Boolean> = tokenRepository.accessTokenFlow.map { it != null }
}
