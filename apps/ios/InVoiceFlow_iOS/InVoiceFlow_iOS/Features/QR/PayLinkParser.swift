import Foundation

/// AMI-42 (iOS): parses a scanned QR string into an invoice identifier.
///
/// The web app renders a scan-to-pay QR pointing at the public landing route
/// `/pay/:id` (see `AutoMyInvoiceWeb.Router` PayLive, AMI-89). We accept:
///   - a full URL whose path contains `/pay/<id>`
///   - a bare UUID (some printed codes encode just the id)
enum PayLinkParser {
    static func invoiceId(from scanned: String) -> String? {
        let trimmed = scanned.trimmingCharacters(in: .whitespacesAndNewlines)

        if let url = URL(string: trimmed) {
            let parts = url.pathComponents
            if let payIndex = parts.firstIndex(of: "pay"),
               payIndex + 1 < parts.count {
                let candidate = parts[payIndex + 1]
                if isUUID(candidate) { return candidate }
            }
        }

        // Fall back to a bare UUID payload.
        if isUUID(trimmed) { return trimmed }

        return nil
    }

    private static func isUUID(_ value: String) -> Bool {
        UUID(uuidString: value) != nil
    }
}
