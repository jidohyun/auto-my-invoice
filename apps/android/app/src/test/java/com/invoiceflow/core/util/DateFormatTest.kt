package com.invoiceflow.core.util

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Regression: the invoice detail printed raw instants ("Paid on:
 * 2026-06-10T07:25:11Z"). DateFormat must turn API date shapes into
 * locale-formatted text and never echo the raw ISO string back.
 */
class DateFormatTest {

    @Test
    fun `instant formats a UTC ISO-8601 string without the raw T or Z`() {
        val out = DateFormat.instant("2026-06-10T07:25:11Z")
        assertNotNull(out)
        assertTrue("should not contain raw ISO marker, got $out", !out!!.contains("T07:25"))
        assertTrue("should not contain trailing Z, got $out", !out.contains("Z"))
        assertTrue("should mention the year, got $out", out.contains("2026"))
    }

    @Test
    fun `date formats a plain calendar date`() {
        val out = DateFormat.date("2026-07-10")
        assertNotNull(out)
        assertTrue("should mention the year, got $out", out!!.contains("2026"))
    }

    @Test
    fun `null and blank inputs return null so callers can omit the row`() {
        assertNull(DateFormat.instant(null))
        assertNull(DateFormat.instant(""))
        assertNull(DateFormat.date(null))
        assertNull(DateFormat.date(""))
    }

    @Test
    fun `unparseable input falls back to the raw value instead of throwing`() {
        assertEquals("not-a-date", DateFormat.instant("not-a-date"))
        assertEquals("13/40/9999", DateFormat.date("13/40/9999"))
    }
}
