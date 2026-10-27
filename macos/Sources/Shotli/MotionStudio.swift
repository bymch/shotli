import AppKit
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
        }
    }

    func rebuild() {
        plate = nil
        backdrop = nil
        publish()
    }

    func togglePlay() {
        if !settings.loops, time >= settings.clampedDuration - 0.02 {
            time = 0
        }
        playing.toggle()
        publish()
    }

    func scrub(to value: Double) {
        time = min(settings.clampedDuration, max(0, value))
        publish()
    }

    func tick() {
        guard playing, !exporting else { return }
        let duration = settings.clampedDuration
        time += 1.0 / Double(MotionFormat.fps)
        if settings.loops {
            if time >= duration { time = time.truncatingRemainder(dividingBy: duration) }
        } else if time >= duration {
            time = duration
            playing = false
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
        exporting = true
        playing = false
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

    var body: some View {
        VStack(spacing: 12) {
            header
            preview
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            controls
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

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ForEach(MotionPreset.allCases) { preset in
                    presetButton(preset)
                }
            }
            Text(session.settings.preset.detail)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 16) {
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
                slider("Duration", value: durationBinding, range: 2.0...8.0, label: "\(Int(session.settings.duration.rounded()))s")
                slider("Movement", value: intensityBinding, range: 0.0...1.0, label: "\(Int((session.settings.intensity * 100).rounded()))%")
                Toggle(isOn: loopBinding) {
                    Text("Loop")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ShotliGlass.ink)
                }
                .toggleStyle(.checkbox)
                .fixedSize()
                .help("Repeat without a jump")
            }
            if reduceMotion {
                Text("The preview stays still until you press play. Export still writes the motion.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .shotliGlass(.panel, radius: ShotliGlass.radiusPanel)
    }

    private func presetButton(_ preset: MotionPreset) -> some View {
        let on = session.settings.preset == preset
        return Button(action: {
            session.settings.preset = preset
            session.scrub(to: session.time)
        }) {
            Text(preset.title)
                .font(.system(size: 12, weight: on ? .semibold : .medium))
                .foregroundColor(on ? ShotliGlass.ink : .secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(on ? Color.white.opacity(0.78) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .stroke(on ? ShotliGlass.accent : Color.clear, lineWidth: on ? 1.5 : 0)
                        )
                )
        }
        .buttonStyle(PressFadeButtonStyle())
        .accessibilityLabel(preset.title)
        .accessibilityAddTraits(on ? .isSelected : AccessibilityTraits())
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
        .frame(minWidth: 140, maxWidth: .infinity)
    }

    private var durationBinding: Binding<Double> {
        Binding(
            get: { session.settings.duration },
            set: { value in
                session.settings.duration = value
                if session.time > value { session.scrub(to: value) }
                else { session.scrub(to: session.time) }
            }
        )
    }

    private var intensityBinding: Binding<Double> {
        Binding(
            get: { session.settings.intensity },
            set: { value in
                session.settings.intensity = value
                session.scrub(to: session.time)
            }
        )
    }

    private var loopBinding: Binding<Bool> {
        Binding(
            get: { session.settings.loops },
            set: { value in
                session.settings.loops = value
                session.scrub(to: min(session.time, session.settings.clampedDuration))
            }
        )
    }

    private func refresh() {
        session.hold(model)
        session.rebuild()
    }
}
