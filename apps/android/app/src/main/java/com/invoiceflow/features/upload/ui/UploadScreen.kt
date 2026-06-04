package com.invoiceflow.features.upload.ui

import android.content.Context
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Image
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.invoiceflow.R
import com.invoiceflow.features.upload.data.model.ExtractedDataDto
import com.invoiceflow.features.upload.viewmodel.UploadStage
import com.invoiceflow.features.upload.viewmodel.UploadViewModel
import com.invoiceflow.ui.components.ErrorState
import java.io.File

/**
 * OCR upload flow: pick an invoice image with the system photo picker, upload
 * it via [UploadViewModel], poll until extraction completes, then hand the
 * extracted data to [onExtracted] which prefills the create-invoice form.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun UploadScreen(
    onBack: () -> Unit,
    onExtracted: (ExtractedDataDto) -> Unit,
    viewModel: UploadViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val context = LocalContext.current

    val pickerLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.PickVisualMedia()
    ) { uri: Uri? ->
        if (uri != null) {
            val file = copyUriToCache(context, uri)
            if (file != null) {
                viewModel.uploadAndExtract(file)
            }
        }
    }

    // Hand off the extracted data once, then clear the trigger.
    LaunchedEffect(state.extractedData) {
        val data = state.extractedData
        if (data != null) {
            onExtracted(data)
            viewModel.consumeNavigation()
        }
    }

    Scaffold(
        topBar = {
            androidx.compose.material3.TopAppBar(
                title = { Text(stringResource(R.string.upload_title)) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = stringResource(R.string.upload_back),
                        )
                    }
                },
            )
        }
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(24.dp),
            contentAlignment = Alignment.Center,
        ) {
            when (state.stage) {
                UploadStage.IDLE -> IdlePicker(
                    onPick = {
                        pickerLauncher.launch(
                            PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)
                        )
                    },
                )

                UploadStage.UPLOADING -> ProgressLabel(stringResource(R.string.upload_uploading))
                UploadStage.PROCESSING -> ProgressLabel(stringResource(R.string.upload_processing))

                UploadStage.FAILED -> ErrorState(
                    message = state.error ?: stringResource(R.string.upload_error_failed),
                    onRetry = {
                        viewModel.reset()
                        pickerLauncher.launch(
                            PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)
                        )
                    },
                )

                // COMPLETED is transient — navigation fires via LaunchedEffect.
                UploadStage.COMPLETED -> ProgressLabel(stringResource(R.string.upload_completed))
            }
        }
    }
}

@Composable
private fun IdlePicker(onPick: () -> Unit) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Icon(
            imageVector = Icons.Default.Image,
            contentDescription = null,
            modifier = Modifier.height(64.dp),
            tint = MaterialTheme.colorScheme.primary,
        )
        Text(
            text = stringResource(R.string.upload_idle_hint),
            style = MaterialTheme.typography.bodyMedium,
            textAlign = TextAlign.Center,
        )
        Button(onClick = onPick, modifier = Modifier.fillMaxWidth()) {
            Text(stringResource(R.string.upload_pick_image))
        }
    }
}

@Composable
private fun ProgressLabel(label: String) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        CircularProgressIndicator()
        Text(label, style = MaterialTheme.typography.bodyMedium, textAlign = TextAlign.Center)
    }
}

/**
 * Copy the picked content [uri] into a private cache file so the upload layer
 * (which takes a [File]) can read it. Returns null if the stream can't be read.
 */
private fun copyUriToCache(context: Context, uri: Uri): File? = runCatching {
    val dir = File(context.cacheDir, "ocr_uploads").apply { mkdirs() }
    val file = File.createTempFile("OCR_", ".jpg", dir)
    context.contentResolver.openInputStream(uri)?.use { input ->
        file.outputStream().use { output -> input.copyTo(output) }
    } ?: return null
    file
}.getOrNull()
