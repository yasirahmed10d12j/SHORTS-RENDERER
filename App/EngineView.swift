import WebKit

enum RenderError: Error, LocalizedError {
    case engineMissing, noTimeline
    case engineNotReady(String)
    case frameFailed(Int), badFrame, bufferFailed, appendFailed, writeFailed, saveDenied

    var errorDescription: String? {
        switch self {
        case .engineMissing: return "Engine bundle nahi mila (App/engine/)."
        case .engineNotReady(let reason):
            if reason.isEmpty { return "Engine ready nahi hua (timeout)." }
            return "Engine ready nahi hua — \(reason)"
        case .noTimeline: return "window.TOTAL missing — engine patch check karo."
        case .frameFailed(let f): return "Frame \(f) render fail."
        case .badFrame: return "Frame JPEG decode fail."
        case .bufferFailed: return "Pixel buffer ban nahi paya."
        case .appendFailed: return "Frame video me append nahi hua."
        case .writeFailed: return "MP4 write fail."
        case .saveDenied: return "Photo library permission nahi mili."
        }
    }
}

/// Last JS console/error message from the engine page (shown in the UI on failure).
final class EngineConsole {
    static let shared = EngineConsole()
    var last = ""
}

/// Loads the bundled cartoon engine (single inline ES bundle: three.js + toon world + story)
/// in an offscreen WKWebView and drives the same interface Playwright used on the PC:
///   window.ready -> true once the engine warmed up
///   window.TOTAL  -> total frame count (patched into main.js during prep)
///   window.renderFrame(f) -> JPEG dataURL of frame f (1080 x 1920)
///
/// Note: the bundle is INLINED into engine.html. WKWebView refuses to load
/// `<script type="module" src="...">` from file:// URLs (no CORS origin), so the
/// engine must not rely on an external script fetch.
@MainActor
final class Engine: NSObject, WKScriptMessageHandler {
    private let web: WKWebView
    private let root: URL

    init() throws {
        guard let html = Bundle.main.url(forResource: "engine", withExtension: "html", subdirectory: "engine") else {
            throw RenderError.engineMissing
        }
        root = html.deletingLastPathComponent()

        let cfg = WKWebViewConfiguration()
        let ucc = cfg.userContentController
        ucc.add(self, name: "console")
        // Forward console output + uncaught JS errors to the app, so an engine
        // failure surfaces as a readable message instead of a bare timeout.
        ucc.addUserScript(WKUserScript(source: """
        window.__errors = [];
        window.onerror = function (m, s, l) {
          var msg = 'JS error: ' + m + (l ? ' (line ' + l + ')' : '');
          window.__errors.push(msg);
          try { window.webkit.messageHandlers.console.postMessage(msg); } catch (e) {}
        };
        ['log', 'warn', 'error'].forEach(function (k) {
          var orig = console[k].bind(console);
          console[k] = function () {
            var parts = Array.prototype.map.call(arguments, function (a) {
              return typeof a === 'string' ? a : JSON.stringify(a);
            });
            var msg = k + ': ' + parts.join(' ');
            try { window.webkit.messageHandlers.console.postMessage(msg); } catch (e) {}
            orig.apply(console, arguments);
          };
        });
        """, injectionTime: .atDocumentStart, forMainFrameOnly: true))

        web = WKWebView(frame: CGRect(x: 0, y: 0, width: 1080, height: 1920), configuration: cfg)
    }

    deinit {
        web.configuration.userContentController.removeScriptMessageHandler(forName: "console")
    }

    func load() async throws {
        web.loadFileURL(root.appendingPathComponent("engine.html"), allowingReadAccessTo: root)
        for i in 0..<600 { // up to ~2.5 min warmup (WebGL compile + warmup frame)
            try await Task.sleep(nanoseconds: 250_000_000)
            if i == 4, try await evalBool("location.protocol === 'file:'") == false {
                throw RenderError.engineNotReady("engine.html load nahi hua (page navigated nahi).")
            }
            if try await evalBool("window.ready === true") { return }
        }
        let errs = ((try? await eval("JSON.stringify(window.__errors || [])")) as? String) ?? "[]"
        let last = EngineConsole.shared.last
        throw RenderError.engineNotReady(errs == "[]" ? last : errs)
    }

    func totalFrames() async throws -> Int {
        guard let n = try await eval("window.TOTAL") as? Int, n > 0 else { throw RenderError.noTimeline }
        return n
    }

    func jpegFrame(_ f: Int) async throws -> Data {
        guard let s = try await eval("window.renderFrame(\(f))") as? String,
              let b64 = s.split(separator: ",", maxSplits: 1).last.map(String.init),
              let data = Data(base64Encoded: b64), data.count > 1000
        else { throw RenderError.frameFailed(f) }
        return data
    }

    // MARK: - JS bridge

    nonisolated func userContentController(_ ucc: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "console", let s = message.body as? String else { return }
        MainActor.assumeIsolated { EngineConsole.shared.last = s }
    }

    private func evalBool(_ js: String) async throws -> Bool { (try await eval(js)) as? Bool ?? false }

    private func eval(_ js: String) async throws -> Any? {
        try await withCheckedThrowingContinuation { cont in
            web.evaluateJavaScript(js) { result, error in
                if let error { cont.resume(throwing: error) } else { cont.resume(returning: result) }
            }
        }
    }
}
