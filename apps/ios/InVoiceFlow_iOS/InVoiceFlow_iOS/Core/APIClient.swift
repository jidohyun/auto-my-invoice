import Foundation

enum APIError: LocalizedError {
    case http(status: Int, body: String)
    case decoding(Error)
    case transport(Error)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .http(let s, let b): return "서버 오류 \(s) — \(b)"
        case .decoding: return "응답을 해석하지 못했습니다."
        case .transport(let e): return "네트워크 오류: \(e.localizedDescription)"
        case .unauthorized: return "로그인이 필요합니다."
        }
    }
}

/// AMI-88 (iOS): minimal async/await HTTP client wired to the
/// /api/v1 surface. Token is read from Keychain on every request; the
/// session-expired (401) case bubbles up as [.unauthorized] so
/// `AuthViewModel` can decide whether to log the user out.
@MainActor
final class APIClient {
    static let shared = APIClient()

    private let session = URLSession.shared
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    /// Override at app start via the `API_BASE_URL` Info.plist key if needed.
    /// Defaults to the live production backend; use Info.plist override (or a
    /// local scheme) to point at a local Phoenix dev server during development.
    var baseURL = URL(string: "https://automyinvoice.fly.dev/api/v1")
        ?? URL(string: "https://automyinvoice.fly.dev")!

    private init() {
        decoder = JSONDecoder()
        encoder = JSONEncoder()
    }

    /// Creates an `APIClient` backed by the given `URLSession`.
    /// Intended for unit tests only — inject a session whose `protocolClasses`
    /// contains a `MockURLProtocol` to intercept network calls.
    static func testInstance(session: URLSession) -> APIClient {
        let client = APIClient()
        client.overrideSession = session
        return client
    }

    // Overrides `session` when set; used only by `testInstance`.
    private var overrideSession: URLSession?
    private var activeSession: URLSession { overrideSession ?? session }

    // MARK: - Public surface

    func login(email: String, password: String) async throws -> AuthData {
        let req = try makeRequest(
            path: "/auth/login",
            method: "POST",
            body: LoginRequest(email: email, password: password),
            requiresAuth: false
        )
        return try await send(req, as: APIResponse<AuthData>.self).data
    }

    func register(email: String, password: String) async throws -> AuthData {
        let req = try makeRequest(
            path: "/auth/register",
            method: "POST",
            body: LoginRequest(email: email, password: password),
            requiresAuth: false
        )
        return try await send(req, as: APIResponse<AuthData>.self).data
    }

    func dashboard() async throws -> KpiSummaryDTO {
        let req = try makeRequest(path: "/dashboard", method: "GET")
        return try await send(req, as: APIResponse<KpiSummaryDTO>.self).data
    }

    // MARK: - Analytics (AMI parity)

    /// `GET /dashboard/analytics` — monthly collections, status distribution,
    /// and aging buckets for the analytics screen.
    func dashboardAnalytics() async throws -> DashboardAnalyticsDTO {
        let req = try makeRequest(path: "/dashboard/analytics", method: "GET")
        return try await send(req, as: APIResponse<DashboardAnalyticsDTO>.self).data
    }

    /// `GET /analytics/reminders` — reminder open/click/conversion effectiveness.
    func reminderEffectiveness() async throws -> ReminderEffectivenessDTO {
        let req = try makeRequest(path: "/analytics/reminders", method: "GET")
        return try await send(req, as: APIResponse<ReminderEffectivenessDTO>.self).data
    }

    /// `GET /clients/ranking` — clients ranked by payment behaviour.
    func clientRanking() async throws -> [ClientRankingDTO] {
        let req = try makeRequest(path: "/clients/ranking", method: "GET")
        return try await send(req, as: APIResponse<[ClientRankingDTO]>.self).data
    }

    /// `GET /clients/:id/analytics` — per-client payment-behaviour summary.
    func clientAnalytics(id: String) async throws -> ClientAnalyticsDTO {
        let req = try makeRequest(path: "/clients/\(id)/analytics", method: "GET")
        return try await send(req, as: APIResponse<ClientAnalyticsDTO>.self).data
    }

    func recentInvoices(limit: Int = 5) async throws -> [InvoiceDTO] {
        let req = try makeRequest(path: "/dashboard/recent?limit=\(limit)", method: "GET")
        return try await send(req, as: APIResponse<[InvoiceDTO]>.self).data
    }

    // MARK: - Invoices (AMI-44)

    func invoices(status: String? = nil, clientId: String? = nil) async throws -> [InvoiceDTO] {
        var items: [URLQueryItem] = []
        if let status, !status.isEmpty { items.append(.init(name: "status", value: status)) }
        if let clientId, !clientId.isEmpty { items.append(.init(name: "client_id", value: clientId)) }
        let req = try makeRequest(path: "/invoices", method: "GET", query: items)
        return try await send(req, as: APIResponse<[InvoiceDTO]>.self).data
    }

    func invoice(id: String) async throws -> InvoiceDTO {
        let req = try makeRequest(path: "/invoices/\(id)", method: "GET")
        return try await send(req, as: APIResponse<InvoiceDTO>.self).data
    }

    func createInvoice(_ body: InvoiceCreateRequest) async throws -> InvoiceDTO {
        let req = try makeRequest(path: "/invoices", method: "POST", body: Wrapped(invoice: body))
        return try await send(req, as: APIResponse<InvoiceDTO>.self).data
    }

    func sendInvoice(id: String) async throws -> InvoiceDTO {
        let req = try makeRequest(path: "/invoices/\(id)/send", method: "POST")
        return try await send(req, as: APIResponse<InvoiceDTO>.self).data
    }

    func markInvoicePaid(id: String) async throws -> InvoiceDTO {
        let req = try makeRequest(path: "/invoices/\(id)/mark_paid", method: "POST")
        return try await send(req, as: APIResponse<InvoiceDTO>.self).data
    }

    /// `POST /invoices/:id/record_payment` — record a (possibly partial)
    /// payment. The server validates status/amount/overpayment and returns the
    /// re-rendered invoice with the new `paid_amount`/`status`.
    func recordPayment(id: String, amount: String) async throws -> InvoiceDTO {
        let req = try makeRequest(
            path: "/invoices/\(id)/record_payment",
            method: "POST",
            body: RecordPaymentRequest(amount: amount, paymentDate: nil, notes: nil)
        )
        return try await send(req, as: APIResponse<InvoiceDTO>.self).data
    }

    /// `POST /invoices/:id/send_reminder` — triggers a manual reminder email
    /// for the given invoice. Returns the server's confirmation message.
    /// Throws `APIError.http(422, ...)` when the invoice status does not allow
    /// reminders, and `APIError.http(429, ...)` when the daily rate limit is hit.
    func sendReminder(id: String) async throws -> ReminderResponseDTO {
        let req = try makeRequest(path: "/invoices/\(id)/send_reminder", method: "POST")
        return try await send(req, as: APIResponse<ReminderResponseDTO>.self).data
    }

    /// `GET /api/v1/invoices/:id/pdf` — downloads the PDF binary for the given
    /// invoice. This Bearer-authenticated parity route mirrors the web
    /// (session-auth) `/invoices/:id/pdf` so the app can fetch it with its
    /// stored token. Returns raw `Data` (application/pdf); callers handle
    /// presentation (share sheet / QuickLook).
    /// Throws `APIError.http(404, ...)` when the invoice is not found.
    func invoicePdf(id: String) async throws -> Data {
        var req = baseRequest(path: "/invoices/\(id)/pdf", method: "GET", query: [], requiresAuth: true)
        req.setValue("application/pdf", forHTTPHeaderField: "Accept")
        return try await sendRaw(req)
    }

    /// `DELETE /invoices/:id` (the `resources` route). Success is 204 No
    /// Content, so we skip decoding.
    func deleteInvoice(id: String) async throws {
        let req = try makeRequest(path: "/invoices/\(id)", method: "DELETE")
        _ = try await sendNoContent(req)
    }

    // MARK: - Clients (AMI-44)

    func clients(search: String? = nil) async throws -> [ClientDTO] {
        var items: [URLQueryItem] = []
        if let search, !search.isEmpty { items.append(.init(name: "q", value: search)) }
        let req = try makeRequest(path: "/clients", method: "GET", query: items)
        return try await send(req, as: APIResponse<[ClientDTO]>.self).data
    }

    func client(id: String) async throws -> ClientDTO {
        let req = try makeRequest(path: "/clients/\(id)", method: "GET")
        return try await send(req, as: APIResponse<ClientDTO>.self).data
    }

    func createClient(_ body: ClientRequest) async throws -> ClientDTO {
        let req = try makeRequest(path: "/clients", method: "POST", body: Wrapped(client: body))
        return try await send(req, as: APIResponse<ClientDTO>.self).data
    }

    func updateClient(id: String, _ body: ClientRequest) async throws -> ClientDTO {
        let req = try makeRequest(path: "/clients/\(id)", method: "PUT", body: Wrapped(client: body))
        return try await send(req, as: APIResponse<ClientDTO>.self).data
    }

    /// `DELETE /clients/:id`. Success is 204 No Content.
    func deleteClient(id: String) async throws {
        let req = try makeRequest(path: "/clients/\(id)", method: "DELETE")
        _ = try await sendNoContent(req)
    }

    // MARK: - OCR upload & extraction (AMI-46)

    /// Multipart `POST /upload`. The Phoenix controller pattern-matches the
    /// `"file"` part (`%Plug.Upload{}`), so the form field MUST be named
    /// `file`. Returns the freshly-created extraction job (status `pending`).
    func uploadImage(data: Data, filename: String, contentType: String) async throws -> ExtractionJobDTO {
        let boundary = "Boundary-\(UUID().uuidString)"
        var req = baseRequest(path: "/upload", method: "POST", query: [], requiresAuth: true)
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.httpBody = multipartBody(
            boundary: boundary,
            field: "file",
            filename: filename,
            contentType: contentType,
            data: data
        )
        return try await send(req, as: APIResponse<ExtractionJobDTO>.self).data
    }

    /// `GET /extraction/:id` — poll the OCR job until `status` is terminal.
    func extractionJob(id: String) async throws -> ExtractionJobDTO {
        let req = try makeRequest(path: "/extraction/\(id)", method: "GET")
        return try await send(req, as: APIResponse<ExtractionJobDTO>.self).data
    }

    // MARK: - Settings (AMI-44)

    func settings() async throws -> UserSettingsDTO {
        let req = try makeRequest(path: "/settings", method: "GET")
        return try await send(req, as: APIResponse<UserSettingsDTO>.self).data
    }

    func updateSettings(_ body: UserSettingsUpdate) async throws -> UserSettingsDTO {
        let req = try makeRequest(path: "/settings", method: "PUT", body: Wrapped(settings: body))
        return try await send(req, as: APIResponse<UserSettingsDTO>.self).data
    }

    // MARK: - Push registration (AMI-41)

    /// POSTs the APNs device token to `/api/v1/devices`. The server route is
    /// pending (backend task), so a 404 here is expected until it ships; the
    /// caller swallows that case so push registration never crashes the app.
    func registerDevice(token: String) async throws {
        let req = try makeRequest(
            path: "/devices",
            method: "POST",
            body: DeviceRegistration(token: token, platform: "ios")
        )
        _ = try await sendNoContent(req)
    }

    // MARK: - Private

    /// Body envelope helper. The Phoenix controllers pattern-match on a
    /// single wrapping key (`%{"invoice" => ...}` etc.), so each request body
    /// is nested under exactly one of these.
    private struct Wrapped<T: Encodable>: Encodable {
        var invoice: T?
        var client: T?
        var settings: T?

        init(invoice: T) { self.invoice = invoice }
        init(client: T) { self.client = client }
        init(settings: T) { self.settings = settings }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            if let invoice { try c.encode(invoice, forKey: .invoice) }
            if let client { try c.encode(client, forKey: .client) }
            if let settings { try c.encode(settings, forKey: .settings) }
        }

        enum CodingKeys: String, CodingKey { case invoice, client, settings }
    }

    private func makeRequest<B: Encodable>(
        path: String,
        method: String,
        body: B,
        requiresAuth: Bool = true
    ) throws -> URLRequest {
        var req = baseRequest(path: path, method: method, query: [], requiresAuth: requiresAuth)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try encoder.encode(body)
        return req
    }

    private func makeRequest(
        path: String,
        method: String,
        query: [URLQueryItem] = [],
        requiresAuth: Bool = true
    ) throws -> URLRequest {
        return baseRequest(path: path, method: method, query: query, requiresAuth: requiresAuth)
    }

    /// Builds a single-file `multipart/form-data` body. Kept here so the upload
    /// endpoint stays consistent with the rest of the client's request shaping.
    private func multipartBody(
        boundary: String,
        field: String,
        filename: String,
        contentType: String,
        data: Data
    ) -> Data {
        var body = Data()
        let dashes = "--\(boundary)\r\n"
        body.append(Data(dashes.utf8))
        let disposition = "Content-Disposition: form-data; name=\"\(field)\"; filename=\"\(filename)\"\r\n"
        body.append(Data(disposition.utf8))
        body.append(Data("Content-Type: \(contentType)\r\n\r\n".utf8))
        body.append(data)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        return body
    }

    private func baseRequest(
        path: String,
        method: String,
        query: [URLQueryItem],
        requiresAuth: Bool
    ) -> URLRequest {
        var url = baseURL.appendingPathComponent(path)
        if !query.isEmpty,
           var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            components.queryItems = query
            url = components.url ?? url
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if requiresAuth, let token = KeychainStore.shared.token() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return req
    }

    private func send<T: Decodable>(_ req: URLRequest, as: T.Type) async throws -> T {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await activeSession.data(for: req)
        } catch {
            throw APIError.transport(error)
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(status) else {
            throw APIError.http(status: status, body: String(data: data, encoding: .utf8) ?? "")
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    /// Sends a request and returns the raw response body as `Data`.
    /// Used for binary endpoints (e.g. PDF download) where the body is not
    /// JSON and must not be decoded.
    private func sendRaw(_ req: URLRequest) async throws -> Data {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await activeSession.data(for: req)
        } catch {
            throw APIError.transport(error)
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(status) else {
            throw APIError.http(status: status, body: String(data: data, encoding: .utf8) ?? "")
        }
        return data
    }

    /// Sends a request whose success response carries no decodable body
    /// (e.g. 204 No Content, or device registration). Status handling matches
    /// `send` but skips JSON decoding.
    private func sendNoContent(_ req: URLRequest) async throws {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await activeSession.data(for: req)
        } catch {
            throw APIError.transport(error)
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(status) else {
            throw APIError.http(status: status, body: String(data: data, encoding: .utf8) ?? "")
        }
    }
}
