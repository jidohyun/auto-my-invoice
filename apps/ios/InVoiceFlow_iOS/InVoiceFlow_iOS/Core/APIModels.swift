import Foundation

/// Wraps every `:data` response from the Phoenix API (see
/// `AutoMyInvoiceWeb.Api.*` controllers).
struct APIResponse<Data: Decodable>: Decodable {
    let data: Data
}

/// Backend `JsonHelpers.render_invoice/1`. Money fields are strings
/// because Phoenix renders `Decimal` as strings to preserve precision.
struct InvoiceDTO: Decodable, Identifiable, Hashable {
    let id: String
    let invoiceNumber: String
    let status: String
    let amount: String
    let paidAmount: String
    let currency: String
    let dueDate: String?
    let sentAt: String?
    let paidAt: String?
    let notes: String?
    let clientId: String?
    // Present on show/create/update (full render); absent on the dashboard
    // recent list. `decodeIfPresent` keeps both responses decodable.
    let client: ClientDTO?
    let items: [InvoiceItemDTO]?

    enum CodingKeys: String, CodingKey {
        case id
        case invoiceNumber = "invoice_number"
        case status
        case amount
        case paidAmount = "paid_amount"
        case currency
        case dueDate = "due_date"
        case sentAt = "sent_at"
        case paidAt = "paid_at"
        case notes
        case clientId = "client_id"
        case client
        case items
    }
}

/// Backend `AutoMyInvoiceWeb.Api.DashboardController.index/2`. Outstanding
/// is already rolled up to KRW server-side (AMI-90).
struct KpiSummaryDTO: Decodable {
    let outstandingAmount: String
    let overdueCount: Int
    let collectionRate: Int
    let collectedThisMonth: String

    enum CodingKeys: String, CodingKey {
        case outstandingAmount = "outstanding_amount"
        case overdueCount = "overdue_count"
        case collectionRate = "collection_rate"
        case collectedThisMonth = "collected_this_month"
    }
}

/// Line item nested inside `JsonHelpers.render_invoice/1` under `items`.
/// `quantity`/`unit_price` are `Decimal` server-side and render as strings.
struct InvoiceItemDTO: Decodable, Identifiable, Hashable {
    let id: String?
    let description: String
    let quantity: String
    let unitPrice: String
    let position: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case description
        case quantity
        case unitPrice = "unit_price"
        case position
    }
}

/// Backend `JsonHelpers.render_client/1`. `address`, `inserted_at`, and
/// `updated_at` are also emitted (see the JSON helper); `decodeIfPresent`
/// keeps the dashboard/recent payloads — which omit them — decodable.
struct ClientDTO: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let email: String?
    let company: String?
    let phone: String?
    let address: String?
    let insertedAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case company
        case phone
        case address
        case insertedAt = "inserted_at"
        case updatedAt = "updated_at"
    }
}

/// Backend `JsonHelpers.render_user/1`, surfaced through `GET /settings`.
/// This is the source of truth for the Settings screen (the OpenAPI
/// `UserSettings` schema is aspirational and not what the server returns).
struct UserSettingsDTO: Decodable, Hashable {
    let id: String
    let email: String
    let companyName: String?
    let plan: String?
    let timezone: String?
    let brandTone: String?
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case companyName = "company_name"
        case plan
        case timezone
        case brandTone = "brand_tone"
        case avatarUrl = "avatar_url"
    }
}

/// `PUT /settings` body. Wrapped under `settings` by `APIClient`, mirroring
/// `SettingsController.update/2` which pattern-matches `%{"settings" => ...}`.
/// Only fields present (non-nil) are encoded so partial updates are clean.
struct UserSettingsUpdate: Encodable {
    var companyName: String?
    var defaultCurrency: String?
    var paymentTerms: Int?
    var brandTone: String?
    var businessAddress: String?
    var businessRegistrationNumber: String?
    var invoicePrefix: String?

    enum CodingKeys: String, CodingKey {
        case companyName = "company_name"
        case defaultCurrency = "default_currency"
        case paymentTerms = "payment_terms"
        case brandTone = "brand_tone"
        case businessAddress = "business_address"
        case businessRegistrationNumber = "business_registration_number"
        case invoicePrefix = "invoice_prefix"
    }
}

/// `POST /clients` / `PUT /clients/:id` body, wrapped under `client`.
struct ClientRequest: Encodable {
    let name: String
    let email: String?
    let phone: String?
    let company: String?
}

/// One line of a `POST /invoices` request. Numbers are sent as strings so
/// the backend's `Decimal` cast accepts them without float rounding.
struct InvoiceItemRequest: Encodable {
    let description: String
    let quantity: String
    let unitPrice: String

    enum CodingKeys: String, CodingKey {
        case description
        case quantity
        case unitPrice = "unit_price"
    }
}

/// `POST /invoices` body, wrapped under `invoice`.
struct InvoiceCreateRequest: Encodable {
    let clientId: String
    let currency: String
    let dueDate: String?
    let notes: String?
    let items: [InvoiceItemRequest]

    enum CodingKeys: String, CodingKey {
        case clientId = "client_id"
        case currency
        case dueDate = "due_date"
        case notes
        case items
    }
}

/// `POST /devices` body for APNs registration (AMI-41). Server endpoint is
/// pending (task #11) but the contract is fixed: `{token, platform}`.
struct DeviceRegistration: Encodable {
    let token: String
    let platform: String
}

/// Backend `JsonHelpers.render_extraction_job/1` — the OCR upload job returned
/// by `POST /upload` and polled via `GET /extraction/:id`. `status` walks
/// pending → processing → completed | failed. `extractedData` is only present
/// once `completed`; on `failed` `errorMessage` explains why.
struct ExtractionJobDTO: Decodable, Identifiable, Hashable {
    let id: String
    let status: String
    let originalFilename: String?
    let confidenceScore: Double?
    let extractedData: ExtractedDataDTO?
    let errorMessage: String?
    let insertedAt: String?

    var isTerminal: Bool {
        let s = status.lowercased()
        return s == "completed" || s == "failed"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case status
        case originalFilename = "original_filename"
        case confidenceScore = "confidence_score"
        case extractedData = "extracted_data"
        case errorMessage = "error_message"
        case insertedAt = "inserted_at"
    }
}

/// Free-form OCR result map (`extraction_job.extracted_data`). Keys mirror
/// `AutoMyInvoice.Extraction.to_invoice_attrs/1`, so these are the fields used
/// to prefill the invoice-create form: amount, currency, due_date, notes,
/// items, plus the client hints (client_email/name/company).
struct ExtractedDataDTO: Decodable, Hashable {
    let amount: String?
    let currency: String?
    let dueDate: String?
    let notes: String?
    let items: [ExtractedItemDTO]?
    let clientEmail: String?
    let clientName: String?
    let clientCompany: String?

    enum CodingKeys: String, CodingKey {
        case amount
        case currency
        case dueDate = "due_date"
        case notes
        case items
        case clientEmail = "client_email"
        case clientName = "client_name"
        case clientCompany = "client_company"
    }

    /// `amount`/numeric fields can come back as either a JSON string or number
    /// depending on the extractor; decode both so prefill never throws.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        amount = ExtractedDataDTO.flexibleString(c, .amount)
        currency = try c.decodeIfPresent(String.self, forKey: .currency)
        dueDate = try c.decodeIfPresent(String.self, forKey: .dueDate)
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        items = try c.decodeIfPresent([ExtractedItemDTO].self, forKey: .items)
        clientEmail = try c.decodeIfPresent(String.self, forKey: .clientEmail)
        clientName = try c.decodeIfPresent(String.self, forKey: .clientName)
        clientCompany = try c.decodeIfPresent(String.self, forKey: .clientCompany)
    }

    static func flexibleString(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> String? {
        if let s = try? c.decodeIfPresent(String.self, forKey: key) { return s }
        if let d = try? c.decodeIfPresent(Double.self, forKey: key) {
            return NSDecimalNumber(value: d).stringValue
        }
        if let i = try? c.decodeIfPresent(Int.self, forKey: key) { return String(i) }
        return nil
    }
}

/// One extracted line item. Numbers tolerate string-or-number encodings, like
/// `ExtractedDataDTO`.
struct ExtractedItemDTO: Decodable, Hashable {
    let description: String?
    let quantity: String?
    let unitPrice: String?

    enum CodingKeys: String, CodingKey {
        case description
        case quantity
        case unitPrice = "unit_price"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        quantity = ExtractedItemDTO.flexibleString(c, .quantity)
        unitPrice = ExtractedItemDTO.flexibleString(c, .unitPrice)
    }

    static func flexibleString(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> String? {
        if let s = try? c.decodeIfPresent(String.self, forKey: key) { return s }
        if let d = try? c.decodeIfPresent(Double.self, forKey: key) {
            return NSDecimalNumber(value: d).stringValue
        }
        if let i = try? c.decodeIfPresent(Int.self, forKey: key) { return String(i) }
        return nil
    }
}

struct AuthData: Decodable {
    let token: String
    let user: AuthUser
}

struct AuthUser: Decodable, Hashable {
    let id: String
    let email: String
}

struct LoginRequest: Encodable {
    let email: String
    let password: String
}

/// `POST /auth/register` request body. The backend pattern-matches top-level
/// `email`/`password` and accepts an optional `company_name`. A nil
/// `companyName` is omitted from the payload.
struct RegisterRequest: Encodable {
    let email: String
    let password: String
    let companyName: String?

    enum CodingKeys: String, CodingKey {
        case email, password
        case companyName = "company_name"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(email, forKey: .email)
        try c.encode(password, forKey: .password)
        try c.encodeIfPresent(companyName, forKey: .companyName)
    }
}

/// `POST /invoices/:id/record_payment` request body.
///
/// `amount` is the only field the backend currently pattern-matches on, but
/// `payment_date` and `notes` are included for forward-compatibility with the
/// full API contract.  Numbers are sent as strings so the server-side
/// `Decimal` cast accepts them without float rounding (same convention as
/// `InvoiceItemRequest`).
///
/// Encoding omits `nil` fields automatically via `encodeIfPresent`, keeping
/// the request body minimal when optional fields are not supplied.
struct RecordPaymentRequest: Encodable {
    /// Payment amount as a decimal string, e.g. `"50000"` or `"1234.56"`.
    let amount: String

    /// ISO-8601 date string, e.g. `"2024-06-01"`.  `nil` → server defaults to now.
    let paymentDate: String?

    /// Free-form notes attached to this payment record.
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case amount
        case paymentDate = "payment_date"
        case notes
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(amount, forKey: .amount)
        try container.encodeIfPresent(paymentDate, forKey: .paymentDate)
        try container.encodeIfPresent(notes, forKey: .notes)
    }
}

/// Response body for `POST /invoices/:id/send_reminder`.
/// The server returns `{"data": {"message": "..."}}` on success.
struct ReminderResponseDTO: Decodable, Equatable {
    let message: String
}

// MARK: - Analytics (AMI parity)

/// `GET /dashboard/analytics` → `{data: {...}}`. Mirrors
/// `AutoMyInvoiceWeb.Api.AnalyticsController.dashboard/2`.
struct DashboardAnalyticsDTO: Decodable {
    let monthlyCollections: [MonthlyCollectionDTO]
    let statusDistribution: [StatusDistributionDTO]
    let invoiceAging: [String: AgingBucketDTO]

    enum CodingKeys: String, CodingKey {
        case monthlyCollections = "monthly_collections"
        case statusDistribution = "status_distribution"
        case invoiceAging = "invoice_aging"
    }
}

/// One month in `Analytics.monthly_collections/2`. Money fields are decimal
/// strings (Phoenix renders Decimal as strings).
struct MonthlyCollectionDTO: Decodable, Identifiable {
    var id: String { month }
    let month: String
    let invoiced: String
    let collected: String
    let count: Int
}

/// One status bucket in `Analytics.status_distribution/1`.
struct StatusDistributionDTO: Decodable, Identifiable {
    var id: String { status }
    let status: String
    let count: Int
    let total: String
}

/// One aging bucket (`0-30`, `31-60`, `61-90`, `90+`) from
/// `Analytics.invoice_aging/1`.
struct AgingBucketDTO: Decodable {
    let count: Int
    let total: String
}

/// One per-step avg-days-to-payment row from `Reminders.reminder_effectiveness/1`.
struct AvgDaysToPaymentEntryDTO: Decodable {
    let step: Int
    let avgDays: Double
    let sampleSize: Int

    enum CodingKeys: String, CodingKey {
        case step
        case avgDays = "avg_days"
        case sampleSize = "sample_size"
    }
}

/// `GET /analytics/reminders` → `{data: {...}}`. Subset of
/// `Reminders.reminder_effectiveness/1` the mobile screen surfaces.
struct ReminderEffectivenessDTO: Decodable {
    let totalSent: Int
    let totalOpened: Int
    let totalClicked: Int
    let overallOpenRate: Double
    let overallClickRate: Double
    let overallConversionRate: Double?
    /// Backend sends this as an ARRAY of per-step rows (`@spec :: [map()]`), not
    /// a scalar — a `Double?` here threw `typeMismatch` on the present array.
    /// Decoded defensively so a missing/null key still yields `[]`.
    let avgDaysToPayment: [AvgDaysToPaymentEntryDTO]

    enum CodingKeys: String, CodingKey {
        case totalSent = "total_sent"
        case totalOpened = "total_opened"
        case totalClicked = "total_clicked"
        case overallOpenRate = "overall_open_rate"
        case overallClickRate = "overall_click_rate"
        case overallConversionRate = "overall_conversion_rate"
        case avgDaysToPayment = "avg_days_to_payment"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        totalSent = try c.decode(Int.self, forKey: .totalSent)
        totalOpened = try c.decode(Int.self, forKey: .totalOpened)
        totalClicked = try c.decode(Int.self, forKey: .totalClicked)
        overallOpenRate = try c.decode(Double.self, forKey: .overallOpenRate)
        overallClickRate = try c.decode(Double.self, forKey: .overallClickRate)
        overallConversionRate = try c.decodeIfPresent(Double.self, forKey: .overallConversionRate)
        avgDaysToPayment = try c.decodeIfPresent([AvgDaysToPaymentEntryDTO].self, forKey: .avgDaysToPayment) ?? []
    }
}

/// `GET /clients/:id/analytics` → `{data: {...}}`. Mirrors
/// `Clients.client_analytics/1` — the per-client payment-behaviour summary.
struct ClientAnalyticsDTO: Decodable {
    let avgPaymentDays: Double?
    let totalInvoiced: String
    let totalPaid: String
    let onTimeRate: Double?
    let invoiceCount: Int
    let paidCount: Int
    let outstandingAmount: String

    enum CodingKeys: String, CodingKey {
        case avgPaymentDays = "avg_payment_days"
        case totalInvoiced = "total_invoiced"
        case totalPaid = "total_paid"
        case onTimeRate = "on_time_rate"
        case invoiceCount = "invoice_count"
        case paidCount = "paid_count"
        case outstandingAmount = "outstanding_amount"
    }
}

/// One client in `Clients.client_ranking/1` (`GET /clients/ranking`).
struct ClientRankingDTO: Decodable, Identifiable {
    let id: String
    let name: String
    let avgPaymentDays: Double?
    let totalInvoiced: String
    let totalPaid: String
    let onTimeRate: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case avgPaymentDays = "avg_payment_days"
        case totalInvoiced = "total_invoiced"
        case totalPaid = "total_paid"
        case onTimeRate = "on_time_rate"
    }
}
