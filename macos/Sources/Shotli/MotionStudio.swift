import AppKit
import AVFoundation
import SwiftUI

final class MotionSession: ObservableObject {
    @Published var settings = MotionSettings()
    @Published var playing = false
    @Published var time: Double = 0
    @Published var frame: NSImage?
    @Published var exporting = false
    @Published var progress: Double = 0
    @Published var status: String?

    private var plate: MotionCompose.Plate?
    private var backdrop: CGImage?
    private var backdropSize = CGSize.zero
    private var timer: Timer?
    private var pictureKey = ""
    private var player: AVAudioPlayer?
    private var musicAccess = false

    func startClock() {
        timer?.invalidate()
        let clock = Timer(timeInterval: 1.0 / Double(MotionFormat.fps), repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(clock, forMode: .common)
        timer = clock
    }

    func stopClock() {
        timer?.invalidate()
        timer = nil
        releaseMusic()
    }

    func sync(_ model: EditorModel, key: String, autoplay: Bool) {
        let changed = key != pictureKey || plate == nil
        pictureKey = key
        if changed {
            plate = nil
            backdrop = nil
        }
        if frame == nil || changed {
            publish()
        }
        if autoplay, !playing, time == 0 {
            playing = true
            syncAudio(force: true)
        }
    }

    func rebuild() {
        plate = nil
        backdrop = nil
        publish()
    }

    func togglePlay() {
        if !settings.loops, time >= settings.outputDuration - 0.02 {
            time = 0
        }
        playing.toggle()
        syncAudio(force: true)
        publish()
    }

    func restart() {
        time = 0
        syncAudio(force: true)
        publish()
    }

    func scrub(to value: Double) {
        time = min(settings.outputDuration, max(0, value))
        syncAudio(force: true)
        publish()
    }

    func chooseMusic() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.mp3, .mpeg4Audio, .wav, .aiff]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "Background music"
        panel.prompt = "Use"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        setMusic(url)
    }

    func clearMusic() {
        releaseMusic()
        settings.music = nil
    }

    func tick() {
        guard playing, !exporting else { return }
        let duration = settings.outputDuration
        let previous = time
        time += 1.0 / Double(MotionFormat.fps)
        var wrapped = false
        if settings.loops {
            if time >= duration {
                time = time.truncatingRemainder(dividingBy: duration)
                wrapped = true
            }
        } else if time >= duration {
            time = duration
            playing = false
            wrapped = true
        }
        if wrapped || abs(time - previous) > 0.2 {
            syncAudio(force: true)
        } else {
            syncAudio(force: false)
        }
        publish()
    }

    func export(_ model: EditorModel) {
        guard !exporting, let picture = model.picture else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mpeg4Movie]
        panel.nameFieldStringValue = "shotli-motion.mp4"
        panel.title = "Export video"
        panel.directoryURL = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first
            ?? FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let crop = model.crop
        let style = model.style
        let annotations = model.annotations
        let settings = self.settings
        playing = false
        player?.pause()
        exporting = true
        progress = 0
        status = "Exporting…"
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try MotionExport.write(
                    picture: picture,
                    crop: crop,
                    style: style,
                    annotations: annotations,
                    settings: settings,
                    to: url,
                    progress: { value in
                        DispatchQueue.main.async { self.progress = value }
                    }
                )
                DispatchQueue.main.async {
                    self.exporting = false
                    self.progress = 1
                    self.status = "Saved \(url.lastPathComponent)"
                    model.notice = "Saved \(url.lastPathComponent)"
                }
            } catch {
                DispatchQueue.main.async {
                    self.exporting = false
                    self.status = error.localizedDescription
                }
            }
        }
    }

    private func setMusic(_ url: URL) {
        releaseMusic()
        settings.music = url
        musicAccess = url.startAccessingSecurityScopedResource()
        prepareAudio()
        syncAudio(force: true)
    }

    private func prepareAudio() {
        guard let url = settings.music else {
            player = nil
            return
        }
        player = try? AVAudioPlayer(contentsOf: url)
        player?.prepareToPlay()
    }

    private func releaseMusic() {
        player?.stop()
        player = nil
        if musicAccess, let url = settings.music {
            url.stopAccessingSecurityScopedResource()
        }
        musicAccess = false
    }

    private func syncAudio(force: Bool) {
        guard let player else { return }
        if !playing || time >= player.duration - 0.05 {
            if player.isPlaying { player.pause() }
            if force { player.currentTime = min(time, max(0, player.duration - 0.01)) }
            return
        }
        let drift = abs(player.currentTime - time)
        if force || drift > 0.3 || !player.isPlaying {
            player.currentTime = time
            player.play()
        }
    }

    private func publish() {
        guard let modelPicture = currentPicture else {
            frame = nil
            return
        }
        if plate == nil {
            plate = MotionCompose.plate(
                picture: modelPicture.picture,
                crop: modelPicture.crop,
                style: modelPicture.style,
                annotations: modelPicture.annotations
            )
            backdrop = nil
        }
        guard let plate else { return }
        let pose = MotionTimeline.pose(settings: settings, time: time)
        let output = MotionFormat.previewSize
        guard let rendered = MotionCompose.frame(
            plate: plate,
            background: plate.style.background,
            pose: pose,
            output: output,
            backdrop: backdropSize == output ? backdrop : nil
        ) else { return }
        backdrop = rendered.backdrop
        backdropSize = output
        frame = NSImage(cgImage: rendered.image, size: NSSize(width: rendered.image.width, height: rendered.image.height))
    }

    private struct RenderInput {
        var picture: LoadedPicture
        var crop: CGRect?
        var style: ShotliStyle
        var annotations: [Annotation]
    }

    private var currentPicture: RenderInput?
    func hold(_ model: EditorModel) {
        guard let picture = model.picture else {
            currentPicture = nil
            return
        }
        currentPicture = RenderInput(picture: picture, crop: model.crop, style: model.style, annotations: model.annotations)
    }
}

struct MotionStudio: View {
    @ObservedObject var model: EditorModel
    var onClose: () -> Void
    @StateObject private var session = MotionSession()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showAdjust = false

    var body: some View {
        VStack(spacing: 12) {
            header
            HStack(alignment: .top, spacing: 12) {
                presets
                    .frame(width: 200)
                    .frame(maxHeight: .infinity)
                VStack(spacing: 10) {
                    preview
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    transport
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1)
                inspector
                    .frame(width: 248)
                    .frame(maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, ShotliGlass.pageInset)
        .padding(.top, 28)
        .padding(.bottom, ShotliGlass.pageInset)
        .onAppear {
            session.hold(model)
            session.startClock()
            session.sync(model, key: pictureKey, autoplay: !reduceMotion)
        }
        .onDisappear { session.stopClock() }
        .onChange(of: model.style) { _ in refresh() }
        .onChange(of: model.annotations) { _ in refresh() }
        .onChange(of: model.crop) { _ in refresh() }
        .onChange(of: pictureKey) { _ in
            session.hold(model)
            session.rebuild()
        }
        .onExitCommand(perform: onClose)
    }

    private var pictureKey: String {
        guard let picture = model.picture else { return "" }
        return "\(picture.width)x\(picture.height)-\(picture.name)"
    }

    private var showsEdges: Bool {
        !session.settings.loops
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: onClose) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Editor")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(ShotliGlass.ink)
                .padding(.horizontal, 10)
                .frame(height: ShotliGlass.controlHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressFadeButtonStyle())
            .help("Back to the editor")
            .accessibilityLabel("Back to the editor")
            Text("Motion")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(ShotliGlass.ink)
            Spacer()
            if session.exporting {
                Text("Exporting \(Int((session.progress * 100).rounded()))%")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            } else if let status = session.status {
                Text(status)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Button(action: { session.export(model) }) {
                HStack(spacing: 6) {
                    Image(systemName: "film")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Export video")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(ShotliGlass.ink)
                .padding(.horizontal, 12)
                .frame(height: ShotliGlass.controlHeight)
                .shotliCapsuleChip()
            }
            .buttonStyle(PressFadeButtonStyle())
            .disabled(session.exporting || model.picture == nil)
            .help("Export a 1080p MP4")
            .accessibilityLabel("Export video")
        }
        .padding(.horizontal, 8)
        .frame(height: 52)
        .shotliGlass(.compact, radius: ShotliGlass.radiusBar)
    }

    private var presets: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Presets")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(MotionPreset.allCases) { preset in
                        presetButton(preset)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxHeight: .infinity, alignment: .top)
        .shotliGlass(.panel, radius: ShotliGlass.radiusPanel)
    }

    private func presetButton(_ preset: MotionPreset) -> some View {
        let on = session.settings.preset == preset
        return Button(action: {
            session.settings.preset = preset
            session.scrub(to: session.time)
        }) {
            VStack(alignment: .leading, spacing: 2) {
                Text(preset.title)
                    .font(.system(size: 13, weight: on ? .semibold : .medium))
                    .foregroundColor(ShotliGlass.ink)
                Text(preset.detail)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(on ? Color.white.opacity(0.78) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(on ? ShotliGlass.accent : Color.clear, lineWidth: on ? 1.5 : 0)
                    )
            )
        }
        .buttonStyle(PressFadeButtonStyle())
        .accessibilityLabel("\(preset.title). \(preset.detail)")
        .accessibilityAddTraits(on ? .isSelected : AccessibilityTraits())
    }

    private var preview: some View {
        ZStack {
            if let frame = session.frame {
                Image(nsImage: frame)
                    .resizable()
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("The picture isn't ready to animate.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: ShotliGlass.radiusPanel, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ShotliGlass.radiusPanel, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .accessibilityLabel("Motion preview")
    }

    private var transport: some View {
        HStack(spacing: 10) {
            Button(action: session.restart) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(ShotliGlass.ink)
                    .frame(width: 32, height: 32)
                    .shotliRoundedChip(radius: 10)
            }
            .buttonStyle(PressFadeButtonStyle())
            .help("Restart")
            .accessibilityLabel("Restart")
            Button(action: session.togglePlay) {
                Image(systemName: session.playing ? "pause.fill" : "play.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(ShotliGlass.ink)
                    .frame(width: 36, height: 32)
                    .shotliRoundedChip(radius: 10)
            }
            .buttonStyle(PressFadeButtonStyle())
            .help(session.playing ? "Pause" : "Play")
            .accessibilityLabel(session.playing ? "Pause" : "Play")
            Text(clock(session.time))
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
                .foregroundColor(ShotliGlass.ink)
                .frame(width: 42, alignment: .trailing)
            Slider(
                value: Binding(
                    get: { session.time },
                    set: { session.scrub(to: $0) }
                ),
                in: 0...session.settings.outputDuration
            )
            .accessibilityLabel("Timeline")
            Text(clock(session.settings.outputDuration))
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
                .foregroundColor(.secondary)
                .frame(width: 42, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .shotliGlass(.compact, radius: 16)
    }

    private var inspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                slider("Duration", value: durationBinding, range: 2.0...8.0, label: seconds(session.settings.duration))
                slider("Speed", value: speedBinding, range: 0.5...2.0, label: String(format: "%.1f×", session.settings.clampedSpeed))
                Toggle(isOn: loopBinding) {
                    Text("Loop")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ShotliGlass.ink)
                }
                .toggleStyle(.checkbox)
                .help("Repeat without a jump")
                if session.settings.preset == .reveal, session.settings.loops {
                    Text("Reveal fades in and out so the loop meets.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                music
                Button(action: { showAdjust.toggle() }) {
                    HStack {
                        Text("Adjust")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(ShotliGlass.ink)
                        Spacer()
                        Image(systemName: showAdjust ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressFadeButtonStyle())
                .accessibilityLabel(showAdjust ? "Hide adjustments" : "Show adjustments")
                if showAdjust {
                    slider("Movement", value: unitBinding(\.intensity), range: 0.0...1.0, label: percent(session.settings.intensity))
                    slider("Rotation", value: unitBinding(\.rotation), range: 0.0...1.0, label: percent(session.settings.rotation))
                    slider("Zoom", value: unitBinding(\.zoom), range: 0.0...1.0, label: percent(session.settings.zoom))
                    slider("Perspective", value: unitBinding(\.perspective), range: 0.0...1.0, label: percent(session.settings.perspective))
                    slider("Shadow", value: unitBinding(\.shadow), range: 0.0...1.0, label: percent(session.settings.shadow))
                    slider("Background", value: unitBinding(\.background), range: 0.0...1.0, label: percent(session.settings.background))
                    if showsEdges {
                        Toggle(isOn: flagBinding(\.entrance)) {
                            Text("Entrance")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(ShotliGlass.ink)
                        }
                        .toggleStyle(.checkbox)
                        .help("Ease in from rest")
                        Toggle(isOn: flagBinding(\.exit)) {
                            Text("Exit")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(ShotliGlass.ink)
                        }
                        .toggleStyle(.checkbox)
                        .help("Ease back to rest")
                    }
                }
                if reduceMotion {
                    Text("The preview stays still until you press play. Export still writes the motion.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .shotliGlass(.panel, radius: ShotliGlass.radiusPanel)
    }

    private var music: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Music")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                if session.settings.music != nil {
                    Button(action: session.clearMusic) {
                        Text("Clear")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(ShotliGlass.ink)
                    }
                    .buttonStyle(PressFadeButtonStyle())
                    .help("Remove the music")
                }
            }
            Button(action: session.chooseMusic) {
                HStack(spacing: 6) {
                    Image(systemName: "music.note")
                        .font(.system(size: 11, weight: .semibold))
                    Text(session.settings.music?.lastPathComponent ?? "Add music")
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 0)
                }
                .foregroundColor(ShotliGlass.ink)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .frame(maxWidth: .infinity)
                .shotliRoundedChip(radius: 10)
            }
            .buttonStyle(PressFadeButtonStyle())
            .help("Play a track under the animation. It is trimmed to the video.")
            .accessibilityLabel(session.settings.music == nil ? "Add music" : "Change music")
        }
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer(minLength: 8)
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundColor(ShotliGlass.ink)
            }
            Slider(value: value, in: range)
                .accessibilityLabel(title)
        }
    }

    private var durationBinding: Binding<Double> {
        Binding(
            get: { session.settings.duration },
            set: { value in
                session.settings.duration = value
                session.scrub(to: min(session.time, session.settings.outputDuration))
            }
        )
    }

    private var speedBinding: Binding<Double> {
        Binding(
            get: { session.settings.speed },
            set: { value in
                session.settings.speed = value
                session.scrub(to: min(session.time, session.settings.outputDuration))
            }
        )
    }

    private func unitBinding(_ keyPath: WritableKeyPath<MotionSettings, Double>) -> Binding<Double> {
        Binding(
            get: { session.settings[keyPath: keyPath] },
            set: { value in
                session.settings[keyPath: keyPath] = value
                session.scrub(to: session.time)
            }
        )
    }

    private var loopBinding: Binding<Bool> {
        Binding(
            get: { session.settings.loops },
            set: { value in
                session.settings.loops = value
                session.scrub(to: min(session.time, session.settings.outputDuration))
            }
        )
    }

    private func flagBinding(_ keyPath: WritableKeyPath<MotionSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { session.settings[keyPath: keyPath] },
            set: { value in
                session.settings[keyPath: keyPath] = value
                session.scrub(to: session.time)
            }
        )
    }

    private func clock(_ value: Double) -> String {
        let clamped = max(0, value)
        let minutes = Int(clamped) / 60
        let seconds = clamped - Double(minutes * 60)
        return String(format: "%d:%04.1f", minutes, seconds)
    }

    private func seconds(_ value: Double) -> String {
        if abs(value - value.rounded()) < 0.05 {
            return "\(Int(value.rounded()))s"
        }
        return String(format: "%.1fs", value)
    }

    private func percent(_ value: Double) -> String {
        "\(Int((min(1, max(0, value)) * 100).rounded()))%"
    }

    private func refresh() {
        session.hold(model)
        session.rebuild()
    }
}
