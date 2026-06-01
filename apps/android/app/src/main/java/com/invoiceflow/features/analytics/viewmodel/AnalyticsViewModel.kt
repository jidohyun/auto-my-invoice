package com.invoiceflow.features.analytics.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.invoiceflow.features.analytics.data.AnalyticsRepository
import com.invoiceflow.features.analytics.data.model.ClientRankingDto
import com.invoiceflow.features.analytics.data.model.DashboardAnalyticsDto
import com.invoiceflow.features.analytics.data.model.ReminderEffectivenessDto
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class AnalyticsState(
    val analytics: DashboardAnalyticsDto? = null,
    val reminders: ReminderEffectivenessDto? = null,
    val ranking: List<ClientRankingDto> = emptyList(),
    val isLoading: Boolean = false,
    val error: String? = null,
)

@HiltViewModel
class AnalyticsViewModel @Inject constructor(
    private val repository: AnalyticsRepository,
) : ViewModel() {

    private val _state = MutableStateFlow(AnalyticsState())
    val state: StateFlow<AnalyticsState> = _state.asStateFlow()

    fun load() {
        _state.update { it.copy(isLoading = true, error = null) }
        viewModelScope.launch {
            runCatching {
                coroutineScope {
                    // Fan out the three independent reads concurrently.
                    val analytics = async { repository.getDashboardAnalytics() }
                    val reminders = async { repository.getReminderEffectiveness() }
                    val ranking = async { repository.getClientRanking() }
                    Triple(analytics.await(), reminders.await(), ranking.await())
                }
            }
                .onSuccess { (analytics, reminders, ranking) ->
                    _state.update {
                        it.copy(
                            analytics = analytics,
                            reminders = reminders,
                            ranking = ranking,
                            isLoading = false,
                        )
                    }
                }
                .onFailure { e ->
                    _state.update { it.copy(isLoading = false, error = e.message ?: "분석 정보를 불러오지 못했습니다") }
                }
        }
    }
}
