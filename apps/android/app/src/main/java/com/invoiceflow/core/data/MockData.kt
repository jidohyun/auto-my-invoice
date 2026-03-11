package com.invoiceflow.core.data

import com.invoiceflow.features.clients.data.model.ClientDto
import com.invoiceflow.features.invoices.data.model.InvoiceDto
import com.invoiceflow.features.invoices.data.model.InvoiceLineItemDto

object MockData {
    val clients = listOf(
        ClientDto(id = "1", name = "주식회사 테크스타", email = "billing@techstar.co.kr", phone = "02-1234-5678", company = "테크스타"),
        ClientDto(id = "2", name = "디자인랩 코리아", email = "contact@designlab.kr", phone = "02-9876-5432", company = "디자인랩"),
        ClientDto(id = "3", name = "스타트업 벤처스", email = "ceo@startupventures.io", phone = null, company = "스타트업 벤처스"),
    )

    val invoices = listOf(
        InvoiceDto(
            id = "1", invoiceNumber = "INV-2026-001", status = "paid",
            client = clients[0],
            lineItems = listOf(InvoiceLineItemDto(description = "UI 디자인", quantity = 1.0, unitPrice = 1500000)),
            subtotal = 1500000, taxAmount = 150000, total = 1650000, currency = "KRW",
            issuedAt = "2026-03-01", dueAt = "2026-03-15", paidAt = "2026-03-10",
            paymentMethod = "bank_transfer", notes = null,
            insertedAt = "2026-03-01T00:00:00Z", updatedAt = "2026-03-10T00:00:00Z",
        ),
        InvoiceDto(
            id = "2", invoiceNumber = "INV-2026-002", status = "sent",
            client = clients[1],
            lineItems = listOf(InvoiceLineItemDto(description = "브랜딩 작업", quantity = 1.0, unitPrice = 850000)),
            subtotal = 850000, taxAmount = 85000, total = 935000, currency = "KRW",
            issuedAt = "2026-03-05", dueAt = "2026-03-20", paidAt = null,
            paymentMethod = null, notes = "2차 작업분",
            insertedAt = "2026-03-05T00:00:00Z", updatedAt = "2026-03-05T00:00:00Z",
        ),
        InvoiceDto(
            id = "3", invoiceNumber = "INV-2026-003", status = "overdue",
            client = clients[2],
            lineItems = listOf(InvoiceLineItemDto(description = "개발 컨설팅", quantity = 4.0, unitPrice = 800000)),
            subtotal = 3200000, taxAmount = 320000, total = 3520000, currency = "KRW",
            issuedAt = "2026-02-10", dueAt = "2026-02-28", paidAt = null,
            paymentMethod = null, notes = null,
            insertedAt = "2026-02-10T00:00:00Z", updatedAt = "2026-02-10T00:00:00Z",
        ),
        InvoiceDto(
            id = "4", invoiceNumber = "INV-2026-004", status = "partially_paid",
            client = clients[0],
            lineItems = listOf(InvoiceLineItemDto(description = "앱 개발", quantity = 1.0, unitPrice = 2100000)),
            subtotal = 2100000, taxAmount = 210000, total = 2310000, currency = "KRW",
            issuedAt = "2026-03-08", dueAt = "2026-03-25", paidAt = null,
            paymentMethod = null, notes = null,
            insertedAt = "2026-03-08T00:00:00Z", updatedAt = "2026-03-08T00:00:00Z",
        ),
        InvoiceDto(
            id = "5", invoiceNumber = "INV-2026-005", status = "draft",
            client = clients[1],
            lineItems = listOf(InvoiceLineItemDto(description = "로고 디자인", quantity = 1.0, unitPrice = 500000)),
            subtotal = 500000, taxAmount = 50000, total = 550000, currency = "KRW",
            issuedAt = null, dueAt = "2026-04-01", paidAt = null,
            paymentMethod = null, notes = "초안",
            insertedAt = "2026-03-10T00:00:00Z", updatedAt = "2026-03-10T00:00:00Z",
        ),
    )
}
