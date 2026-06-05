package com.invoiceflow.core.network

import com.squareup.moshi.JsonClass

@JsonClass(generateAdapter = true)
data class ApiResponse<T>(val data: T)

@JsonClass(generateAdapter = true)
data class PaginatedApiResponse<T>(
    val data: List<T>,
    val meta: PaginationMeta,
)

/**
 * 페이지네이션 메타. 백엔드는 `total` 만 항상 보장하고 page/limit/total_pages
 * 는 엔드포인트에 따라 생략한다(/clients 는 {total} 만, /invoices 는
 * {total, counts}). 누락 시 Moshi 가 "Required value missing" 으로 죽지 않도록
 * total 외에는 nullable + 기본값으로 둔다.
 */
@JsonClass(generateAdapter = true)
data class PaginationMeta(
    val total: Int,
    val page: Int? = null,
    val limit: Int? = null,
    @com.squareup.moshi.Json(name = "total_pages") val totalPages: Int? = null,
)
