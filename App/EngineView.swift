import WebKit

enum RenderError: Error, LocalizedError {
    case engineMissing, engineNotReady, noTimeline
    case frameFailed(Int), badFrame, bufferFailed, appendFailed, writeFailed, saveDenied

    var errorDescription: String? {
        switch self {
        case .engineMissing: return "Engine bundle nahi mila (App/engine/)."
        case .engineNotReady: return "Engine ready nahi hua (timeout)."
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

/// Loads the bundled cartoon engine (a single ES bundle: three.js + toon world + story)
/// in an offscreen WKWebView and drives the same interface Playwright used on the PC:
///   window.ready -> true once the engine warmed up
///   window.TOTAL  -> total frame count (patched into main.js during prep)
///   window.renderFrame(f) -> JPEG dataURL of frame f (1080 x 1920)
@MainActor
final class Engine {
    private let web: WKWebView
    private let root: URL

    init() throws {
        guard let html = Bundle.main.url(forResource: "engine", withExtension: "html", subdirectory: "engine") else {
            throw RenderError.engineMissing
        }
        root = html.deletingLastPathComponent()
        web = WKWebView(frame: CGRect(x: 0, y: 0, width: 1080, height: 1920))
        web.configuration.upgradeKnownHostsToHTTPS = false
    }

    func load() async throws {
        web.loadFileURL(root.appendingPathComponent("engine.html"), allowingReadAccessTo: root)
        for _ in 0..<600 { // up to ~2.5 min warmup (WebGL compile + warmup frame)
            try await Task.sleep(nanoseconds: 250_000_000)
            if try await evalBool("window.ready === true") { return }
        }
        throw RenderError.engineNotReady
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

    private func evalBool(_ js: String) async throws -> Bool { (try await eval(js)) as? Bool ?? false }

    private func eval(_ js: String) async throws -> Any? {
        try await withCheckedThrowingContinuation { cont in
            web.evaluateJavaScript(js) { result, error in
                if let error { cont.resume(throwing: error) } else { cont.resume(returning: result) }
            }
        }
    }
}
