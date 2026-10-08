import XCTest
// Guarded so the same file also compiles when sources and tests are built
// together into one module (see README, "No SwiftPM" section).
#if canImport(LenientMessage)
@testable import LenientMessage
#endif

final class NaiveDecodingTests: XCTestCase {
    private let typeMismatchText = "The data couldn\u{2019}t be read because it isn\u{2019}t in the correct format."
    private let missingText = "The data couldn\u{2019}t be read because it is missing."

    // Proves: the exact payload the developer expected works.
    func test_naive_decodes_the_happy_path() {
        let body: [String: Any] = ["status": "success", "stepId": "s1", "reference": "r-1"]
        XCTAssertEqual(NaiveMessageHandler.handle(body: body), .followUp(reference: "r-1"))
    }

    // Proves: a number where a string was expected shows the raw Cocoa text.
    func test_naive_numeric_reference_shows_raw_cocoa_error() {
        let body: [String: Any] = ["status": "success", "stepId": "s1", "reference": 42]
        XCTAssertEqual(NaiveMessageHandler.handle(body: body), .alert(typeMismatchText))
    }

    // Proves: JSON null shows the "is missing" Cocoa text.
    func test_naive_null_reference_shows_raw_cocoa_error() {
        let body: [String: Any] = ["status": "success", "stepId": "s1", "reference": NSNull()]
        XCTAssertEqual(NaiveMessageHandler.handle(body: body), .alert(missingText))
    }

    // Proves: an omitted key shows the same "is missing" Cocoa text.
    func test_naive_missing_key_shows_raw_cocoa_error() {
        let body: [String: Any] = ["status": "success", "stepId": "s1"]
        XCTAssertEqual(NaiveMessageHandler.handle(body: body), .alert(missingText))
    }

    // Proves: even a cancelled step (no follow-up needed) raises an alert if a field is off.
    func test_naive_cancelled_step_with_numeric_id_still_alerts() {
        let body: [String: Any] = ["status": "cancelled", "stepId": 7, "reference": "r"]
        XCTAssertEqual(NaiveMessageHandler.handle(body: body), .alert(typeMismatchText))
    }
}

final class FixedDecodingTests: XCTestCase {
    private struct Case {
        let name: String
        let body: Any
        let expected: HandlingOutcome
    }

    private var table: [Case] { [
        Case(name: "string ids", body: ["status": "success", "stepId": "s1", "reference": "r-1"] as [String: Any],
             expected: .followUp(reference: "r-1")),
        Case(name: "numeric reference", body: ["status": "success", "stepId": 1, "reference": 42] as [String: Any],
             expected: .followUp(reference: "42")),
        Case(name: "double reference", body: ["status": "success", "reference": 1.5] as [String: Any],
             expected: .followUp(reference: "1.5")),
        Case(name: "bool reference", body: ["status": "success", "reference": true] as [String: Any],
             expected: .followUp(reference: "true")),
        Case(name: "extra keys", body: ["status": "success", "reference": "r", "extra": ["a": 1], "x": NSNull()] as [String: Any],
             expected: .followUp(reference: "r")),
        Case(name: "status casing", body: ["status": "SUCCESS", "reference": "r"] as [String: Any],
             expected: .followUp(reference: "r")),
        Case(name: "null reference", body: ["status": "success", "reference": NSNull()] as [String: Any],
             expected: .alert(LenientMessageHandler.userFacingError)),
        Case(name: "missing reference", body: ["status": "success", "stepId": "s1"] as [String: Any],
             expected: .alert(LenientMessageHandler.userFacingError)),
        Case(name: "empty reference", body: ["status": "success", "reference": ""] as [String: Any],
             expected: .alert(LenientMessageHandler.userFacingError)),
        Case(name: "blank reference", body: ["status": "success", "reference": "   "] as [String: Any],
             expected: .alert(LenientMessageHandler.userFacingError)),
        Case(name: "array reference", body: ["status": "success", "reference": [1, 2]] as [String: Any],
             expected: .alert(LenientMessageHandler.userFacingError)),
        Case(name: "cancelled step", body: ["status": "cancelled", "stepId": 7] as [String: Any],
             expected: .nothing),
        Case(name: "no status", body: ["reference": "r"] as [String: Any],
             expected: .nothing),
        Case(name: "JSON text body", body: #"{"status":"success","reference":99}"#,
             expected: .followUp(reference: "99")),
        Case(name: "plain text body", body: "hello", expected: .ignored),
        Case(name: "broken JSON text body", body: #"{"status":"succ"#, expected: .ignored),
        Case(name: "array body", body: [1, 2, 3], expected: .ignored),
        Case(name: "null body", body: NSNull(), expected: .ignored),
        Case(name: "number body", body: 5, expected: .ignored),
    ] }

    // Proves: every payload shape maps to the intended outcome.
    func test_fixed_payload_shape_table() {
        for c in table {
            XCTAssertEqual(LenientMessageHandler.handle(body: c.body), c.expected, c.name)
        }
    }

    // Proves: a numeric id no longer surfaces any Cocoa error text.
    func test_fixed_numeric_reference_is_normalised_to_string() {
        let m = LenientStepMessage(messageBody: ["status": "success", "reference": 42] as [String: Any])
        XCTAssertEqual(m?.reference, "42")
        XCTAssertEqual(m?.canComplete, true)
    }

    // Proves: a "success" with an empty required field cannot trigger the follow-up call.
    func test_fixed_success_with_empty_reference_cannot_complete() {
        let m = LenientStepMessage(messageBody: ["status": "success", "reference": ""] as [String: Any])
        XCTAssertNotNil(m)
        XCTAssertEqual(m?.canComplete, false)
        XCTAssertNotEqual(LenientMessageHandler.handle(body: ["status": "success", "reference": ""] as [String: Any]),
                          .followUp(reference: ""))
    }

    // Proves: unreadable messages are ignored, not shown to the user.
    func test_fixed_unreadable_message_is_ignored_not_alerted() {
        XCTAssertNil(LenientStepMessage(messageBody: "not json"))
        XCTAssertEqual(LenientMessageHandler.handle(body: "not json"), .ignored)
    }

    // Proves: readable-but-invalid shows a product-level text, never a Cocoa one.
    func test_fixed_readable_but_invalid_shows_product_level_error() {
        guard case .alert(let text) = LenientMessageHandler.handle(body: ["status": "success"] as [String: Any]) else {
            return XCTFail("expected alert")
        }
        XCTAssertFalse(text.contains("data couldn"))
    }
}
