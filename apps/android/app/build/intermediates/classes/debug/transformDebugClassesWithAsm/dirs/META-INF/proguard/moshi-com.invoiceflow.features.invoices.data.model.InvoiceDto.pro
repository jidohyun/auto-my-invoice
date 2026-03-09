-if class com.invoiceflow.features.invoices.data.model.InvoiceDto
-keepnames class com.invoiceflow.features.invoices.data.model.InvoiceDto
-if class com.invoiceflow.features.invoices.data.model.InvoiceDto
-keep class com.invoiceflow.features.invoices.data.model.InvoiceDtoJsonAdapter {
    public <init>(com.squareup.moshi.Moshi);
}
