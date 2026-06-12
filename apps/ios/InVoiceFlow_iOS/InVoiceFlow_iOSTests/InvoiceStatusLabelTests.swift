import XCTest
@testable import InVoiceFlow_iOS

/// Guards the invoice status -> Korean label mapping. Regression: the
/// `partially_paid` case was missing and leaked the raw enum to the UI.
final class InvoiceStatusLabelTests: XCTestCase {
    func test_label_mapsAllBackendStatuses() {
        XCTAssertEqual(InvoiceStatus.label("draft"), "초안")
        XCTAssertEqual(InvoiceStatus.label("sent"), "발송됨")
        XCTAssertEqual(InvoiceStatus.label("paid"), "결제완료")
        XCTAssertEqual(InvoiceStatus.label("partially_paid"), "부분결제")
        XCTAssertEqual(InvoiceStatus.label("overdue"), "연체")
        XCTAssertEqual(InvoiceStatus.label("cancelled"), "취소됨")
    }

    func test_label_isCaseInsensitive() {
        XCTAssertEqual(InvoiceStatus.label("PARTIALLY_PAID"), "부분결제")
        XCTAssertEqual(InvoiceStatus.label("Sent"), "발송됨")
    }

    func test_label_unknownStatusFallsBackToRaw() {
        XCTAssertEqual(InvoiceStatus.label("weird"), "weird")
    }

    func test_money_krwHasNoFractionAndGroups() {
        // KRW: no decimals, grouped thousands.
        let formatted = MoneyFormatter.format("1500000.00", currency: "KRW")
        XCTAssertTrue(formatted.contains("1,500,000"), "got \(formatted)")
        XCTAssertFalse(formatted.contains(".00"), "KRW should not show decimals: \(formatted)")
    }

    func test_money_usdKeepsTwoFractionDigits() {
        let formatted = MoneyFormatter.format("99.5", currency: "USD")
        XCTAssertTrue(formatted.contains("99.50"), "got \(formatted)")
    }
}
