import XCTest
@testable import InVoiceFlow_iOS

/// Unit tests for `RecordPaymentRequest` — verifies JSON serialisation and
/// deserialisation behaviour as required by Sub-AC 1.
///
/// The struct is `Encodable`-only (request body); round-trip tests are done by
/// encoding to JSON and then decoding back with a generic `[String: Any]`
/// dictionary so the tests stay independent of a `Decodable` conformance on
/// the model itself.
final class RecordPaymentRequestTests: XCTestCase {

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]   // deterministic key order for assertions
        return e
    }()

    // MARK: - Encoding: all fields present

    /// When all three fields are provided the JSON must contain
    /// `amount`, `payment_date`, and `notes` with snake_case keys.
    func testEncode_allFields() throws {
        let request = RecordPaymentRequest(
            amount: "50000",
            paymentDate: "2024-06-01",
            notes: "1차 중도금"
        )

        let data = try encoder.encode(request)
        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        XCTAssertEqual(json["amount"] as? String, "50000")
        XCTAssertEqual(json["payment_date"] as? String, "2024-06-01")
        XCTAssertEqual(json["notes"] as? String, "1차 중도금")
        XCTAssertEqual(json.count, 3, "Unexpected extra keys in JSON payload")
    }

    // MARK: - Encoding: amount only (optional fields nil)

    /// When `paymentDate` and `notes` are `nil` the JSON must contain
    /// only the `amount` key — no `null` values should be emitted.
    func testEncode_amountOnly_omitsNilFields() throws {
        let request = RecordPaymentRequest(
            amount: "1234.56",
            paymentDate: nil,
            notes: nil
        )

        let data = try encoder.encode(request)
        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        XCTAssertEqual(json["amount"] as? String, "1234.56")
        XCTAssertNil(json["payment_date"], "payment_date must be absent when nil")
        XCTAssertNil(json["notes"], "notes must be absent when nil")
        XCTAssertEqual(json.count, 1, "Only 'amount' key expected")
    }

    // MARK: - Encoding: partial fields

    /// Providing only `paymentDate` (without `notes`) should produce a payload
    /// with exactly `amount` and `payment_date`.
    func testEncode_amountAndDate_omitsNotes() throws {
        let request = RecordPaymentRequest(
            amount: "99999",
            paymentDate: "2024-12-31",
            notes: nil
        )

        let data = try encoder.encode(request)
        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        XCTAssertEqual(json["amount"] as? String, "99999")
        XCTAssertEqual(json["payment_date"] as? String, "2024-12-31")
        XCTAssertNil(json["notes"], "notes must be absent when nil")
        XCTAssertEqual(json.count, 2)
    }

    /// Providing only `notes` (without `paymentDate`) should produce a payload
    /// with exactly `amount` and `notes`.
    func testEncode_amountAndNotes_omitsPaymentDate() throws {
        let request = RecordPaymentRequest(
            amount: "500",
            paymentDate: nil,
            notes: "현금 수령"
        )

        let data = try encoder.encode(request)
        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        XCTAssertEqual(json["amount"] as? String, "500")
        XCTAssertNil(json["payment_date"], "payment_date must be absent when nil")
        XCTAssertEqual(json["notes"] as? String, "현금 수령")
        XCTAssertEqual(json.count, 2)
    }

    // MARK: - CodingKeys: snake_case mapping

    /// Confirms the raw JSON string contains snake_case keys matching the
    /// backend's Phoenix controller expectation.
    func testEncode_jsonStringContainsSnakeCaseKeys() throws {
        let request = RecordPaymentRequest(
            amount: "100",
            paymentDate: "2024-01-15",
            notes: "test"
        )

        let data = try encoder.encode(request)
        let jsonString = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertTrue(
            jsonString.contains("\"payment_date\""),
            "JSON must use snake_case key 'payment_date', got: \(jsonString)"
        )
        XCTAssertFalse(
            jsonString.contains("\"paymentDate\""),
            "camelCase 'paymentDate' must not appear in JSON output"
        )
    }

    // MARK: - Decimal precision

    /// Verifies that decimal string values survive encoding without floating-point
    /// rounding — the convention used throughout the codebase for money fields.
    func testEncode_preservesDecimalPrecision() throws {
        let preciseAmount = "123456789.99"
        let request = RecordPaymentRequest(
            amount: preciseAmount,
            paymentDate: nil,
            notes: nil
        )

        let data = try encoder.encode(request)
        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        XCTAssertEqual(
            json["amount"] as? String,
            preciseAmount,
            "Decimal precision must be preserved verbatim"
        )
    }

    // MARK: - Empty strings

    /// Empty-string `notes` and `paymentDate` are valid non-nil values and
    /// should be encoded (not omitted).
    func testEncode_emptyStringFieldsAreIncluded() throws {
        let request = RecordPaymentRequest(
            amount: "1000",
            paymentDate: "",
            notes: ""
        )

        let data = try encoder.encode(request)
        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        XCTAssertEqual(json["payment_date"] as? String, "")
        XCTAssertEqual(json["notes"] as? String, "")
        XCTAssertEqual(json.count, 3)
    }
}
