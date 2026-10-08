import Foundation
import os

/// Decodes a scalar leniently: String, Bool, Int, Double and null all
/// become `String?`. Anything else (array, object) becomes nil.
/// Blank strings are treated as absent.
enum LenientString {
    static func decode<K: CodingKey>(from container: KeyedDecodingContainer<K>, forKey key: K) -> String? {
        guard container.contains(key) else { return nil }
        if let v = try? container.decode(String.self, forKey: key) { return normalize(v) }
        // Bool must be tried before Int/Double: be explicit about `true`/`false`.
        if let v = try? container.decode(Bool.self, forKey: key) { return v ? "true" : "false" }
        if let v = try? container.decode(Int.self, forKey: key) { return String(v) }
        if let v = try? container.decode(Double.self, forKey: key) { return String(v) }
        return nil // null, array, object
    }

    static func normalize(_ s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}

public struct LenientStepMessage: Decodable, Equatable, Sendable {
    public let status: String?
    public let stepId: String?
    public let reference: String?

    private enum CodingKeys: String, CodingKey { case status, stepId, reference }

    public init(status: String?, stepId: String?, reference: String?) {
        self.status = status
        self.stepId = stepId
        self.reference = reference
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = LenientString.decode(from: c, forKey: .status)
        stepId = LenientString.decode(from: c, forKey: .stepId)
        reference = LenientString.decode(from: c, forKey: .reference)
    }

    /// Builds a message from `WKScriptMessage.body`, which may be an
    /// NSDictionary (JS object) or a String (JSON text). Returns nil when
    /// the body is not a JSON object at all.
    public init?(messageBody body: Any) {
        let data: Data
        if let text = body as? String {
            guard let d = text.data(using: .utf8) else { return nil }
            data = d
        } else if JSONSerialization.isValidJSONObject(body) {
            guard let d = try? JSONSerialization.data(withJSONObject: body) else { return nil }
            data = d
        } else {
            return nil
        }
        guard let decoded = try? JSONDecoder().decode(LenientStepMessage.self, from: data) else { return nil }
        self = decoded
    }

    public var isSuccess: Bool { status?.lowercased() == "success" }

    /// A "success" event is only actionable when the required field is present.
    public var canComplete: Bool { isSuccess && reference != nil }
}

public enum LenientMessageHandler {
    private static let logger = Logger(subsystem: "LenientMessage", category: "web-messages")

    public static let userFacingError = "We could not confirm this step. Please try again."

    public static func handle(body: Any) -> HandlingOutcome {
        // 1. Unreadable: ignore and log, never bother the user.
        guard let message = LenientStepMessage(messageBody: body) else {
            logger.error("Ignoring unreadable web message: \(String(describing: body), privacy: .private)")
            return .ignored
        }
        // 2. Readable but not a success: nothing to do.
        guard message.isSuccess else { return .nothing }
        // 3. Readable success that cannot be completed: product-level error.
        guard message.canComplete, let reference = message.reference else {
            logger.error("Success message without a reference")
            return .alert(userFacingError)
        }
        return .followUp(reference: reference)
    }
}
