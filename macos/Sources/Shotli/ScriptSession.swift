import AppKit
import AVFoundation
import SwiftUI

/// Drives the Script Video window: editing parts, recording voice and screen takes, previewing, and building.
final class ScriptSession: ObservableObject {
    static let shared = ScriptSession()

    enum Take: Equatable { case voice, screen }

    enum Phase: Equatable {
        case idle
        /// The screen recorder waits for Start so you can set up the screen first.
        case ready
        case countdown(Int, Take)
        case recording(Take)
        case saving
    }

    @Published var project: ScriptProject?
    @Published var selection: String?
    @Published var phase: Phase = .idle
    @Published var elapsed: Double = 0
    @Published var level: Float = 0
    @Published var status: String?
    @Published var building = false
    @Published var buildProgress: Double = 0
    @Published var playVoiceWhileRecording = true
    @Published var stopWithVoice = true
    @Published var previewAll = false {
        didSet { if previewAll != oldValue { reloadPreview() } }
    }
    @Published var playing = false
    @Published var playTime: Double = 0
    @Published var previewLength: Double = 0
    @Published var hasPreview = false
    @Published var voicePlaying = false
    @Published var lastBuild: URL?

    let player = AVPlayer()

    private let store = ScriptStore.shared
    private let voice = VoiceRecorder()
    private var screenRecorder: AnyObject?
    private var clock: Timer?
    private var countdownTimer: Timer?
    private var guide: AVAudioPlayer?
    private var listener: AVAudioPlayer?
    private var hiddenWindows: [NSWindow] = []
    private let panel = RecordingPanel()
    private var saveWork: DispatchWorkItem?
    private var pendingFile: String?
    private var autoStop: DispatchWorkItem?
    private var recordingScreen: NSScreen?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var previewToken = 0

    init() {
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 10), queue: .main) { [weak self] time in
            guard let self else { return }
            let seconds = CMTimeGetSeconds(time)
            self.playTime = seconds.isFinite ? seconds : 0
        }
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: .main) { [weak self] note in
            guard let self, (note.object as? AVPlayerItem) === self.player.currentItem else { return }
            self.playing = false
            self.player.seek(to: .zero)
        }
    }

    // MARK: - Projects

    func open() {
        store.load()
        if project == nil {
            project = store.projects.first ?? store.create()
            selection = project?.parts.first?.id
        }
        reloadPreview()
    }

    func switchTo(_ next: ScriptProject) {
        guard phase == .idle else { return }
        flushSave()
        project = next
        selection = next.parts.first?.id
        lastBuild = nil
        status = nil
        reloadPreview()
    }

    func newScript() {
        switchTo(store.create())
    }

    func deleteScript() {
        guard let project, phase == .idle else { return }
        let alert = NSAlert()
        alert.messageText = "Delete \u{201C}\(project.title)\u{201D}?"
        alert.informativeText = "Its script and recordings go to the Bin. Videos you built stay where you saved them."
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        alert.buttons.first?.hasDestructiveAction = true
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        saveWork?.cancel()
        stopPreview()
        store.delete(project)
        self.project = nil
        switchTo(store.projects.first ?? store.create())
    }

    var part: ScriptPart? { project?.parts.first { $0.id == selection } }

    var partNumber: Int? {
        guard let project, let selection else { return nil }
        return project.parts.firstIndex { $0.id == selection }.map { $0 + 1 }
    }

    func url(_ name: String?) -> URL? {
        guard let name, let project else { return nil }
        return store.media(name, in: project.id)
    }

    func edit(_ change: (inout ScriptProject) -> Void) {
        guard var next = project else { return }
        change(&next)
        project = next
        scheduleSave()
    }

    private func editPart(_ id: String, _ change: (inout ScriptPart) -> Void) {
        edit { project in
            guard let index = project.parts.firstIndex(where: { $0.id == id }) else { return }
            change(&project.parts[index])
        }
    }

    func setText(_ text: String) {
        guard let id = selection else { return }
        editPart(id) { $0.text = text }
    }

    func setTitle(_ title: String) {
        edit { $0.title = title }
    }

    func select(_ id: String) {
        guard phase == .idle, id != selection else { return }
        selection = id
        stopVoicePreview()
        if !previewAll { reloadPreview() }
    }

    func addPart() {
        guard phase == .idle else { return }
        let part = ScriptPart()
        edit { $0.parts.append(part) }
        select(part.id)
    }

    func deletePart(_ id: String) {
        guard phase == .idle, let project, let index = project.parts.firstIndex(where: { $0.id == id }) else { return }
        let removed = project.parts[index]
        let hasWork = removed.voice != nil || removed.screen != nil || !removed.text.isEmpty
        if hasWork {
            let alert = NSAlert()
            alert.messageText = "Delete part \(index + 1)?"
            alert.informativeText = "Its script and recordings are removed."
            alert.addButton(withTitle: "Delete")
            alert.addButton(withTitle: "Cancel")
            alert.buttons.first?.hasDestructiveAction = true
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        store.discard(removed.voice, in: project.id)
        store.discard(removed.screen, in: project.id)
        edit { project in
            project.parts.remove(at: index)
            if project.parts.isEmpty { project.parts.append(ScriptPart()) }
        }
        if selection == id, let parts = self.project?.parts {
            selection = parts[min(index, parts.count - 1)].id
        }
        reloadPreview()
    }

    func movePart(_ id: String, by offset: Int) {
        edit { project in
            guard let index = project.parts.firstIndex(where: { $0.id == id }) else { return }
            let target = index + offset
            guard project.parts.indices.contains(target) else { return }
            project.parts.swapAt(index, target)
        }
        if previewAll { reloadPreview() }
    }

    private func scheduleSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.flushSave() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    func flushSave() {
        saveWork?.cancel()
        saveWork = nil
        if let project { store.save(project) }
    }

    // MARK: - Voice

    func recordVoice() {
        guard phase == .idle, part != nil else { return }
        stopPreview()
        stopVoicePreview()
        VoiceRecorder.requestAccess { [weak self] granted in
            guard let self else { return }
            guard granted else {
                self.microphoneAlert()
                return
            }
            self.startCountdown(.voice)
        }
    }

    private func beginVoice() {
        guard let project else { return }
        let name = "voice-\(UUID().uuidString.prefix(8)).m4a"
        do {
            try FileManager.default.createDirectory(at: store.folder(project.id), withIntermediateDirectories: true)
            try voice.start(to: store.media(name, in: project.id))
        } catch {
            phase = .idle
            status = error.localizedDescription
            return
        }
        pendingFile = name
        phase = .recording(.voice)
        startClock()
    }

    private func finishVoice(keep: Bool) {
        voice.stop()
        stopClock()
        guard let name = pendingFile, let project, let id = selection else {
            phase = .idle
            return
        }
        pendingFile = nil
        let url = store.media(name, in: project.id)
        let seconds = ScriptBuild.seconds(of: url)
        if keep, seconds > 0.3 {
            let old = part?.voice
            editPart(id) {
                $0.voice = name
                $0.voiceSeconds = seconds
            }
            store.discard(old, in: project.id)
            flushSave()
            status = nil
        } else {
            try? FileManager.default.removeItem(at: url)
        }
        phase = .idle
        reloadPreview()
    }

    func toggleVoicePreview() {
        if voicePlaying {
            stopVoicePreview()
            return
        }
        guard let url = url(part?.voice), let player = try? AVAudioPlayer(contentsOf: url) else { return }
        stopPreview()
        listener = player
        player.play()
        voicePlaying = true
        DispatchQueue.main.asyncAfter(deadline: .now() + player.duration + 0.1) { [weak self, weak player] in
            guard let self, let player, self.listener === player else { return }
            self.voicePlaying = false
        }
    }

    func stopVoicePreview() {
        listener?.stop()
        listener = nil
        voicePlaying = false
    }

    // MARK: - Screen

    func recordScreen() {
        guard phase == .idle, part != nil else { return }
        guard #available(macOS 12.3, *) else {
            status = "Recording the screen needs macOS 12.3 or later."
            return
        }
        guard CGPreflightScreenCaptureAccess() else {
            CGRequestScreenCaptureAccess()
            screenAlert()
            return
        }
        stopPreview()
        stopVoicePreview()
        recordingScreen = ScriptStudioWindow.shared.window?.screen ?? NSScreen.main
        hiddenWindows = NSApp.windows.filter { $0.isVisible && $0.styleMask.contains(.titled) && !($0 is NSPanel) }
        hiddenWindows.forEach { $0.orderOut(nil) }
        phase = .ready
        panel.show(on: recordingScreen) { RecordingHUD(session: self) }
    }

    /// Start pressed on the floating bar.
    func startScreen() {
        guard phase == .ready else { return }
        startCountdown(.screen)
    }

    private func beginScreen() {
        guard #available(macOS 12.3, *), let project else { return }
        let name = "screen-\(UUID().uuidString.prefix(8)).mov"
        let url = store.media(name, in: project.id)
        try? FileManager.default.createDirectory(at: store.folder(project.id), withIntermediateDirectories: true)
        let number = recordingScreen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        let displayID = number?.uint32Value ?? CGMainDisplayID()
        let recorder = ScreenRecorder()
        screenRecorder = recorder
        pendingFile = name
        Task {
            do {
                try await recorder.start(displayID: displayID, to: url)
                await MainActor.run { self.screenStarted() }
            } catch {
                await MainActor.run {
                    self.screenRecorder = nil
                    self.pendingFile = nil
                    try? FileManager.default.removeItem(at: url)
                    self.endScreenSession()
                    self.status = error.localizedDescription
                }
            }
        }
    }

    private func screenStarted() {
        phase = .recording(.screen)
        startClock()
        guard let part, let voiceURL = url(part.voice) else { return }
        if playVoiceWhileRecording, let player = try? AVAudioPlayer(contentsOf: voiceURL) {
            guide = player
            player.play()
        }
        if stopWithVoice, part.voiceSeconds > 0 {
            let work = DispatchWorkItem { [weak self] in self?.stop() }
            autoStop = work
            DispatchQueue.main.asyncAfter(deadline: .now() + part.voiceSeconds + 0.5, execute: work)
        }
    }

    private func finishScreen(keep: Bool) {
        guard #available(macOS 12.3, *), let recorder = screenRecorder as? ScreenRecorder else {
            endScreenSession()
            return
        }
        autoStop?.cancel()
        autoStop = nil
        guide?.stop()
        guide = nil
        stopClock()
        phase = .saving
        let name = pendingFile
        pendingFile = nil
        screenRecorder = nil
        Task {
            let problem: String?
            do {
                try await recorder.stop()
                problem = nil
            } catch {
                problem = error.localizedDescription
            }
            await MainActor.run {
                self.saveScreen(name: name, keep: keep && problem == nil)
                self.endScreenSession()
                if let problem { self.status = problem }
            }
        }
    }

    private func saveScreen(name: String?, keep: Bool) {
        guard let name, let project, let id = selection else { return }
        let url = store.media(name, in: project.id)
        let seconds = ScriptBuild.seconds(of: url)
        guard keep, seconds > 0.2 else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        let old = part?.screen
        editPart(id) {
            $0.screen = name
            $0.screenSeconds = seconds
        }
        store.discard(old, in: project.id)
        flushSave()
        status = nil
    }

    private func endScreenSession() {
        panel.close()
        phase = .idle
        NSApp.activate(ignoringOtherApps: true)
        hiddenWindows.forEach { $0.makeKeyAndOrderFront(nil) }
        hiddenWindows = []
        ScriptStudioWindow.shared.window?.makeKeyAndOrderFront(nil)
        reloadPreview()
    }

    // MARK: - Countdown and stop

    private func startCountdown(_ take: Take) {
        phase = .countdown(3, take)
        countdownTimer?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] timer in
            guard let self, case .countdown(let left, let take) = self.phase else {
                timer.invalidate()
                return
            }
            if left > 1 {
                self.phase = .countdown(left - 1, take)
                return
            }
            timer.invalidate()
            switch take {
            case .voice: self.beginVoice()
            case .screen: self.beginScreen()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        countdownTimer = timer
    }

    /// Stop keeps the take.
    func stop() {
        switch phase {
        case .recording(.voice): finishVoice(keep: true)
        case .recording(.screen): finishScreen(keep: true)
        case .countdown, .ready: cancel()
        default: break
        }
    }

    /// Cancel throws the take away.
    func cancel() {
        switch phase {
        case .countdown(_, let take):
            countdownTimer?.invalidate()
            countdownTimer = nil
            if take == .screen { endScreenSession() } else { phase = .idle }
        case .ready:
            endScreenSession()
        case .recording(.voice):
            finishVoice(keep: false)
        case .recording(.screen):
            finishScreen(keep: false)
        default:
            break
        }
    }

    private func startClock() {
        elapsed = 0
        let started = Date()
        clock?.invalidate()
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.elapsed = Date().timeIntervalSince(started)
            if self.phase == .recording(.voice) {
                self.level = self.voice.level
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        clock = timer
    }

    private func stopClock() {
        clock?.invalidate()
        clock = nil
        level = 0
    }

    // MARK: - Preview and build

    func reloadPreview() {
        stopPreview()
        previewToken += 1
        let token = previewToken
        let clips: [ScriptBuild.Clip]
        if let project {
            if previewAll {
                clips = ScriptBuild.clips(project)
            } else if let part, let screen = part.screen {
                clips = [ScriptBuild.Clip(screen: store.media(screen, in: project.id), voice: part.voice.map { store.media($0, in: project.id) })]
            } else {
                clips = []
            }
        } else {
            clips = []
        }
        guard !clips.isEmpty else {
            player.replaceCurrentItem(with: nil)
            hasPreview = false
            previewLength = 0
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let plan = try? ScriptBuild.plan(clips)
            DispatchQueue.main.async {
                guard token == self.previewToken else { return }
                guard let plan else {
                    self.player.replaceCurrentItem(with: nil)
                    self.hasPreview = false
                    return
                }
                let item = AVPlayerItem(asset: plan.composition)
                item.videoComposition = plan.video
                self.player.replaceCurrentItem(with: item)
                self.previewLength = plan.length
                self.playTime = 0
                self.hasPreview = true
            }
        }
    }

    func togglePlay() {
        guard hasPreview else { return }
        if playing {
            player.pause()
            playing = false
        } else {
            stopVoicePreview()
            if playTime >= previewLength - 0.05 { player.seek(to: .zero) }
            player.play()
            playing = true
        }
    }

    func seek(to seconds: Double) {
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        playTime = seconds
    }

    private func stopPreview() {
        player.pause()
        playing = false
    }

    func build() {
        guard let project, !building else { return }
        let clips = ScriptBuild.clips(project)
        guard !clips.isEmpty else {
            status = ScriptBuildError.nothing.localizedDescription
            return
        }
        flushSave()
        stopPreview()
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mpeg4Movie]
        panel.nameFieldStringValue = "\(Self.safeName(project.title)).mp4"
        panel.title = "Build video"
        panel.prompt = "Build"
        panel.directoryURL = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        let skipped = project.parts.count - clips.count
        building = true
        buildProgress = 0
        status = nil
        lastBuild = nil
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let plan = try ScriptBuild.plan(clips)
                try ScriptBuild.export(plan, to: destination) { value in
                    DispatchQueue.main.async { self.buildProgress = value }
                }
                DispatchQueue.main.async {
                    self.building = false
                    self.lastBuild = destination
                    let note = skipped > 0 ? " \(skipped) part\(skipped == 1 ? "" : "s") without a screen recording left out." : ""
                    self.status = "Saved \(destination.lastPathComponent).\(note)"
                }
            } catch {
                DispatchQueue.main.async {
                    self.building = false
                    self.status = error.localizedDescription
                }
            }
        }
    }

    func revealBuild() {
        guard let lastBuild else { return }
        NSWorkspace.shared.activateFileViewerSelecting([lastBuild])
    }

    static func safeName(_ title: String) -> String {
        let cleaned = title.components(separatedBy: CharacterSet(charactersIn: "/:\\")).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Script video" : cleaned
    }

    // MARK: - Permissions

    private func microphoneAlert() {
        let alert = NSAlert()
        alert.messageText = "Turn on the microphone for Shotli"
        alert.informativeText = "Shotli needs the microphone to record your voice. In Privacy & Security, open Microphone and turn Shotli on."
        alert.addButton(withTitle: "Open Microphone Settings")
        alert.addButton(withTitle: "Not Now")
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }

    private func screenAlert() {
        let alert = NSAlert()
        alert.messageText = "Turn on Screen Recording for Shotli"
        alert.informativeText = "In Screen & System Audio Recording, turn Shotli on. Then quit Shotli, open it again, and record the screen."
        alert.addButton(withTitle: "Open Screen Recording Settings")
        alert.addButton(withTitle: "Not Now")
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}

enum ScriptTime {
    static func format(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
