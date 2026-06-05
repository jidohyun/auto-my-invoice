package com.invoiceflow.features.upload.viewmodel

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.invoiceflow.R
import com.invoiceflow.features.upload.data.UploadRepository
import com.invoiceflow.features.upload.data.model.ExtractedDataDto
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.io.File
import javax.inject.Inject

enum class UploadStage { IDLE, UPLOADING, PROCESSING, COMPLETED, FAILED }

data class UploadState(
    val stage: UploadStage = UploadStage.IDLE,
    val error: String? = null,
    /** Populated once extraction completes; drives navigation to InvoiceCreate. */
    val extractedData: ExtractedDataDto? = null,
)

@HiltViewModel
class UploadViewModel @Inject constructor(
    @ApplicationContext private val appContext: Context,
    private val uploadRepository: UploadRepository,
) : ViewModel() {

    private val _state = MutableStateFlow(UploadState())
    val state: StateFlow<UploadState> = _state.asStateFlow()

    /**
     * Upload [file] then poll the extraction job until it completes or fails.
     * Polls up to [maxPolls] times at [pollIntervalMs] intervals.
     */
    fun uploadAndExtract(file: File, maxPolls: Int = 30, pollIntervalMs: Long = 2000L) {
        if (_state.value.stage == UploadStage.UPLOADING || _state.value.stage == UploadStage.PROCESSING) return
        _state.update { it.copy(stage = UploadStage.UPLOADING, error = null, extractedData = null) }
        viewModelScope.launch {
            try {
                val job = uploadRepository.uploadFile(file)
                _state.update { it.copy(stage = UploadStage.PROCESSING) }

                var current = job
                var polls = 0
                while (current.status !in setOf("completed", "failed") && polls < maxPolls) {
                    delay(pollIntervalMs)
                    current = uploadRepository.getExtractionJob(job.id)
                    polls++
                }

                when (current.status) {
                    "completed" -> _state.update {
                        it.copy(stage = UploadStage.COMPLETED, extractedData = current.extractedData)
                    }
                    "failed" -> _state.update {
                        it.copy(stage = UploadStage.FAILED, error = current.errorMessage ?: appContext.getString(R.string.upload_error_extract_failed))
                    }
                    else -> _state.update {
                        it.copy(stage = UploadStage.FAILED, error = appContext.getString(R.string.upload_error_timeout))
                    }
                }
            } catch (e: Exception) {
                _state.update { it.copy(stage = UploadStage.FAILED, error = e.message ?: appContext.getString(R.string.upload_error_failed)) }
            } finally {
                runCatching { if (file.exists()) file.delete() }
            }
        }
    }

    fun reset() {
        _state.value = UploadState()
    }

    /** Clear the extracted-data trigger after the screen has navigated. */
    fun consumeNavigation() {
        _state.update { it.copy(extractedData = null) }
    }
}
