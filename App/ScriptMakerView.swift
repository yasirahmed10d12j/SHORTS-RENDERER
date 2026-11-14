import SwiftUI
import AVFoundation

/// Script Maker: user idea -> LLM script (scenes) -> ElevenLabs voice per scene.
/// Saves Documents/script/scenes.json + scene-XX.mp3 files with word timings.
struct ScriptMakerView: View {
    // script writer
    @State private var provider: LLMProvider = .gemini
    @State private var llmKey = ""
    @State private var llmModel = ""
    @State private var llmKeySaved = false
    @State private var idea = ""
    @State private var script: StoryScript?
    @State private var scriptBusy = false
    @State private var status = ""

    // voice
    @State private var voices: [ElevenVoice] = []
    @State private var voiceID = ""
    @State private var voiceBusy = false
    @State private var sceneStatus: [Int: String] = [:]
    @State private var players: [Int: AVAudioPlayer] = [:]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Script Maker")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                writerSection
                if scriptBusy { ProgressView() }
                if script != nil { scriptSection }
                if !status.isEmpty {
                    Text(status).font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(20)
        }
        .onAppear {
            if llmModel.isEmpty { llmModel = provider.defaultModel }
            if Keychain.get("llm_key") != nil { llmKeySaved = true }
            if Keychain.get("elevenlabs_key") != nil {
                Task { await loadVoices() }
            }
        }
    }

    // MARK: - writer section

    private var writerSection: some View {
        GroupBox("1. Story idea — apne words me likho") {
            VStack(alignment: .leading, spacing: 10) {
                TextEditor(text: $idea)
                    .frame(height: 100)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
                HStack {
                    Picker("", selection: $provider) {
                        ForEach(LLMProvider.allCases) { p in Text(p.label).tag(p) }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: provider) { p in llmModel = p.defaultModel } // iOS 16 signature
                    TextField("model", text: $llmModel)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                }
                HStack {
                    SecureField(llmKeySaved ? "LLM API key saved ✓" : "LLM API key", text: $llmKey)
                        .textFieldStyle(.roundedBorder)
                    Button(llmKeySaved ? "✓" : "Save") { saveLLMKey() }
                        .buttonStyle(.bordered)
                }
                makeScriptButton
            }
            .padding(4)
        }
        .font(.subheadline)
    }

    private var makeScriptButton: some View {
        Button {
            Task { await makeScript() }
        } label: {
            Label("Script banao", systemImage: "wand.and.stars")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(scriptBusy || !llmKeySaved || idea.trimmed.isEmpty)
    }

    // MARK: - script + scenes section

    private var scriptSection: some View {
        GroupBox("2. Scenes — voice generate karo") {
            VStack(alignment: .leading, spacing: 12) {
                if let s = script {
                    Text(s.title).font(.headline)
                    if let log = s.logline, !log.isEmpty {
                        Text(log).font(.caption).foregroundStyle(.secondary)
                    }
                    voiceControls
                    ForEach(s.scenes) { scene in
                        SceneCard(
                            scene: scene,
                            status: sceneStatus[scene.n] ?? "",
                            hasAudio: players[scene.n] != nil,
                            onPlay: { togglePlay(scene.n) }
                        )
                    }
                    saveHint
                }
            }
            .padding(4)
        }
        .font(.subheadline)
    }

    private var voiceControls: some View {
        VStack(spacing: 10) {
            Picker("Voice", selection: $voiceID) {
                if voices.isEmpty { Text("Key save karo →").tag("") }
                ForEach(voices) { v in Text(v.name).tag(v.voiceId) }
            }
            Button {
                Task { await generateVoices() }
            } label: {
                Label("Voice generate (sab scenes)", systemImage: "waveform")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(voiceBusy || voiceID.isEmpty)
        }
    }

    private var saveHint: some View {
        Text("scenes.json + scene MP3s Documents/script/ me save hote hain — render engine inhi timings se sync hoga.")
            .font(.caption2)
            .foregroundStyle(.tertiary)
    }

    private func togglePlay(_ n: Int) {
        guard let p = players[n] else { return }
        if p.isPlaying {
            p.pause()
        } else {
            _ = p.play()
        }
    }

    // MARK: - script

    private func saveLLMKey() {
        let k = llmKey.trimmingCharacters(in: .whitespaces)
        guard !k.isEmpty else { return }
        Keychain.set(k, for: "llm_key")
        llmKey = ""
        llmKeySaved = true
        status = "LLM key Keychain me save ho gayi."
    }

    private func makeScript() async {
        scriptBusy = true
        status = "Script ban rahi hai… 0s"
        // live elapsed counter so it's obvious the request is alive
        let timer = Task {
            var elapsed = 0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                elapsed += 1
                status = "Script ban rahi hai… \(elapsed)s"
            }
        }
        defer { timer.cancel() }
        do {
            guard let key = Keychain.get("llm_key") else { throw LLMError.empty }
            let model = llmModel.trimmingCharacters(in: .whitespaces).isEmpty ? provider.defaultModel : llmModel
            script = try await LLM.makeScript(idea: idea, provider: provider, key: key, model: model)
            status = "✅ \(script?.scenes.count ?? 0) scenes bane — ab voice generate karo."
        } catch {
            status = "Error: \(error.localizedDescription)"
        }
        scriptBusy = false
    }

    // MARK: - voice

    private func loadVoices() async {
        guard let key = Keychain.get("elevenlabs_key") else { return }
        do {
            voices = try await ElevenLabs.voices(key: key)
            if voiceID.isEmpty, let first = voices.first { voiceID = first.voiceId }
        } catch {
            status = "Voices load fail: \(error.localizedDescription)"
        }
    }

    private func generateVoices() async {
        guard let script else { return }
        guard let key = Keychain.get("elevenlabs_key") else {
            status = "Pehle 'Voice & Render' tab me ElevenLabs key save karo."
            return
        }
        voiceBusy = true
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("script", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var metas: [[String: Any]] = []
        var ok = true
        for scene in script.scenes {
            sceneStatus[scene.n] = "generate…"
            do {
                let r = try await ElevenLabs.speech(text: scene.narration, key: key, voiceId: voiceID)
                let file = folder.appendingPathComponent(String(format: "scene-%02d.mp3", scene.n))
                try r.audio.write(to: file)
                metas.append([
                    "n": scene.n,
                    "narration": scene.narration,
                    "visual": scene.visual ?? "",
                    "audio": file.lastPathComponent,
                    "duration": r.duration,
                    "words": r.words.map { ["word": $0.word, "start": $0.start, "end": $0.end] },
                ])
                sceneStatus[scene.n] = "✅ \(String(format: "%.1f", r.duration))s"
                players[scene.n] = try? AVAudioPlayer(contentsOf: file)
            } catch {
                sceneStatus[scene.n] = "❌ \(error.localizedDescription)"
                ok = false
            }
        }
        if ok, let json = try? JSONSerialization.data(withJSONObject: ["title": script.title, "scenes": metas]) {
            try? json.write(to: folder.appendingPathComponent("scenes.json"))
            status = "✅ Sab scenes ki voice ready (scenes.json saved)."
        } else if !metas.isEmpty {
            status = "\(metas.count)/\(script.scenes.count) scenes ready — fail wale dobara try karo."
        }
        voiceBusy = false
    }
}

/// One scene card (extracted so the big body expression stays type-checkable).
private struct SceneCard: View {
    let scene: StoryScript.Scene
    let status: String
    let hasAudio: Bool
    let onPlay: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Scene \(scene.n)").font(.caption.bold())
                Spacer()
                if !status.isEmpty {
                    Text(status).font(.caption2).foregroundStyle(.secondary)
                }
                if hasAudio {
                    Button(action: onPlay) {
                        Image(systemName: "play.fill")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            }
            Text(scene.narration).font(.subheadline)
            if let v = scene.visual, !v.isEmpty {
                Text("🎬 " + v).font(.caption).foregroundStyle(.tertiary)
            }
        }
        .padding(8)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
