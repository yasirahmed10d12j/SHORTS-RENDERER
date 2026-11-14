import AVFoundation
import CoreImage

/// Writes frames into an H.264 1080x1920 MP4 at 30 fps via AVAssetWriter.
/// Phase 1: video only. Phase 2 adds the voice/music/SFX audio track.
@MainActor
final class VideoWriter {
    private let writer: AVAssetWriter
    private let input: AVAssetWriterInput
    private let adaptor: AVAssetWriterInputPixelBufferAdaptor
    private let ciContext = CIContext()
    private let fps: CMTimeScale = 30

    init(url: URL) throws {
        try? FileManager.default.removeItem(at: url)
        writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 1080,
            AVVideoHeightKey: 1920,
            AVVideoCompressionPropertiesKey: [AVVideoQualityKey: 0.92],
        ])
        adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: 1080,
                kCVPixelBufferHeightKey as String: 1920,
            ])
        // The adaptor binds itself to the input at creation; adding only the input is enough
        // (and add(adaptor) has no overload on the newer SDKs).
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
    }

    func append(_ jpeg: Data, frame: Int) async throws {
        guard let ci = CIImage(data: jpeg) else { throw RenderError.badFrame }
        let attrs = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
        ] as CFDictionary
        var pixel: CVPixelBuffer?
        guard CVPixelBufferCreate(kCFAllocatorDefault, 1080, 1920, kCVPixelFormatType_32BGRA, attrs, &pixel) == kCVReturnSuccess,
              let pb = pixel else { throw RenderError.bufferFailed }
        ciContext.render(ci, to: pb)
        while !input.isReadyForMoreMediaData {
            try await Task.sleep(nanoseconds: 16_000_000)
        }
        let time = CMTime(value: CMTimeValue(frame), timescale: fps)
        guard adaptor.append(pb, withPresentationTime: time) else { throw RenderError.appendFailed }
    }

    func finish() async throws {
        input.markAsFinished()
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            writer.finishWriting { [writerStatus = writer.status, writerError = writer.error] in
                writerStatus == .completed
                    ? cont.resume()
                    : cont.resume(throwing: writerError ?? RenderError.writeFailed)
            }
        }
    }
}
