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

    /// Transient success banner (e.g. reminder queued). The view shows it for a
    /// moment then clears it; nil means no banner.
    var toast: String?

    /// When set, the view presents a share sheet for the freshly-downloaded
    /// PDF. Cleared by the view once the sheet is dismissed.
    var pdfShareURL: URL?
    private(set) var isDownloadingPDF = false

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

    /// Records a (possibly partial) payment. `amount` is the raw decimal string
    /// the user typed; the server re-renders the invoice with the new balance.
    func recordPayment(amount: String) async {
        let trimmed = amount.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        await act { try await self.api.recordPayment(id: self.invoiceId, amount: trimmed) }
    }

    /// Queues a manual reminder. Unlike the other actions this returns a status
    /// message (not an invoice), so on success we show a toast and leave the
    /// invoice as-is.
    func sendReminder() async {
        guard !isActing else { return }
        isActing = true
        error = nil
        defer { isActing = false }
        do {
            toast = try await api.sendReminder(id: invoiceId).message
        } catch let e as APIError {
            error = e.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Downloads the invoice PDF and writes it to a temp file, then sets
    /// `pdfShareURL` so the view can present a share sheet.
    func downloadPDF() async {
        guard !isDownloadingPDF, let number = invoice?.invoiceNumber else { return }
        isDownloadingPDF = true
        error = nil
        defer { isDownloadingPDF = false }
        do {
            let data = try await api.invoicePdf(id: invoiceId)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(number).pdf")
            try data.write(to: url, options: .atomic)
            pdfShareURL = url
        } catch let e as APIError {
            error = e.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
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
