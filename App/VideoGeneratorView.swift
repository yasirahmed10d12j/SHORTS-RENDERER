import SwiftUI
import AVFoundation
import Photos

/// One card in the horizontal built-in story picker.
private struct StoryCard: View {
    let story: BuiltInStory
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(story.title)
                .font(.subheadline.bold())
                .lineLimit(2)
            if let log = story.logline {
                Text(log)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(width: 160, alignment: .leading)
        .padding(12)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
    }

    private var cardBackground: Color {
        isSelected ? Color.blue.opacity(0.2) : Color.gray.opacity(0.15)
    }
}

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

    // --- built-in stories ---
    @State private var builtInStories: [BuiltInStory] = []
    @State private var selectedStory: BuiltInStory?

    @State private var script: StoryScript?
    @State private var scriptBusy = false
    @State private var sceneStatus: [Int: String] = [:]
    @State private var players: [Int: AVAudioPlayer] = [:]

    @State private var voices: [ElevenVoice] = []
    @State private var voiceID = ""
    @State private var voiceBusy = false
    @State private var allVoicesReady = false

    // --- render state ---
    @State private var rendered = 0
    @State private var renderStartTime: Date? = nil
    @State private var total = 0
    @State private var fps: Double = 0
    @State private var eta: Double = 0
    @State private var progress: Double = 0
    @State private var running = false
    @State private var done = false
    @State private var liveEngine: Engine?

    @State private var status = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text("Video Generator")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)

                // ── 0. Story Picker (built-in) ───────────────────
                if !builtInStories.isEmpty { storyPickerSection }

                Divider()

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
            Task { await loadBuiltInStories() }
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

    // ── story picker ────────────────────────────────────────────────────────

    private var storyPickerSection: some View {
        GroupBox("📚 Built-In Stories — select one to render instantly") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Choose from \(builtInStories.count) ready-made stories — bundled voiceover, ek click render:")
                    .font(.caption).foregroundStyle(.secondary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(builtInStories) { story in
                            Button {
                                selectStory(story)
                            } label: {
                                StoryCard(story: story, isSelected: selectedStory?.id == story.id)
                            }
                        }
                    }
                }
                
                if let selected = selectedStory {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Selected: \(selected.title)").font(.headline)
                        Text(selected.logline ?? "").font(.caption).foregroundStyle(.secondary)
                        Text("\(selected.scenes.count) scenes · ~\(Int(selected.estimatedDuration))s voice")
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                    .padding(8)
                    .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(4)
        }
        .font(.subheadline)
    }

    private func selectStory(_ story: BuiltInStory) {
        selectedStory = story
        script = story.storyScript
        sceneStatus = [:]
        players = [:]
        allVoicesReady = false
        clearOldScriptFiles()  // remove stale voice from previous script
        Task { await loadBundledVoices(for: story) }
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
        GroupBox("Step 3 — voice") {
            VStack(spacing: 10) {
                if selectedStory != nil {
                    // built-in story: voiceover is bundled in the app, nothing to generate
                    Label("Voice bundled — ab seedha Render dabao", systemImage: "checkmark.seal.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.green)
                        .frame(maxWidth: .infinity)
                    if !allVoicesReady {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Bundled voice load ho rahi hai…").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                } else {
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
                }
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
                if let engine = liveEngine, running {
                    EnginePreview(engine: engine)
                        .frame(height: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.3)))
                }
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
        selectedStory = nil
        clearOldScriptFiles()  // remove stale voice from previous story
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
        selectedStory = nil
        clearOldScriptFiles()  // remove stale voice from previous story
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

    private func loadBuiltInStories() async {
        do {
            builtInStories = try StoryBundle.load()
            status = "✅ \(builtInStories.count) stories loaded!"
        } catch {
            status = "Story bundle load failed: \(error.localizedDescription)"
        }
    }

    private func genAllVoices() async {
        guard let s = script else { return }

        // Custom scripts only — built-in stories use loadBundledVoices() automatically.
        guard let key = Keychain.get("elevenlabs_key") else {
            status = "Pehle ElevenLabs key save karo."; return
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

    /// Built-in story: voiceover MP3s ship inside the app bundle (voices/<story-id>/scene-XX.mp3,
    /// generated on the laptop with Kokoro). Copy them into Documents/script/ so AudioMux
    /// picks them up — no on-device synthesis, no API key.
    private func loadBundledVoices(for story: BuiltInStory) async {
        voiceBusy = true; allVoicesReady = false
        status = "Bundled voice load ho rahi hai…"
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folder = docs.appendingPathComponent("script", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var metas: [[String: Any]] = []
        var totalDur = 0.0

        for sc in story.scenes {
            let name = String(format: "scene-%02d", sc.n)
            // folder reference in bundle keeps per-story subfolders: voices/<id>/scene-XX.mp3
            guard let bundled = Bundle.main.url(forResource: name, withExtension: "mp3",
                                                subdirectory: "voices/\(story.id)") else {
                status = "❌ Bundled voice missing: \(story.id)/\(name).mp3"
                voiceBusy = false
                return
            }
            let file = folder.appendingPathComponent(name + ".mp3")
            do {
                try? FileManager.default.removeItem(at: file)
                try FileManager.default.copyItem(at: bundled, to: file)
                let dur = AudioMux.duration(of: file)
                metas.append(["n": sc.n, "audio": file.lastPathComponent, "duration": dur])
                totalDur += dur
                sceneStatus[sc.n] = "✅ \(String(format: "%.1f", dur))s"
                players[sc.n] = try? AVAudioPlayer(contentsOf: file)
            } catch {
                status = "❌ Voice copy fail: \(error.localizedDescription)"
                voiceBusy = false
                return
            }
        }

        if let json = try? JSONSerialization.data(withJSONObject: ["title": story.title, "scenes": metas]) {
            try? json.write(to: folder.appendingPathComponent("scenes.json"))
        }
        allVoicesReady = true
        voiceBusy = false
        status = String(format: "✅ Voice ready (%.0fs) — ab Render dabao.", totalDur)
    }

    private func runRender() async {
        defer {
            running = false
            liveEngine = nil
            UIApplication.shared.isIdleTimerDisabled = false // screen lock allowed again
        }
        renderStartTime = nil
        do {
            rendered = 0; total = 0; progress = 0; fps = 0; eta = 0; done = false
            renderStartTime = Date()
            // keep the screen on + app foreground during render: WKWebView
            // throttles JS timers when the screen locks, which stalls frames
            UIApplication.shared.isIdleTimerDisabled = true
            status = "Engine load…"
            // engine.html me sirf Mountain Man ka baked timeline hai; baaki
            // built-in stories data-driven engine2 (specs.json) se render hoti hain.
            let storyId = selectedStory?.id
            let useEngine2 = storyId != nil && storyId != "the-mountain-man"
            let engine = try Engine(page: useEngine2 ? "engine2" : "engine")
            liveEngine = engine // live preview (foreground) during render
            try await engine.load()
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            var plan: AudioPlan?
            if let p = AudioMux.detect(docs: docs) { plan = p }
            if useEngine2 {
                let spec = try storySpecJSON(for: storyId!)
                status = "Story load (3D spec)…"
                try await engine.loadStory(spec)
                status = "✅ Spec loaded — visuals story ke set se banenge."
                try await Task.sleep(nanoseconds: 800_000_000) // show status briefly
            } else if let plan {
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

    /// Built-in story ka engine2 spec: bundled App/specs.json se, JS-safe raw JSON string.
    private func storySpecJSON(for storyId: String) throws -> String {
        guard let url = Bundle.main.url(forResource: "specs", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let all = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let spec = all[storyId] else {
            throw RenderError.engineNotReady("Spec nahi mila: \(storyId) (specs.json check karo).")
        }
        let d = try JSONSerialization.data(withJSONObject: spec, options: [.sortedKeys])
        return String(decoding: d, as: UTF8.self)
    }

    private func clearOldScriptFiles() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try? FileManager.default.removeItem(at: docs.appendingPathComponent("script", isDirectory: true))
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

// MARK: - Live render preview (foreground, GPU/Metal-backed WKWebView)
struct EnginePreview: UIViewRepresentable {
    let engine: Engine
    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        let web = engine.previewView
        web.frame = container.bounds
        web.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.addSubview(web)
        return container
    }
    func updateUIView(_ uiView: UIView, context: Context) {
        engine.previewView.frame = uiView.bounds
    }
}
