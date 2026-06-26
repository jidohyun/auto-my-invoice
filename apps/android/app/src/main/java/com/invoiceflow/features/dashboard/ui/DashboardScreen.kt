package com.invoiceflow.features.dashboard.ui

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Assessment
import androidx.compose.material.icons.filled.People
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.invoiceflow.R
import com.invoiceflow.core.util.MoneyFormatter
import com.invoiceflow.features.dashboard.viewmodel.DashboardViewModel
import com.invoiceflow.features.dashboard.data.model.KpiSummaryDto
import com.invoiceflow.features.invoices.data.model.InvoiceDto
import com.invoiceflow.ui.components.StatusPill
import java.text.NumberFormat
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DashboardScreen(
    onNavigateToInvoice: (String) -> Unit,
    onNavigateToCreate: () -> Unit,
    onNavigateToInvoices: () -> Unit,
    onNavigateToSettings: () -> Unit = {},
    onNavigateToAnalytics: () -> Unit = {},
    onNavigateToClients: () -> Unit = {},
    viewModel: DashboardViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val refreshing = state.isLoading

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.dashboard_title)) },
                actions = {
                    IconButton(onClick = onNavigateToCreate) {
                        Icon(Icons.Default.Add, contentDescription = stringResource(R.string.dashboard_action_create))
                    }
                    IconButton(onClick = onNavigateToClients) {
                        Icon(Icons.Default.People, contentDescription = stringResource(R.string.dashboard_action_clients))
                    }
                    IconButton(onClick = onNavigateToAnalytics) {
                        Icon(Icons.Default.Assessment, contentDescription = stringResource(R.string.dashboard_action_analytics))
                    }
                    IconButton(onClick = onNavigateToSettings) {
                        Icon(Icons.Default.Settings, contentDescription = stringResource(R.string.dashboard_action_settings))
                    }
                }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .padding(padding)
                .padding(horizontal = 16.dp)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            state.error?.let { msg ->
                Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer)) {
                    Column(
                        modifier = Modifier.padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        Text(msg, color = MaterialTheme.colorScheme.onErrorContainer)
                        TextButton(onClick = viewModel::refresh) { Text(stringResource(R.string.dashboard_retry)) }
                    }
                }
            }

            KpiRow(state.kpi, refreshing)

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(stringResource(R.string.dashboard_recent_title), style = MaterialTheme.typography.titleMedium)
                TextButton(onClick = onNavigateToInvoices) { Text(stringResource(R.string.dashboard_view_all)) }
            }

            if (state.recent.isEmpty() && !refreshing) {
                EmptyRecentInvoices(onNavigateToCreate)
            } else {
                state.recent.forEach { inv ->
                    RecentInvoiceRow(inv) { onNavigateToInvoice(inv.id) }
                }
            }

            Spacer(Modifier.height(24.dp))
        }
    }
}

@Composable
private fun KpiRow(kpi: KpiSummaryDto?, refreshing: Boolean) {
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        KpiCard(
            label = stringResource(R.string.dashboard_kpi_outstanding),
            value = kpi?.outstandingAmount?.let { MoneyFormatter.formatKrwCompact(it) } ?: if (refreshing) "..." else "₩0",
            sub = kpi?.overdueCount?.let { stringResource(R.string.dashboard_kpi_overdue_count, it) } ?: "",
            modifier = Modifier.weight(1f),
        )
        KpiCard(
            label = stringResource(R.string.dashboard_kpi_collection_rate),
            value = kpi?.collectionRate?.let { "${it}%" } ?: if (refreshing) "..." else "0%",
            sub = stringResource(R.string.dashboard_kpi_this_month_label),
            modifier = Modifier.weight(1f),
        )
        KpiCard(
            label = stringResource(R.string.dashboard_kpi_collected_this_month),
            value = kpi?.collectedThisMonth?.let { MoneyFormatter.formatKrwCompact(it) } ?: if (refreshing) "..." else "₩0",
            sub = "",
            modifier = Modifier.weight(1f),
        )
    }
}

@Composable
private fun KpiCard(label: String, value: String, sub: String, modifier: Modifier = Modifier) {
    Card(modifier = modifier) {
        Column(Modifier.padding(12.dp)) {
            Text(
                label,
                style = MaterialTheme.typography.labelMedium,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            Spacer(Modifier.height(4.dp))
            // KRW totals can be 8+ digits; titleLarge overflowed the narrow
            // 3-up card and wrapped to three lines ("₩60,185,/000"). Compact the
            // figure (₩60.2M) so it stays on one line at a comfortable size.
            Text(
                value,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                maxLines = 1,
                softWrap = false,
                overflow = TextOverflow.Ellipsis,
            )
            if (sub.isNotEmpty()) {
                Spacer(Modifier.height(2.dp))
                Text(sub, style = MaterialTheme.typography.labelSmall, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
    }
}

@Composable
private fun RecentInvoiceRow(invoice: InvoiceDto, onClick: () -> Unit) {
    Card(onClick = onClick) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(Modifier.weight(1f)) {
                Text(
                    invoice.invoiceNumber ?: stringResource(R.string.dashboard_invoice_number_fallback, invoice.id.take(6)),
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.SemiBold,
                )
                Spacer(Modifier.height(4.dp))
                StatusPill(statusString = invoice.status)
            }
            Text(
                MoneyFormatter.format(invoice.amount, invoice.currency),
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Medium,
            )
        }
    }
}

@Composable
private fun EmptyRecentInvoices(onCreate: () -> Unit) {
    Card {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(stringResource(R.string.dashboard_empty_title), style = MaterialTheme.typography.bodyMedium)
            Text(stringResource(R.string.dashboard_empty_subtitle), style = MaterialTheme.typography.labelSmall)
            Button(onClick = onCreate) { Text(stringResource(R.string.dashboard_empty_create)) }
        }
    }
}

private fun formatKrw(raw: String): String {
    val n = raw.toBigDecimalOrNull() ?: return "₩0"
    val fmt = NumberFormat.getCurrencyInstance(Locale.KOREA)
    return fmt.format(n)
}
