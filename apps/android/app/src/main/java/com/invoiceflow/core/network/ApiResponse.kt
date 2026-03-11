package com.invoiceflow.core.network

import com.squareup.moshi.JsonClass

@JsonClass(generateAdapter = true)
data class ApiResponse<T>(val data: T)

@JsonClass(generateAdapter = true)
data class PaginatedApiResponse<T>(
    val data: List<T>,
    val meta: PaginationMeta,
)

@JsonClass(generateAdapter = true)
data class PaginationMeta(
    val total: Int,
    val page: Int,
    val limit: Int,
    @com.squareup.moshi.Json(name = "total_pages") val totalPages: Int,
)
