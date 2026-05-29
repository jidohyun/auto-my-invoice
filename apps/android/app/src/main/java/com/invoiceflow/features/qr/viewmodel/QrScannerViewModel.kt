package com.invoiceflow.features.qr.viewmodel

import androidx.lifecycle.ViewModel
import com.invoiceflow.features.qr.data.InvoicePayUrlParser
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import javax.inject.Inject

/**
 * AMI-42/72: drives the QR scanner. Holds a one-shot "handled" guard so a
 * burst of identical frames from ML Kit only triggers a single navigation.
 */
data class QrScannerUiState(
    val handled: Boolean = false,
    val invoiceId: String? = null,
    val error: String? = null,
)

sealed interface QrScannerIntent {
    data class CodeScanned(val rawValue: String?) : QrScannerIntent
    data object ErrorDismissed : QrScannerIntent
    data object Reset : QrScannerIntent
}

@HiltViewModel
class QrScannerViewModel @Inject constructor() : ViewModel() {

    private val _state = MutableStateFlow(QrScannerUiState())
    val state: StateFlow<QrScannerUiState> = _state.asStateFlow()

    fun onIntent(intent: QrScannerIntent) {
        when (intent) {
            is QrScannerIntent.CodeScanned -> onCodeScanned(intent.rawValue)
            QrScannerIntent.ErrorDismissed -> _state.update { it.copy(error = null) }
            QrScannerIntent.Reset -> _state.value = QrScannerUiState()
        }
    }

    private fun onCodeScanned(rawValue: String?) {
        if (_state.value.handled) return

        val invoiceId = InvoicePayUrlParser.parseInvoiceId(rawValue)
        if (invoiceId == null) {
            _state.update { it.copy(error = "송장 결제 QR 코드가 아닙니다") }
            return
        }
        _state.update { it.copy(handled = true, invoiceId = invoiceId, error = null) }
    }
}
