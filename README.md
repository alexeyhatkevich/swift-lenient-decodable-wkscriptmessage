# Lenient decoding of WKScriptMessage bodies

A web page posts a JSON "step finished" message to native code with
`window.webkit.messageHandlers.checkout.postMessage(...)`. The native handler
decodes `message.body` into a `Decodable` struct with strict `String` fields.
The moment the page sends a number, `null`, or omits a key, `JSONDecoder` throws
and the app shows the raw Cocoa text in an "Error" alert:

- "The data couldn't be read because it isn't in the correct format." (`typeMismatch`)
- "The data couldn't be read because it is missing." (`null` / `keyNotFound`)

## How to run

1. Open `Demo/Demo.xcodeproj` in Xcode 15+ (or `xed Demo`), pick an iPhone simulator, press Cmd+R.
   Keep the control on **Naive** and tap buttons 2, 3, 4 in the page: a raw Cocoa error alert appears.
   Switch to **Fixed** and tap the same buttons: no Cocoa text; bad messages are only logged
   (button 7) or produce a product-level message (buttons 3, 4).
2. Tests: Cmd+U in the same project, or from the terminal:
   `swift test` (macOS, no simulator needed).
3. Alternatively open `Package.swift` directly for just the library and tests.

## The fix

`Sources/LenientMessage/LenientStepMessage.swift`:

- `init(from:)` uses a helper that accepts String, Bool, Int, Double and null and normalises to `String?`.
- `init?(messageBody:)` converts `WKScriptMessage.body` (NSDictionary or JSON text) safely.
- `canComplete` gates the follow-up call: a "success" with an empty required field never triggers it.
- Unreadable message: ignore and log with `os.Logger`. Readable but invalid: product-level error.

The naive version is in `NaiveStepMessage.swift`. `Tests/` has a table test of payload shapes.

## No SwiftPM? Compile sources and tests into a bare bundle

The sources are Foundation-only, so they can be built straight into an XCTest bundle
(useful when package resolution of a big project fails). Test imports are guarded with
`#if canImport(LenientMessage)` so the same file works when sources and tests share one module:

    scripts/swiftc-xctest.sh

Write-up: https://alexeyhatkevich.blogspot.com
