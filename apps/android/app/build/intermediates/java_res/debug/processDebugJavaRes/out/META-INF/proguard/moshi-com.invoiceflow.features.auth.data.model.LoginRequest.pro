-if class com.invoiceflow.features.auth.data.model.LoginRequest
-keepnames class com.invoiceflow.features.auth.data.model.LoginRequest
-if class com.invoiceflow.features.auth.data.model.LoginRequest
-keep class com.invoiceflow.features.auth.data.model.LoginRequestJsonAdapter {
    public <init>(com.squareup.moshi.Moshi);
}
