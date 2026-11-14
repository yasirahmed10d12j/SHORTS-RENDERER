import SwiftUI
import AVFoundation
import Photos

/// End-to-end Video Generator: idea -> LLM script -> per-scene ElevenLabs voice ->
/// render engine syncs to voice timeline -> final MP4 with audio muxed in.
struct VideoGeneratorView: View {
    // --- script, voice, render state ---
    @State private var provider: LLMProvider = .gemini
    @State private var llmKey = ""
    @State private var llmModel = ""
    @State private var llmKeySaved = false
    @State private var idea = ""
    @State private var pasteText = ""

    @State private var script: StoryScript?
    @State private var scriptBusy = false
    @State private var sceneStatus: [Int: String] = [:]
    @State private var players: [Int: AVAudioPlayer] = [:]

    @State private var voices: [ElevenVoice] = []
    @State private var voiceID = ""
    @State private var voiceBusy = false
    @State private var allVoicesReady = false

    // --- render state ---
    @State private var renderStartTime: Date? = nil
    @State private var total = 0
    @State private var fps: Double = 0
    @State private var eta: Double = 0
    @State private var progress: Double = 0
    @State private var running = false
    @State private var done = false

    @State private var status = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text("Video Generator")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)

                // ── 1. Idea / Paste ────────────────────────────────
                ideSection

                if scriptBusy || running { ProgressView() }

                // ── 2. Script ──────────────────────────────────────
                if let s = script { scriptCards(s) }

                // ── 3. Voice ────────────────────────────────────────
                if script != nil { voiceControls }

                Divider()

                // ── 4. Render ──────────────────────────────────────
                renderSection

                if !status.isEmpty { Text(status).font(.caption).foregroundStyle(.secondary) }
            }
            .padding(20)
        }
        .onAppear {
            if llmModel.isEmpty { llmModel = provider.defaultModel }
            if Keychain.get("llm_key") != nil { llmKeySaved = true }
            if Keychain.get("elevenlabs_key") != nil { Task { await loadVoices() } }
        }
    }

    // MARK: - idea input

    private var ideSection: some View {
        GroupBox("Step 1 — idea likho ya bahar se paste karo") {
            VStack(alignment: .leading, spacing: 10) {
                VStack(spacing: 8) {
                    Text("Option A: AI se script banao").font(.subheadline.bold())
                    TextEditor(text: $idea)
                        .frame(height: 80)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
                    HStack {
                        Picker("", selection: $provider) {
                            ForEach(LLMProvider.allCases) { p in Text(p.label).tag(p) }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: provider) { p in llmModel = p.defaultModel }
                        TextField("model", text: $llmModel)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                    }
                    HStack {
                        SecureField(llmKeySaved ? "LLM key saved ✓" : "LLM API key", text: $llmKey)
                            .textFieldStyle(.roundedBorder)
                        Button(llmKeySaved ? "✓" : "Save") { saveLLMKey() }
                            .buttonStyle(.bordered)
                    }
                    Button { Task { await makeScript() } } label: {
                        Label("Script banao", systemImage: "wand.and.stars")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(scriptBusy || !llmKeySaved || idea.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(6)

                Divider()

                VStack(spacing: 8) {
                    Text("Option B: bahar se bani script paste karo").font(.subheadline.bold())
                    TextEditor(text: $pasteText)
                        .frame(height: 80)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
                    Button { parsePasted() } label: {
                        Label("Parse karo", systemImage: "doc.text")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(pasteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || scriptBusy)
                    Text("Samajh: Scene 1:, #1, 1., VISUAL lines. Markers na mile to paragraphs.")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
                .padding(6)
            }
        }
        .font(.subheadline)
    }

    // ── script cards ────────────────────────────────────────────────────────

    private func scriptCards(_ s: StoryScript) -> some View {
        GroupBox("Step 2 — \(s.scenes.count) scenes") {
            VStack(alignment: .leading, spacing: 10) {
                Text(s.title).font(.headline)
                if let log = s.logline, !log.isEmpty {
                    Text(log).font(.caption).foregroundStyle(.secondary)
                }
                ForEach(s.scenes) { scene in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("Scene \(scene.n)").font(.caption.bold())
                            Spacer()
                            if let st = sceneStatus[scene.n], !st.isEmpty {
                                Text(st).font(.caption2).foregroundStyle(.secondary)
                            }
                            if players[scene.n] != nil {
                                Button { togglePlay(scene.n) } label: { Image(systemName: "play.fill") }
                                    .buttonStyle(.bordered).controlSize(.mini)
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
    }

    // ── voice controls ──────────────────────────────────────────────────────

    private var voiceControls: some View {
        GroupBox("Step 3 — voice generation") {
            VStack(spacing: 10) {
                Picker("Voice", selection: $voiceID) {
                    if voices.isEmpty { Text("Key save karo →").tag("") }
                    ForEach(voices) { v in Text(v.name).tag(v.voiceId) }
                }
                Button { Task { await genAllVoices() } } label: {
                    Label(allVoicesReady ? "🔄 Voice dobara" : "✅ Voice generate", systemImage: "waveform")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(voiceBusy || voiceID.isEmpty)
                if !status.isEmpty { Text(status).font(.caption).foregroundStyle(.secondary) }
            }
            .padding(4)
        }
        .font(.subheadline)
    }

    // ── render section ─────────────────────────────────────────────────────

    private var renderSection: some View {
        GroupBox("Step 4 — render") {
            VStack(alignment: .leading, spacing: 10) {
                if running && total > 0 {
                    Text("\(rendered) / \(total)")
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .monospacedDigit()
                    Text(String(format: "%.0f%%", progress * 100))
                        .font(.title3).foregroundStyle(.secondary)
                    if fps > 0.5 {
                        let el = Int(Date().timeIntervalSince(renderStartTime ?? Date()))
                        Text("\(String(format: "%.1f", fps)) fps · ~\(Int(eta.rounded()))s baki · \(el)s elapsed")
                            .font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
                ProgressView(value: progress)
                Button {
                    running = true
                    Task { await runRender() }
                } label: {
                    Label("▶ Render video & save", systemImage: "film")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(running || script == nil || !allVoicesReady)
                if done {
                    Text("✅ Video Photos me save ho gaya").foregroundStyle(.green)
                }
            }
            .padding(4)
        }
        .font(.subheadline)
    }

    // ── helpers ─────────────────────────────────────────────────────────────

    private func togglePlay(_ n: Int) {
        guard let p = players[n] else { return }
        if p.isPlaying { p.pause() } else { _ = p.play() }
    }

    private func saveLLMKey() {
        let k = llmKey.trimmingCharacters(in: .whitespaces)
        guard !k.isEmpty else { return }
        Keychain.set(k, for: "llm_key")
        llmKey = ""
        llmKeySaved = true
        status = "LLM key saved."
    }

    private func makeScript() async {
        scriptBusy = true
        status = "Script ban rahi hai…"
        do {
            guard let key = Keychain.get("llm_key") else { throw LLMError.empty }
            let model = llmModel.trimmingCharacters(in: .whitespaces).isEmpty ? provider.defaultModel : llmModel
            script = try await LLM.makeScript(idea: idea, provider: provider, key: key, model: model)
            scriptBusy = false
            status = "✅ \(script?.scenes.count ?? 0) scenes — ab voice generate karo."
        } catch {
            scriptBusy = false
            status = "Script error: \(error.localizedDescription)"
        }
    }

    private func parsePasted() {
        let s = LLM.parseScriptText(pasteText)
        script = s
        sceneStatus = [:]
        players = [:]
        allVoicesReady = false
        status = "✅ \(s.scenes.count) scenes parsed — ab voice generate karo."
    }

    private func loadVoices() async {
        guard let key = Keychain.get("elevenlabs_key") else { return }
        do { voices = try await ElevenLabs.voices(key: key);
              if voiceID.isEmpty, let f = voices.first { voiceID = f.voiceId } }
        catch { status = "Voice load fail: \(error.localizedDescription)" }
    }

    private func genAllVoices() async {
        guard let s = script else { return }
        guard let key = Keychain.get("elevenlabs_key") else {
            status = "Pehle 'Voice & Render' tab me ElevenLabs key save karo."; return
        }
        voiceBusy = true; allVoicesReady = false
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("script", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var metas: [[String: Any]] = []; var ok = true
        for sc in s.scenes {
            sceneStatus[sc.n] = "generate…"
            do {
                let r = try await ElevenLabs.speech(text: sc.narration, key: key, voiceId: voiceID)
                let file = folder.appendingPathComponent(String(format: "scene-%02d.mp3", sc.n))
                try r.audio.write(to: file)
                metas.append(["n": sc.n, "audio": file.lastPathComponent, "duration": r.duration])
                sceneStatus[sc.n] = "✅ \(String(format: "%.1f", r.duration))s"
                players[sc.n] = try? AVAudioPlayer(contentsOf: file)
            } catch {
                sceneStatus[sc.n] = "❌ \(error.localizedDescription)"; ok = false
            }
        }
        if ok, let json = try? JSONSerialization.data(withJSONObject: ["title": s.title, "scenes": metas]) {
            try? json.write(to: folder.appendingPathComponent("scenes.json"))
            allVoicesReady = true
            status = "✅ Sab voices ready — ab Render dabao."
        } else if !metas.isEmpty {
            status = "\(metas.count)/\(s.scenes.count) ready"
        }
        voiceBusy = false
    }

    private func runRender() async {
        defer { running = false }
        renderStartTime = nil
        elapsedSecs = 0
        do {
            rendered = 0; total = 0; progress = 0; fps = 0; eta = 0; done = false
            renderStartTime = Date()
            status = "Engine load…"
            let engine = try Engine()
            try await engine.load()
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            var plan: AudioPlan?
            if let p = AudioMux.detect(docs: docs) { plan = p }
            if let plan {
                try await engine.setVoiceDuration(plan.totalDuration)
                status = String(format: "Voice detect — %.1fs ke hisaab se render hogi.", plan.totalDuration)
                try await Task.sleep(nanoseconds: 1_000_000_000) // show status briefly
            }
            let total_ = try await engine.totalFrames(); total = total_; status = "Render shuru…"
            let rawURL = FileManager.default.temporaryDirectory.appendingPathComponent("short.mp4")
            let writer = try VideoWriter(url: rawURL)
            for f in 0..<total_ {
                let jpeg = try await engine.jpegFrame(f)
                try await writer.append(jpeg, frame: f)
                rendered = f + 1
                progress = Double(rendered) / Double(total_)
                let dt = Date().timeIntervalSince(renderStartTime ?? Date())
                fps = dt > 0 ? Double(rendered) / dt : 0
                eta = fps > 0 ? Double(total_ - rendered) / fps : 0
            }
            try await writer.finish()

            // mux voice into video if present
            var outURL = rawURL
            if let plan {
                status = "Audio mix… \(String(format: "%.1fs", plan.totalDuration))"
                let muxed = FileManager.default.temporaryDirectory.appendingPathComponent("final.mp4")
                try await AudioMux.mux(video: rawURL, plan: plan, out: muxed)
                outURL = muxed
            } else {
                status = "Photos me save…"
            }
            try await saveToPhotos(outURL)
            done = true
            status = "Done — \(total_) frames in \(Int(Date().timeIntervalSince(renderStartTime ?? Date())))s."
                + (plan != nil ? " Voice included." : "")
        } catch {
            status = "Render error: \(error.localizedDescription)"
        }
        
    }

    private func saveToPhotos(_ url: URL) async throws {
        let auth = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard auth == .authorized || auth == .limited else { throw RenderError.saveDenied }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }
    }

    // ── timer helpers ─────────────────────────────────────────────────────────
    // (elapsedSecs shown during render computed directly from start Date below)

}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
