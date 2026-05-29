package com.invoiceflow.features.notifications

import android.util.Log
import com.google.firebase.messaging.FirebaseMessaging
import com.invoiceflow.features.notifications.data.DeviceRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import javax.inject.Inject
import javax.inject.Singleton

/**
 * AMI-41/72: bridges the FCM token to our backend via POST /api/v1/devices.
 *
 * The token half ("which device am I?") lives here; the notification half
 * ("show a notification when a message arrives") lives in
 * [AmiMessagingService].
 *
 * Contract agreed with the server team:
 *
 *     POST /api/v1/devices
 *     { "token": "<fcm_token>", "platform": "android" }
 *
 * Idempotent on (user_id, token). The call requires the Bearer token, so
 * unauthenticated refreshes (e.g. before login) will fail — that's expected;
 * [pullAndRegister] is re-invoked on successful login to recover.
 */
@Singleton
class PushTokenRegistrar @Inject constructor(
    private val deviceRepository: DeviceRepository,
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    /** Called by [AmiMessagingService.onNewToken] on FCM token refresh. */
    fun onTokenRefreshed(token: String) {
        Log.i(TAG, "FCM token refreshed: ${token.take(16)}...")
        scope.launch { registerWithBackend(token) }
    }

    /** Called on successful login so the new session inherits the token. */
    fun pullAndRegister() {
        scope.launch {
            runCatching { FirebaseMessaging.getInstance().token.await() }
                .onSuccess { token ->
                    Log.i(TAG, "FCM token at login: ${token.take(16)}...")
                    registerWithBackend(token)
                }
                .onFailure { e -> Log.w(TAG, "FCM token fetch failed", e) }
        }
    }

    /** POST /api/v1/devices { token, platform: "android" }. */
    private suspend fun registerWithBackend(token: String) {
        runCatching { deviceRepository.registerDevice(token = token, platform = PLATFORM) }
            .onSuccess { device -> Log.i(TAG, "Device registered: ${device.id}") }
            .onFailure { e -> Log.w(TAG, "Device registration failed", e) }
    }

    companion object {
        private const val TAG = "PushTokenRegistrar"
        private const val PLATFORM = "android"
    }
}
