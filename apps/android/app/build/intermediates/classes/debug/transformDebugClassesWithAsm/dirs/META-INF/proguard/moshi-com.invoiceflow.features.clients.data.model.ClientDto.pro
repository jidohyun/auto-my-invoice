-if class com.invoiceflow.features.clients.data.model.ClientDto
-keepnames class com.invoiceflow.features.clients.data.model.ClientDto
-if class com.invoiceflow.features.clients.data.model.ClientDto
-keep class com.invoiceflow.features.clients.data.model.ClientDtoJsonAdapter {
    public <init>(com.squareup.moshi.Moshi);
}
