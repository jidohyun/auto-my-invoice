package com.invoiceflow.features.settings.data

import com.invoiceflow.core.network.ApiService
import com.invoiceflow.features.settings.data.model.UserSettingsDto
import com.invoiceflow.features.settings.data.model.UserSettingsRequest
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SettingsRepository @Inject constructor(private val apiService: ApiService) {
    suspend fun getSettings(): UserSettingsDto = apiService.getSettings().data
    suspend fun updateSettings(request: UserSettingsRequest): UserSettingsDto =
        apiService.updateSettings(request).data
}
