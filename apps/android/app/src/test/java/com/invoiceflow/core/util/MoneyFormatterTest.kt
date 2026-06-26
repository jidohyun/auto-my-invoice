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

    // --- formatKrwCompact: dashboard KPI cards ---
    // Regression: the full grouped figure ("₩60,185,000") wrapped onto three
    // lines in the narrow 3-up KPI card. Compact 억/만 units keep it on one line.

    @Test
    fun `compact uses 만 unit with grouped thousands`() {
        val out = MoneyFormatter.formatKrwCompact("60185000")
        assertEquals("₩6,018만", out)
    }

    @Test
    fun `compact uses 억 unit for hundred-million-plus`() {
        val out = MoneyFormatter.formatKrwCompact("120000000")
        assertEquals("₩1.2억", out)
    }

    @Test
    fun `compact falls back to plain grouped figure under 10000`() {
        val out = MoneyFormatter.formatKrwCompact("9800")
        assertTrue("expected grouped figure, got $out", out.contains("9,800"))
    }

    @Test
    fun `compact handles null and non-numeric input`() {
        assertEquals("₩0", MoneyFormatter.formatKrwCompact(null))
        assertEquals("₩0", MoneyFormatter.formatKrwCompact("abc"))
    }
}
