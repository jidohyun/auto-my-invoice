package com.invoiceflow.features.invoices.data

import com.invoiceflow.core.network.ApiService
import com.invoiceflow.features.invoices.data.model.InvoiceCreateRequest
import com.invoiceflow.features.invoices.data.model.InvoiceDto
import com.invoiceflow.features.invoices.data.model.InvoiceUpdateRequest
import com.invoiceflow.features.invoices.data.model.MarkPaidRequest
import com.invoiceflow.features.invoices.data.model.RecordPaymentRequest
import com.invoiceflow.features.invoices.data.model.SendInvoiceRequest
import okhttp3.ResponseBody
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class InvoiceRepository @Inject constructor(private val apiService: ApiService) {

    suspend fun getInvoices(page: Int = 1, limit: Int = 20, status: String? = null, clientId: String? = null, search: String? = null) =
        apiService.getInvoices(page, limit, status, clientId, search)

    suspend fun getInvoice(id: String): InvoiceDto = apiService.getInvoice(id).data

    suspend fun createInvoice(request: InvoiceCreateRequest): InvoiceDto = apiService.createInvoice(request).data

    suspend fun updateInvoice(id: String, request: InvoiceUpdateRequest): InvoiceDto = apiService.updateInvoice(id, request).data

    suspend fun deleteInvoice(id: String) = apiService.deleteInvoice(id)

    suspend fun sendInvoice(id: String, message: String? = null): InvoiceDto =
        apiService.sendInvoice(id, SendInvoiceRequest(message)).data

    suspend fun markPaid(id: String, request: MarkPaidRequest = MarkPaidRequest()): InvoiceDto =
        apiService.markInvoicePaid(id, request).data

    /** Records a (possibly partial) payment; returns the re-rendered invoice. */
    suspend fun recordPayment(id: String, amount: String): InvoiceDto =
        apiService.recordPayment(id, RecordPaymentRequest(amount = amount)).data

    /** Queues a manual reminder; returns the server's confirmation message. */
    suspend fun sendReminder(id: String): String =
        apiService.sendReminder(id).data.message

    /** Streams the invoice PDF bytes. Caller is responsible for closing/using
     *  the [ResponseBody] (e.g. copying to a cache file). */
    suspend fun downloadInvoicePdf(id: String): ResponseBody =
        apiService.downloadInvoicePdf(id)
}
