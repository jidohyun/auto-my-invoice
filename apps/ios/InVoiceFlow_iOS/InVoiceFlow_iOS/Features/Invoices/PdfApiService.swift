import Foundation

/// Possible outcomes when fetching an invoice PDF.
/// Wraps raw `Data` on success so callers never need to inspect `APIError`
/// for the happy path.
enum PdfFetchResult {
    /// PDF binary returned by the server.
    case success(Data)
    /// Invoice not found or not owned by the current user (server → 404).
    case notFound
}

/// Abstracts `GET /invoices/:id/pdf` so ViewModels and unit tests stay
/// decoupled from `APIClient`.
protocol PdfApiServiceProtocol {
    func fetchInvoicePdf(invoiceId: String) async throws -> PdfFetchResult
}

/// Live implementation that delegates to `APIClient`.
/// Errors thrown are `APIError` values (`.unauthorized`, `.transport`,
/// `.http` for non-404 server errors).
@MainActor
final class PdfApiService: PdfApiServiceProtocol {

    private let api: APIClient

    init(api: APIClient = .shared) {
        self.api = api
    }

    /// Downloads the PDF binary for the given invoice.
    ///
    /// - Parameter invoiceId: UUID string of the invoice.
    /// - Returns: `.success(Data)` with raw PDF bytes, or `.notFound` when
    ///   the server returns 404 (invoice absent or not owned by caller).
    /// - Throws:
    ///   - `APIError.unauthorized` — no stored token or server 401.
    ///   - `APIError.transport(_)` — network-level failure.
    ///   - `APIError.http(status:body:)` — non-404 server error.
    func fetchInvoicePdf(invoiceId: String) async throws -> PdfFetchResult {
        do {
            let data = try await api.invoicePdf(id: invoiceId)
            return .success(data)
        } catch let apiError as APIError {
            switch apiError {
            case .http(let status, _) where status == 404:
                return .notFound
            default:
                throw apiError
            }
        }
    }
}
