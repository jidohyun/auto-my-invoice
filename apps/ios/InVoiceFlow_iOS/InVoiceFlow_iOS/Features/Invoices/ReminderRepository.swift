import Foundation

/// Possible outcomes when sending a manual reminder.
enum SendReminderResult: Equatable {
    /// Reminder was queued successfully. `message` is the server's localised string.
    case success(message: String)
    /// The invoice status does not allow reminders (server → 422).
    case invalidStatus
    /// Daily rate-limit exceeded (server → 429).
    case rateLimited
}

/// Abstracts the `POST /invoices/:id/send_reminder` call so the ViewModel and
/// unit tests stay decoupled from `APIClient`.
protocol ReminderRepositoryProtocol {
    func sendReminder(invoiceId: String) async throws -> SendReminderResult
}

/// Live implementation that delegates to `APIClient`.
/// Errors thrown are `APIError` values; callers can pattern-match on them.
final class ReminderRepository: ReminderRepositoryProtocol {
    private let api: APIClient

    init(api: APIClient = .shared) {
        self.api = api
    }

    /// Calls `POST /invoices/:id/send_reminder` and maps the three server
    /// outcomes (200, 422, 429) to `SendReminderResult` cases.
    /// Any other HTTP error or transport failure is re-thrown as `APIError`.
    func sendReminder(invoiceId: String) async throws -> SendReminderResult {
        do {
            let response = try await api.sendReminder(id: invoiceId)
            return .success(message: response.message)
        } catch let apiError as APIError {
            switch apiError {
            case .http(let status, _) where status == 422:
                return .invalidStatus
            case .http(let status, _) where status == 429:
                return .rateLimited
            default:
                throw apiError
            }
        }
    }
}
