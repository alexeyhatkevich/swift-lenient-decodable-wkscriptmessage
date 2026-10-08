import SwiftUI
import WebKit
import LenientMessage

enum HandlerMode: String, CaseIterable, Identifiable {
    case naive = "Naive", fixed = "Fixed"
    var id: String { rawValue }
}

struct ContentView: View {
    @State private var mode: HandlerMode = .naive
    @State private var alertText: String?
    @State private var log: [String] = []

    var body: some View {
        VStack(spacing: 8) {
            Picker("Handler", selection: $mode) {
                ForEach(HandlerMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            Text("Tap the page buttons. Naive: shapes other than string ids pop a raw Cocoa error. Fixed: no alert, bad messages are only logged.")
                .font(.footnote).foregroundStyle(.secondary)
            PageView(mode: mode) { outcome in
                log.insert(String(describing: outcome), at: 0)
                if case .alert(let text) = outcome { alertText = text }
            }
            .border(.gray)
            Text(log.first.map { "Last outcome: \($0)" } ?? "Last outcome: -")
                .font(.footnote.monospaced()).lineLimit(3)
        }
        .padding()
        .alert("Error", isPresented: Binding(get: { alertText != nil }, set: { if !$0 { alertText = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(alertText ?? "") }
    }
}

struct PageView: UIViewRepresentable {
    let mode: HandlerMode
    let onOutcome: (HandlingOutcome) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "checkout")
        let web = WKWebView(frame: .zero, configuration: config)
        let url = Bundle.main.url(forResource: "page", withExtension: "html")!
        web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.mode = mode
        context.coordinator.onOutcome = onOutcome
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        var mode: HandlerMode = .naive
        var onOutcome: (HandlingOutcome) -> Void = { _ in }

        func userContentController(_ c: WKUserContentController, didReceive message: WKScriptMessage) {
            let outcome: HandlingOutcome = switch mode {
            case .naive: NaiveMessageHandler.handle(body: message.body)
            case .fixed: LenientMessageHandler.handle(body: message.body)
            }
            onOutcome(outcome)
        }
    }
}
