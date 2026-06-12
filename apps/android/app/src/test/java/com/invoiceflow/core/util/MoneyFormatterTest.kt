package com.invoiceflow.core.util

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Regression: the invoice list/detail rendered raw "${currency} ${amount}"
 * ("KRW 1500000.00"). MoneyFormatter must group thousands, use the right
 * symbol, and drop decimals for KRW/JPY.
 */
class MoneyFormatterTest {

    @Test
    fun `KRW groups thousands and drops decimals`() {
        val out = MoneyFormatter.format("1500000.00", "KRW")
        assertTrue("expected grouped thousands, got $out", out.contains("1,500,000"))
        assertTrue("KRW should not show decimals, got $out", !out.contains(".00"))
    }

    @Test
    fun `JPY drops decimals`() {
        val out = MoneyFormatter.format("9800.00", "JPY")
        assertTrue("expected 9,800, got $out", out.contains("9,800"))
        assertTrue("JPY should not show decimals, got $out", !out.contains(".00"))
    }

    @Test
    fun `USD keeps two fraction digits`() {
        val out = MoneyFormatter.format("99.5", "USD")
        assertTrue("expected 99.50, got $out", out.contains("99.50"))
    }

    @Test
    fun `null amount is handled gracefully`() {
        assertEquals("KRW 0", MoneyFormatter.format(null, "KRW"))
    }

    @Test
    fun `null currency defaults to KRW`() {
        val out = MoneyFormatter.format("1000", null)
        assertTrue("expected grouped KRW, got $out", out.contains("1,000"))
    }
}
