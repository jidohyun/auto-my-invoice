package com.invoiceflow.features.analytics.ui

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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.background
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.invoiceflow.features.analytics.data.model.AgingBucketDto
import com.invoiceflow.features.analytics.data.model.ClientRankingDto
import com.invoiceflow.features.analytics.data.model.MonthlyCollectionDto
import com.invoiceflow.features.analytics.data.model.ReminderEffectivenessDto
import com.invoiceflow.features.analytics.data.model.StatusDistributionDto
import com.invoiceflow.features.analytics.viewmodel.AnalyticsViewModel
import com.invoiceflow.ui.components.ErrorState
import com.invoiceflow.ui.components.StatusPill

/**
 * AMI parity (Android): read-only analytics screen mirroring the web
 * dashboard's charts — monthly collections, status distribution, invoice
 * aging, reminder effectiveness, and the client payment ranking. Money is
 * server-rolled to KRW (AMI-90).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AnalyticsScreen(
    onNavigateBack: () -> Unit,
    viewModel: AnalyticsViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    LaunchedEffect(Unit) { viewModel.load() }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("분석") },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "뒤로")
                    }
                },
            )
        },
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            when {
                state.isLoading && state.analytics == null ->
                    CircularProgressIndicator(modifier = Modifier.align(Alignment.Center))

                state.error != null && state.analytics == null ->
                    ErrorState(
                        message = state.error ?: "",
                        onRetry = { viewModel.load() },
                        modifier = Modifier.align(Alignment.Center),
                    )

                else -> Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .verticalScroll(rememberScrollState())
                        .padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp),
                ) {
                    state.analytics?.let { a ->
                        MonthlySection(a.monthlyCollections)
                        StatusSection(a.statusDistribution)
                        AgingSection(a.invoiceAging)
                    }
                    state.reminders?.let { ReminderSection(it) }
                    if (state.ranking.isNotEmpty()) RankingSection(state.ranking)
                }
            }
        }
    }
}

@Composable
private fun Section(title: String, content: @Composable () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(MaterialTheme.colorScheme.surfaceVariant)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Text(title, style = MaterialTheme.typography.titleMedium)
        content()
    }
}

@Composable
private fun MonthlySection(rows: List<MonthlyCollectionDto>) {
    val maxValue = rows.mapNotNull { it.invoiced.toDoubleOrNull() }.maxOrNull() ?: 1.0
    Section("월별 청구·수금") {
        if (rows.isEmpty()) {
            HintText("데이터가 없습니다.")
        } else {
            rows.forEach { row -> MonthlyBar(row, if (maxValue == 0.0) 1.0 else maxValue) }
        }
    }
}

@Composable
private fun MonthlyBar(row: MonthlyCollectionDto, maxValue: Double) {
    val invoiced = row.invoiced.toDoubleOrNull() ?: 0.0
    val collected = row.collected.toDoubleOrNull() ?: 0.0
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Row(modifier = Modifier.fillMaxWidth()) {
            Text(row.month, style = MaterialTheme.typography.labelMedium)
            Spacer(Modifier.fillMaxWidth(0.5f))
            Text(
                "수금 ${formatKrw(row.collected)}",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Bar(fraction = (invoiced / maxValue).toFloat(), color = MaterialTheme.colorScheme.outline)
        Bar(fraction = (collected / maxValue).toFloat(), color = MaterialTheme.colorScheme.primary)
    }
}

@Composable
private fun Bar(fraction: Float, color: androidx.compose.ui.graphics.Color) {
    Box(
        modifier = Modifier
            .fillMaxWidth(fraction.coerceIn(0.02f, 1f))
            .height(8.dp)
            .clip(RoundedCornerShape(3.dp))
            .background(color)
    )
}

@Composable
private fun StatusSection(rows: List<StatusDistributionDto>) {
    Section("상태 분포") {
        if (rows.isEmpty()) {
            HintText("데이터가 없습니다.")
        } else {
            rows.forEach { row ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    StatusPill(statusString = row.status)
                    Spacer(Modifier.fillMaxWidth(0.4f))
                    Text("${row.count}건", style = MaterialTheme.typography.bodyMedium)
                    Spacer(Modifier.fillMaxWidth())
                    Text(
                        formatKrw(row.total),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }
    }
}

@Composable
private fun AgingSection(buckets: Map<String, AgingBucketDto>) {
    val order = listOf("0-30", "31-60", "61-90", "90+")
    Section("미수금 연령") {
        order.forEach { key ->
            val bucket = buckets[key]
            Row(modifier = Modifier.fillMaxWidth()) {
                Text("${key}일", style = MaterialTheme.typography.bodyMedium)
                Spacer(Modifier.fillMaxWidth(0.4f))
                Text("${bucket?.count ?: 0}건", style = MaterialTheme.typography.bodyMedium)
                Spacer(Modifier.fillMaxWidth())
                Text(
                    formatKrw(bucket?.total ?: "0"),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

@Composable
private fun ReminderSection(r: ReminderEffectivenessDto) {
    Section("리마인더 효과") {
        StatRow("발송", "${r.totalSent}건")
        StatRow("열람률", "%.1f%%".format(r.overallOpenRate))
        StatRow("클릭률", "%.1f%%".format(r.overallClickRate))
        r.overallConversionRate?.let { StatRow("결제 전환율", "%.1f%%".format(it)) }
        r.avgDaysToPayment?.let { StatRow("평균 결제 소요", "%.1f일".format(it)) }
    }
}

@Composable
private fun RankingSection(rows: List<ClientRankingDto>) {
    Section("고객 결제 순위") {
        rows.forEach { row ->
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Row(modifier = Modifier.fillMaxWidth()) {
                    Text(row.name, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.Medium)
                    Spacer(Modifier.fillMaxWidth())
                    row.avgPaymentDays?.let {
                        Text(
                            "평균 %.0f일".format(it),
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
                Row(modifier = Modifier.fillMaxWidth()) {
                    Text(
                        "청구 ${formatKrw(row.totalInvoiced)}",
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Spacer(Modifier.fillMaxWidth())
                    row.onTimeRate?.let {
                        Text(
                            "정시 %.0f%%".format(it),
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }
            HorizontalDivider()
        }
    }
}

@Composable
private fun StatRow(label: String, value: String) {
    Row(modifier = Modifier.fillMaxWidth()) {
        Text(label, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Spacer(Modifier.fillMaxWidth())
        Text(value, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium)
    }
}

@Composable
private fun HintText(text: String) {
    Text(text, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
}

/** Formats a decimal string as KRW (amounts are server-rolled to KRW). */
private fun formatKrw(raw: String): String {
    val value = raw.toBigDecimalOrNull() ?: return "₩0"
    return "₩%,d".format(value.toLong())
}
