import Foundation
import Observation

/// AMI-44 (iOS): invoice list backed by `GET /api/v1/invoices`. Mirrors the
/// MVI pattern used by `DashboardViewModel` — `@Observable` state, an async
/// `refresh`, and `APIError` surfaced as a localized string.
@MainActor
@Observable
final class InvoiceListViewModel {
    private(set) var invoices: [InvoiceDTO] = []
    private(set) var isLoading = false
    private(set) var error: String?

    /// nil = all statuses. Filtering happens server-side via the `status` query.
    var statusFilter: String?

    private let api: APIClient

    init(api: APIClient = .shared) {
        self.api = api
    }

    func refresh() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            invoices = try await api.invoices(status: statusFilter)
        } catch let e as APIError {
            error = e.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
    }

    func setFilter(_ status: String?) async {
        statusFilter = status
        await refresh()
    }
}
