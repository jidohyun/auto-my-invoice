//
//  ContentView.swift
//  InVoiceFlow_iOS
//
//  Created by 하동건 on 3/11/26.
//

import SwiftUI

/// AMI-88 (iOS): root router. Reads `AuthViewModel.state` from the
/// environment and swaps between the login flow and the main tab UI. No
/// NavigationStack here; each leaf owns its own navigation.
struct ContentView: View {
    @Environment(AuthViewModel.self) private var auth

    var body: some View {
        switch auth.state {
        case .checking:
            ProgressView().controlSize(.large)
        case .loggedOut:
            LoginView()
        case .loggedIn:
            MainTabView()
        }
    }
}

/// AMI-44 (iOS): primary navigation surface. Tabs for Dashboard, Invoices,
/// Clients, and Settings, plus a QR scan entry point (AMI-42) that deep-links
/// a scanned pay code into the invoice detail under the Invoices tab.
struct MainTabView: View {
    @State private var selection: Tab = .dashboard
    @State private var showScanner = false
    /// Set by the QR scanner; consumed by the Invoices tab to push detail.
    @State private var scannedInvoiceId: String?

    enum Tab: Hashable { case dashboard, invoices, clients, settings }

    var body: some View {
        TabView(selection: $selection) {
            DashboardView()
                .tabItem { Label("대시보드", systemImage: "chart.bar") }
                .tag(Tab.dashboard)

            InvoiceListView(deepLinkInvoiceId: $scannedInvoiceId)
                .tabItem { Label("송장", systemImage: "doc.text") }
                .tag(Tab.invoices)

            ClientListView()
                .tabItem { Label("고객", systemImage: "person.2") }
                .tag(Tab.clients)

            SettingsView()
                .tabItem { Label("설정", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
        .overlay(alignment: .bottomTrailing) { scanButton }
        .sheet(isPresented: $showScanner) {
            QrScannerView { invoiceId in
                scannedInvoiceId = invoiceId
                selection = .invoices
            }
        }
    }

    private var scanButton: some View {
        Button {
            showScanner = true
        } label: {
            Image(systemName: "qrcode.viewfinder")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.accentColor, in: .circle)
                .shadow(radius: 4, y: 2)
        }
        .accessibilityLabel("QR 결제 스캔")
        .padding(.trailing, 20)
        .padding(.bottom, 60)
    }
}

#Preview {
    ContentView()
        .environment(AuthViewModel())
}
