package com.invoiceflow.features.upload.data

import com.invoiceflow.core.network.ApiService
import com.invoiceflow.features.upload.data.model.ExtractionJobDto
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.MultipartBody
import okhttp3.RequestBody.Companion.asRequestBody
import java.io.File
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class UploadRepository @Inject constructor(private val apiService: ApiService) {

    suspend fun uploadFile(file: File): ExtractionJobDto {
        val requestBody = file.asRequestBody("application/octet-stream".toMediaTypeOrNull())
        val part = MultipartBody.Part.createFormData("file", file.name, requestBody)
        return apiService.uploadFile(part).data
    }

    suspend fun getExtractionJob(jobId: String): ExtractionJobDto =
        apiService.getExtractionJob(jobId).data
}
