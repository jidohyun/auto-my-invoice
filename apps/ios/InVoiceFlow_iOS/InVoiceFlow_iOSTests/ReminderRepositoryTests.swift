import XCTest
@testable import InVoiceFlow_iOS

// MARK: - Mock

/// Test double for `ReminderRepositoryProtocol`.
/// Configure `stubbedResult` / `stubbedError` before calling `sendReminder`.
final class MockReminderRepository: ReminderRepositoryProtocol {
    var stubbedResult: SendReminderResult?
    var stubbedError: Error?
    private(set) var capturedInvoiceId: String?

    func sendReminder(invoiceId: String) async throws -> SendReminderResult {
        capturedInvoiceId = invoiceId
        if let error = stubbedError { throw error }
        return stubbedResult!
    }
}

// MARK: - Unit tests

@MainActor
final class ReminderRepositoryTests: XCTestCase {

    // MARK: Helpers

    /// Builds a `ReminderRepository` that wraps a fake `URLProtocol` responding
    /// with the given `statusCode` and JSON `body`.
    private func makeRepository(
        statusCode: Int,
        body: Data
    ) -> (ReminderRepository, MockURLProtocol.Type) {
        MockURLProtocol.responseStatusCode = statusCode
        MockURLProtocol.responseData = body
        MockURLProtocol.responseError = nil

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        let client = APIClient.testInstance(session: session)
        return (ReminderRepository(api: client), MockURLProtocol.self)
    }

    private func makeRepository(transportError: Error) -> ReminderRepository {
        MockURLProtocol.responseError = transportError
        MockURLProtocol.responseStatusCode = 0
        MockURLProtocol.responseData = Data()

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let client = APIClient.testInstance(session: URLSession(configuration: config))
        return ReminderRepository(api: client)
    }

    // MARK: Success (200)

    func test_sendReminder_success_returnsMessage() async throws {
        let json = #"{"data":{"message":"리마인더가 발송 예약되었습니다"}}"#.data(using: .utf8)!
        let (repo, _) = makeRepository(statusCode: 200, body: json)

        let result = try await repo.sendReminder(invoiceId: "abc-123")

        XCTAssertEqual(result, .success(message: "리마인더가 발송 예약되었습니다"))
    }

    func test_sendReminder_success_passesCorrectInvoiceId() async throws {
        let json = #"{"data":{"message":"ok"}}"#.data(using: .utf8)!
        MockURLProtocol.responseStatusCode = 200
        MockURLProtocol.responseData = json
        MockURLProtocol.responseError = nil

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let client = APIClient.testInstance(session: URLSession(configuration: config))
        let repo = ReminderRepository(api: client)

        _ = try await repo.sendReminder(invoiceId: "invoice-999")

        // Verify the request URL contained the correct ID
        XCTAssertTrue(
            MockURLProtocol.lastRequestURL?.absoluteString.contains("invoice-999") == true,
            "Expected URL to contain invoice-999, got \(MockURLProtocol.lastRequestURL?.absoluteString ?? "nil")"
        )
    }

    // MARK: 422 Invalid Status

    func test_sendReminder_422_returnsInvalidStatus() async throws {
        let json = #"{"error":"이 상태에서는 리마인더를 보낼 수 없습니다"}"#.data(using: .utf8)!
        let (repo, _) = makeRepository(statusCode: 422, body: json)

        let result = try await repo.sendReminder(invoiceId: "inv-1")

        XCTAssertEqual(result, .invalidStatus)
    }

    // MARK: 429 Rate Limited

    func test_sendReminder_429_returnsRateLimited() async throws {
        let json = #"{"error":"오늘 이미 리마인더를 보냈습니다. 내일 다시 시도하세요."}"#.data(using: .utf8)!
        let (repo, _) = makeRepository(statusCode: 429, body: json)

        let result = try await repo.sendReminder(invoiceId: "inv-2")

        XCTAssertEqual(result, .rateLimited)
    }

    // MARK: 401 Unauthorized

    func test_sendReminder_401_throwsUnauthorized() async {
        let json = #"{"error":"unauthorized"}"#.data(using: .utf8)!
        let (repo, _) = makeRepository(statusCode: 401, body: json)

        do {
            _ = try await repo.sendReminder(invoiceId: "inv-3")
            XCTFail("Expected APIError.unauthorized to be thrown")
        } catch APIError.unauthorized {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: 500 Server Error

    func test_sendReminder_500_throwsHTTPError() async {
        let json = #"{"error":"internal server error"}"#.data(using: .utf8)!
        let (repo, _) = makeRepository(statusCode: 500, body: json)

        do {
            _ = try await repo.sendReminder(invoiceId: "inv-4")
            XCTFail("Expected APIError.http to be thrown")
        } catch APIError.http(let status, _) {
            XCTAssertEqual(status, 500)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: Transport Error

    func test_sendReminder_transportError_throwsTransportError() async {
        let repo = makeRepository(transportError: URLError(.notConnectedToInternet))

        do {
            _ = try await repo.sendReminder(invoiceId: "inv-5")
            XCTFail("Expected APIError.transport to be thrown")
        } catch APIError.transport {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

// MARK: - MockURLProtocol

final class MockURLProtocol: URLProtocol {
    static var responseStatusCode: Int = 200
    static var responseData: Data = Data()
    static var responseError: Error?
    static var lastRequestURL: URL?
    /// HTTP method of the most-recently intercepted request (e.g. "GET", "POST").
    static var lastRequestMethod: String?
    /// When set, overrides the `Content-Type` header in the stubbed response.
    /// Defaults to `"application/json"` when `nil`.
    static var responseContentType: String?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        MockURLProtocol.lastRequestURL = request.url
        MockURLProtocol.lastRequestMethod = request.httpMethod

        if let error = MockURLProtocol.responseError {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        let contentType = MockURLProtocol.responseContentType ?? "application/json"
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: MockURLProtocol.responseStatusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": contentType]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: MockURLProtocol.responseData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
