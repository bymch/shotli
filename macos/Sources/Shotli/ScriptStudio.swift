import AppKit
import AVFoundation
import SwiftUI

/// The Script Video window. One window, kept for the life of the app.
final class ScriptStudioWindow {
    static let shared = ScriptStudioWindow()

    private(set) var window: NSWindow?

    func show() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1240, height: 780),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "Script Video"
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isReleasedWhenClosed = false
            window.minSize = NSSize(width: 1040, height: 660)
            window.contentView = NSHostingView(rootView: ScriptStudio())
            window.center()
            window.setFrameAutosaveName("ShotliScriptVideo")
            self.window = window
        }
        window?.makeKeyAndOrderFront(nil)
    }
}

struct ScriptStudio: View {
    @ObservedObject private var session = ScriptSession.shared
    @ObservedObject private var store = ScriptStore.shared
    @Environment(\.colorScheme) private var colorScheme
    private var ink: Color { ShotliGlass.ink(colorScheme) }

    var body: some View {
        VStack(spacing: 12) {
            header
            HStack(alignment: .top, spacing: 12) {
                partsList
                    .frame(width: 236)
                    .frame(maxHeight: .infinity)
                editor
                    .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
                    .layoutPriority(1)
                preview
                    .frame(width: 440)
                    .frame(maxHeight: .infinity)
            }
        }
        .padding(.horizontal, ShotliGlass.pageInset)
        .padding(.top, 30)
        .padding(.bottom, ShotliGlass.pageInset)
        .background(ShotliWorkspaceWash().ignoresSafeArea())
        .overlay {
            if isVoicePhase {
                Teleprompter(session: session)
            }
        }
        .shotliAppearance()
        .onAppear { session.open() }
        .onDisappear { session.flushSave() }
    }

    private var isVoicePhase: Bool {
        switch session.phase {
        case .countdown(_, .voice), .recording(.voice): return true
        default: return false
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "film")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(ShotliGlass.accent)
                .padding(.leading, 64)
            TextField("Script name", text: Binding(
                get: { session.project?.title ?? "" },
                set: { session.setTitle($0) }
            ))
            .textFieldStyle(.plain)
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(ink)
            .frame(maxWidth: 280)
            Menu {
                ForEach(store.projects) { project in
                    Button(project.title.isEmpty ? "Untitled script" : project.title) { session.switchTo(project) }
                }
                Divider()
                Button("New Script") { session.newScript() }
                Button("Delete This Script…") { session.deleteScript() }
                Divider()
                Button("Show Recordings in Finder") {
                    if let id = session.project?.id {
                        NSWorkspace.shared.open(store.folder(id))
                    }
                }
            } label: {
                Text("Scripts")
                    .font(.system(size: 12, weight: .medium))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .disabled(session.phase != .idle)
            Spacer()
            if session.building {
                Text("Building \(Int((session.buildProgress * 100).rounded()))%")
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
                    .foregroundColor(.secondary)
            } else if let status = session.status {
                Text(status)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if session.lastBuild != nil {
                    Button("Show in Finder") { session.revealBuild() }
                        .buttonStyle(.link)
                        .font(.system(size: 12, weight: .medium))
                }
            }
            if let project = session.project, project.length > 0 {
                Text("Video \(ScriptTime.format(project.length))")
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
                    .foregroundColor(.secondary)
            }
            Button(action: session.build) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Build video")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .frame(height: ShotliGlass.controlHeight)
                .background(Capsule().fill(ShotliGlass.accent))
                .opacity(canBuild ? 1 : 0.45)
            }
            .buttonStyle(PressFadeButtonStyle())
            .disabled(!canBuild)
            .help("Join every part into one MP4")
        }
        .padding(.horizontal, 8)
    }

    private var canBuild: Bool {
        !session.building && session.phase == .idle && !(session.project?.recordedParts.isEmpty ?? true)
    }

    // MARK: Parts

    private var partsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Parts")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(Array((session.project?.parts ?? []).enumerated()), id: \.element.id) { index, part in
                        partRow(part, number: index + 1, count: session.project?.parts.count ?? 0)
                    }
                }
            }
            Button(action: session.addPart) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Add part")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer(minLength: 0)
                }
                .foregroundColor(ink)
                .padding(.horizontal, 10)
                .frame(height: 32)
                .frame(maxWidth: .infinity)
                .shotliRoundedChip(radius: 10)
            }
            .buttonStyle(PressFadeButtonStyle())
            .disabled(session.phase != .idle)
        }
        .padding(12)
        .shotliGlass(.panel, radius: ShotliGlass.radiusPanel)
    }

    private func partRow(_ part: ScriptPart, number: Int, count: Int) -> some View {
        let on = session.selection == part.id
        let firstLine = part.text.split(whereSeparator: \.isNewline).first.map(String.init)?
            .trimmingCharacters(in: .whitespaces) ?? ""
        return Button(action: { session.select(part.id) }) {
            HStack(alignment: .top, spacing: 8) {
                Text("\(number)")
                    .font(.system(size: 11, weight: .bold))
                    .monospacedDigit()
                    .foregroundColor(on ? .white : ink)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(on ? ShotliGlass.accent : ShotliGlass.segment(colorScheme)))
                VStack(alignment: .leading, spacing: 4) {
                    Text(firstLine.isEmpty ? "Empty part" : firstLine)
                        .font(.system(size: 12, weight: on ? .semibold : .medium))
                        .foregroundColor(firstLine.isEmpty ? .secondary : ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 8) {
                        stepIcon("text.alignleft", done: !part.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        stepIcon("mic.fill", done: part.voice != nil)
                        stepIcon("video.fill", done: part.screen != nil)
                        Spacer(minLength: 0)
                        if part.length > 0 {
                            Text(ScriptTime.format(part.length))
                                .font(.system(size: 10, weight: .medium))
                                .monospacedDigit()
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(on ? ShotliGlass.selectedNav(colorScheme) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PressFadeButtonStyle())
        .contextMenu {
            Button("Move Up") { session.movePart(part.id, by: -1) }
                .disabled(number == 1)
            Button("Move Down") { session.movePart(part.id, by: 1) }
                .disabled(number == count)
            Divider()
            Button("Delete Part") { session.deletePart(part.id) }
        }
        .accessibilityLabel("Part \(number). \(firstLine.isEmpty ? "Empty" : firstLine)")
        .accessibilityAddTraits(on ? .isSelected : AccessibilityTraits())
    }

    private func stepIcon(_ symbol: String, done: Bool) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(done ? ShotliGlass.accent : Color.secondary.opacity(0.45))
    }

    // MARK: Editor

    private var editor: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let part = session.part, let number = session.partNumber {
                    HStack {
                        Text("Part \(number)")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(ink)
                        Spacer()
                        if let count = session.project?.parts.count, count > 1 {
                            Button(action: { session.deletePart(part.id) }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(PressFadeButtonStyle())
                            .help("Delete this part")
                            .accessibilityLabel("Delete part \(number)")
                        }
                    }
                    scriptStep(part)
                    voiceStep(part)
                    screenStep(part)
                }
            }
            .padding(16)
        }
        .shotliGlass(.panel, radius: ShotliGlass.radiusPanel)
    }

    private func stepTitle(_ number: Int, _ title: String, done: Bool) -> some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(done ? ShotliGlass.accent : ShotliGlass.segment(colorScheme))
                    .frame(width: 20, height: 20)
                if done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text("\(number)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(ink)
                }
            }
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(ink)
        }
    }

    private func scriptStep(_ part: ScriptPart) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            stepTitle(1, "Script", done: !part.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            ZStack(alignment: .topLeading) {
                TextEditor(text: Binding(get: { session.part?.text ?? "" }, set: { session.setText($0) }))
                    .font(.system(size: 15))
                    .padding(6)
                    .frame(minHeight: 150)
                if part.text.isEmpty {
                    Text("Write what you'll say in this part.")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .allowsHitTesting(false)
                }
            }
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(nsColor: .textBackgroundColor)))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(ShotliGlass.hairline(colorScheme), lineWidth: 1))
        }
    }

    private func voiceStep(_ part: ScriptPart) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            stepTitle(2, "Voice", done: part.voice != nil)
            HStack(spacing: 8) {
                if part.voice != nil {
                    actionButton(session.voicePlaying ? "stop.fill" : "play.fill",
                                 session.voicePlaying ? "Stop" : "Play voice", prominent: false) {
                        session.toggleVoicePreview()
                    }
                    Text(ScriptTime.format(part.voiceSeconds))
                        .font(.system(size: 12, weight: .medium))
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                    Spacer()
                    actionButton("mic.fill", "Record again", prominent: false, action: session.recordVoice)
                } else {
                    actionButton("mic.fill", "Record voice", prominent: true, action: session.recordVoice)
                    Spacer()
                }
            }
            Text("Your script shows as a teleprompter after a 3, 2, 1. Press Return to stop or Esc to throw the take away.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func screenStep(_ part: ScriptPart) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            stepTitle(3, "Screen", done: part.screen != nil)
            HStack(spacing: 8) {
                if part.screen != nil {
                    Image(systemName: "video.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text(ScriptTime.format(part.screenSeconds))
                        .font(.system(size: 12, weight: .medium))
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                    Spacer()
                    actionButton("record.circle", "Record again", prominent: false, action: session.recordScreen)
                } else {
                    actionButton("record.circle", "Record screen", prominent: part.voice != nil, action: session.recordScreen)
                    Spacer()
                }
            }
            Toggle(isOn: $session.playVoiceWhileRecording) {
                Text("Play my voice while I record")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(ink)
            }
            .toggleStyle(.checkbox)
            .disabled(part.voice == nil)
            Toggle(isOn: $session.stopWithVoice) {
                Text("Stop when my voice ends")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(ink)
            }
            .toggleStyle(.checkbox)
            .disabled(part.voice == nil)
            Text("Shotli hides itself and records the screen this window is on. Use the bar at the top of the screen to start and stop. Shotli's own windows never appear in the video.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func actionButton(_ symbol: String, _ title: String, prominent: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(prominent ? .white : ink)
            .padding(.horizontal, 14)
            .frame(height: ShotliGlass.controlHeight)
            .background {
                if prominent {
                    Capsule().fill(Color(nsColor: .systemRed))
                } else {
                    Capsule().fill(Color.clear).shotliCapsuleChip()
                }
            }
        }
        .buttonStyle(PressFadeButtonStyle())
        .disabled(session.phase != .idle || session.building)
    }

    // MARK: Preview

    private var preview: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Preview")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Picker("", selection: $session.previewAll) {
                    Text("This part").tag(false)
                    Text("Whole video").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 200)
            }
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(colorScheme == .dark ? 0.5 : 0.88))
                if session.hasPreview {
                    PlayerLayerView(player: session.player)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "video.slash")
                            .font(.system(size: 22))
                        Text(session.previewAll ? "Record the screen for a part to see the video here." : "Record the screen for this part to see it here.")
                            .font(.system(size: 12))
                            .multilineTextAlignment(.center)
                    }
                    .foregroundColor(.white.opacity(0.6))
                    .padding(24)
                }
            }
            .aspectRatio(16.0 / 10.0, contentMode: .fit)
            .onTapGesture { session.togglePlay() }
            HStack(spacing: 10) {
                Button(action: session.togglePlay) {
                    Image(systemName: session.playing ? "pause.fill" : "play.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(ink)
                        .frame(width: 32, height: 32)
                        .shotliCapsuleChip()
                }
                .buttonStyle(PressFadeButtonStyle())
                .disabled(!session.hasPreview)
                .accessibilityLabel(session.playing ? "Pause" : "Play")
                Text(ScriptTime.format(session.playTime))
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundColor(.secondary)
                Slider(value: Binding(get: { min(session.playTime, max(session.previewLength, 0.01)) },
                                      set: { session.seek(to: $0) }),
                       in: 0...max(session.previewLength, 0.01))
                    .disabled(!session.hasPreview)
                Text(ScriptTime.format(session.previewLength))
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundColor(.secondary)
            }
            if !session.previewAll, let note = timingNote {
                Text(note)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .shotliGlass(.panel, radius: ShotliGlass.radiusPanel)
    }

    private var timingNote: String? {
        guard let part = session.part, part.screen != nil, part.voice != nil else { return nil }
        let gap = part.voiceSeconds - part.screenSeconds
        if gap > 0.3 {
            return String(format: "Your voice runs %.1fs past the screen recording. The last frame holds until it ends.", gap)
        }
        if gap < -0.3 {
            return String(format: "The screen recording runs %.1fs past your voice.", -gap)
        }
        return nil
    }
}

/// Large script text while the microphone records.
private struct Teleprompter: View {
    @ObservedObject var session: ScriptSession

    var body: some View {
        ZStack {
            Color(white: 0.07).ignoresSafeArea()
            VStack(spacing: 22) {
                switch session.phase {
                case .countdown(let left, _):
                    Text("\(left)")
                        .font(.system(size: 96, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .monospacedDigit()
                    Text("Get ready to read")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                default:
                    HStack(spacing: 10) {
                        Circle().fill(Color.red).frame(width: 12, height: 12)
                        Text("Recording  \(ScriptTime.format(session.elapsed))")
                            .font(.system(size: 15, weight: .semibold))
                            .monospacedDigit()
                            .foregroundColor(.white)
                        LevelMeter(level: session.level)
                            .frame(width: 120, height: 6)
                    }
                }
                ScrollView {
                    Text((session.part?.text.isEmpty ?? true) ? "No script for this part. Say whatever you like." : (session.part?.text ?? ""))
                        .font(.system(size: 30, weight: .medium))
                        .lineSpacing(10)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 820)
                        .padding(.horizontal, 40)
                }
                .frame(maxHeight: 420)
                HStack(spacing: 12) {
                    Button("Cancel") { session.cancel() }
                        .keyboardShortcut(.cancelAction)
                    Button(action: session.stop) {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(session.phase != .recording(.voice))
                }
                .controlSize(.large)
            }
            .padding(40)
        }
    }
}

private struct LevelMeter: View {
    var level: Float

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.2))
                Capsule().fill(Color.green)
                    .frame(width: geo.size.width * CGFloat(level))
            }
        }
        .animation(.linear(duration: 0.05), value: level)
    }
}

/// The floating bar shown while the screen records.
struct RecordingHUD: View {
    @ObservedObject var session: ScriptSession

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                status
                Spacer()
                buttons
            }
            .frame(height: 36)
            if let text = session.part?.text, !text.isEmpty {
                ScrollView {
                    Text(text)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.85))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 64)
            }
        }
        .padding(14)
        .frame(width: 460)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.86))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder private var status: some View {
        let number = session.partNumber ?? 1
        switch session.phase {
        case .ready:
            VStack(alignment: .leading, spacing: 2) {
                Text("Part \(number): set up your screen")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Text("Press Start when you're ready.")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
            }
        case .countdown(let left, _):
            Text("Recording in \(left)…")
                .font(.system(size: 15, weight: .semibold))
                .monospacedDigit()
                .foregroundColor(.white)
        case .recording:
            HStack(spacing: 8) {
                Circle().fill(Color.red).frame(width: 10, height: 10)
                Text(timeLabel)
                    .font(.system(size: 15, weight: .semibold))
                    .monospacedDigit()
                    .foregroundColor(.white)
            }
        default:
            Text("Saving…")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
        }
    }

    private var timeLabel: String {
        let now = ScriptTime.format(session.elapsed)
        guard let voice = session.part?.voiceSeconds, voice > 0, session.part?.voice != nil else { return now }
        return "\(now) / voice \(ScriptTime.format(voice))"
    }

    @ViewBuilder private var buttons: some View {
        switch session.phase {
        case .ready:
            Button("Cancel") { session.cancel() }
            Button("Start") { session.startScreen() }
                .keyboardShortcut(.defaultAction)
        case .countdown:
            Button("Cancel") { session.cancel() }
        case .recording:
            Button("Discard") { session.cancel() }
            Button(action: session.stop) {
                Label("Stop", systemImage: "stop.fill")
            }
        default:
            EmptyView()
        }
    }
}

/// AVPlayerLayer without AVKit's controls.
struct PlayerLayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> PlayerHostView {
        let view = PlayerHostView()
        view.playerLayer.player = player
        return view
    }

    func updateNSView(_ view: PlayerHostView, context: Context) {
        view.playerLayer.player = player
    }

    final class PlayerHostView: NSView {
        let playerLayer = AVPlayerLayer()

        override init(frame: NSRect) {
            super.init(frame: frame)
            wantsLayer = true
            playerLayer.videoGravity = .resizeAspect
            layer?.addSublayer(playerLayer)
        }

        required init?(coder: NSCoder) { nil }

        override func layout() {
            super.layout()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            playerLayer.frame = bounds
            CATransaction.commit()
        }
    }
}
