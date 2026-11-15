import AVFoundation

/// Where the voiceover audio lives and how it maps onto the video timeline.
struct AudioPlan {
    struct Clip {
        let url: URL
        let offset: Double // seconds into the video
        let duration: Double
    }

    let totalDuration: Double
    let clips: [Clip]
}

/// Detects a saved voiceover (Script Maker scenes.json, or a single voice.mp3)
/// and muxes it into the rendered MP4 with AVAssetExportSession.
enum AudioMux {
    static func detect(docs: URL) -> AudioPlan? {
        // 1) Script Maker output: Documents/script/scenes.json + scene-XX.mp3
        let scenesURL = docs.appendingPathComponent("script/scenes.json")
        if let data = try? Data(contentsOf: scenesURL),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let arr = obj["scenes"] as? [[String: Any]] {
            var clips: [AudioPlan.Clip] = []
            var t = 0.0
            for sc in arr {
                guard let file = sc["audio"] as? String,
                      let d = (sc["duration"] as? NSNumber)?.doubleValue, d > 0 else { continue }
                let url = docs.appendingPathComponent("script/" + file)
                guard FileManager.default.fileExists(atPath: url.path) else { continue }
                clips.append(AudioPlan.Clip(url: url, offset: t, duration: d))
                t += d
            }
            if !clips.isEmpty { return AudioPlan(totalDuration: t, clips: clips) }
        }

        // 2) Voice tab output: Documents/voice.mp3 (+ voice.json with word timings)
        let voice = docs.appendingPathComponent("voice.mp3")
        if FileManager.default.fileExists(atPath: voice.path) {
            let d = duration(of: voice)
            if d > 0 { return AudioPlan(totalDuration: d, clips: [AudioPlan.Clip(url: voice, offset: 0, duration: d)]) }
        }
        return nil
    }

    static func duration(of url: URL) -> Double {
        let a = AVURLAsset(url: url)
        let s = a.duration.seconds
        return (s.isFinite && s > 0) ? s : 0
    }

    /// Muxes the rendered video and the voice plan into outURL (MP4, audio as AAC).
    static func mux(video: URL, plan: AudioPlan, out: URL) async throws {
        let comp = AVMutableComposition()

        let vsrc = AVURLAsset(url: video)
        guard let vtrack = vsrc.tracks(withMediaType: .video).first else {
            throw fail("video track missing", nil)
        }
        let vcomp = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        guard let vcomp else { throw fail("composition video track", nil) }
        try vcomp.insertTimeRange(CMTimeRange(start: .zero, duration: vsrc.duration), of: vtrack, at: .zero)

        let acompTrack = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        guard let acomp = acompTrack else { throw fail("composition audio track", nil) }
        for clip in plan.clips {
            let m4a = try await toAAC(clip.url)
            let src = AVURLAsset(url: m4a)
            guard let atrack = src.tracks(withMediaType: .audio).first else { continue }
            let d = min(src.duration, CMTime(seconds: clip.duration, preferredTimescale: 600))
            try acomp.insertTimeRange(CMTimeRange(start: .zero, duration: d), of: atrack, at: CMTime(seconds: clip.offset, preferredTimescale: 600))
        }

        try? FileManager.default.removeItem(at: out)
        // Passthrough is fastest but frequently fails on device for AVMutableComposition
        // (works in simulator only) — fall back to a re-encode preset.
        do {
            try await exportSession(comp, out: out, preset: AVAssetExportPresetPassthrough)
        } catch {
            try? FileManager.default.removeItem(at: out)
            try await exportSession(comp, out: out, preset: AVAssetExportPresetHighestQuality)
        }
    }

    private static func exportSession(_ asset: AVAsset, out: URL, preset: String) async throws {
        guard let ex = AVAssetExportSession(asset: asset, presetName: preset) else {
            throw fail("export session (\(preset))", nil)
        }
        ex.outputURL = out
        ex.outputFileType = AVFileType.mp4
        ex.exportAsynchronously {}
        while ex.status == .waiting || ex.status == .exporting {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        if ex.status != .completed {
            throw fail("export (\(preset))", ex.error)
        }
    }

    /// MP3 is not allowed inside an .mp4 container — convert clips to AAC .m4a first.
    private static func toAAC(_ url: URL) async throws -> URL {
        let out = url.deletingPathExtension().appendingPathExtension("m4a")
        if FileManager.default.fileExists(atPath: out.path) {
            // re-export if the mp3 was regenerated after this m4a was made
            let mp3Mod = ((try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date) ?? .distantPast
            let m4aMod = ((try? FileManager.default.attributesOfItem(atPath: out.path))?[.modificationDate] as? Date) ?? .distantPast
            if m4aMod >= mp3Mod { return out }
            try? FileManager.default.removeItem(at: out)
        }
        do {
            guard let ex = AVAssetExportSession(asset: AVURLAsset(url: url), presetName: AVAssetExportPresetAppleM4A) else {
                throw fail("aac session", nil)
            }
            ex.outputURL = out
            ex.outputFileType = AVFileType.m4a
            ex.exportAsynchronously {}
            while ex.status == .waiting || ex.status == .exporting {
                try await Task.sleep(nanoseconds: 100_000_000)
            }
            if ex.status != .completed {
                throw fail("aac export", ex.error)
            }
        } catch {
            // Fallback: decode MP3 with AVAudioFile and write AAC manually
            // (AVAssetExportSession refuses MP3 sources on some iOS versions).
            try? FileManager.default.removeItem(at: out)
            try convertToAACViaAudioFile(url, out: out)
        }
        return out
    }

    /// MP3 -> AAC .m4a via AVAudioFile (no AVAssetExportSession involved).
    private static func convertToAACViaAudioFile(_ url: URL, out: URL) throws {
        let input = try AVAudioFile(forReading: url)
        let fmt = input.processingFormat
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: fmt.sampleRate,
            AVNumberOfChannelsKey: fmt.channelCount,
            AVEncoderBitRateKey: 128_000,
        ]
        let output = try AVAudioFile(forWriting: out, settings: settings)
        let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(fmt.sampleRate))!
        while input.framePosition < input.length {
            try input.read(into: buf)
            try output.write(from: buf)
        }
        if output.length == 0 { throw fail("aac encode empty", nil) }
    }

    private static func fail(_ step: String, _ error: Error?) -> Error {
        let desc = error?.localizedDescription ?? "unknown"
        return NSError(domain: "AudioMux", code: 1,
                       userInfo: [NSLocalizedDescriptionKey: "\(step): \(desc)"])
    }
}
