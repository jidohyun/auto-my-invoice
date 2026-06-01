package com.invoiceflow.features.clients.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.invoiceflow.features.analytics.data.model.ClientAnalyticsDto
import com.invoiceflow.features.clients.data.ClientRepository
import com.invoiceflow.features.clients.data.model.ClientDto
import com.invoiceflow.features.clients.data.model.ClientRequest
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class ClientListState(
    val clients: List<ClientDto> = emptyList(),
    val isLoading: Boolean = false,
    val error: String? = null,
)

data class ClientDetailState(
    val client: ClientDto? = null,
    /** Supplementary payment-behaviour summary; null until/unless it loads. */
    val analytics: ClientAnalyticsDto? = null,
    val isLoading: Boolean = false,
    val error: String? = null,
)

data class ClientFormState(
    val isSubmitting: Boolean = false,
    /** Set to the saved client's id once create/update succeeds. */
    val savedClientId: String? = null,
    val error: String? = null,
)

@HiltViewModel
class ClientViewModel @Inject constructor(
    private val clientRepository: ClientRepository,
) : ViewModel() {

    private val _state = MutableStateFlow(ClientListState())
    val state: StateFlow<ClientListState> = _state.asStateFlow()

    private val _detailState = MutableStateFlow(ClientDetailState())
    val detailState: StateFlow<ClientDetailState> = _detailState.asStateFlow()

    private val _formState = MutableStateFlow(ClientFormState())
    val formState: StateFlow<ClientFormState> = _formState.asStateFlow()

    fun loadClients() {
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true, error = null) }
            try {
                val response = clientRepository.getClients()
                _state.update { it.copy(clients = response.data, isLoading = false) }
            } catch (e: Exception) {
                _state.update { it.copy(error = e.message ?: "Failed to load clients", isLoading = false) }
            }
        }
    }

    fun loadClient(id: String) {
        viewModelScope.launch {
            _detailState.update { it.copy(isLoading = true, error = null) }
            try {
                val client = clientRepository.getClient(id)
                _detailState.update { it.copy(client = client, isLoading = false) }
            } catch (e: Exception) {
                _detailState.update { it.copy(error = e.message ?: "Failed to load client", isLoading = false) }
            }
            // Analytics is supplementary — swallow its failure so it never
            // blanks the screen when the core client load already succeeded.
            runCatching { clientRepository.getClientAnalytics(id) }
                .onSuccess { analytics -> _detailState.update { it.copy(analytics = analytics) } }
        }
    }

    /** Reset the form before opening create/edit so stale state never leaks in. */
    fun resetForm() {
        _formState.value = ClientFormState()
    }

    fun createClient(request: ClientRequest) = submitForm { clientRepository.createClient(request) }

    fun updateClient(id: String, request: ClientRequest) = submitForm { clientRepository.updateClient(id, request) }

    private fun submitForm(block: suspend () -> ClientDto) {
        if (_formState.value.isSubmitting) return
        _formState.update { it.copy(isSubmitting = true, error = null) }
        viewModelScope.launch {
            runCatching { block() }
                .onSuccess { client ->
                    _formState.update { it.copy(isSubmitting = false, savedClientId = client.id) }
                    loadClients()
                }
                .onFailure { e ->
                    _formState.update { it.copy(isSubmitting = false, error = e.message ?: "거래처 저장 실패") }
                }
        }
    }

    fun consumeFormNavigation() {
        _formState.update { it.copy(savedClientId = null) }
    }
}
