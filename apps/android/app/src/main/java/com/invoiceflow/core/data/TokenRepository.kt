package com.invoiceflow.core.data

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.firstOrNull
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "auth_prefs")

@Singleton
class TokenRepository @Inject constructor(
    @ApplicationContext private val context: Context,
) {
    private val accessTokenKey = stringPreferencesKey("access_token")
    private val refreshTokenKey = stringPreferencesKey("refresh_token")

    val accessTokenFlow: Flow<String?> = context.dataStore.data.map { it[accessTokenKey] }
    val refreshTokenFlow: Flow<String?> = context.dataStore.data.map { it[refreshTokenKey] }

    suspend fun getAccessToken(): String? = accessTokenFlow.firstOrNull()
    suspend fun getRefreshToken(): String? = refreshTokenFlow.firstOrNull()

    suspend fun saveTokens(accessToken: String, refreshToken: String) {
        context.dataStore.edit {
            it[accessTokenKey] = accessToken
            it[refreshTokenKey] = refreshToken
        }
    }

    suspend fun clearTokens() {
        context.dataStore.edit {
            it.remove(accessTokenKey)
            it.remove(refreshTokenKey)
        }
    }
}
