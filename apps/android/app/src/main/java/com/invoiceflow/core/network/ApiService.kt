package com.invoiceflow.core.network

import com.invoiceflow.features.auth.data.model.AuthData
import com.invoiceflow.features.auth.data.model.LoginRequest
import com.invoiceflow.features.auth.data.model.RefreshTokenRequest
import com.invoiceflow.features.auth.data.model.RegisterRequest
import com.invoiceflow.features.analytics.data.model.ClientRankingDto
import com.invoiceflow.features.analytics.data.model.DashboardAnalyticsDto
import com.invoiceflow.features.analytics.data.model.ReminderEffectivenessDto
import com.invoiceflow.features.clients.data.model.ClientDto
import com.invoiceflow.features.clients.data.model.ClientRequest
import com.invoiceflow.features.dashboard.data.model.KpiSummaryDto
import com.invoiceflow.features.invoices.data.model.InvoiceCreateRequest
import com.invoiceflow.features.invoices.data.model.InvoiceDto
import com.invoiceflow.features.invoices.data.model.InvoiceUpdateRequest
import com.invoiceflow.features.invoices.data.model.MarkPaidRequest
import com.invoiceflow.features.invoices.data.model.RecordPaymentRequest
import com.invoiceflow.features.invoices.data.model.ReminderResponse
import com.invoiceflow.features.invoices.data.model.SendInvoiceRequest
import com.invoiceflow.features.notifications.data.model.DeviceDto
import com.invoiceflow.features.notifications.data.model.DeviceRegistrationRequest
import com.invoiceflow.features.settings.data.model.UserSettingsDto
import com.invoiceflow.features.settings.data.model.UserSettingsRequest
import com.invoiceflow.features.upload.data.model.ExtractionJobDto
import okhttp3.MultipartBody
import okhttp3.ResponseBody
import retrofit2.http.Body
import retrofit2.http.DELETE
import retrofit2.http.GET
import retrofit2.http.Multipart
import retrofit2.http.POST
import retrofit2.http.PUT
import retrofit2.http.Part
import retrofit2.http.Path
import retrofit2.http.Query
import retrofit2.http.Streaming

interface ApiService {

    // Auth
    @POST("auth/login")
    suspend fun login(@Body request: LoginRequest): ApiResponse<AuthData>

    @POST("auth/register")
    suspend fun register(@Body request: RegisterRequest): ApiResponse<AuthData>

    @POST("auth/refresh")
    suspend fun refreshToken(@Body request: RefreshTokenRequest): ApiResponse<AuthData>

    @DELETE("auth/logout")
    suspend fun logout()

    // Dashboard — backend route is /api/v1/dashboard (DashboardController :index).
    @GET("dashboard")
    suspend fun getDashboardKpi(): ApiResponse<KpiSummaryDto>

    @GET("dashboard/recent")
    suspend fun getRecentInvoices(@Query("limit") limit: Int = 5): ApiResponse<List<InvoiceDto>>

    // Analytics (read-only, AMI parity)
    @GET("dashboard/analytics")
    suspend fun getDashboardAnalytics(): ApiResponse<DashboardAnalyticsDto>

    @GET("analytics/reminders")
    suspend fun getReminderEffectiveness(): ApiResponse<ReminderEffectivenessDto>

    @GET("clients/ranking")
    suspend fun getClientRanking(): ApiResponse<List<ClientRankingDto>>

    // Invoices
    @GET("invoices")
    suspend fun getInvoices(
        @Query("page") page: Int = 1,
        @Query("limit") limit: Int = 20,
        @Query("status") status: String? = null,
        @Query("client_id") clientId: String? = null,
        @Query("search") search: String? = null,
    ): PaginatedApiResponse<InvoiceDto>

    @GET("invoices/{id}")
    suspend fun getInvoice(@Path("id") id: String): ApiResponse<InvoiceDto>

    @POST("invoices")
    suspend fun createInvoice(@Body request: InvoiceCreateRequest): ApiResponse<InvoiceDto>

    @PUT("invoices/{id}")
    suspend fun updateInvoice(@Path("id") id: String, @Body request: InvoiceUpdateRequest): ApiResponse<InvoiceDto>

    @DELETE("invoices/{id}")
    suspend fun deleteInvoice(@Path("id") id: String)

    @POST("invoices/{id}/send")
    suspend fun sendInvoice(@Path("id") id: String, @Body request: SendInvoiceRequest = SendInvoiceRequest()): ApiResponse<InvoiceDto>

    @POST("invoices/{id}/mark_paid")
    suspend fun markInvoicePaid(@Path("id") id: String, @Body request: MarkPaidRequest = MarkPaidRequest()): ApiResponse<InvoiceDto>

    @POST("invoices/{id}/record_payment")
    suspend fun recordPayment(@Path("id") id: String, @Body request: RecordPaymentRequest): ApiResponse<InvoiceDto>

    @POST("invoices/{id}/send_reminder")
    suspend fun sendReminder(@Path("id") id: String): ApiResponse<ReminderResponse>

    // Streamed so the (potentially large) PDF binary is not buffered fully in
    // memory. Returns the raw application/pdf bytes; the caller writes them to
    // a cache file and shares via FileProvider.
    @Streaming
    @GET("invoices/{id}/pdf")
    suspend fun downloadInvoicePdf(@Path("id") id: String): ResponseBody

    // Clients
    @GET("clients")
    suspend fun getClients(
        @Query("page") page: Int = 1,
        @Query("limit") limit: Int = 20,
        @Query("q") query: String? = null,
    ): PaginatedApiResponse<ClientDto>

    @GET("clients/{id}")
    suspend fun getClient(@Path("id") id: String): ApiResponse<ClientDto>

    @POST("clients")
    suspend fun createClient(@Body request: ClientRequest): ApiResponse<ClientDto>

    @PUT("clients/{id}")
    suspend fun updateClient(@Path("id") id: String, @Body request: ClientRequest): ApiResponse<ClientDto>

    @DELETE("clients/{id}")
    suspend fun deleteClient(@Path("id") id: String)

    // Upload & Extraction
    @Multipart
    @POST("upload")
    suspend fun uploadFile(@Part file: MultipartBody.Part): ApiResponse<ExtractionJobDto>

    @GET("upload/{jobId}")
    suspend fun getExtractionJob(@Path("jobId") jobId: String): ApiResponse<ExtractionJobDto>

    // Devices — AMI-41/72: register the FCM push token for this device.
    @POST("devices")
    suspend fun registerDevice(@Body request: DeviceRegistrationRequest): ApiResponse<DeviceDto>

    // Settings
    @GET("settings")
    suspend fun getSettings(): ApiResponse<UserSettingsDto>

    @PUT("settings")
    suspend fun updateSettings(@Body request: UserSettingsRequest): ApiResponse<UserSettingsDto>
}
