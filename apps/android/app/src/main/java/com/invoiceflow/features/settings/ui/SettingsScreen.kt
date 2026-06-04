package com.invoiceflow.features.settings.ui

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
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.invoiceflow.R
import com.invoiceflow.features.settings.viewmodel.SettingsIntent
import com.invoiceflow.features.settings.viewmodel.SettingsUiState
import com.invoiceflow.features.settings.viewmodel.SettingsViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    onLoggedOut: () -> Unit = {},
    viewModel: SettingsViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val snackbarHostState = remember { SnackbarHostState() }

    LaunchedEffect(Unit) { viewModel.onIntent(SettingsIntent.Load) }

    LaunchedEffect(state.loggedOut) {
        if (state.loggedOut) onLoggedOut()
    }

    LaunchedEffect(state.savedMessage, state.error) {
        val message = state.savedMessage ?: state.error
        if (message != null) {
            snackbarHostState.showSnackbar(message)
            viewModel.onIntent(SettingsIntent.MessageShown)
        }
    }

    Scaffold(
        topBar = { TopAppBar(title = { Text(stringResource(R.string.settings_title)) }) },
        snackbarHost = { SnackbarHost(snackbarHostState) },
    ) { padding ->
        if (state.isLoading) {
            Box(Modifier.fillMaxSize().padding(padding)) {
                CircularProgressIndicator(Modifier.align(Alignment.Center))
            }
            return@Scaffold
        }

        Column(
            modifier = Modifier
                .padding(padding)
                .padding(16.dp)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            ProfileSection(
                businessName = state.businessName,
                onBusinessNameChange = { viewModel.onIntent(SettingsIntent.BusinessNameChanged(it)) },
            )
            PaymentTermsSection(
                selected = state.paymentTermsDays,
                onSelect = { viewModel.onIntent(SettingsIntent.PaymentTermsChanged(it)) },
            )
            CurrencySection(
                selected = state.defaultCurrency,
                onSelect = { viewModel.onIntent(SettingsIntent.CurrencyChanged(it)) },
            )
            NotificationSection(
                notifyPayment = state.notifyPayment,
                notifyOverdue = state.notifyOverdue,
                notifyReminder = state.notifyReminder,
                onPaymentChange = { viewModel.onIntent(SettingsIntent.NotifyPaymentChanged(it)) },
                onOverdueChange = { viewModel.onIntent(SettingsIntent.NotifyOverdueChanged(it)) },
                onReminderChange = { viewModel.onIntent(SettingsIntent.NotifyReminderChanged(it)) },
            )
            Button(
                onClick = { viewModel.onIntent(SettingsIntent.Save) },
                enabled = !state.isSaving,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(stringResource(if (state.isSaving) R.string.settings_saving else R.string.settings_save))
            }
            OutlinedButton(
                onClick = { viewModel.onIntent(SettingsIntent.Logout) },
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.outlinedButtonColors(
                    contentColor = MaterialTheme.colorScheme.error,
                ),
            ) {
                Text(stringResource(R.string.settings_logout))
            }
            Spacer(Modifier.height(24.dp))
        }
    }
}

@Composable
private fun SectionCard(title: String, content: @Composable () -> Unit) {
    Card {
        Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
            content()
        }
    }
}

@Composable
private fun ProfileSection(businessName: String, onBusinessNameChange: (String) -> Unit) {
    SectionCard(title = stringResource(R.string.settings_profile)) {
        OutlinedTextField(
            value = businessName,
            onValueChange = onBusinessNameChange,
            label = { Text(stringResource(R.string.settings_company_name)) },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun PaymentTermsSection(selected: Int, onSelect: (Int) -> Unit) {
    SectionCard(title = stringResource(R.string.settings_payment_terms)) {
        Row(
            modifier = Modifier.fillMaxWidth().selectableGroup(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            SettingsUiState.PAYMENT_TERMS.forEach { days ->
                FilterChip(
                    selected = selected == days,
                    onClick = { onSelect(days) },
                    label = { Text("Net $days") },
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun CurrencySection(selected: String, onSelect: (String) -> Unit) {
    SectionCard(title = stringResource(R.string.settings_default_currency)) {
        Row(
            modifier = Modifier.fillMaxWidth().selectableGroup(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            SettingsUiState.CURRENCIES.forEach { currency ->
                FilterChip(
                    selected = selected == currency,
                    onClick = { onSelect(currency) },
                    label = { Text(currency) },
                )
            }
        }
    }
}

@Composable
private fun NotificationSection(
    notifyPayment: Boolean,
    notifyOverdue: Boolean,
    notifyReminder: Boolean,
    onPaymentChange: (Boolean) -> Unit,
    onOverdueChange: (Boolean) -> Unit,
    onReminderChange: (Boolean) -> Unit,
) {
    SectionCard(title = stringResource(R.string.settings_notifications)) {
        ToggleRow(stringResource(R.string.settings_notify_payment), notifyPayment, onPaymentChange)
        ToggleRow(stringResource(R.string.settings_notify_overdue), notifyOverdue, onOverdueChange)
        ToggleRow(stringResource(R.string.settings_notify_reminder), notifyReminder, onReminderChange)
    }
}

@Composable
private fun ToggleRow(label: String, checked: Boolean, onCheckedChange: (Boolean) -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(label, style = MaterialTheme.typography.bodyLarge)
        Switch(checked = checked, onCheckedChange = onCheckedChange)
    }
}
