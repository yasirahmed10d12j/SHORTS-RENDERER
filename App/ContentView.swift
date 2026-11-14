import SwiftUI
import Photos

struct ContentView: View {
    @State private var status = "Ready. 'Render test' se Mountain Man example story phone pe render hogi."
    @State private var rendered = 0
    @State private var total = 0
    @State private var fps: Double = 0
    @State private var eta: Double = 0
    @State private var progress: Double = 0
    @State private var running = false
    @State private var done = false

    var body: some View {
        VStack(spacing: 24) {
            Text("Cartoon Short Renderer")
                .font(.title2.bold())

            if running && total > 0 {
                // Big frame counter: "150 / 1250"
                Text("\(rendered) / \(total)")
                    .font(.system(size: 40, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                Text(String(format: "%.0f%%", progress * 100))
                    .font(.title3)
                    .foregroundStyle(.secondary)
                if fps > 0.5 {
                    Text(String(format: "%.1f frames/s  ·  ~%ds baki", fps, Int(eta.rounded())))
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            ProgressView(value: progress)

            Text(status)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button {
                running = true
                Task { await render() }
            } label: {
                Text("Render test video")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(running)

            if done {
                Text("✅ Video Photos me save ho gaya")
                    .foregroundStyle(.green)
            }
        }
        .padding(28)
    }

    private func render() async {
        do {
            rendered = 0; total = 0; progress = 0; fps = 0; eta = 0; done = false
            status = "Engine load ho raha hai…"
            let engine = try Engine()
            try await engine.load()
            let total_ = try await engine.totalFrames()
            total = total_
            status = "Render shuru…"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("short.mp4")
            let writer = try VideoWriter(url: url)
            let start = Date()
            for f in 0..<total_ {
                let jpeg = try await engine.jpegFrame(f)
                try await writer.append(jpeg, frame: f)
                rendered = f + 1
                progress = Double(rendered) / Double(total_)
                let dt = Date().timeIntervalSince(start)
                fps = dt > 0 ? Double(rendered) / dt : 0
                eta = fps > 0 ? Double(total_ - rendered) / fps : 0
            }
            try await writer.finish()
            status = "Photos me save ho raha hai…"
            try await saveToPhotos(url)
            done = true
            status = String(format: "Done — %d frames in %.0fs.", total_, Date().timeIntervalSince(start))
            running = false
        } catch {
            status = "Error: \(error.localizedDescription)"
            running = false
        }
    }

    private func saveToPhotos(_ url: URL) async throws {
        let auth = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard auth == .authorized || auth == .limited else { throw RenderError.saveDenied }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }
    }
}
