package com.invoiceflow.features.settings.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.invoiceflow.features.settings.data.SettingsRepository
import com.invoiceflow.features.settings.data.model.UserSettingsRequest
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * AMI-43: settings screen state.
 *
 * Profile (company/business name), default currency and payment terms are
 * persisted through the existing /settings endpoint. The notification
 * toggles (payment / overdue / reminder) are not yet part of the backend
 * settings contract, so they are held as local UI state and surfaced for
 * when the server adds them — see [SettingsUiState.notifyPayment] etc.
 */
data class SettingsUiState(
    val isLoading: Boolean = false,
    val isSaving: Boolean = false,
    val error: String? = null,
    val savedMessage: String? = null,
    val businessName: String = "",
    val defaultCurrency: String = "KRW",
    val paymentTermsDays: Int = 30,
    val notifyPayment: Boolean = true,
    val notifyOverdue: Boolean = true,
    val notifyReminder: Boolean = true,
) {
    companion object {
        /** Allowed default currencies surfaced in the picker. */
        val CURRENCIES = listOf("KRW", "USD", "EUR", "JPY")

        /** Payment-term presets: Net 15/30/45/60. */
        val PAYMENT_TERMS = listOf(15, 30, 45, 60)
    }
}

sealed interface SettingsIntent {
    data object Load : SettingsIntent
    data class BusinessNameChanged(val value: String) : SettingsIntent
    data class CurrencyChanged(val value: String) : SettingsIntent
    data class PaymentTermsChanged(val days: Int) : SettingsIntent
    data class NotifyPaymentChanged(val enabled: Boolean) : SettingsIntent
    data class NotifyOverdueChanged(val enabled: Boolean) : SettingsIntent
    data class NotifyReminderChanged(val enabled: Boolean) : SettingsIntent
    data object Save : SettingsIntent
    data object MessageShown : SettingsIntent
}

@HiltViewModel
class SettingsViewModel @Inject constructor(
    private val settingsRepository: SettingsRepository,
) : ViewModel() {

    private val _state = MutableStateFlow(SettingsUiState())
    val state: StateFlow<SettingsUiState> = _state.asStateFlow()

    fun onIntent(intent: SettingsIntent) {
        when (intent) {
            SettingsIntent.Load -> load()
            is SettingsIntent.BusinessNameChanged ->
                _state.update { it.copy(businessName = intent.value) }
            is SettingsIntent.CurrencyChanged ->
                _state.update { it.copy(defaultCurrency = intent.value) }
            is SettingsIntent.PaymentTermsChanged ->
                _state.update { it.copy(paymentTermsDays = intent.days) }
            is SettingsIntent.NotifyPaymentChanged ->
                _state.update { it.copy(notifyPayment = intent.enabled) }
            is SettingsIntent.NotifyOverdueChanged ->
                _state.update { it.copy(notifyOverdue = intent.enabled) }
            is SettingsIntent.NotifyReminderChanged ->
                _state.update { it.copy(notifyReminder = intent.enabled) }
            SettingsIntent.Save -> save()
            SettingsIntent.MessageShown ->
                _state.update { it.copy(savedMessage = null, error = null) }
        }
    }

    private fun load() {
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true, error = null) }
            try {
                val settings = settingsRepository.getSettings()
                _state.update {
                    it.copy(
                        isLoading = false,
                        businessName = settings.businessName.orEmpty(),
                        defaultCurrency = settings.defaultCurrency,
                        paymentTermsDays = settings.paymentTermsDays,
                    )
                }
            } catch (e: Exception) {
                _state.update {
                    it.copy(isLoading = false, error = e.message ?: "설정을 불러오지 못했습니다")
                }
            }
        }
    }

    private fun save() {
        val current = _state.value
        viewModelScope.launch {
            _state.update { it.copy(isSaving = true, error = null, savedMessage = null) }
            try {
                settingsRepository.updateSettings(
                    UserSettingsRequest(
                        businessName = current.businessName.takeIf { it.isNotBlank() },
                        defaultCurrency = current.defaultCurrency,
                        paymentTermsDays = current.paymentTermsDays,
                    )
                )
                _state.update { it.copy(isSaving = false, savedMessage = "저장되었습니다") }
            } catch (e: Exception) {
                _state.update {
                    it.copy(isSaving = false, error = e.message ?: "저장에 실패했습니다")
                }
            }
        }
    }
}
