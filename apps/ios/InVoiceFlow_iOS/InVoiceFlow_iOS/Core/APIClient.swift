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

    /// Override at app start if needed (UserDefaults / build setting).
    /// Default points at the local Phoenix dev server.
    var baseURL = URL(string: "http://localhost:4000/api/v1")!

    private init() {
        decoder = JSONDecoder()
        encoder = JSONEncoder()
    }

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

    // MARK: - Clients (AMI-44)

    func clients(search: String? = nil) async throws -> [ClientDTO] {
        var items: [URLQueryItem] = []
        if let search, !search.isEmpty { items.append(.init(name: "q", value: search)) }
        let req = try makeRequest(path: "/clients", method: "GET", query: items)
        return try await send(req, as: APIResponse<[ClientDTO]>.self).data
    }

    func createClient(_ body: ClientRequest) async throws -> ClientDTO {
        let req = try makeRequest(path: "/clients", method: "POST", body: Wrapped(client: body))
        return try await send(req, as: APIResponse<ClientDTO>.self).data
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
            (data, response) = try await session.data(for: req)
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

    /// Sends a request whose success response carries no decodable body
    /// (e.g. 204 No Content, or device registration). Status handling matches
    /// `send` but skips JSON decoding.
    private func sendNoContent(_ req: URLRequest) async throws {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: req)
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
