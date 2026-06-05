import XCTest
@testable import InVoiceFlow_iOS

// MARK: - Unit tests

/// Tests for `PdfApiService.fetchInvoicePdf(invoiceId:)`.
///
/// All network I/O is intercepted by `MockURLProtocol` (defined in
/// `ReminderRepositoryTests.swift`) injected via
/// `URLSessionConfiguration.protocolClasses`.  This covers:
///   - Success (200): raw PDF `Data` returned as `.success`
///   - 404 Not Found: mapped to `.notFound` result
///   - 401 Unauthorized: re-thrown as `APIError.unauthorized`
///   - Network error: re-thrown as `APIError.transport`
@MainActor
final class PdfApiServiceTests: XCTestCase {

    // MARK: - Helpers

    /// Builds a `PdfApiService` whose underlying `APIClient` is backed by
    /// a `MockURLProtocol` session responding with `statusCode` and `body`.
    private func makeService(
        statusCode: Int,
        body: Data,
        contentType: String = "application/pdf"
    ) -> PdfApiService {
        MockURLProtocol.responseStatusCode = statusCode
        MockURLProtocol.responseData = body
        MockURLProtocol.responseError = nil
        MockURLProtocol.responseContentType = contentType

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        let api = APIClient.testInstance(session: session)
        return PdfApiService(api: api)
    }

    private func makeService(transportError: Error) -> PdfApiService {
        MockURLProtocol.responseError = transportError
        MockURLProtocol.responseStatusCode = 0
        MockURLProtocol.responseData = Data()
        MockURLProtocol.responseContentType = nil

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let api = APIClient.testInstance(session: URLSession(configuration: config))
        return PdfApiService(api: api)
    }

    // MARK: - Success (200)

    func test_fetchInvoicePdf_success_returnsPdfData() async throws {
        let pdfBytes = Data("%PDF-1.4 fake pdf content".utf8)
        let service = makeService(statusCode: 200, body: pdfBytes)

        let result = try await service.fetchInvoicePdf(invoiceId: "inv-abc")

        guard case .success(let data) = result else {
            XCTFail("Expected .success, got \(result)")
            return
        }
        XCTAssertEqual(data, pdfBytes)
    }

    func test_fetchInvoicePdf_success_requestContainsInvoiceId() async throws {
        let service = makeService(statusCode: 200, body: Data("%PDF-1.4".utf8))

        _ = try await service.fetchInvoicePdf(invoiceId: "invoice-999")

        let lastURL = MockURLProtocol.lastRequestURL?.absoluteString ?? ""
        XCTAssertTrue(
            lastURL.contains("invoice-999"),
            "Expected URL to contain 'invoice-999', got: \(lastURL)"
        )
    }

    func test_fetchInvoicePdf_success_requestURLContainsPdfSegment() async throws {
        let service = makeService(statusCode: 200, body: Data("%PDF-1.4".utf8))

        _ = try await service.fetchInvoicePdf(invoiceId: "abc-123")

        let lastURL = MockURLProtocol.lastRequestURL?.absoluteString ?? ""
        XCTAssertTrue(
            lastURL.contains("/pdf"),
            "Expected URL to contain '/pdf', got: \(lastURL)"
        )
    }

    func test_fetchInvoicePdf_success_usesGETMethod() async throws {
        let service = makeService(statusCode: 200, body: Data("%PDF".utf8))

        _ = try await service.fetchInvoicePdf(invoiceId: "abc-123")

        XCTAssertEqual(MockURLProtocol.lastRequestMethod, "GET")
    }

    // MARK: - 404 Not Found

    func test_fetchInvoicePdf_404_returnsNotFound() async throws {
        let body = Data(#"{"error":"not found"}"#.utf8)
        let service = makeService(statusCode: 404, body: body, contentType: "application/json")

        let result = try await service.fetchInvoicePdf(invoiceId: "missing-id")

        guard case .notFound = result else {
            XCTFail("Expected .notFound, got \(result)")
            return
        }
    }

    // MARK: - 401 Unauthorized

    func test_fetchInvoicePdf_401_throwsUnauthorized() async {
        let body = Data(#"{"error":"unauthorized"}"#.utf8)
        let service = makeService(statusCode: 401, body: body, contentType: "application/json")

        do {
            _ = try await service.fetchInvoicePdf(invoiceId: "inv-1")
            XCTFail("Expected APIError.unauthorized to be thrown")
        } catch APIError.unauthorized {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Network errors

    func test_fetchInvoicePdf_noConnection_throwsTransport() async {
        let service = makeService(transportError: URLError(.notConnectedToInternet))

        do {
            _ = try await service.fetchInvoicePdf(invoiceId: "inv-2")
            XCTFail("Expected APIError.transport to be thrown")
        } catch APIError.transport {
            // expected
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func test_fetchInvoicePdf_timeout_throwsTransportWithTimedOutCode() async {
        let service = makeService(transportError: URLError(.timedOut))

        do {
            _ = try await service.fetchInvoicePdf(invoiceId: "inv-timeout")
            XCTFail("Expected APIError.transport to be thrown")
        } catch APIError.transport(let underlying) {
            let urlError = underlying as? URLError
            XCTAssertEqual(urlError?.code, .timedOut)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - 500 Server Error

    func test_fetchInvoicePdf_500_throwsHTTPError() async {
        let body = Data(#"{"error":"internal server error"}"#.utf8)
        let service = makeService(statusCode: 500, body: body, contentType: "application/json")

        do {
            _ = try await service.fetchInvoicePdf(invoiceId: "inv-3")
            XCTFail("Expected APIError.http to be thrown")
        } catch APIError.http(let status, _) {
            XCTAssertEqual(status, 500)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
