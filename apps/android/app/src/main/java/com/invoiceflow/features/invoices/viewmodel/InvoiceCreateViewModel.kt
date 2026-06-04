package com.invoiceflow.features.invoices.viewmodel

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.invoiceflow.R
import com.invoiceflow.features.invoices.data.InvoiceRepository
import com.invoiceflow.features.invoices.data.model.InvoiceCreateRequest
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class InvoiceCreateState(
    val isSubmitting: Boolean = false,
    val createdInvoiceId: String? = null,
    val error: String? = null,
)

@HiltViewModel
class InvoiceCreateViewModel @Inject constructor(
    @ApplicationContext private val appContext: Context,
    private val invoiceRepository: InvoiceRepository,
) : ViewModel() {

    private val _state = MutableStateFlow(InvoiceCreateState())
    val state: StateFlow<InvoiceCreateState> = _state.asStateFlow()

    fun submit(request: InvoiceCreateRequest) {
        if (_state.value.isSubmitting) return
        _state.update { it.copy(isSubmitting = true, error = null) }
        viewModelScope.launch {
            runCatching { invoiceRepository.createInvoice(request) }
                .onSuccess { invoice ->
                    _state.update { it.copy(isSubmitting = false, createdInvoiceId = invoice.id) }
                }
                .onFailure { e ->
                    _state.update { it.copy(isSubmitting = false, error = e.message ?: appContext.getString(R.string.invoices_create_failed)) }
                }
        }
    }

    fun consumeNavigation() {
        _state.update { it.copy(createdInvoiceId = null) }
    }
}
