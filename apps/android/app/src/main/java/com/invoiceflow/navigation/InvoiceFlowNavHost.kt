package com.invoiceflow.navigation

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.invoiceflow.features.auth.ui.LoginScreen
import com.invoiceflow.features.auth.ui.RegisterScreen
import com.invoiceflow.features.auth.viewmodel.AuthViewModel
import com.invoiceflow.features.clients.ui.ClientDetailScreen
import com.invoiceflow.features.clients.ui.ClientFormScreen
import com.invoiceflow.features.clients.ui.ClientListScreen
import com.invoiceflow.features.dashboard.ui.DashboardScreen
import com.invoiceflow.features.invoices.ui.InvoiceCreateScreen
import com.invoiceflow.features.invoices.ui.InvoiceDetailScreen
import com.invoiceflow.features.invoices.ui.InvoiceListScreen
import com.invoiceflow.features.qr.ui.QrScannerScreen
import com.invoiceflow.features.settings.ui.SettingsScreen
import com.invoiceflow.features.upload.ui.UploadScreen

@Composable
fun InvoiceFlowNavHost(
    navController: NavHostController = rememberNavController(),
) {
    val authViewModel: AuthViewModel = hiltViewModel()
    val isLoggedIn by authViewModel.isLoggedIn.collectAsStateWithLifecycle()

    val startDestination = if (isLoggedIn) NavRoutes.Dashboard.route else NavRoutes.Login.route

    NavHost(
        navController = navController,
        startDestination = startDestination,
    ) {
        // Auth
        composable(NavRoutes.Login.route) {
            LoginScreen(
                onLoginSuccess = {
                    navController.navigate(NavRoutes.Dashboard.route) {
                        popUpTo(NavRoutes.Login.route) { inclusive = true }
                    }
                },
                onNavigateToRegister = {
                    navController.navigate(NavRoutes.Register.route)
                }
            )
        }

        composable(NavRoutes.Register.route) {
            RegisterScreen(
                onRegisterSuccess = {
                    navController.navigate(NavRoutes.Dashboard.route) {
                        popUpTo(NavRoutes.Login.route) { inclusive = true }
                    }
                },
                onNavigateToLogin = {
                    navController.popBackStack()
                }
            )
        }

        // Dashboard
        composable(NavRoutes.Dashboard.route) {
            DashboardScreen(
                onNavigateToInvoice = { id ->
                    navController.navigate(NavRoutes.InvoiceDetail.createRoute(id))
                },
                onNavigateToCreate = { navController.navigate(NavRoutes.InvoiceCreate.route) },
                onNavigateToInvoices = { navController.navigate(NavRoutes.InvoiceList.route) },
                onNavigateToSettings = { navController.navigate(NavRoutes.Settings.route) },
            )
        }

        // Invoices
        composable(NavRoutes.InvoiceList.route) {
            InvoiceListScreen(
                onNavigateToDetail = { invoiceId ->
                    navController.navigate(NavRoutes.InvoiceDetail.createRoute(invoiceId))
                },
                onNavigateToCreate = {
                    navController.navigate(NavRoutes.InvoiceCreate.createRoute())
                },
                onNavigateToScanner = {
                    navController.navigate(NavRoutes.QrScanner.route)
                },
                onNavigateToUpload = {
                    navController.navigate(NavRoutes.Upload.route)
                },
            )
        }

        // OCR upload — on extraction, prefill the create-invoice form.
        composable(NavRoutes.Upload.route) {
            UploadScreen(
                onBack = { navController.popBackStack() },
                onExtracted = { data ->
                    val route = NavRoutes.InvoiceCreate.createRoute(
                        amount = data.total?.toString(),
                        currency = data.currency,
                        dueDate = data.dueAt,
                        notes = data.vendorName?.let { "OCR: $it" },
                    )
                    navController.popBackStack()
                    navController.navigate(route)
                },
            )
        }

        composable(
            route = NavRoutes.InvoiceCreate.route,
            arguments = listOf(
                navArgument("amount") { type = NavType.StringType; nullable = true; defaultValue = null },
                navArgument("currency") { type = NavType.StringType; nullable = true; defaultValue = null },
                navArgument("dueDate") { type = NavType.StringType; nullable = true; defaultValue = null },
                navArgument("notes") { type = NavType.StringType; nullable = true; defaultValue = null },
            ),
        ) { backStackEntry ->
            InvoiceCreateScreen(
                onBack = { navController.popBackStack() },
                onCreated = { id ->
                    navController.popBackStack()
                    navController.navigate(NavRoutes.InvoiceDetail.createRoute(id))
                },
                prefillAmount = backStackEntry.arguments?.getString("amount"),
                prefillCurrency = backStackEntry.arguments?.getString("currency"),
                prefillDueDate = backStackEntry.arguments?.getString("dueDate"),
                prefillNotes = backStackEntry.arguments?.getString("notes"),
            )
        }

        composable(
            route = NavRoutes.InvoiceDetail.route,
            arguments = listOf(navArgument("invoiceId") { type = NavType.StringType })
        ) { backStackEntry ->
            val invoiceId = backStackEntry.arguments?.getString("invoiceId") ?: return@composable
            InvoiceDetailScreen(
                invoiceId = invoiceId,
                onNavigateBack = { navController.popBackStack() }
            )
        }

        // Clients
        composable(NavRoutes.ClientList.route) {
            ClientListScreen(
                onNavigateToDetail = { clientId ->
                    navController.navigate(NavRoutes.ClientDetail.createRoute(clientId))
                },
                onNavigateToCreate = {
                    navController.navigate(NavRoutes.ClientCreate.route)
                },
            )
        }

        // Register the static create route BEFORE the dynamic detail route so
        // "clients/create" is never captured by "clients/{clientId}".
        composable(NavRoutes.ClientCreate.route) {
            ClientFormScreen(
                clientId = null,
                onBack = { navController.popBackStack() },
                onSaved = { id ->
                    navController.popBackStack()
                    navController.navigate(NavRoutes.ClientDetail.createRoute(id))
                },
            )
        }

        composable(
            route = NavRoutes.ClientEdit.route,
            arguments = listOf(navArgument("clientId") { type = NavType.StringType }),
        ) { backStackEntry ->
            val clientId = backStackEntry.arguments?.getString("clientId") ?: return@composable
            ClientFormScreen(
                clientId = clientId,
                onBack = { navController.popBackStack() },
                onSaved = { navController.popBackStack() },
            )
        }

        composable(
            route = NavRoutes.ClientDetail.route,
            arguments = listOf(navArgument("clientId") { type = NavType.StringType }),
        ) { backStackEntry ->
            val clientId = backStackEntry.arguments?.getString("clientId") ?: return@composable
            ClientDetailScreen(
                clientId = clientId,
                onNavigateBack = { navController.popBackStack() },
                onEdit = { id -> navController.navigate(NavRoutes.ClientEdit.createRoute(id)) },
            )
        }

        // Settings — AMI-43
        composable(NavRoutes.Settings.route) {
            SettingsScreen()
        }

        // QR Scanner — AMI-42/72
        composable(NavRoutes.QrScanner.route) {
            QrScannerScreen(
                onNavigateBack = { navController.popBackStack() },
                onInvoiceScanned = { invoiceId ->
                    navController.popBackStack()
                    navController.navigate(NavRoutes.InvoiceDetail.createRoute(invoiceId))
                },
            )
        }
    }
}
