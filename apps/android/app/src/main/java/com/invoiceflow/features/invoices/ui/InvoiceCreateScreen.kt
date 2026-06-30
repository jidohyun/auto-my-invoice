package com.invoiceflow.features.invoices.ui

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.invoiceflow.R
import com.invoiceflow.features.clients.viewmodel.ClientViewModel
import com.invoiceflow.features.invoices.data.model.InvoiceCreateRequest
import com.invoiceflow.features.invoices.data.model.InvoiceItemRequest
import com.invoiceflow.features.invoices.viewmodel.InvoiceCreateViewModel
import java.math.BigDecimal
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset

/**
 * AMI-88: minimal "new invoice" form for mobile.
 *
 * Picks a client, takes amount + currency + due date + optional notes,
 * POSTs to /api/v1/invoices via [InvoiceCreateViewModel.submit]. On
 * success [onCreated] navigates to the detail screen for the new invoice.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun InvoiceCreateScreen(
    onBack: () -> Unit,
    onCreated: (String) -> Unit,
    onNavigateToClients: () -> Unit = {},
    prefillAmount: String? = null,
    prefillCurrency: String? = null,
    prefillDueDate: String? = null,
    prefillNotes: String? = null,
    clientViewModel: ClientViewModel = hiltViewModel(),
    viewModel: InvoiceCreateViewModel = hiltViewModel(),
) {
    val clientState by clientViewModel.state.collectAsStateWithLifecycle()
    val state by viewModel.state.collectAsStateWithLifecycle()

    LaunchedEffect(Unit) { clientViewModel.loadClients() }
    LaunchedEffect(state.createdInvoiceId) {
        val id = state.createdInvoiceId
        if (id != null) {
            onCreated(id)
            viewModel.consumeNavigation()
        }
    }

    var clientMenuOpen by remember { mutableStateOf(false) }
    var showNoClientDialog by remember { mutableStateOf(false) }
    var currencyMenuOpen by remember { mutableStateOf(false) }
    var amount by rememberSaveable { mutableStateOf(prefillAmount.orEmpty()) }
    var currency by rememberSaveable { mutableStateOf(prefillCurrency ?: "KRW") }
    var notes by rememberSaveable { mutableStateOf(prefillNotes.orEmpty()) }
    var dueDate by rememberSaveable { mutableStateOf(prefillDueDate ?: LocalDate.now().plusDays(14).toString()) }
    var selectedClientId by rememberSaveable { mutableStateOf<String?>(null) }
    val selectedClient = clientState.clients.find { it.id == selectedClientId }

    // 라인아이템 — 비어 있으면 단일 금액 입력, 1개 이상이면 합계로 금액 자동 계산.
    val items = remember { mutableStateListOf<ItemRow>() }
    val itemsTotal = items.sumOf { it.lineTotal() }
    val usingItems = items.isNotEmpty()
    val effectiveAmount = if (usingItems) itemsTotal.toPlainString() else amount

    // 날짜 피커
    var showDatePicker by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.invoices_create_title)) },
                navigationIcon = {
                    IconButton(onClick = onBack) { Icon(Icons.Default.ArrowBack, stringResource(R.string.invoices_back)) }
                },
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .padding(padding)
                .padding(16.dp)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            // Client picker
            Box {
                OutlinedButton(
                    onClick = {
                        if (clientState.clients.isEmpty()) {
                            showNoClientDialog = true
                        } else {
                            clientMenuOpen = true
                        }
                    },
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text(selectedClient?.name ?: stringResource(R.string.invoices_select_client))
                }
                DropdownMenu(
                    expanded = clientMenuOpen,
                    onDismissRequest = { clientMenuOpen = false },
                ) {
                    clientState.clients.forEach { c ->
                        DropdownMenuItem(
                            text = { Text(c.name) },
                            onClick = {
                                selectedClientId = c.id
                                clientMenuOpen = false
                            },
                        )
                    }
                }
            }

            // 품목(라인아이템) 에디터 — 항목을 추가하면 금액은 합계로 자동 계산된다.
            HorizontalDivider()
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = androidx.compose.ui.Alignment.CenterVertically,
            ) {
                Text(stringResource(R.string.invoices_items), style = MaterialTheme.typography.titleMedium)
                TextButton(onClick = { items.add(ItemRow()) }) {
                    Icon(Icons.Default.Add, contentDescription = null, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.width(4.dp))
                    Text(stringResource(R.string.invoices_add_item))
                }
            }

            items.forEachIndexed { index, row ->
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    OutlinedTextField(
                        value = row.description,
                        onValueChange = { items[index] = row.copy(description = it) },
                        label = { Text(stringResource(R.string.invoices_item_description)) },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth(),
                    )
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedTextField(
                            value = row.quantity,
                            onValueChange = { v -> items[index] = row.copy(quantity = v.filter { it.isDigit() }) },
                            label = { Text(stringResource(R.string.invoices_item_quantity)) },
                            singleLine = true,
                            modifier = Modifier.weight(1f),
                        )
                        OutlinedTextField(
                            value = row.unitPrice,
                            onValueChange = { v -> items[index] = row.copy(unitPrice = v.filter { it.isDigit() || it == '.' }) },
                            label = { Text(stringResource(R.string.invoices_item_unit_price)) },
                            singleLine = true,
                            modifier = Modifier.weight(2f),
                        )
                        IconButton(onClick = { items.removeAt(index) }) {
                            Icon(Icons.Default.Delete, contentDescription = stringResource(R.string.invoices_delete), tint = MaterialTheme.colorScheme.error)
                        }
                    }
                }
            }

            if (usingItems) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    Text(stringResource(R.string.invoices_total), style = MaterialTheme.typography.titleMedium)
                    Text(
                        "$currency ${itemsTotal.toPlainString()}",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                    )
                }
            } else {
                // 항목이 없을 때만 단일 금액 직접 입력.
                OutlinedTextField(
                    value = amount,
                    onValueChange = { input ->
                        amount = input.filter { ch -> ch.isDigit() || ch == '.' }
                    },
                    label = { Text(stringResource(R.string.invoices_amount_label)) },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
            HorizontalDivider()

            // Currency picker
            Box {
                OutlinedButton(
                    onClick = { currencyMenuOpen = true },
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text(stringResource(R.string.invoices_currency, currency))
                }
                DropdownMenu(
                    expanded = currencyMenuOpen,
                    onDismissRequest = { currencyMenuOpen = false },
                ) {
                    listOf("KRW", "USD", "EUR", "JPY", "GBP").forEach { c ->
                        DropdownMenuItem(
                            text = { Text(c) },
                            onClick = {
                                currency = c
                                currencyMenuOpen = false
                            },
                        )
                    }
                }
            }

            // 지급 기한 — 날짜 피커로 선택.
            OutlinedButton(
                onClick = { showDatePicker = true },
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(stringResource(R.string.invoices_due_date, dueDate))
            }

            OutlinedTextField(
                value = notes,
                onValueChange = { notes = it },
                label = { Text(stringResource(R.string.invoices_notes_label)) },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(96.dp),
            )

            state.error?.let { msg -> Text(msg, color = MaterialTheme.colorScheme.error) }

            Button(
                onClick = {
                    val clientId = selectedClientId ?: return@Button
                    if (effectiveAmount.isBlank()) return@Button
                    viewModel.submit(
                        InvoiceCreateRequest(
                            clientId = clientId,
                            amount = effectiveAmount,
                            currency = currency,
                            dueDate = dueDate,
                            notes = if (notes.isBlank()) null else notes,
                            items = items
                                .filter { it.description.isNotBlank() }
                                .map {
                                    InvoiceItemRequest(
                                        description = it.description,
                                        quantity = it.quantity.ifBlank { "1" },
                                        unitPrice = it.unitPrice.ifBlank { "0" },
                                    )
                                },
                        )
                    )
                },
                enabled = !state.isSubmitting && selectedClientId != null && effectiveAmount.isNotBlank(),
                modifier = Modifier.fillMaxWidth(),
            ) {
                if (state.isSubmitting) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(20.dp),
                        strokeWidth = 2.dp,
                        color = MaterialTheme.colorScheme.onPrimary,
                    )
                    Spacer(Modifier.width(8.dp))
                    Text(stringResource(R.string.invoices_creating))
                } else {
                    Text(stringResource(R.string.invoices_create_button))
                }
            }
        }

        if (showNoClientDialog) {
            AlertDialog(
                onDismissRequest = { showNoClientDialog = false },
                title = { Text(stringResource(R.string.invoices_no_client_dialog_title)) },
                text = { Text(stringResource(R.string.invoices_no_client_dialog_message)) },
                confirmButton = {
                    TextButton(onClick = {
                        showNoClientDialog = false
                        onNavigateToClients()
                    }) {
                        Text(stringResource(R.string.invoices_no_client_go_to_clients))
                    }
                },
                dismissButton = {
                    TextButton(onClick = { showNoClientDialog = false }) {
                        Text(stringResource(R.string.invoices_cancel))
                    }
                },
            )
        }

        if (showDatePicker) {
            val initialMillis = runCatching {
                LocalDate.parse(dueDate).atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli()
            }.getOrNull()
            val datePickerState = rememberDatePickerState(initialSelectedDateMillis = initialMillis)
            DatePickerDialog(
                onDismissRequest = { showDatePicker = false },
                confirmButton = {
                    TextButton(onClick = {
                        datePickerState.selectedDateMillis?.let { millis ->
                            dueDate = Instant.ofEpochMilli(millis)
                                .atZone(ZoneOffset.UTC).toLocalDate().toString()
                        }
                        showDatePicker = false
                    }) { Text(stringResource(R.string.invoices_confirm)) }
                },
                dismissButton = {
                    TextButton(onClick = { showDatePicker = false }) { Text(stringResource(R.string.invoices_cancel)) }
                },
            ) {
                DatePicker(state = datePickerState)
            }
        }
    }
}

/** 송장 생성 폼의 라인아이템 한 행. 빈 행을 추가했다가 채우는 방식. */
private data class ItemRow(
    val description: String = "",
    val quantity: String = "1",
    val unitPrice: String = "",
) {
    /** 수량 × 단가. 파싱 실패 시 0. */
    fun lineTotal(): BigDecimal {
        val q = quantity.toBigDecimalOrNull() ?: BigDecimal.ZERO
        val p = unitPrice.toBigDecimalOrNull() ?: BigDecimal.ZERO
        return q.multiply(p)
    }
}
