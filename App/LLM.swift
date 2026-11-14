import Foundation

/// LLM clients for the in-app Script Maker: user idea -> structured script JSON.
/// Gemini (free tier), OpenAI and OpenRouter (OpenAI-compatible) supported.
enum LLMProvider: String, CaseIterable, Identifiable {
    case gemini, openai, openrouter
    var id: String { rawValue }

    var label: String {
        switch self {
        case .gemini: return "Gemini (free tier)"
        case .openai: return "OpenAI"
        case .openrouter: return "OpenRouter"
        }
    }

    var defaultModel: String {
        switch self {
        case .gemini: return "gemini-3.8-flash"
        case .openai: return "gpt-4o-mini"
        case .openrouter: return "openai/gpt-4o-mini"
        }
    }
}

struct StoryScript: Codable {
    let title: String
    let logline: String?
    let scenes: [Scene]

    struct Scene: Codable, Identifiable {
        let n: Int
        let narration: String
        let visual: String?
        var id: Int { n }
    }
}

enum LLMError: Error, LocalizedError {
    case http(Int, String), empty, badJSON(String)

    var errorDescription: String? {
        switch self {
        case .http(let c, let m): return "LLM API error \(c): \(m)"
        case .empty: return "LLM ne khaali jawab diya."
        case .badJSON(let m): return "Script JSON parse fail: \(m)"
        }
    }
}

enum LLM {
    static func makeScript(idea: String, provider: LLMProvider, key: String, model: String) async throws -> StoryScript {
        let system = """
        Tum ek vertical cartoon short (9:16, ~30-45s) ke scriptwriter ho. User apne words me story idea \
        dega; tum use proper scenes me todna. Rules:
        - 6 se 9 scenes. Har scene ki narration 1-2 chhoti spoken sentences; pehle scene me strong hook.
        - Har scene ka visual 1 line me: screen pe kya hoga (characters, action, background). Simple, animatable.
        - Wahi language use karo jisme user ne likha (Hindi/Hinglish/English).
        - Sirf original content: koi real celebrity, brand, ya famous cartoon character nahi.
        - Last scene me emotional ya funny punch.
        Output SIRF valid JSON, koi markdown nahi:
        {"title":"...","logline":"...","scenes":[{"n":1,"narration":"...","visual":"..."}]}
        """
        let prompt = system + "\n\nUser ka idea: " + idea
        let raw: String
        switch provider {
        case .gemini:
            raw = try await gemini(prompt: prompt, key: key, model: model)
        case .openai, .openrouter:
            raw = try await openaiCompatible(prompt: prompt, key: key, model: model, provider: provider)
        }
        return try decodeScript(raw)
    }

    // MARK: - providers

    private static func gemini(prompt: String, key: String, model: String) async throws -> String {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(key)") else {
            throw LLMError.empty
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 240
        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": ["responseMimeType": "application/json", "temperature": 0.9],
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        try check(resp, data)
        struct R: Decodable {
            struct Cand: Decodable {
                struct Content: Decodable {
                    struct Part: Decodable { let text: String? }
                    let parts: [Part]
                }
                let content: Content
            }
            let candidates: [Cand]
        }
        let r = try JSONDecoder().decode(R.self, from: data)
        return r.candidates.first?.content.parts.compactMap(\.text).joined() ?? ""
    }

    private static func openaiCompatible(prompt: String, key: String, model: String, provider: LLMProvider) async throws -> String {
        let base = provider == .openrouter ? "https://openrouter.ai/api/v1" : "https://api.openai.com/v1"
        guard let url = URL(string: base + "/chat/completions") else { throw LLMError.empty }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 240
        let body: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": prompt]],
            "response_format": ["type": "json_object"],
            "temperature": 0.9,
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        try check(resp, data)
        struct R: Decodable {
            struct Choice: Decodable {
                struct Msg: Decodable { let content: String? }
                let message: Msg
            }
            let choices: [Choice]
        }
        let r = try JSONDecoder().decode(R.self, from: data)
        return r.choices.first?.message.content ?? ""
    }

    // MARK: - tolerant JSON decode

    static func decodeScript(_ raw: String) throws -> StoryScript {        guard let start = raw.firstIndex(of: "{"), let end = raw.lastIndex(of: "}"), start < end else {
            throw LLMError.badJSON("jawab me JSON nahi mila")
        }
        let json = String(raw[start...end])
        let obj = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
        guard let obj, let scenes = obj["scenes"] as? [[String: Any]] else {
            throw LLMError.badJSON("scenes missing")
        }
        let mapped = scenes.enumerated().compactMap { i, sc -> StoryScript.Scene? in
            guard let narration = sc["narration"] as? String, !narration.isEmpty else { return nil }
            return StoryScript.Scene(n: (sc["n"] as? Int) ?? (i + 1), narration: narration, visual: sc["visual"] as? String)
        }
        guard !mapped.isEmpty else { throw LLMError.badJSON("scenes khaali") }
        return StoryScript(title: (obj["title"] as? String) ?? "Untitled", logline: obj["logline"] as? String, scenes: mapped)
    }

    /// Parses a pasted script (from ChatGPT/Gemini web/notes) into scenes.
    /// Understands "Scene 1:", "1.", "#1", "shot 2" markers and VISUAL/CAMERA lines.
    /// With no markers, blank-line-separated paragraphs become scenes.
    static func parseScriptText(_ raw: String) -> StoryScript {
        struct Block { var narration = ""; var visual = "" }
        let lines = raw.components(separatedBy: "\n")
        let markerWords = ["scene", "sean", "sene", "सीन", "shot", "clip", "दृश्य", "part"]

        func markerNumber(_ line: String) -> Int? {
            let low = line.lowercased()
            for w in markerWords where low.hasPrefix(w) {
                let digits = line.dropFirst(w.count).drop(while: { $0 == " " || $0 == ":" || $0 == "#" || $0 == "-" || $0 == "." || $0 == ")" }).prefix(while: { $0.isNumber })
                return Int(digits) // nil = unnumbered marker, still starts a block
            }
            if let first = line.first, first.isNumber {
                let digits = line.prefix(while: { $0.isNumber })
                if digits.count <= 2, digits.count < line.count { return Int(digits) }
            }
            if line.hasPrefix("#") {
                let digits = line.dropFirst().prefix(while: { $0.isNumber })
                if let n = Int(digits) { return n }
            }
            return nil
        }

        func isVisual(_ line: String) -> Bool {
            let low = line.lowercased()
            let keywords = ["visual", "camera", "on screen", "🎬", "दृश्य", "animation", "shot desc", "bg:", "background:"]
            if keywords.contains(where: { low.hasPrefix($0) }) { return true }
            return line.hasPrefix("(") && line.hasSuffix(")")
        }

        func stripLabel(_ line: String) -> String {
            if let ci = line.firstIndex(of: ":") {
                let rest = line[line.index(after: ci)...].trimmingCharacters(in: .whitespaces)
                if !rest.isEmpty { return rest }
            }
            if line.hasPrefix("(") && line.hasSuffix(")") {
                return String(line.dropFirst().dropLast())
            }
            // "Scene 1 - text" / "Scene 1 text"
            var s = Substring(line)
            for w in markerWords where s.lowercased().hasPrefix(w) {
                s = s.dropFirst(w.count).drop(while: { " :#-.0123456789)".contains($0) && !$0.isLetter })
            }
            s = s.drop(while: { $0 == "-" || $0 == " " })
            return s.trimmingCharacters(in: .whitespaces)
        }

        var blocks: [Block] = []
        for line in lines {
            let t = line.trimmingCharacters(in: .whitespaces)
            guard !t.isEmpty else { continue }
            if markerNumber(t) != nil {
                blocks.append(Block())
                let rest = stripLabel(t)
                if !rest.isEmpty { blocks[blocks.count - 1].narration = rest }
                continue
            }
            if blocks.isEmpty { blocks.append(Block()) }
            if isVisual(t) {
                blocks[blocks.count - 1].visual = stripLabel(t)
            } else {
                let i = blocks.count - 1
                blocks[i].narration += blocks[i].narration.isEmpty ? t : " " + t
            }
        }
        if blocks.isEmpty {
            var cur = Block()
            for line in lines {
                let t = line.trimmingCharacters(in: .whitespaces)
                if t.isEmpty {
                    if !cur.narration.isEmpty { blocks.append(cur); cur = Block() }
                } else {
                    cur.narration += cur.narration.isEmpty ? t : " " + t
                }
            }
            if !cur.narration.isEmpty { blocks.append(cur) }
        }
        guard !blocks.isEmpty else { return StoryScript(title: "Pasted Script", logline: nil, scenes: []) }
        let scenes = blocks.enumerated().map { i, b in
            StoryScript.Scene(n: i + 1, narration: b.narration, visual: b.visual.isEmpty ? nil : b.visual)
        }
        return StoryScript(title: "Pasted Script", logline: nil, scenes: scenes)
    }

    private static func check(_ resp: URLResponse, _ data: Data) throws {
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            throw LLMError.http(code, String(data: data.prefix(300), encoding: .utf8) ?? "")
        }
    }
}
