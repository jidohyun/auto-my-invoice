package com.invoiceflow.features.clients.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.text.KeyboardOptions
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.invoiceflow.features.clients.data.model.ClientRequest
import com.invoiceflow.features.clients.viewmodel.ClientViewModel

/**
 * Create-or-edit form for a client. When [clientId] is non-null the form
 * loads the existing client, prefills the fields, and PUTs an update;
 * otherwise it POSTs a new client. On success [onSaved] navigates away.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ClientFormScreen(
    clientId: String?,
    onBack: () -> Unit,
    onSaved: (String) -> Unit,
    viewModel: ClientViewModel = hiltViewModel(),
) {
    val isEdit = clientId != null
    val formState by viewModel.formState.collectAsStateWithLifecycle()
    val detailState by viewModel.detailState.collectAsStateWithLifecycle()

    var name by remember { mutableStateOf("") }
    var email by remember { mutableStateOf("") }
    var company by remember { mutableStateOf("") }
    var phone by remember { mutableStateOf("") }
    var prefilled by remember { mutableStateOf(false) }

    // Reset transient form state once when the screen opens.
    LaunchedEffect(clientId) {
        viewModel.resetForm()
        if (clientId != null) viewModel.loadClient(clientId)
    }

    // Prefill exactly once when editing and the client arrives.
    LaunchedEffect(detailState.client) {
        val client = detailState.client
        if (isEdit && client != null && client.id == clientId && !prefilled) {
            name = client.name
            email = client.email ?: ""
            company = client.company ?: ""
            phone = client.phone ?: ""
            prefilled = true
        }
    }

    // Navigate away once the save succeeds.
    LaunchedEffect(formState.savedClientId) {
        val id = formState.savedClientId
        if (id != null) {
            onSaved(id)
            viewModel.consumeFormNavigation()
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(if (isEdit) "거래처 편집" else "새 거래처") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "뒤로")
                    }
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
            OutlinedTextField(
                value = name,
                onValueChange = { name = it },
                label = { Text("이름 *") },
                singleLine = true,
                isError = name.isBlank(),
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedTextField(
                value = email,
                onValueChange = { email = it },
                label = { Text("이메일") },
                singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedTextField(
                value = company,
                onValueChange = { company = it },
                label = { Text("회사") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedTextField(
                value = phone,
                onValueChange = { phone = it },
                label = { Text("전화번호") },
                singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone),
                modifier = Modifier.fillMaxWidth(),
            )

            formState.error?.let { msg -> Text(msg, color = MaterialTheme.colorScheme.error) }

            Button(
                onClick = {
                    if (name.isBlank()) return@Button
                    val request = ClientRequest(
                        name = name.trim(),
                        email = email.trim().ifBlank { null },
                        company = company.trim().ifBlank { null },
                        phone = phone.trim().ifBlank { null },
                    )
                    if (clientId != null) {
                        viewModel.updateClient(clientId, request)
                    } else {
                        viewModel.createClient(request)
                    }
                },
                enabled = !formState.isSubmitting && name.isNotBlank(),
                modifier = Modifier.fillMaxWidth(),
            ) {
                if (formState.isSubmitting) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(20.dp),
                        strokeWidth = 2.dp,
                        color = MaterialTheme.colorScheme.onPrimary,
                    )
                    Spacer(Modifier.width(8.dp))
                    Text("저장 중...")
                } else {
                    Text(if (isEdit) "변경 사항 저장" else "거래처 추가")
                }
            }
        }
    }
}
