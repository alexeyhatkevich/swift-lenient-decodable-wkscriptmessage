import Foundation

/// The bug: every field is a non-optional `String`, so any deviation
/// from the exact shape the developer expected makes decoding throw.
public struct NaiveStepMessage: Decodable, Equatable, Sendable {
    public let status: String
    public let stepId: String
    public let reference: String
}

public enum NaiveMessageHandler {
    public static func handle(body: Any) -> HandlingOutcome {
        do {
            let data = try JSONSerialization.data(withJSONObject: body)
            let message = try JSONDecoder().decode(NaiveStepMessage.self, from: data)
            guard message.status == "success" else { return .nothing }
            return .followUp(reference: message.reference)
        } catch {
            // The raw Cocoa text ends up in front of the user.
            return .alert(error.localizedDescription)
        }
    }
}
