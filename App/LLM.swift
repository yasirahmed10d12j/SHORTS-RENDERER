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
        req.timeoutInterval = 120
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
        req.timeoutInterval = 120
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

    static func decodeScript(_ raw: String) throws -> StoryScript {
        guard let start = raw.firstIndex(of: "{"), let end = raw.lastIndex(of: "}"), start < end else {
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

    private static func check(_ resp: URLResponse, _ data: Data) throws {
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            throw LLMError.http(code, String(data: data.prefix(300), encoding: .utf8) ?? "")
        }
    }
}
