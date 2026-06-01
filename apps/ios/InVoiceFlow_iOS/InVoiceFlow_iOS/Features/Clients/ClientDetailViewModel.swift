import Foundation
import Observation

/// AMI-44 (iOS): single-client detail backed by `GET /api/v1/clients/:id`,
/// plus the client's invoices (`GET /invoices?client_id=`) rolled up into a
/// few counts. Follows the same `@Observable` MVI shape as the other view
/// models: a `load()` that sets `isLoading`/`error`, and an `update()` that
/// returns success so the edit form can dismiss.
@MainActor
@Observable
final class ClientDetailViewModel {
    private(set) var client: ClientDTO?
    private(set) var invoices: [InvoiceDTO] = []
    private(set) var analytics: ClientAnalyticsDTO?
    private(set) var isLoading = false
    private(set) var isSaving = false
    private(set) var error: String?

    let clientId: String
    private let api: APIClient

    init(client: ClientDTO, api: APIClient = .shared) {
        self.clientId = client.id
        self.client = client
        self.api = api
    }

    init(clientId: String, api: APIClient = .shared) {
        self.clientId = clientId
        self.api = api
    }

    /// Total invoice count for this client.
    var invoiceCount: Int { invoices.count }

    /// Count of invoices that are still outstanding (anything not paid or
    /// cancelled) — the figure a user cares about on a client screen.
    var outstandingCount: Int {
        invoices.filter {
            let s = $0.status.lowercased()
            return s != "paid" && s != "cancelled" && s != "canceled"
        }.count
    }

    var paidCount: Int {
        invoices.filter { $0.status.lowercased() == "paid" }.count
    }

    func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            // Fetch the canonical client and its invoices together.
            async let clientResult = api.client(id: clientId)
            async let invoiceResult = api.invoices(clientId: clientId)
            client = try await clientResult
            invoices = try await invoiceResult
        } catch let e as APIError {
            error = e.errorDescription
        } catch {
            self.error = error.localizedDescription
        }

        // Analytics is supplementary — a failure here must not blank the
        // screen, so it is fetched separately and its error is swallowed.
        analytics = try? await api.clientAnalytics(id: clientId)
    }

    /// Saves edits via `PUT /clients/:id`. Returns success so the edit sheet
    /// can dismiss; the refreshed client replaces the local copy.
    func update(name: String, email: String?, phone: String?, company: String?) async -> Bool {
        guard !isSaving else { return false }
        isSaving = true
        error = nil
        defer { isSaving = false }
        do {
            let updated = try await api.updateClient(
                id: clientId,
                ClientRequest(name: name, email: email, phone: phone, company: company)
            )
            client = updated
            return true
        } catch let e as APIError {
            error = e.errorDescription
            return false
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}
