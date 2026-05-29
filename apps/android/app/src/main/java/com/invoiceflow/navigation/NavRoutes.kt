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
    data object InvoiceCreate : NavRoutes("invoices/create")

    data object ClientList : NavRoutes("clients")
    data object ClientDetail : NavRoutes("clients/{clientId}") {
        fun createRoute(clientId: String) = "clients/$clientId"
    }

    // AMI-43: settings screen.
    data object Settings : NavRoutes("settings")

    // AMI-42/72: invoice pay QR scanner.
    data object QrScanner : NavRoutes("qr-scanner")
}
