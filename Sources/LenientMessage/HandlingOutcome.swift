import Foundation

/// What the native side decides to do with one message from the web page.
public enum HandlingOutcome: Equatable, Sendable {
    /// Success: call the follow-up API with this reference.
    case followUp(reference: String)
    /// Show this text in an alert.
    case alert(String)
    /// The message was unreadable. Nothing is shown; it is only logged.
    case ignored
    /// Readable and valid, but nothing to do (e.g. the step was cancelled).
    case nothing
}
