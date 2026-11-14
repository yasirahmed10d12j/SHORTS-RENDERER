import Foundation

/// ElevenLabs text-to-speech client.
/// Uses the /with-timestamps endpoint so one call returns BOTH the audio and
/// per-character alignment -> exact word timings (replaces the kit's timing.py,
/// and is more accurate than on-device SFSpeechRecognizer).
enum ElevenLabs {
    static let base = "https://api.elevenlabs.io"
    /// Flash v2.5: fastest + cheapest, supports timestamps, good for narration.
    static let defaultModel = "eleven_flash_v2_5"
    static let models = ["eleven_flash_v2_5", "eleven_turbo_v2_5", "eleven_multilingual_v2"]

    static func voices(key: String) async throws -> [ElevenVoice] {
        var req = URLRequest(url: URL(string: "\(base)/v1/voices")!)
        req.setValue(key, forHTTPHeaderField: "xi-api-key")
        let (data, resp) = try await URLSession.shared.data(for: req)
        try check(resp, data)
        struct Resp: Decodable { let voices: [ElevenVoice] }
        return try JSONDecoder().decode(Resp.self, from: data).voices
    }

    static func speech(text: String, key: String, voiceId: String, model: String = defaultModel) async throws -> ElevenResult {
        let url = URL(string: "\(base)/v1/text-to-speech/\(voiceId)/with-timestamps")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(key, forHTTPHeaderField: "xi-api-key")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 120
        let body: [String: Any] = [
            "text": text,
            "model_id": model,
            "voice_settings": [
                "stability": 0.5,
                "similarity_boost": 0.75,
                "style": 0.0,
                "use_speaker_boost": true,
            ],
            "output_format": "mp3_44100_128",
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        try check(resp, data)
        let parsed = try JSONDecoder().decode(TimestampsResponse.self, from: data)
        guard let audio = Data(base64Encoded: parsed.audioBase64) else { throw ElevenError.noAudio }
        let words = wordsFromAlignment(parsed.alignment)
        return ElevenResult(audio: audio, words: words, duration: parsed.alignment?.characterEndTimes.last ?? 0)
    }

    // MARK: - word timings from character alignment

    static func wordsFromAlignment(_ a: TimestampsResponse.Alignment?) -> [ElevenWord] {
        guard let a else { return [] }
        var words: [ElevenWord] = []
        var cur = ""
        var curStart: Double = 0
        let n = min(a.characters.count, a.characterStartTimes.count, a.characterEndTimes.count)
        for i in 0..<n {
            let ch = a.characters[i]
            if ch == " " || ch == "\n" || ch == "\r" {
                if !cur.isEmpty {
                    words.append(ElevenWord(word: cur, start: curStart, end: a.characterEndTimes[i - 1]))
                    cur = ""
                }
            } else if cur.isEmpty {
                cur = ch
                curStart = a.characterStartTimes[i]
            } else {
                cur += ch
            }
        }
        if !cur.isEmpty, let lastEnd = a.characterEndTimes.last {
            words.append(ElevenWord(word: cur, start: curStart, end: lastEnd))
        }
        return words
    }

    private static func check(_ resp: URLResponse, _ data: Data) throws {
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            throw ElevenError.http(code, String(data: data.prefix(300), encoding: .utf8) ?? "")
        }
    }
}

struct ElevenVoice: Identifiable, Decodable {
    let voiceId: String
    let name: String
    var id: String { voiceId }
    enum CodingKeys: String, CodingKey { case voiceId = "voice_id"; case name }
}

struct ElevenWord: Codable {
    let word: String
    let start: Double
    let end: Double
}

struct ElevenResult {
    let audio: Data // MP3 bytes
    let words: [ElevenWord]
    let duration: Double
}

struct TimestampsResponse: Decodable {
    let audioBase64: String
    let alignment: Alignment?

    enum CodingKeys: String, CodingKey {
        case audioBase64 = "audio_base64"
        case alignment
    }

    struct Alignment: Decodable {
        let characters: [String]
        let characterStartTimes: [Double]
        let characterEndTimes: [Double]

        enum CodingKeys: String, CodingKey {
            case characters
            case characterStartTimes = "character_start_times_seconds"
            case characterEndTimes = "character_end_times_seconds"
        }
    }
}

enum ElevenError: Error, LocalizedError {
    case badURL, noAudio, http(Int, String)

    var errorDescription: String? {
        switch self {
        case .badURL: return "ElevenLabs URL galat hai."
        case .noAudio: return "ElevenLabs se audio nahi mila."
        case .http(let code, let msg): return "ElevenLabs API error \(code): \(msg)"
        }
    }
}
