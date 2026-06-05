package com.invoiceflow.features.auth.data.model

import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass

@JsonClass(generateAdapter = true)
data class LoginRequest(val email: String, val password: String)

@JsonClass(generateAdapter = true)
data class RegisterRequest(
    val email: String,
    val password: String,
    // 백엔드 User 스키마는 name/full_name 이 없고 company_name(선택)만 받는다.
    // null 이면 Moshi 기본적으로 키를 생략하므로 회사명 미입력도 안전.
    @Json(name = "company_name") val companyName: String? = null,
)

/// Mirrors the backend `POST /auth/login|register` payload exactly:
/// `{"data": {"token": "...", "user": {...}}}`. The backend issues a single
/// Phoenix.Token (no refresh token / expiry envelope), so we persist just the
/// one bearer token; a 401 self-heals by clearing it and returning to login.
@JsonClass(generateAdapter = true)
data class AuthData(
    val token: String,
    val user: UserDto,
)

@JsonClass(generateAdapter = true)
data class UserDto(
    val id: String,
    val email: String,
    val plan: String? = null,
    @Json(name = "company_name") val companyName: String? = null,
    val timezone: String? = null,
    @Json(name = "brand_tone") val brandTone: String? = null,
    @Json(name = "avatar_url") val avatarUrl: String? = null,
)
