-if class com.invoiceflow.features.auth.data.model.LoginResponse
-keepnames class com.invoiceflow.features.auth.data.model.LoginResponse
-if class com.invoiceflow.features.auth.data.model.LoginResponse
-keep class com.invoiceflow.features.auth.data.model.LoginResponseJsonAdapter {
    public <init>(com.squareup.moshi.Moshi);
}
