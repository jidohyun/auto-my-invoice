package com.invoiceflow.features.clients.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.invoiceflow.features.analytics.data.model.ClientAnalyticsDto
import com.invoiceflow.features.clients.data.model.ClientDto
import com.invoiceflow.features.clients.viewmodel.ClientViewModel
import com.invoiceflow.ui.components.ErrorState
import java.text.NumberFormat
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ClientDetailScreen(
    clientId: String,
    onNavigateBack: () -> Unit,
    onEdit: (String) -> Unit,
    viewModel: ClientViewModel = hiltViewModel(),
) {
    val state by viewModel.detailState.collectAsStateWithLifecycle()

    LaunchedEffect(clientId) { viewModel.loadClient(clientId) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("거래처 상세") },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "뒤로")
                    }
                },
                actions = {
                    if (state.client != null) {
                        IconButton(onClick = { onEdit(clientId) }) {
                            Icon(Icons.Default.Edit, contentDescription = "편집")
                        }
                    }
                },
            )
        }
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
                    onRetry = { viewModel.loadClient(clientId) },
                    modifier = Modifier.align(Alignment.Center),
                )
                state.client != null -> ClientDetailContent(state.client!!, state.analytics)
            }
        }
    }
}

@Composable
private fun ClientDetailContent(client: ClientDto, analytics: ClientAnalyticsDto?) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(text = client.name, style = MaterialTheme.typography.headlineSmall)
        client.company?.takeIf { it.isNotBlank() }?.let {
            Text(text = it, style = MaterialTheme.typography.bodyLarge)
        }

        Spacer(Modifier.height(8.dp))

        // KPI row: invoice count + total billed.
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            StatCard(label = "송장 수", value = "${client.invoiceCount}건", modifier = Modifier.weight(1f))
            StatCard(label = "총 청구액", value = formatKrw(client.totalBilled), modifier = Modifier.weight(1f))
        }

        analytics?.let { AnalyticsSection(it) }

        Spacer(Modifier.height(8.dp))

        client.email?.takeIf { it.isNotBlank() }?.let { InfoRow("이메일", it) }
        client.phone?.takeIf { it.isNotBlank() }?.let { InfoRow("전화", it) }
        client.taxId?.takeIf { it.isNotBlank() }?.let { InfoRow("사업자번호", it) }
        client.notes?.takeIf { it.isNotBlank() }?.let { InfoRow("메모", it) }
    }
}

@Composable
private fun AnalyticsSection(a: ClientAnalyticsDto) {
    Spacer(Modifier.height(8.dp))
    Text("결제 분석", style = MaterialTheme.typography.titleMedium)
    InfoRow("총 수금액", formatKrwString(a.totalPaid))
    InfoRow("미수금", formatKrwString(a.outstandingAmount))
    a.avgPaymentDays?.let { InfoRow("평균 결제 소요", "%.0f일".format(it)) }
    a.onTimeRate?.let { InfoRow("정시 결제율", "%.0f%%".format(it)) }
}

@Composable
private fun StatCard(label: String, value: String, modifier: Modifier = Modifier) {
    Card(modifier = modifier) {
        Column(Modifier.padding(16.dp)) {
            Text(label, style = MaterialTheme.typography.labelMedium)
            Spacer(Modifier.height(4.dp))
            Text(value, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
        }
    }
}

@Composable
private fun InfoRow(label: String, value: String) {
    Column {
        Text(text = label, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(text = value, style = MaterialTheme.typography.bodyLarge)
    }
}

private fun formatKrw(amount: Long): String {
    val fmt = NumberFormat.getCurrencyInstance(Locale.KOREA)
    return fmt.format(amount)
}

/** Formats a decimal-string amount (analytics money fields) as KRW. */
private fun formatKrwString(raw: String): String {
    val value = raw.toBigDecimalOrNull() ?: return formatKrw(0)
    return formatKrw(value.toLong())
}
