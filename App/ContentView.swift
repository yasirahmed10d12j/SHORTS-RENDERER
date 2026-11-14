import SwiftUI
import Photos
import AVFoundation

struct ContentView: View {
    // render
    @State private var status = "Pehle voiceover generate karo (neeche), phir render."
    @State private var rendered = 0
    @State private var total = 0
    @State private var fps: Double = 0
    @State private var eta: Double = 0
    @State private var progress: Double = 0
    @State private var running = false
    @State private var done = false

    // voiceover
    @State private var apiKey = ""
    @State private var keySaved = false
    @State private var voices: [ElevenVoice] = []
    @State private var voiceID = ""
    @State private var script = ""
    @State private var voiceStatus = ""
    @State private var voiceBusy = false
    @State private var voiceReady = false
    @State private var voiceInfo = ""
    @State private var player: AVAudioPlayer?

    var body: some View {
        VStack(spacing: 20) {
            Text("Cartoon Short Renderer")
                .font(.title2.bold())

            GroupBox("ElevenLabs voice") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        SecureField("API key (ek baar paste karo)", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                        Button(keySaved ? "✓" : "Save") { saveKey() }
                            .buttonStyle(.bordered)
                    }
                    HStack {
                        Picker("Voice", selection: $voiceID) {
                            if voices.isEmpty { Text(keySaved ? "Voices load karo →" : "Key pehle save karo").tag("") }
                            ForEach(voices) { v in Text(v.name).tag(v.voiceId) }
                        }
                        Button {
                            Task { await loadVoices() }
                        } label: { Image(systemName: "arrow.clockwise") }
                            .disabled(!keySaved || voiceBusy)
                    }
                    TextEditor(text: $script)
                        .frame(height: 90)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
                    if !voiceStatus.isEmpty {
                        Text(voiceStatus).font(.caption).foregroundStyle(.secondary)
                    }
                    HStack {
                        Button {
                            Task { await generateVoice() }
                        } label: {
                            Label(voiceReady ? "Dobara generate" : "Generate voiceover", systemImage: "waveform")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(voiceBusy || !keySaved || voiceID.isEmpty || script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        if voiceReady {
                            Button {
                                if let player {
                                    if player.isPlaying {
                                        player.pause()
                                    } else {
                                        _ = player.play()
                                    }
                                } else {
                                    try? playPreview()
                                }
                            } label: { Image(systemName: "play.fill") }
                                .buttonStyle(.bordered)
                        }
                    }
                    .disabled(voiceBusy)
                    if !voiceInfo.isEmpty {
                        Text(voiceInfo).font(.caption2).foregroundStyle(.tertiary)
                    }
                }
                .padding(4)
            }
            .font(.subheadline)

            Divider()

            // render
            if running && total > 0 {
                Text("\(rendered) / \(total)")
                    .font(.system(size: 40, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                Text(String(format: "%.0f%%", progress * 100))
                    .font(.title3)
                    .foregroundStyle(.secondary)
                if fps > 0.5 {
                    Text("\(String(format: "%.1f", fps)) frames/s · ~\(Int(eta.rounded()))s baki")
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
                Text("Render video")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(running)

            if done {
                Text("✅ Video Photos me save ho gaya")
                    .foregroundStyle(.green)
            }
        }
        .padding(24)
        .onAppear {
            if let k = Keychain.get("elevenlabs_key") {
                apiKey = ""
                keySaved = true
                Task { await loadVoices() }
            }
        }
    }

    // MARK: - voiceover

    private func saveKey() {
        let k = apiKey.trimmingCharacters(in: .whitespaces)
        guard !k.isEmpty else { return }
        Keychain.set(k, for: "elevenlabs_key")
        apiKey = ""
        keySaved = true
        voiceStatus = "Key Keychain me save ho gayi."
        Task { await loadVoices() }
    }

    private func loadVoices() async {
        guard let key = Keychain.get("elevenlabs_key") else { return }
        keySaved = true
        do {
            voices = try await ElevenLabs.voices(key: key)
            if voiceID.isEmpty, let first = voices.first { voiceID = first.voiceId }
            voiceStatus = "\(voices.count) voices mile."
        } catch {
            voiceStatus = "Voices load fail: \(error.localizedDescription)"
        }
    }

    private func generateVoice() async {
        voiceBusy = true
        voiceStatus = "ElevenLabs se voice generate ho rahi hai…"
        do {
            guard let key = Keychain.get("elevenlabs_key") else { throw ElevenError.noAudio }
            Keychain.set(voiceID, for: "elevenlabs_voice") // Script Maker bhi yahi voice use karega
            let result = try await ElevenLabs.speech(text: script, key: key, voiceId: voiceID)
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            try result.audio.write(to: docs.appendingPathComponent("voice.mp3"))
            let meta: [String: Any] = [
                "duration": result.duration,
                "voice_id": voiceID,
                "model": ElevenLabs.defaultModel,
                "words": result.words.map { ["word": $0.word, "start": $0.start, "end": $0.end] },
            ]
            let json = try JSONSerialization.data(withJSONObject: meta)
            try json.write(to: docs.appendingPathComponent("voice.json"))
            voiceReady = true
            voiceStatus = "✅ Voice ready — \(result.words.count) words, \(String(format: "%.1f", result.duration))s"
            voiceInfo = "voice.mp3 + voice.json Documents me save ho gaye (word timings ElevenLabs alignment se)."
        } catch {
            voiceStatus = "Error: \(error.localizedDescription)"
        }
        voiceBusy = false
    }

    private func playPreview() throws {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        player = try AVAudioPlayer(contentsOf: docs.appendingPathComponent("voice.mp3"))
        player?.play()
    }

    // MARK: - render

    private func render() async {
        do {
            rendered = 0; total = 0; progress = 0; fps = 0; eta = 0; done = false
            status = "Engine load ho raha hai…"
            let engine = try Engine()
            try await engine.load()
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let plan = AudioMux.detect(docs: docs)
            if let plan {
                try await engine.setVoiceDuration(plan.totalDuration)
                status = String(format: "Voice milegi — video %.1fs ke hisaab se render hogi.", plan.totalDuration)
            }
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
            var outURL = url
            if let plan {
                status = "Voice video me mix ho rahi hai…"
                let muxed = FileManager.default.temporaryDirectory.appendingPathComponent("final.mp4")
                try await AudioMux.mux(video: url, plan: plan, out: muxed)
                outURL = muxed
            }
            status = "Photos me save ho raha hai…"
            try await saveToPhotos(outURL)
            done = true
            status = "Done — \(total_) frames in \(Int(Date().timeIntervalSince(start)))s." + (plan != nil ? " Voice included." : "")
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
