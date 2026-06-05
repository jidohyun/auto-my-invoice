import Foundation
import Observation

/// AMI-44 (iOS): drives the new-invoice form. Loads the client list for the
/// picker, holds an editable set of line items, and submits to
/// `POST /api/v1/invoices`. Validation mirrors the backend changeset: a
/// client and at least one complete line item are required.
@MainActor
@Observable
final class InvoiceCreateViewModel {
    struct DraftItem: Identifiable, Hashable {
        let id = UUID()
        var description = ""
        var quantity = "1"
        var unitPrice = ""

        var isComplete: Bool {
            !description.trimmingCharacters(in: .whitespaces).isEmpty
                && Decimal(string: quantity) != nil
                && Decimal(string: unitPrice) != nil
        }
    }

    private(set) var clients: [ClientDTO] = []
    private(set) var isLoadingClients = false
    private(set) var isSubmitting = false
    private(set) var error: String?

    var selectedClientId: String?
    var currency = "KRW"
    var dueDate: Date?
    var notes = ""
    var items: [DraftItem] = [DraftItem()]

    let currencies = ["KRW", "USD", "EUR", "JPY", "GBP"]

    private let api: APIClient
    /// Set when seeded from an OCR extraction (AMI-46). Surfaced in the form so
    /// the user can confirm/correct the auto-filled values before submitting.
    private(set) var prefillNotice: String?

    init(api: APIClient = .shared) {
        self.api = api
    }

    /// Seeds the draft from an OCR extraction result (AMI-46). Currency, due
    /// date, notes, and any line items are filled; the client picker is left
    /// for the user since the extractor only returns hints, not an id.
    convenience init(prefill: ExtractedDataDTO, api: APIClient = .shared) {
        self.init(api: api)
        if let currency = prefill.currency, currencies.contains(currency.uppercased()) {
            self.currency = currency.uppercased()
        }
        if let due = prefill.dueDate, !due.isEmpty {
            self.dueDate = Self.parseDate(due)
        }
        self.notes = prefill.notes ?? ""

        let seeded = (prefill.items ?? []).compactMap { item -> DraftItem? in
            guard let desc = item.description, !desc.isEmpty else { return nil }
            var draft = DraftItem()
            draft.description = desc
            draft.quantity = item.quantity ?? "1"
            draft.unitPrice = item.unitPrice ?? ""
            return draft
        }
        if !seeded.isEmpty {
            self.items = seeded
        } else if let amount = prefill.amount, !amount.isEmpty {
            // No line items but a total — seed a single line so the amount
            // carries over and the user can refine it.
            var draft = DraftItem()
            draft.description = "추출된 항목"
            draft.quantity = "1"
            draft.unitPrice = amount
            self.items = [draft]
        }
        self.prefillNotice = "OCR로 자동 입력되었습니다. 고객을 선택하고 내용을 확인하세요."
    }

    var canSubmit: Bool {
        selectedClientId != nil
            && items.contains(where: { $0.isComplete })
            && !isSubmitting
    }

    func loadClients() async {
        isLoadingClients = true
        defer { isLoadingClients = false }
        do {
            clients = try await api.clients()
            if selectedClientId == nil { selectedClientId = clients.first?.id }
        } catch let e as APIError {
            error = e.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
    }

    func addItem() {
        items.append(DraftItem())
    }

    func removeItem(_ item: DraftItem) {
        items.removeAll { $0.id == item.id }
        if items.isEmpty { items = [DraftItem()] }
    }

    /// Returns the created invoice on success, nil on failure (error is set).
    func submit() async -> InvoiceDTO? {
        guard let clientId = selectedClientId, canSubmit else { return nil }
        isSubmitting = true
        error = nil
        defer { isSubmitting = false }

        let payloadItems = items
            .filter { $0.isComplete }
            .map {
                InvoiceItemRequest(
                    description: $0.description,
                    quantity: $0.quantity,
                    unitPrice: $0.unitPrice
                )
            }

        let body = InvoiceCreateRequest(
            clientId: clientId,
            currency: currency,
            dueDate: dueDate.map { Self.dateString($0) },
            notes: notes.isEmpty ? nil : notes,
            items: payloadItems
        )

        do {
            return try await api.createInvoice(body)
        } catch let e as APIError {
            error = e.errorDescription
            return nil
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    private static func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        return formatter.string(from: date)
    }

    private static func parseDate(_ raw: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        // Tolerate an ISO8601 timestamp by trimming to the date portion.
        let dateOnly = String(raw.prefix(10))
        return formatter.date(from: dateOnly)
    }
}
