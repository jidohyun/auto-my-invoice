package com.invoiceflow.features.invoices.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.invoiceflow.features.invoices.data.InvoiceRepository
import com.invoiceflow.features.invoices.data.model.InvoiceDto
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class InvoiceListState(
    val invoices: List<InvoiceDto> = emptyList(),
    val isLoading: Boolean = false,
    val error: String? = null,
    /** One of: null (all) | "draft" | "sent" | "overdue" | "paid" | "partially_paid". */
    val statusFilter: String? = null,
    val search: String = "",
)

data class InvoiceDetailState(
    val invoice: InvoiceDto? = null,
    val isLoading: Boolean = false,
    val error: String? = null,
    /** True while a send/mark-paid/delete action is in flight. */
    val isActionRunning: Boolean = false,
    /** Transient error from an action (separate from load error). */
    val actionError: String? = null,
    /** Transient success message to surface in a snackbar. */
    val actionMessage: String? = null,
    /** Set true once a delete succeeds so the screen can pop back. */
    val deleted: Boolean = false,
)

@HiltViewModel
class InvoiceViewModel @Inject constructor(
    private val invoiceRepository: InvoiceRepository,
) : ViewModel() {

    private val _listState = MutableStateFlow(InvoiceListState())
    val listState: StateFlow<InvoiceListState> = _listState.asStateFlow()

    private val _detailState = MutableStateFlow(InvoiceDetailState())
    val detailState: StateFlow<InvoiceDetailState> = _detailState.asStateFlow()

    fun loadInvoices() {
        val state = _listState.value
        viewModelScope.launch {
            _listState.update { it.copy(isLoading = true, error = null) }
            try {
                val response = invoiceRepository.getInvoices(
                    status = state.statusFilter,
                    search = state.search.takeIf { q -> q.isNotBlank() },
                )
                _listState.update { it.copy(invoices = response.data, isLoading = false) }
            } catch (e: Exception) {
                _listState.update { it.copy(error = e.message ?: "Failed to load invoices", isLoading = false) }
            }
        }
    }

    fun setStatusFilter(status: String?) {
        _listState.update { it.copy(statusFilter = status) }
        loadInvoices()
    }

    fun setSearch(query: String) {
        _listState.update { it.copy(search = query) }
        loadInvoices()
    }

    fun loadInvoice(id: String) {
        viewModelScope.launch {
            _detailState.update { it.copy(isLoading = true, error = null) }
            try {
                val invoice = invoiceRepository.getInvoice(id)
                _detailState.update { it.copy(invoice = invoice, isLoading = false) }
            } catch (e: Exception) {
                _detailState.update { it.copy(error = e.message ?: "Failed to load invoice", isLoading = false) }
            }
        }
    }

    /** Send the invoice to the client and refresh detail + list on success. */
    fun send(id: String) = runAction(id, "송장을 발송했습니다") { invoiceRepository.sendInvoice(id) }

    /** Mark the invoice as fully paid and refresh detail + list on success. */
    fun markPaid(id: String) = runAction(id, "결제 완료로 표시했습니다") { invoiceRepository.markPaid(id) }

    /** Delete the invoice; on success flag [InvoiceDetailState.deleted] so the screen pops. */
    fun delete(id: String) {
        if (_detailState.value.isActionRunning) return
        _detailState.update { it.copy(isActionRunning = true, actionError = null) }
        viewModelScope.launch {
            runCatching { invoiceRepository.deleteInvoice(id) }
                .onSuccess {
                    _detailState.update { it.copy(isActionRunning = false, deleted = true, actionMessage = "송장을 삭제했습니다") }
                    loadInvoices()
                }
                .onFailure { e ->
                    _detailState.update { it.copy(isActionRunning = false, actionError = e.message ?: "송장 삭제 실패") }
                }
        }
    }

    /** Shared runner for send/mark-paid: updates the loaded invoice and refreshes the list. */
    private fun runAction(id: String, successMessage: String, block: suspend () -> InvoiceDto) {
        if (_detailState.value.isActionRunning) return
        _detailState.update { it.copy(isActionRunning = true, actionError = null) }
        viewModelScope.launch {
            runCatching { block() }
                .onSuccess { updated ->
                    _detailState.update {
                        it.copy(isActionRunning = false, invoice = updated, actionMessage = successMessage)
                    }
                    loadInvoices()
                }
                .onFailure { e ->
                    _detailState.update { it.copy(isActionRunning = false, actionError = e.message ?: "작업에 실패했습니다") }
                }
        }
    }

    /** Clear the transient success/error after the UI has shown it. */
    fun consumeActionFeedback() {
        _detailState.update { it.copy(actionMessage = null, actionError = null) }
    }
}
