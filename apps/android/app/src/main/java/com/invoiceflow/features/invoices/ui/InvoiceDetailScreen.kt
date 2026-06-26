package com.invoiceflow.features.invoices.ui

import android.content.Intent
import androidx.core.content.FileProvider
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
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.invoiceflow.R
import com.invoiceflow.core.util.DateFormat
import com.invoiceflow.core.util.MoneyFormatter
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
    val context = LocalContext.current
    var showDeleteDialog by remember { mutableStateOf(false) }
    var showPaymentDialog by remember { mutableStateOf(false) }
    var paymentAmount by remember { mutableStateOf("") }

    // Resolved at composition since the share chooser is built inside a coroutine.
    val pdfShareTitle = stringResource(R.string.invoices_pdf_share_chooser)

    LaunchedEffect(invoiceId) { viewModel.loadInvoice(invoiceId) }

    // Once the PDF is cached, fire a share/open chooser then consume it so the
    // sheet is not re-presented on recomposition.
    LaunchedEffect(state.pdfFile) {
        val file = state.pdfFile ?: return@LaunchedEffect
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
        val share = Intent(Intent.ACTION_SEND).apply {
            type = "application/pdf"
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        context.startActivity(Intent.createChooser(share, pdfShareTitle).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        viewModel.consumePdfFile()
    }

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
                title = { Text(stringResource(R.string.invoices_detail_title)) },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.invoices_back))
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
                                contentDescription = stringResource(R.string.invoices_delete),
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
                    isDownloadingPdf = state.isDownloadingPdf,
                    onSend = { viewModel.send(invoiceId) },
                    onMarkPaid = { viewModel.markPaid(invoiceId) },
                    onRecordPayment = {
                        paymentAmount = ""
                        showPaymentDialog = true
                    },
                    onSendReminder = { viewModel.sendReminder(invoiceId) },
                    onDownloadPdf = { viewModel.downloadPdf(invoiceId) },
                )
            }
        }
    }

    if (showDeleteDialog) {
        AlertDialog(
            onDismissRequest = { showDeleteDialog = false },
            title = { Text(stringResource(R.string.invoices_delete_dialog_title)) },
            text = { Text(stringResource(R.string.invoices_delete_dialog_message)) },
            confirmButton = {
                TextButton(
                    onClick = {
                        showDeleteDialog = false
                        viewModel.delete(invoiceId)
                    },
                ) {
                    Text(stringResource(R.string.invoices_delete), color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteDialog = false }) { Text(stringResource(R.string.invoices_cancel)) }
            },
        )
    }

    if (showPaymentDialog) {
        AlertDialog(
            onDismissRequest = { showPaymentDialog = false },
            title = { Text(stringResource(R.string.invoices_record_payment)) },
            text = {
                Column {
                    Text(stringResource(R.string.invoices_record_payment_message))
                    Spacer(Modifier.height(8.dp))
                    OutlinedTextField(
                        value = paymentAmount,
                        onValueChange = { paymentAmount = it },
                        label = { Text(stringResource(R.string.invoices_amount_label)) },
                        singleLine = true,
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                    )
                }
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        showPaymentDialog = false
                        viewModel.recordPayment(invoiceId, paymentAmount)
                    },
                    enabled = paymentAmount.isNotBlank(),
                ) {
                    Text(stringResource(R.string.invoices_record))
                }
            },
            dismissButton = {
                TextButton(onClick = { showPaymentDialog = false }) { Text(stringResource(R.string.invoices_cancel)) }
            },
        )
    }
}

@Composable
private fun InvoiceDetailContent(
    invoice: InvoiceDto,
    isActionRunning: Boolean,
    isDownloadingPdf: Boolean,
    onSend: () -> Unit,
    onMarkPaid: () -> Unit,
    onRecordPayment: () -> Unit,
    onSendReminder: () -> Unit,
    onDownloadPdf: () -> Unit,
) {
    val status = invoice.status.lowercase()
    // Send is allowed for draft/sent/overdue/partially_paid; not for paid or cancelled.
    val canSend = status in setOf("draft", "sent", "overdue", "partially_paid")
    // Mark-paid is allowed unless already fully paid or cancelled.
    val canMarkPaid = status !in setOf("paid", "cancelled")
    // Reminder / partial payment apply to issued-but-unpaid invoices.
    val isUnpaid = status in setOf("sent", "overdue", "partially_paid")

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        // Header card: number + status, the headline amount, and the due date —
        // mirrors the iOS detail header instead of a flat "label: value" dump.
        HeaderCard(invoice)

        invoice.client?.let { ClientSection(it) }

        DetailsSection(invoice)

        invoice.notes?.takeIf { it.isNotBlank() }?.let { NotesSection(it) }

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
                    Text(stringResource(R.string.invoices_action_send))
                }
            }
            OutlinedButton(
                onClick = onMarkPaid,
                enabled = canMarkPaid && !isActionRunning,
                modifier = Modifier.weight(1f),
            ) {
                Text(stringResource(R.string.invoices_mark_paid))
            }
        }

        if (isUnpaid) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                OutlinedButton(
                    onClick = onRecordPayment,
                    enabled = !isActionRunning,
                    modifier = Modifier.weight(1f),
                ) {
                    Text(stringResource(R.string.invoices_record_payment))
                }
                OutlinedButton(
                    onClick = onSendReminder,
                    enabled = !isActionRunning,
                    modifier = Modifier.weight(1f),
                ) {
                    Text(stringResource(R.string.invoices_send_reminder))
                }
            }
        }

        OutlinedButton(
            onClick = onDownloadPdf,
            enabled = !isDownloadingPdf,
            modifier = Modifier.fillMaxWidth(),
        ) {
            if (isDownloadingPdf) {
                InlineSpinner()
            } else {
                Text(stringResource(R.string.invoices_download_pdf))
            }
        }
    }
}

@Composable
private fun HeaderCard(invoice: InvoiceDto) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = stringResource(R.string.invoices_number_header, invoice.invoiceNumber),
                    style = MaterialTheme.typography.titleMedium,
                )
                StatusPill(statusString = invoice.status)
            }
            Spacer(Modifier.height(12.dp))
            Text(
                text = MoneyFormatter.format(invoice.amount, invoice.currency),
                style = MaterialTheme.typography.headlineMedium,
            )
            DateFormat.date(invoice.dueDate)?.let { due ->
                Spacer(Modifier.height(4.dp))
                Text(
                    text = stringResource(R.string.invoices_field_due_date, due),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

@Composable
private fun ClientSection(client: com.invoiceflow.features.clients.data.model.ClientDto) {
    SectionCard(stringResource(R.string.invoices_section_client)) {
        Text(client.name, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.Medium)
        client.email?.takeIf { it.isNotBlank() }?.let {
            Text(it, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        client.company?.takeIf { it.isNotBlank() }?.let {
            Text(it, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
private fun DetailsSection(invoice: InvoiceDto) {
    SectionCard(stringResource(R.string.invoices_section_details)) {
        MetaRow(
            stringResource(R.string.invoices_meta_paid),
            MoneyFormatter.format(invoice.paidAmount, invoice.currency),
        )
        DateFormat.instant(invoice.sentAt)?.let {
            MetaRow(stringResource(R.string.invoices_meta_sent_at), it)
        }
        DateFormat.instant(invoice.paidAt)?.let {
            MetaRow(stringResource(R.string.invoices_meta_paid_at), it)
        }
    }
}

@Composable
private fun NotesSection(notes: String) {
    SectionCard(stringResource(R.string.invoices_section_notes)) {
        Text(notes, style = MaterialTheme.typography.bodyMedium)
    }
}

/** A titled card used by the client / details / notes sections. */
@Composable
private fun SectionCard(title: String, content: @Composable () -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Text(title, style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            content()
        }
    }
}

/** A label/value row for the payment-details meta items. */
@Composable
private fun MetaRow(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(label, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(value, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium)
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
    Text(stringResource(R.string.invoices_processing))
}
