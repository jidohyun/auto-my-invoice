package com.invoiceflow.features.qr.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class InvoicePayUrlParserTest {

    @Test
    fun `parses path form pay link`() {
        val id = InvoicePayUrlParser.parseInvoiceId("https://app.invoiceflow.app/pay/abc-123")
        assertEquals("abc-123", id)
    }

    @Test
    fun `parses invoices path form`() {
        val id = InvoicePayUrlParser.parseInvoiceId("https://app.invoiceflow.app/invoices/inv-42")
        assertEquals("inv-42", id)
    }

    @Test
    fun `parses query param form`() {
        val id = InvoicePayUrlParser.parseInvoiceId("https://app.invoiceflow.app/pay?invoice_id=q-7")
        assertEquals("q-7", id)
    }

    @Test
    fun `parses custom scheme deep link`() {
        val id = InvoicePayUrlParser.parseInvoiceId("invoiceflow://invoices/deep-9")
        assertEquals("deep-9", id)
    }

    @Test
    fun `returns null for unrelated url`() {
        assertNull(InvoicePayUrlParser.parseInvoiceId("https://example.com/about"))
    }

    @Test
    fun `returns null for blank input`() {
        assertNull(InvoicePayUrlParser.parseInvoiceId(""))
        assertNull(InvoicePayUrlParser.parseInvoiceId(null))
        assertNull(InvoicePayUrlParser.parseInvoiceId("   "))
    }

    @Test
    fun `returns null when path segment has no id`() {
        assertNull(InvoicePayUrlParser.parseInvoiceId("https://app.invoiceflow.app/pay/"))
    }
}
