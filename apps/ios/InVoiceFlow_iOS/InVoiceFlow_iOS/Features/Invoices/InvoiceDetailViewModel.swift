import Foundation
import Observation

/// AMI-44 (iOS): single-invoice detail backed by `GET /api/v1/invoices/:id`,
/// with the two state-changing actions the API exposes: send (`/send`) and
/// mark-paid (`/mark_paid`). Each action re-fetches the rendered invoice the
/// server returns so the UI reflects the new status immediately.
@MainActor
@Observable
final class InvoiceDetailViewModel {
    private(set) var invoice: InvoiceDTO?
    private(set) var isLoading = false
    private(set) var isActing = false
    private(set) var error: String?

    let invoiceId: String
    private let api: APIClient

    init(invoiceId: String, api: APIClient = .shared) {
        self.invoiceId = invoiceId
        self.api = api
    }

    func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            invoice = try await api.invoice(id: invoiceId)
        } catch let e as APIError {
            error = e.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
    }

    func send() async {
        await act { try await self.api.sendInvoice(id: self.invoiceId) }
    }

    func markPaid() async {
        await act { try await self.api.markInvoicePaid(id: self.invoiceId) }
    }

    /// Deletes the invoice. Returns `true` so the view can pop the detail
    /// screen; on failure `error` is set and the view stays put.
    func delete() async -> Bool {
        guard !isActing else { return false }
        isActing = true
        error = nil
        defer { isActing = false }
        do {
            try await api.deleteInvoice(id: invoiceId)
            return true
        } catch let e as APIError {
            error = e.errorDescription
            return false
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    private func act(_ operation: @escaping () async throws -> InvoiceDTO) async {
        guard !isActing else { return }
        isActing = true
        error = nil
        defer { isActing = false }
        do {
            invoice = try await operation()
        } catch let e as APIError {
            error = e.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
    }
}
