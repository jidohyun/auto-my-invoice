package com.invoiceflow.features.notifications.data

import com.invoiceflow.core.network.ApiService
import com.invoiceflow.features.notifications.data.model.DeviceDto
import com.invoiceflow.features.notifications.data.model.DeviceRegistrationRequest
import javax.inject.Inject
import javax.inject.Singleton

/**
 * AMI-41/72: thin wrapper over the /devices endpoint, mirroring the other
 * feature repositories (ClientRepository, SettingsRepository).
 */
@Singleton
class DeviceRepository @Inject constructor(private val apiService: ApiService) {

    suspend fun registerDevice(token: String, platform: String = "android"): DeviceDto =
        apiService.registerDevice(DeviceRegistrationRequest(token = token, platform = platform)).data
}
