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
                            .onChange(of: provider) { _, p in llmModel = p.defaultModel }
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
                        Button {
                            Task { await makeScript() }
                        } label: {
                            Label("Script banao", systemImage: "wand.and.stars")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(scriptBusy || !llmKeySaved || idea.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(4)
                }
                .font(.subheadline)

                if scriptBusy { ProgressView() }

                if let script {
                    Text(script.title)
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let log = script.logline, !log.isEmpty {
                        Text(log).font(.caption).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    GroupBox("2. Scenes — voice generate karo") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Picker("Voice", selection: $voiceID) {
                                    if voices.isEmpty { Text("Key save karo →").tag("") }
                                    ForEach(voices) { v in Text(v.name).tag(v.voiceId) }
                                }
                            }
                            Button {
                                Task { await generateVoices() }
                            } label: {
                                Label("Voice generate (sab scenes)", systemImage: "waveform")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(voiceBusy || voiceID.isEmpty)

                            ForEach(script.scenes) { scene in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Scene \(scene.n)").font(.caption.bold())
                                        Spacer()
                                        if sceneStatus[scene.n] != nil {
                                            Text(sceneStatus[scene.n]!).font(.caption2).foregroundStyle(.secondary)
                                        }
                                        if players[scene.n] != nil {
                                            Button {
                                                let p = players[scene.n]!
                                                p.isPlaying ? p.pause() : p.play()
                                            } label: { Image(systemName: "play.fill") }
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
                        .padding(4)
                    }
                    .font(.subheadline)

                    Text("scenes.json + scene MP3s Documents/script/ me save hote hain — render engine inhi timings se sync hoga.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

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
        status = "\(provider.label) se script ban rahi hai…"
        do {
            guard let key = Keychain.get("llm_key") else { throw LLMError.empty }
            script = try await LLM.makeScript(idea: idea, provider: provider, key: key, model: llmModel.trimmingCharacters(in: .whitespaces).isEmpty ? provider.defaultModel : llmModel)
            status = "✅ \(script!.scenes.count) scenes bane — ab voice generate karo."
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
