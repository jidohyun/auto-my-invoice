package com.invoiceflow.features.auth.data.model

import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass

@JsonClass(generateAdapter = true)
data class LoginRequest(val email: String, val password: String)

@JsonClass(generateAdapter = true)
data class RegisterRequest(val email: String, val password: String, val name: String)

@JsonClass(generateAdapter = true)
data class RefreshTokenRequest(@Json(name = "refresh_token") val refreshToken: String)

@JsonClass(generateAdapter = true)
data class AuthData(
    @Json(name = "access_token") val accessToken: String,
    @Json(name = "refresh_token") val refreshToken: String,
    @Json(name = "expires_in") val expiresIn: Int,
    val user: UserDto,
)

@JsonClass(generateAdapter = true)
data class UserDto(
    val id: String,
    val email: String,
    val name: String,
    @Json(name = "avatar_url") val avatarUrl: String?,
)
