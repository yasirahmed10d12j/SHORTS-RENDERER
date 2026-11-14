import SwiftUI
import Photos

struct ContentView: View {
    @State private var status = "Ready. 'Render test' se Mountain Man example story phone pe render hogi."
    @State private var progress: Double = 0
    @State private var running = false
    @State private var done = false

    var body: some View {
        VStack(spacing: 24) {
            Text("Cartoon Short Renderer")
                .font(.title2.bold())
            Text(status)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            ProgressView(value: progress)
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
            progress = 0; done = false
            status = "Engine load ho raha hai…"
            let engine = try Engine()
            try await engine.load()
            let total = try await engine.totalFrames()
            status = "\(total) frames render honge (~\(String(format: "%.0f", Double(total) * 0.3))s)…"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("short.mp4")
            let writer = try VideoWriter(url: url)
            for f in 0..<total {
                let jpeg = try await engine.jpegFrame(f)
                try await writer.append(jpeg, frame: f)
                progress = Double(f + 1) / Double(total)
                if f % 30 == 0 { status = "Frame \(f + 1)/\(total)…" }
            }
            try await writer.finish()
            status = "Photos me save ho raha hai…"
            try await saveToPhotos(url)
            done = true
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
