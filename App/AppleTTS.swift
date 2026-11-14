import AVFoundation
import Foundation

/// Uses iOS's built-in AVSpeechSynthesizer for voice generation — no external API needed.
enum AppleTTS {
    private static let synthesizer = AVSpeechSynthesizer()
    
    /// Generate voice audio files for scenes using iOS TTS.
    static func generateVoices(
        scenes: [StoryScene],
        folder: URL,
        onProgress: @escaping (Int, String) -> Void
    ) async throws -> ([String: Any], Bool) {
        var metas: [[String: Any]] = []
        var ok = true
        
        for scene in scenes {
            onProgress(scene.n, "synthesizing...")
            
            do {
                let audioData = try await synthesize(text: scene.narration)
                let file = folder.appendingPathComponent("scene-\(String(format: "%02d", scene.n)).wav")
                try audioData.write(to: file)
                let duration = Double(audioData.count) / 44100.0 * 2 // rough WAV estimate
                metas.append(["n": scene.n, "audio": file.lastPathComponent, "duration": duration])
                onProgress(scene.n, "✅ \(String(format: "%.1f", duration))s")
            } catch {
                onProgress(scene.n, "❌ \(error.localizedDescription)")
                ok = false
            }
        }
        
        return (metas, ok)
    }
    
    private static func synthesize(text: String) async throws -> Data {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return Data() }
        
        return try await withCheckedThrowingContinuation { continuation in
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            utterance.rate = 0.45
            
            let engine = AVAudioEngine()
            let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44100, channels: 1, interleaved: false)!
            
            var capturedBuffer: [Float] = []
            
            engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                let count = Int(buffer.frameLength)
                let ptr = buffer.floatChannelData?[0]
                if let ptr {
                    capturedBuffer.append(contentsOf: UnsafeBufferPointer(start: ptr, count: count))
                }
            }
            
            engine.prepare()
            try? engine.start()
            synthesizer.speak(utterance)
            
            let startTime = Date()
            while synthesizer.isSpeaking && Date().timeIntervalSince(startTime) < 60 {
                try? Task.sleep(nanoseconds: 100_000_000)
            }
            
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
            
            // Convert floats to PCM Int16
            var pcmData = Data()
            for sample in capturedBuffer {
                let intSample = Int16(min(max(Int(sample * 32767), -32768), 32767))
                pcmData.append(Data(bytes: &intSample, count: MemoryLayout<Int16>.size))
            }
            
            let wavHeader = createWAVHeader(size: pcmData.count)
            continuation.resume(returning: wavHeader + pcmData)
        }
    }
    
    private static func createWAVHeader(size: Int) -> Data {
        let byteRate = UInt32(44100 * 2)
        let chunkSize = UInt32(36 + size * 2)
        let dataSize = UInt32(size * 2)
        
        var header = Data()
        header.append([UInt8]("RIFF".utf8))
        header.append(chunkSize.bytes)
        header.append([UInt8]("WAVE".utf8))
        header.append([UInt8]("fmt ".utf8))
        header.append(UInt32(16).bytes)
        header.append(UInt16(1).bytes)
        header.append(UInt16(1).bytes)
        header.append(byteRate.bytes)
        header.append(UInt16(2).bytes)
        header.append(UInt16(16).bytes)
        header.append([UInt8]("data".utf8))
        header.append(dataSize.bytes)
        return header
    }
}

extension UInt32 {
    var bytes: [UInt8] {
        [UInt8(self & 0xFF), UInt8((self >> 8) & 0xFF), UInt8((self >> 16) & 0xFF), UInt8((self >> 24) & 0xFF)]
    }
}
extension UInt16 {
    var bytes: [UInt8] {
        [UInt8(self & 0xFF), UInt8((self >> 8) & 0xFF)]
    }
}
