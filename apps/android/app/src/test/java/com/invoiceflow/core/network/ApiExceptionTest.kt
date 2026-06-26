package com.invoiceflow.core.network

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.IOException

/**
 * Regression: ErrorMappingInterceptor throws ApiException from inside the OkHttp
 * chain. If ApiException were a plain Exception, OkHttp's dispatcher thread would
 * crash the app (FATAL EXCEPTION: OkHttp Dispatcher) instead of propagating the
 * error to the suspend call site. It MUST be an IOException so Retrofit surfaces
 * it to the coroutine where the repository's try/catch handles it.
 */
class ApiExceptionTest {

    @Test
    fun `ApiException is an IOException so OkHttp propagates it`() {
        val e = ApiException("unauthorized", "Invalid credentials")
        assertTrue("ApiException must extend IOException", e is IOException)
    }

    @Test
    fun `ApiException carries server code and message`() {
        val e = ApiException("unauthorized", "Invalid credentials")
        assertEquals("unauthorized", e.code)
        assertEquals("Invalid credentials", e.message)
    }
}
