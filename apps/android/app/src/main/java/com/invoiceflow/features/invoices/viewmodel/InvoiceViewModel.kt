package com.invoiceflow.features.invoices.viewmodel

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.invoiceflow.R
import com.invoiceflow.features.invoices.data.InvoiceRepository
import com.invoiceflow.features.invoices.data.model.InvoiceDto
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
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
    /** True while the PDF is being downloaded/written to cache. */
    val isDownloadingPdf: Boolean = false,
    /** Set to the cached PDF file once downloaded so the screen can share it. */
    val pdfFile: File? = null,
)

@HiltViewModel
class InvoiceViewModel @Inject constructor(
    private val invoiceRepository: InvoiceRepository,
    @ApplicationContext private val appContext: Context,
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
    fun send(id: String) = runAction(id, appContext.getString(R.string.invoices_send_success)) { invoiceRepository.sendInvoice(id) }

    /** Mark the invoice as fully paid and refresh detail + list on success. */
    fun markPaid(id: String) = runAction(id, appContext.getString(R.string.invoices_mark_paid_success)) { invoiceRepository.markPaid(id) }

    /** Record a (possibly partial) payment of [amount] and refresh on success. */
    fun recordPayment(id: String, amount: String) {
        val trimmed = amount.trim()
        if (trimmed.isEmpty()) return
        runAction(id, appContext.getString(R.string.invoices_record_payment_success)) { invoiceRepository.recordPayment(id, trimmed) }
    }

    /** Queue a manual reminder. Returns a message (not an invoice), so the
     *  invoice itself is left unchanged and the result is shown in a snackbar. */
    fun sendReminder(id: String) {
        if (_detailState.value.isActionRunning) return
        _detailState.update { it.copy(isActionRunning = true, actionError = null) }
        viewModelScope.launch {
            runCatching { invoiceRepository.sendReminder(id) }
                .onSuccess { message ->
                    _detailState.update { it.copy(isActionRunning = false, actionMessage = message) }
                }
                .onFailure { e ->
                    _detailState.update { it.copy(isActionRunning = false, actionError = e.message ?: appContext.getString(R.string.invoices_reminder_failed)) }
                }
        }
    }

    /** Download the invoice PDF to the cache dir and expose it via
     *  [InvoiceDetailState.pdfFile] so the screen can share it. */
    fun downloadPdf(id: String) {
        if (_detailState.value.isDownloadingPdf) return
        val number = _detailState.value.invoice?.invoiceNumber ?: id
        _detailState.update { it.copy(isDownloadingPdf = true, actionError = null) }
        viewModelScope.launch {
            runCatching {
                withContext(Dispatchers.IO) {
                    val body = invoiceRepository.downloadInvoicePdf(id)
                    val dir = File(appContext.cacheDir, "pdfs").apply { mkdirs() }
                    val file = File(dir, "$number.pdf")
                    body.byteStream().use { input ->
                        file.outputStream().use { output -> input.copyTo(output) }
                    }
                    file
                }
            }
                .onSuccess { file ->
                    _detailState.update { it.copy(isDownloadingPdf = false, pdfFile = file) }
                }
                .onFailure { e ->
                    _detailState.update { it.copy(isDownloadingPdf = false, actionError = e.message ?: appContext.getString(R.string.invoices_pdf_download_failed)) }
                }
        }
    }

    /** Clear [InvoiceDetailState.pdfFile] after the share sheet has been shown. */
    fun consumePdfFile() {
        _detailState.update { it.copy(pdfFile = null) }
    }

    /** Delete the invoice; on success flag [InvoiceDetailState.deleted] so the screen pops. */
    fun delete(id: String) {
        if (_detailState.value.isActionRunning) return
        _detailState.update { it.copy(isActionRunning = true, actionError = null) }
        viewModelScope.launch {
            runCatching { invoiceRepository.deleteInvoice(id) }
                .onSuccess {
                    _detailState.update { it.copy(isActionRunning = false, deleted = true, actionMessage = appContext.getString(R.string.invoices_delete_success)) }
                    loadInvoices()
                }
                .onFailure { e ->
                    _detailState.update { it.copy(isActionRunning = false, actionError = e.message ?: appContext.getString(R.string.invoices_delete_failed)) }
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
                    _detailState.update { it.copy(isActionRunning = false, actionError = e.message ?: appContext.getString(R.string.invoices_action_failed)) }
                }
        }
    }

    /** Clear the transient success/error after the UI has shown it. */
    fun consumeActionFeedback() {
        _detailState.update { it.copy(actionMessage = null, actionError = null) }
    }
}
