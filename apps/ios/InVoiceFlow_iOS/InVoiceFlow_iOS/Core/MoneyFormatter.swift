import Foundation

/// Shared currency formatting for the invoice screens. The API renders money
/// as `Decimal`-backed strings (e.g. "1500000.00") with a separate currency
/// code, so we parse the string and format per the invoice's own currency.
enum MoneyFormatter {
    static func format(_ raw: String, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = currency.uppercased() == "KRW" ? 0 : 2
        if let value = Decimal(string: raw) {
            return formatter.string(from: value as NSDecimalNumber) ?? "\(currency) \(raw)"
        }
        return "\(currency) \(raw)"
    }
}

/// Localized Korean labels for invoice statuses, matched 1:1 with the backend
/// `Invoice.status` enum (draft/sent/paid/overdue/cancelled).
enum InvoiceStatus {
    static func label(_ status: String) -> String {
        switch status.lowercased() {
        case "draft": return "초안"
        case "sent": return "발송됨"
        case "paid": return "결제완료"
        case "overdue": return "연체"
        case "cancelled", "canceled": return "취소됨"
        default: return status
        }
    }
}
