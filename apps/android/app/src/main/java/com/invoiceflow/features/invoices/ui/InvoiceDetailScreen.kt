package com.invoiceflow.features.invoices.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.invoiceflow.features.invoices.data.model.InvoiceDto
import com.invoiceflow.features.invoices.viewmodel.InvoiceViewModel
import com.invoiceflow.ui.components.ErrorState
import com.invoiceflow.ui.components.StatusPill

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun InvoiceDetailScreen(
    invoiceId: String,
    onNavigateBack: () -> Unit,
    viewModel: InvoiceViewModel = hiltViewModel(),
) {
    val state by viewModel.detailState.collectAsStateWithLifecycle()
    val snackbarHostState = remember { SnackbarHostState() }
    var showDeleteDialog by remember { mutableStateOf(false) }

    LaunchedEffect(invoiceId) { viewModel.loadInvoice(invoiceId) }

    // Surface action feedback (success or error) in a snackbar, then consume it.
    LaunchedEffect(state.actionMessage, state.actionError) {
        val msg = state.actionMessage ?: state.actionError
        if (msg != null) {
            snackbarHostState.showSnackbar(msg)
            viewModel.consumeActionFeedback()
        }
    }

    // Pop back once a delete succeeds.
    LaunchedEffect(state.deleted) {
        if (state.deleted) onNavigateBack()
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("송장 상세") },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "뒤로")
                    }
                },
                actions = {
                    if (state.invoice != null) {
                        IconButton(
                            onClick = { showDeleteDialog = true },
                            enabled = !state.isActionRunning,
                        ) {
                            Icon(
                                Icons.Default.Delete,
                                contentDescription = "삭제",
                                tint = MaterialTheme.colorScheme.error,
                            )
                        }
                    }
                },
            )
        },
        snackbarHost = { SnackbarHost(snackbarHostState) },
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            when {
                state.isLoading -> CircularProgressIndicator(modifier = Modifier.align(Alignment.Center))
                state.error != null -> ErrorState(
                    message = state.error ?: "",
                    onRetry = { viewModel.loadInvoice(invoiceId) },
                    modifier = Modifier.align(Alignment.Center),
                )
                state.invoice != null -> InvoiceDetailContent(
                    invoice = state.invoice!!,
                    isActionRunning = state.isActionRunning,
                    onSend = { viewModel.send(invoiceId) },
                    onMarkPaid = { viewModel.markPaid(invoiceId) },
                )
            }
        }
    }

    if (showDeleteDialog) {
        AlertDialog(
            onDismissRequest = { showDeleteDialog = false },
            title = { Text("송장 삭제") },
            text = { Text("이 송장을 삭제하시겠습니까? 되돌릴 수 없습니다.") },
            confirmButton = {
                TextButton(
                    onClick = {
                        showDeleteDialog = false
                        viewModel.delete(invoiceId)
                    },
                ) {
                    Text("삭제", color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteDialog = false }) { Text("취소") }
            },
        )
    }
}

@Composable
private fun InvoiceDetailContent(
    invoice: InvoiceDto,
    isActionRunning: Boolean,
    onSend: () -> Unit,
    onMarkPaid: () -> Unit,
) {
    val status = invoice.status.lowercase()
    // Send is allowed for draft/sent/overdue/partially_paid; not for paid or cancelled.
    val canSend = status in setOf("draft", "sent", "overdue", "partially_paid")
    // Mark-paid is allowed unless already fully paid or cancelled.
    val canMarkPaid = status !in setOf("paid", "cancelled")

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
    ) {
        Text(text = "송장 #${invoice.invoiceNumber}", style = MaterialTheme.typography.headlineMedium)
        Spacer(modifier = Modifier.height(8.dp))
        StatusPill(statusString = invoice.status)
        Spacer(modifier = Modifier.height(16.dp))
        Text(text = "거래처: ${invoice.client?.name ?: "-"}", style = MaterialTheme.typography.bodyLarge)
        Text(text = "금액: ${invoice.currency} ${invoice.amount}", style = MaterialTheme.typography.bodyLarge)
        Text(text = "결제액: ${invoice.currency} ${invoice.paidAmount}", style = MaterialTheme.typography.bodyLarge)
        Text(text = "지급 기한: ${invoice.dueDate ?: "-"}", style = MaterialTheme.typography.bodyLarge)
        invoice.sentAt?.let { Text(text = "발송일: $it", style = MaterialTheme.typography.bodyMedium) }
        invoice.paidAt?.let { Text(text = "결제일: $it", style = MaterialTheme.typography.bodyMedium) }
        invoice.notes?.takeIf { it.isNotBlank() }?.let {
            Spacer(modifier = Modifier.height(8.dp))
            Text(text = "메모: $it", style = MaterialTheme.typography.bodyMedium)
        }

        Spacer(modifier = Modifier.height(24.dp))

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Button(
                onClick = onSend,
                enabled = canSend && !isActionRunning,
                modifier = Modifier.weight(1f),
            ) {
                if (isActionRunning) {
                    InlineSpinner()
                } else {
                    Text("발송")
                }
            }
            OutlinedButton(
                onClick = onMarkPaid,
                enabled = canMarkPaid && !isActionRunning,
                modifier = Modifier.weight(1f),
            ) {
                Text("결제 완료로 표시")
            }
        }
    }
}

@Composable
private fun InlineSpinner() {
    CircularProgressIndicator(
        modifier = Modifier.size(20.dp),
        strokeWidth = 2.dp,
        color = MaterialTheme.colorScheme.onPrimary,
    )
    Spacer(Modifier.width(8.dp))
    Text("처리 중...")
}
