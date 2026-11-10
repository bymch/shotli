import AppKit
import AVFoundation
import ScreenCaptureKit
import SwiftUI

/// Records the microphone to an AAC file.
final class VoiceRecorder {
    private var recorder: AVAudioRecorder?

    var elapsed: Double { recorder?.currentTime ?? 0 }

    /// 0...1, for a level meter.
    var level: Float {
        guard let recorder, recorder.isRecording else { return 0 }
        recorder.updateMeters()
        let power = recorder.averagePower(forChannel: 0)
        return max(0, min(1, (power + 50) / 50))
    }

    func start(to url: URL) throws {
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 128_000,
        ]
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = true
        guard recorder.record() else {
            throw ScriptBuildError.export("Couldn't start the microphone.")
        }
        self.recorder = recorder
    }

    func stop() {
        recorder?.stop()
        recorder = nil
    }

    static func requestAccess(_ done: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            done(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async { done(granted) }
            }
        default:
            done(false)
        }
    }
}

/// Records one display to an H.264 movie with ScreenCaptureKit. Shotli's own windows are left out.
@available(macOS 12.3, *)
final class ScreenRecorder: NSObject, SCStreamOutput, SCStreamDelegate {
    private var stream: SCStream?
    private var writer: AVAssetWriter?
    private var input: AVAssetWriterInput?
    private var started = false
    private var failure: Error?
    private let queue = DispatchQueue(label: "co.uk.bymichael.shotli.screen-recorder")

    func start(displayID: CGDirectDisplayID, to url: URL) async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == displayID }) ?? content.displays.first else {
            throw ScriptBuildError.export("Couldn't find the screen to record.")
        }
        let own = content.applications.filter { $0.processID == getpid() }
        let filter = SCContentFilter(display: display, excludingApplications: own, exceptingWindows: [])
        var width = display.width
        var height = display.height
        if let mode = CGDisplayCopyDisplayMode(display.displayID), mode.pixelWidth > 0, mode.pixelHeight > 0 {
            width = mode.pixelWidth
            height = mode.pixelHeight
        }
        let shrink = min(1, Double(ScriptBuild.longestSide) / Double(max(width, height)))
        width = max(2, Int(Double(width) * shrink) / 2 * 2)
        height = max(2, Int(Double(height) * shrink) / 2 * 2)

        let config = SCStreamConfiguration()
        config.width = width
        config.height = height
        config.minimumFrameInterval = CMTime(value: 1, timescale: ScriptBuild.fps)
        config.showsCursor = true
        config.queueDepth = 6
        config.pixelFormat = kCVPixelFormatType_32BGRA

        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: max(4_000_000, width * height * 3),
                AVVideoExpectedSourceFrameRateKey: Int(ScriptBuild.fps),
                AVVideoMaxKeyFrameIntervalKey: Int(ScriptBuild.fps) * 2,
            ],
        ])
        input.expectsMediaDataInRealTime = true
        guard writer.canAdd(input) else { throw ScriptBuildError.export("Couldn't write the recording.") }
        writer.add(input)
        guard writer.startWriting() else {
            throw ScriptBuildError.export(writer.error?.localizedDescription ?? "Couldn't write the recording.")
        }
        self.writer = writer
        self.input = input

        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
        try await stream.startCapture()
        self.stream = stream
    }

    /// Stops and finishes the file. The last frame lasts until now, even if the screen sat still.
    func stop() async throws {
        if let stream { try? await stream.stopCapture() }
        stream = nil
        let end = CMClockGetTime(CMClockGetHostTimeClock())
        let ready: Bool = queue.sync {
            guard started, let writer, let input else { return false }
            writer.endSession(atSourceTime: end)
            input.markAsFinished()
            return true
        }
        guard let writer else { return }
        guard ready else {
            writer.cancelWriting()
            throw failure ?? ScriptBuildError.export("Nothing was recorded. Check Screen Recording is on for Shotli.")
        }
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            writer.finishWriting { done.resume() }
        }
        if writer.status != .completed {
            throw ScriptBuildError.export(writer.error?.localizedDescription ?? "Couldn't finish the recording.")
        }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let raw = attachments.first?[.status] as? Int,
              SCFrameStatus(rawValue: raw) == .complete,
              let writer, let input, writer.status == .writing else { return }
        if !started {
            writer.startSession(atSourceTime: sampleBuffer.presentationTimeStamp)
            started = true
        }
        if input.isReadyForMoreMediaData {
            input.append(sampleBuffer)
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        queue.async { self.failure = error }
    }
}

/// The small floating bar shown while the screen records. It is never in the recording.
final class RecordingPanel {
    private var panel: NSPanel?

    func show<Content: View>(on screen: NSScreen?, @ViewBuilder content: () -> Content) {
        close()
        let host = NSHostingView(rootView: content())
        host.layoutSubtreeIfNeeded()
        let size = host.fittingSize
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = host
        let frame = (screen ?? NSScreen.main)?.visibleFrame ?? .zero
        panel.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2, y: frame.maxY - size.height - 16))
        panel.orderFrontRegardless()
        self.panel = panel
    }

    func close() {
        panel?.orderOut(nil)
        panel = nil
    }
}
