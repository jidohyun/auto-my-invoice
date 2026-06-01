package com.invoiceflow.features.analytics.data

import com.invoiceflow.core.network.ApiService
import com.invoiceflow.features.analytics.data.model.ClientRankingDto
import com.invoiceflow.features.analytics.data.model.DashboardAnalyticsDto
import com.invoiceflow.features.analytics.data.model.ReminderEffectivenessDto
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class AnalyticsRepository @Inject constructor(private val apiService: ApiService) {

    suspend fun getDashboardAnalytics(): DashboardAnalyticsDto =
        apiService.getDashboardAnalytics().data

    suspend fun getReminderEffectiveness(): ReminderEffectivenessDto =
        apiService.getReminderEffectiveness().data

    suspend fun getClientRanking(): List<ClientRankingDto> =
        apiService.getClientRanking().data
}
