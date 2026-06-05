package com.invoiceflow.navigation

sealed class NavRoutes(val route: String) {
    // Auth
    data object Login : NavRoutes("login")
    data object Register : NavRoutes("register")

    // Main
    data object Dashboard : NavRoutes("dashboard")
    data object InvoiceList : NavRoutes("invoices")
    data object InvoiceDetail : NavRoutes("invoices/{invoiceId}") {
        fun createRoute(invoiceId: String) = "invoices/$invoiceId"
    }
    /**
     * Create-invoice route with optional OCR prefill query params. The plain
     * [route] (no params) is used for a blank form; [createRoute] builds a URL
     * with extracted amount/currency/dueDate/notes that the screen reads back.
     */
    data object InvoiceCreate : NavRoutes("invoices/create?amount={amount}&currency={currency}&dueDate={dueDate}&notes={notes}") {
        fun createRoute(
            amount: String? = null,
            currency: String? = null,
            dueDate: String? = null,
            notes: String? = null,
        ): String {
            val params = buildList {
                amount?.let { add("amount=${java.net.URLEncoder.encode(it, "UTF-8")}") }
                currency?.let { add("currency=${java.net.URLEncoder.encode(it, "UTF-8")}") }
                dueDate?.let { add("dueDate=${java.net.URLEncoder.encode(it, "UTF-8")}") }
                notes?.let { add("notes=${java.net.URLEncoder.encode(it, "UTF-8")}") }
            }
            return if (params.isEmpty()) "invoices/create" else "invoices/create?${params.joinToString("&")}"
        }
    }

    // OCR upload — pick an invoice image, extract, then prefill InvoiceCreate.
    data object Upload : NavRoutes("upload")

    data object ClientList : NavRoutes("clients")
    data object ClientCreate : NavRoutes("clients/create")
    data object ClientDetail : NavRoutes("clients/{clientId}") {
        fun createRoute(clientId: String) = "clients/$clientId"
    }
    data object ClientEdit : NavRoutes("clients/{clientId}/edit") {
        fun createRoute(clientId: String) = "clients/$clientId/edit"
    }

    // AMI-43: settings screen.
    data object Settings : NavRoutes("settings")

    // AMI-42/72: invoice pay QR scanner.
    data object QrScanner : NavRoutes("qr-scanner")

    // AMI parity: read-only analytics dashboard.
    data object Analytics : NavRoutes("analytics")
}
