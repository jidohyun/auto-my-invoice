package com.invoiceflow.features.auth.data

import com.invoiceflow.core.data.TokenRepository
import com.invoiceflow.core.network.ApiService
import com.invoiceflow.features.auth.data.model.AuthData
import com.invoiceflow.features.auth.data.model.LoginRequest
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
        tokenRepository.saveToken(response.data.token)
        return response.data
    }

    suspend fun register(email: String, password: String, companyName: String?): AuthData {
        val response = apiService.register(
            RegisterRequest(email, password, companyName?.takeIf { it.isNotBlank() })
        )
        tokenRepository.saveToken(response.data.token)
        return response.data
    }

    suspend fun logout() {
        try { apiService.logout() } catch (_: Exception) {}
        tokenRepository.clearTokens()
    }

    fun isLoggedIn(): Flow<Boolean> = tokenRepository.accessTokenFlow.map { it != null }
}
