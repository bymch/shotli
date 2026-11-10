import AppKit
import AVFoundation
import Foundation

enum MotionVerify {
    static func run() -> Int {
        do {
            try checkSeam()
            try checkAspects()
            try checkPlayback()
            try checkSoundtracks()
            try checkScriptBuild()
            print("motion verified")
            return 0
        } catch {
            fputs("motion verify failed: \(error)\n", stderr)
            return 1
        }
    }

    private static func checkSeam() throws {
        let picture = LoadedPicture(image: sampleScreenshot(), name: "Sample.png", scaled: false)
        var settings = MotionSettings()
        settings.loops = true
        settings.duration = 4
        settings.intensity = 1
        guard let plate = MotionCompose.plate(picture: picture, crop: nil, style: pictureStyle(), annotations: []) else {
            throw Failure("plate")
        }
        for preset in MotionPreset.allCases {
            settings.preset = preset
            try assertSeam(plate, settings, preset.title)
        }
        settings.preset = .orbit
        settings.speed = 1.5
        try assertSeam(plate, settings, "Orbit at 1.5×")
    }

    private static func assertSeam(_ plate: MotionCompose.Plate, _ settings: MotionSettings, _ name: String) throws {
        let start = try render(plate, settings, time: 0)
        let end = try render(plate, settings, time: settings.outputDuration)
        let moved = try render(plate, settings, time: settings.outputDuration * 0.25)
        if checksum(start) != checksum(end) {
            throw Failure("\(name) loop seam")
        }
        if checksum(start) == checksum(moved) {
            throw Failure("\(name) did not move")
        }
    }

    private static func checkAspects() throws {
        let wide = LoadedPicture(image: solid(900, 280, .white), name: "Wide.png", scaled: false)
        let tall = LoadedPicture(image: solid(280, 900, .white), name: "Tall.png", scaled: false)
        var style = pictureStyle()
        style.background = .color("#E10600")
        for picture in [wide, tall] {
            guard let plate = MotionCompose.plate(picture: picture, crop: nil, style: style, annotations: []) else {
                throw Failure("aspect plate")
            }
            var settings = MotionSettings()
            settings.preset = .drift
            settings.intensity = 1
            let image = try render(plate, settings, time: 0.4, output: CGSize(width: 640, height: 360))
            let corners = [(2, 2), (image.width - 3, 2), (2, image.height - 3), (image.width - 3, image.height - 3)]
            for corner in corners {
                let pixel = try pixel(image, x: corner.0, y: corner.1)
                if pixel.0 < 180 || pixel.1 > 80 || pixel.2 > 80 {
                    throw Failure("card left the \(picture.name) frame rgb \(pixel.0) \(pixel.1) \(pixel.2)")
                }
            }
            let middle = try pixel(image, x: image.width / 2, y: image.height / 2)
            if middle.0 > 200 && middle.1 < 40 {
                throw Failure("\(picture.name) card missing")
            }
        }
        var wallpaper = pictureStyle()
        wallpaper.background = .wallpaper(.dots)
        let picture = LoadedPicture(image: sampleScreenshot(), name: "Sample.png", scaled: false)
        guard let wallpaperPlate = MotionCompose.plate(picture: picture, crop: nil, style: wallpaper, annotations: []) else {
            throw Failure("wallpaper plate")
        }
        _ = try render(wallpaperPlate, MotionSettings(), time: 0)
    }

    private static func checkPlayback() throws {
        let picture = LoadedPicture(image: sampleScreenshot(), name: "Sample.png", scaled: false)
        var settings = MotionSettings()
        settings.preset = .focus
        settings.duration = 2
        settings.loops = true
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("shotli-motion-verify-\(UUID().uuidString).mp4")
        defer { try? FileManager.default.removeItem(at: url) }
        try MotionExport.write(
            picture: picture,
            crop: nil,
            style: pictureStyle(),
            annotations: [],
            settings: settings,
            to: url,
            output: CGSize(width: 320, height: 180),
            fps: 10,
            progress: { _ in }
        )
        let asset = AVURLAsset(url: url)
        let keys = ["duration", "tracks", "playable"]
        let ready = DispatchSemaphore(value: 0)
        asset.loadValuesAsynchronously(forKeys: keys) { ready.signal() }
        _ = ready.wait(timeout: .now() + 8)
        for key in keys {
            var error: NSError?
            if asset.statusOfValue(forKey: key, error: &error) != .loaded {
                throw Failure(error?.localizedDescription ?? "asset \(key)")
            }
        }
        guard asset.isPlayable else { throw Failure("file is not playable") }
        let seconds = CMTimeGetSeconds(asset.duration)
        if abs(seconds - 2) > 0.2 { throw Failure("duration \(seconds)") }
        guard let track = asset.tracks(withMediaType: .video).first else { throw Failure("no video track") }
        let natural = track.naturalSize
        if abs(natural.width - 320) > 1 || abs(natural.height - 180) > 1 {
            throw Failure("size \(natural.width)x\(natural.height)")
        }
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
        ])
        reader.add(output)
        guard reader.startReading(), output.copyNextSampleBuffer() != nil else {
            throw Failure("could not read a frame")
        }
    }

    private static func checkSoundtracks() throws {
        for track in Soundtrack.allCases {
            let started = Date()
            let audio = track.render()
            let rate = Soundtrack.sampleRate
            let seconds = Double(audio.left.count) / rate
            if seconds < Soundtrack.minimumLength { throw Failure("\(track.title) is \(seconds)s") }
            var peak: Float = 0
            for i in 0..<audio.left.count {
                let l = audio.left[i], r = audio.right[i]
                if !l.isFinite || !r.isFinite { throw Failure("\(track.title) has a bad sample") }
                peak = max(peak, abs(l), abs(r))
            }
            if peak > 0.95 || peak < 0.5 { throw Failure("\(track.title) peak \(peak)") }
            // Every second has sound, so no track goes quiet partway through a video.
            let window = Int(rate)
            for start in stride(from: 0, to: audio.left.count - window, by: window) {
                var sum: Float = 0
                for i in start..<(start + window) { sum += audio.left[i] * audio.left[i] + audio.right[i] * audio.right[i] }
                let rms = (sum / Float(window * 2)).squareRoot()
                if rms < 0.03 { throw Failure("\(track.title) quiet at \(start / window)s (\(rms))") }
            }
            print("  \(track.title): \(String(format: "%.1f", seconds))s, peak \(String(format: "%.2f", peak)), made in \(String(format: "%.2f", Date().timeIntervalSince(started)))s")
        }
        let picture = LoadedPicture(image: sampleScreenshot(), name: "Sample.png", scaled: false)
        var settings = MotionSettings()
        settings.duration = 2
        settings.music = try Soundtrack.glow.url()
        guard settings.soundtrack == .glow else { throw Failure("track not recognised from its file") }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("shotli-motion-music-\(UUID().uuidString).mp4")
        defer { try? FileManager.default.removeItem(at: url) }
        try MotionExport.write(picture: picture, crop: nil, style: pictureStyle(), annotations: [], settings: settings,
                               to: url, output: CGSize(width: 320, height: 180), fps: 10, progress: { _ in })
        let asset = AVURLAsset(url: url)
        let ready = DispatchSemaphore(value: 0)
        asset.loadValuesAsynchronously(forKeys: ["tracks", "duration"]) { ready.signal() }
        _ = ready.wait(timeout: .now() + 8)
        guard let audio = asset.tracks(withMediaType: .audio).first else { throw Failure("no music in the video") }
        if abs(CMTimeGetSeconds(audio.timeRange.duration) - 2) > 0.2 { throw Failure("music length \(CMTimeGetSeconds(audio.timeRange.duration))") }
        if settings.musicLevel(at: 2) > 0.001 || abs(settings.musicLevel(at: 0) - 0.8) > 0.001 { throw Failure("music fade") }
    }

    /// Two parts: the first has a 2s screen and a 3s voice, so its last frame holds; the second is a
    /// smaller 1.5s screen with no voice. The video should run 4.5s at the first part's size.
    private static func checkScriptBuild() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("shotli-script-verify-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let picture = LoadedPicture(image: sampleScreenshot(), name: "Sample.png", scaled: false)
        func screen(_ name: String, seconds: Double, size: CGSize) throws -> URL {
            var settings = MotionSettings()
            settings.duration = seconds
            let url = folder.appendingPathComponent(name)
            try MotionExport.write(picture: picture, crop: nil, style: pictureStyle(), annotations: [], settings: settings,
                                   to: url, output: size, fps: 30, progress: { _ in })
            return url
        }
        let first = try screen("one.mp4", seconds: 2, size: CGSize(width: 320, height: 180))
        let second = try screen("two.mp4", seconds: 2, size: CGSize(width: 240, height: 180))
        let voice = folder.appendingPathComponent("voice.wav")
        let rate = Soundtrack.sampleRate
        let tone = (0..<Int(3 * rate)).map { Float(sin(2 * Double.pi * 220 * Double($0) / rate) * 0.3) }
        try Soundtrack.write((tone, tone), to: voice)
        var part = ScriptPart()
        part.text = "Hello"
        if abs(ScriptBuild.seconds(of: voice) - 3) > 0.05 { throw Failure("voice length \(ScriptBuild.seconds(of: voice))") }
        let plan = try ScriptBuild.plan([
            ScriptBuild.Clip(screen: first, voice: voice),
            ScriptBuild.Clip(screen: second, voice: nil),
        ])
        if abs(plan.length - 5) > 0.1 { throw Failure("script plan length \(plan.length)") }
        if plan.size != CGSize(width: 320, height: 180) { throw Failure("script size \(plan.size)") }
        let out = folder.appendingPathComponent("built.mp4")
        try ScriptBuild.export(plan, to: out, progress: { _ in })
        let asset = AVURLAsset(url: out)
        let ready = DispatchSemaphore(value: 0)
        asset.loadValuesAsynchronously(forKeys: ["tracks", "duration"]) { ready.signal() }
        _ = ready.wait(timeout: .now() + 8)
        let seconds = CMTimeGetSeconds(asset.duration)
        if abs(seconds - 5) > 0.15 { throw Failure("built script video is \(seconds)s") }
        guard let audio = asset.tracks(withMediaType: .audio).first else { throw Failure("built script video has no voice") }
        if abs(CMTimeGetSeconds(audio.timeRange.duration) - 3) > 0.15 { throw Failure("voice runs \(CMTimeGetSeconds(audio.timeRange.duration))s") }
        guard let video = asset.tracks(withMediaType: .video).first else { throw Failure("built script video has no picture") }
        if abs(video.naturalSize.width - 320) > 1 || abs(video.naturalSize.height - 180) > 1 {
            throw Failure("built size \(video.naturalSize)")
        }
        // A frame inside the held stretch (2s to 3s) must be real picture, not black.
        let generator = AVAssetImageGenerator(asset: asset)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let held = try generator.copyCGImage(at: CMTime(seconds: 2.6, preferredTimescale: 600), actualTime: nil)
        let (r, g, b) = try pixel(held, x: held.width / 2, y: held.height / 2)
        if Int(r) + Int(g) + Int(b) < 30 { throw Failure("held frame is black") }
        print("  script build: \(String(format: "%.2f", seconds))s with a held frame")
    }

    private static func render(_ plate: MotionCompose.Plate, _ settings: MotionSettings, time: Double, output: CGSize = CGSize(width: 480, height: 270)) throws -> CGImage {
        let pose = MotionTimeline.pose(settings: settings, time: time)
        guard let frame = MotionCompose.frame(plate: plate, background: plate.style.background, pose: pose, output: output, backdrop: nil) else {
            throw Failure("frame")
        }
        return frame.image
    }

    private static func pictureStyle() -> ShotliStyle {
        ShotliStyle(
            padding: 48,
            radius: 22,
            shadow: 36,
            frame: .none,
            canvas: .auto,
            canvasWidth: 0,
            canvasHeight: 0,
            background: .gradient(from: "#5B6CFF", mid: "#8D7CFF", to: "#F2C4FF", angle: 160)
        )
    }

    private static func solid(_ width: Int, _ height: Int, _ color: NSColor) -> CGImage {
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(color.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }

    private static func checksum(_ image: CGImage) -> UInt64 {
        guard let cf = image.dataProvider?.data else { return 0 }
        let data = cf as Data
        var hash: UInt64 = 14_695_981_039_346_656_037
        let step = max(1, data.count / 5000)
        var index = 0
        while index < data.count {
            hash ^= UInt64(data[index])
            hash &*= 1_099_511_628_211
            index += step
        }
        return hash
    }

    private static func pixel(_ image: CGImage, x: Int, y: Int) throws -> (UInt8, UInt8, UInt8) {
        guard let data = image.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else { throw Failure("pixels") }
        let offset = y * image.bytesPerRow + x * 4
        guard offset + 2 < CFDataGetLength(data) else { throw Failure("pixel bounds") }
        return (bytes[offset], bytes[offset + 1], bytes[offset + 2])
    }

    private struct Failure: LocalizedError {
        var message: String
        init(_ message: String) { self.message = message }
        var errorDescription: String? { message }
    }
}
