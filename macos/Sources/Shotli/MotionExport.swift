import AVFoundation
import CoreMedia
import CoreVideo
import Foundation

enum MotionExportError: LocalizedError {
    case unreadable
    case writer(String)

    var errorDescription: String? {
        switch self {
        case .unreadable:
            return "Couldn't render the animation."
        case .writer(let message):
            return message.isEmpty ? "Couldn't write the video." : message
        }
    }
}

/// Writes one video from `MotionCompose` frames. A later GIF export can call the same frame function.
enum MotionExport {
    static func write(
        picture: LoadedPicture,
        crop: CGRect?,
        style: ShotliStyle,
        annotations: [Annotation],
        settings: MotionSettings,
        to destination: URL,
        output: CGSize = MotionFormat.exportSize,
        fps: Int = MotionFormat.fps,
        progress: @escaping (Double) -> Void
    ) throws {
        let size = MotionCompose.evenSize(output)
        guard let plate = MotionCompose.plate(picture: picture, crop: crop, style: style, annotations: annotations) else {
            throw MotionExportError.unreadable
        }
        let frameCount = max(2, Int((settings.outputDuration * Double(fps)).rounded()))
        let silent = FileManager.default.temporaryDirectory.appendingPathComponent("shotli-motion-\(UUID().uuidString).mp4")
        let mixed = FileManager.default.temporaryDirectory.appendingPathComponent("shotli-motion-audio-\(UUID().uuidString).mp4")
        defer {
            try? FileManager.default.removeItem(at: silent)
            try? FileManager.default.removeItem(at: mixed)
        }
        try encode(plate: plate, background: style.background, settings: settings, frames: frameCount, fps: fps, size: size, to: silent, progress: progress)
        let finished: URL
        if let music = settings.music {
            let accessing = music.startAccessingSecurityScopedResource()
            defer { if accessing { music.stopAccessingSecurityScopedResource() } }
            try mix(video: silent, music: music, to: mixed)
            finished = mixed
        } else {
            finished = silent
        }
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: finished, to: destination)
    }

    private static func mix(video: URL, music: URL, to destination: URL) throws {
        let videoAsset = AVURLAsset(url: video)
        let musicAsset = AVURLAsset(url: music)
        try load(videoAsset)
        try load(musicAsset)
        guard let videoTrack = videoAsset.tracks(withMediaType: .video).first else {
            throw MotionExportError.writer("Couldn't read the video.")
        }
        guard let musicTrack = musicAsset.tracks(withMediaType: .audio).first else {
            throw MotionExportError.writer("That file has no audio.")
        }
        let composition = AVMutableComposition()
        guard let composedVideo = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let composedAudio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw MotionExportError.writer("Couldn't mix the music.")
        }
        let videoDuration = videoAsset.duration
        try composedVideo.insertTimeRange(CMTimeRange(start: .zero, duration: videoDuration), of: videoTrack, at: .zero)
        let audioDuration = CMTimeMinimum(videoDuration, musicTrack.timeRange.duration)
        try composedAudio.insertTimeRange(CMTimeRange(start: .zero, duration: audioDuration), of: musicTrack, at: .zero)
        guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw MotionExportError.writer("Couldn't mix the music.")
        }
        exporter.outputURL = destination
        exporter.outputFileType = .mp4
        let group = DispatchGroup()
        group.enter()
        exporter.exportAsynchronously { group.leave() }
        group.wait()
        if exporter.status != .completed {
            throw MotionExportError.writer(exporter.error?.localizedDescription ?? "Couldn't mix the music.")
        }
    }

    private static func load(_ asset: AVURLAsset) throws {
        let keys = ["tracks", "duration"]
        let ready = DispatchSemaphore(value: 0)
        asset.loadValuesAsynchronously(forKeys: keys) { ready.signal() }
        _ = ready.wait(timeout: .now() + 8)
        for key in keys {
            var error: NSError?
            if asset.statusOfValue(forKey: key, error: &error) != .loaded {
                throw MotionExportError.writer(error?.localizedDescription ?? "Couldn't read the audio.")
            }
        }
    }

    private static func encode(
        plate: MotionCompose.Plate,
        background: Background,
        settings: MotionSettings,
        frames: Int,
        fps: Int,
        size: CGSize,
        to url: URL,
        progress: @escaping (Double) -> Void
    ) throws {
        let width = Int(size.width)
        let height = Int(size.height)
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let video: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: max(1_500_000, width * height * 3),
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoMaxKeyFrameIntervalKey: fps,
                AVVideoExpectedSourceFrameRateKey: fps,
            ],
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: video)
        input.expectsMediaDataInRealTime = false
        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: attributes)
        guard writer.canAdd(input) else { throw MotionExportError.writer("This Mac can't write that video.") }
        writer.add(input)
        guard writer.startWriting() else {
            throw MotionExportError.writer(writer.error?.localizedDescription ?? "Couldn't start the video.")
        }
        writer.startSession(atSourceTime: .zero)
        var backdrop: CGImage?
        for index in 0..<frames {
            if !waitUntilReady(input) {
                writer.cancelWriting()
                throw MotionExportError.writer("The video encoder stalled.")
            }
            let time = Double(index) / Double(fps)
            let pose = MotionTimeline.pose(settings: settings, time: time)
            guard let rendered = MotionCompose.frame(plate: plate, background: background, pose: pose, output: size, backdrop: backdrop) else {
                writer.cancelWriting()
                throw MotionExportError.unreadable
            }
            backdrop = rendered.backdrop
            let buffer = try pixelBuffer(rendered.image, adaptor: adaptor, width: width, height: height)
            let stamp = CMTime(value: CMTimeValue(index), timescale: CMTimeScale(fps))
            if !adaptor.append(buffer, withPresentationTime: stamp) {
                writer.cancelWriting()
                throw MotionExportError.writer(writer.error?.localizedDescription ?? "Couldn't add a video frame.")
            }
            progress(Double(index + 1) / Double(frames))
        }
        input.markAsFinished()
        writer.endSession(atSourceTime: CMTime(value: CMTimeValue(frames), timescale: CMTimeScale(fps)))
        let group = DispatchGroup()
        group.enter()
        writer.finishWriting { group.leave() }
        group.wait()
        if writer.status != .completed {
            throw MotionExportError.writer(writer.error?.localizedDescription ?? "Couldn't finish the video.")
        }
    }

    private static func waitUntilReady(_ input: AVAssetWriterInput) -> Bool {
        var spins = 0
        while !input.isReadyForMoreMediaData {
            spins += 1
            if spins > 800 { return false }
            Thread.sleep(forTimeInterval: 0.005)
        }
        return true
    }

    private static func pixelBuffer(_ image: CGImage, adaptor: AVAssetWriterInputPixelBufferAdaptor, width: Int, height: Int) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        let pool = adaptor.pixelBufferPool
        let status: CVReturn
        if let pool {
            status = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
        } else {
            status = CVPixelBufferCreate(
                nil,
                width,
                height,
                kCVPixelFormatType_32BGRA,
                nil,
                &buffer
            )
        }
        guard status == kCVReturnSuccess, let buffer else { throw MotionExportError.writer("Couldn't allocate a video frame.") }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        let bitmap = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmap
        ) else { throw MotionExportError.writer("Couldn't draw a video frame.") }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return buffer
    }
}
