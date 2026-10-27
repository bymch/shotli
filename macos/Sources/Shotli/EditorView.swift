import AppKit
import ObjectiveC
import SwiftUI
import UniformTypeIdentifiers

private let accent = ShotliGlass.accent
private let ink = ShotliGlass.ink
private let line = ShotliGlass.line
private let leftRailMin: CGFloat = 232
private let leftRailIdeal: CGFloat = 280
private let rightRailMin: CGFloat = 248
private let rightRailIdeal: CGFloat = 292
private let railInset: CGFloat = 14
private let thumbGap: CGFloat = 8
private let thumbHeight: CGFloat = 58

private enum BackgroundShelf: String, Identifiable {
    case gradient, glass, cosmic, mystic, desktop, abstract, earth, studio, scenes, linear, pattern

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gradient: return "Gradient"
        case .glass: return "Glass"
        case .cosmic: return "Cosmic"
        case .mystic: return "Mystic"
        case .desktop: return "Desktop"
        case .abstract: return "Abstract"
        case .earth: return "Earth"
        case .studio: return "Studio"
        case .scenes: return "Scenes"
        case .linear: return "Linear"
        case .pattern: return "Pattern"
        }
    }

    var wallpapers: [WallpaperID] {
        switch self {
        case .gradient: return WallpaperID.fields
        case .glass: return WallpaperID.glass
        case .cosmic: return WallpaperID.cosmic
        case .mystic: return WallpaperID.mystic
        case .desktop: return WallpaperID.desktop
        case .abstract: return WallpaperID.abstract
        case .earth: return WallpaperID.earth
        case .studio: return WallpaperID.backdrops
        case .scenes: return WallpaperID.scenes
        case .pattern: return WallpaperID.patterns
        case .linear: return []
        }
    }
}

private enum SceneThumbs {
    static var cache: [String: NSImage] = [:]
    static func image(_ id: WallpaperID) -> NSImage? {
        if let found = cache[id.rawValue] { return found }
        guard let rendered = renderSceneThumbnail(id) else { return nil }
        cache[id.rawValue] = rendered
        return rendered
    }
}

struct EditorView: View {
    @ObservedObject var model: EditorModel
    @State private var dropTarget = false
    @State private var didConfigure = false
    @State private var showMotion = false
    @State private var adjustingLight = false
    @State private var showTemplates = false
    @State private var backgroundShelf: BackgroundShelf?
    @State private var gradientPopover: String?
    @State private var expandedShelves: Set<String> = []
    @State private var didSeedLibrary = false
    @State private var hoveredPreset: String?
    @State private var showMagic = false
    @State private var magicColors: [MagicColor] = []
    @State private var magicBackgrounds: [MagicBackground] = []
    @State private var settingsSheet = false
    @ObservedObject private var settings = ShotliSettings.shared
    private let dockTools: [Tool] = [.select, .rect, .rectFill, .circle, .line, .arrow, .draw, .text, .marker, .pixelate, .blur, .crop]
    private let fontSizes: [CGFloat] = [18, 24, 32, 44]
    private let strokeWidths: [CGFloat] = [2, 4, 6, 8]

    var body: some View {
        VStack(spacing: 0) {
            if model.picture == nil {
                stage {
                    LibraryHome(onOpen: { model.openPanel() })
                }
            } else if showMotion {
                MotionStudio(model: model) { showMotion = false }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                studioBar
                HStack(alignment: .top, spacing: 12) {
                    leftRail
                        .frame(minWidth: leftRailMin, idealWidth: leftRailIdeal, maxWidth: leftRailIdeal)
                        .frame(maxHeight: .infinity)
                    VStack(spacing: 12) {
                        stage {
                            GeometryReader { geo in
                                CanvasView(model: model, viewport: geo.size)
                                    .frame(width: geo.size.width, height: geo.size.height)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: ShotliGlass.radiusPanel, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: ShotliGlass.radiusPanel, style: .continuous)
                                .stroke(Color.black.opacity(0.06), lineWidth: 1)
                                .allowsHitTesting(false)
                        )
                        Button(action: { showMotion = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "move.3d")
                                    .font(.system(size: 11, weight: .semibold))
                                Text("Motion")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(ink)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .shotliGlass(.compact, radius: 18)
                        }
                        .buttonStyle(PressFadeButtonStyle())
                        .fixedSize(horizontal: true, vertical: true)
                        .help("Open Motion Studio")
                        .accessibilityLabel("Motion")
                    }
                    .frame(minWidth: 360, idealWidth: 520, maxWidth: .infinity, maxHeight: .infinity)
                    .layoutPriority(1)
                    rightRail
                        .frame(minWidth: rightRailMin, idealWidth: rightRailIdeal, maxWidth: rightRailIdeal)
                        .frame(maxHeight: .infinity)
                }
                .padding(.horizontal, ShotliGlass.pageInset)
                .padding(.bottom, ShotliGlass.pageInset)
            }
        }
        .background(ShotliWorkspaceWash().ignoresSafeArea())
        .overlay {
            if showTemplates {
                TemplatesPanel(model: model, shot: shotImage) { showTemplates = false }
            }
            if let backgroundShelf {
                backgroundBrowser(backgroundShelf)
            }
        }
        .onAppear {
            refreshMagic()
            configureWindow()
            seedLibrary()
        }
        .onChange(of: pictureKey) { _ in
            refreshMagic()
            if model.picture == nil {
                showTemplates = false
                showMotion = false
                backgroundShelf = nil
                gradientPopover = nil
            }
        }
        .onChange(of: settings.openRequest) { _ in
            if model.picture == nil {
                LibraryModel.shared.showSettings()
            } else {
                settingsSheet = true
            }
        }
        .sheet(isPresented: $settingsSheet) {
            SettingsPane(onDone: { settingsSheet = false })
                .frame(width: 560, height: 640)
        }
    }

    private var studioBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                if model.picture != nil {
                    iconButton("chevron.left", help: "Library") { model.showLibrary() }
                    Button(action: { showTemplates = true }) {
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(LinearGradient(colors: [Color(nsColor: NSColor(hex: "#F78529")!), Color(nsColor: NSColor(hex: "#7A42E8")!)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 16, height: 16)
                            Text("Templates")
                                .font(.system(size: 13, weight: .medium))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                        .foregroundColor(ink)
                        .padding(.horizontal, 4)
                        .frame(height: 32)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Templates")
                }
            }
            .padding(.leading, 8)
            .frame(minWidth: leftRailMin, idealWidth: leftRailIdeal, maxWidth: leftRailIdeal, alignment: .leading)

            HStack(spacing: 8) {
                if model.picture != nil {
                    HStack(spacing: 2) {
                        iconButton("arrow.uturn.backward", help: "Undo (⌘Z)") { model.undo() }
                            .disabled(!model.canUndo)
                            .opacity(model.canUndo ? 1 : 0.35)
                        iconButton("arrow.uturn.forward", help: "Redo (⌘⇧Z)") { model.redo() }
                            .disabled(!model.canRedo)
                            .opacity(model.canRedo ? 1 : 0.35)
                    }
                    barCapsule("Start Over", help: "Clear this screenshot", action: { model.startOver() })
                    toolDock
                }
            }
            .frame(minWidth: 360, idealWidth: 520, maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .layoutPriority(1)

            if model.picture != nil {
                exportButton
                    .padding(.trailing, 8)
                    .frame(minWidth: rightRailMin, idealWidth: rightRailIdeal, maxWidth: rightRailIdeal, alignment: .trailing)
            } else {
                Color.clear
                    .frame(minWidth: rightRailMin, idealWidth: rightRailIdeal, maxWidth: rightRailIdeal)
                    .frame(height: 32)
            }
        }
        .frame(height: 52)
        .shotliGlass(.compact, radius: ShotliGlass.radiusBar)
        .padding(.horizontal, ShotliGlass.pageInset)
        .padding(.top, 34)
        .padding(.bottom, 8)
    }

    private var exportButton: some View {
        HStack(spacing: 0) {
            Button(action: { model.exportPNG() }) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Export")
                        .font(.system(size: 13, weight: .semibold))
                    Text("1× PNG")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .foregroundColor(ink)
                .padding(.leading, 12)
                .padding(.trailing, 8)
                .frame(height: 32)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressFadeButtonStyle())
            .disabled(model.picture == nil)
            .help("Export PNG (⌘S)")
            .accessibilityLabel("Export PNG")
            Rectangle()
                .fill(line)
                .frame(width: 1, height: 14)
            Button(action: { model.copyPNG() }) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(ink)
                    .frame(width: 34, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressFadeButtonStyle())
            .disabled(model.picture == nil)
            .help("Copy PNG (⌘C)")
            .accessibilityLabel("Copy PNG")
        }
        .shotliCapsuleChip()
    }

    private func barCapsule(_ title: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(ink)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .shotliCapsuleChip()
                .contentShape(Capsule())
        }
        .buttonStyle(PressFadeButtonStyle())
        .help(help)
        .accessibilityLabel(help)
    }

    private var leftRail: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                tabButton("Mockup", on: model.style.frame == .none) {
                    model.setFrame(.none)
                }
                tabButton("Frame", on: model.style.frame != .none) {
                    if model.style.frame == .none { model.setFrame(.browser) }
                }
            }
            .padding(3)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.black.opacity(0.05)))
            .padding(.horizontal, railInset)
            .padding(.vertical, 10)
            if model.style.frame != .none {
                HStack(spacing: 4) {
                    tabButton("Browser", on: model.style.frame == .browser) { model.setFrame(.browser) }
                    tabButton("Window", on: model.style.frame == .desktop) { model.setFrame(.desktop) }
                }
                .padding(3)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.black.opacity(0.05)))
                .padding(.horizontal, railInset)
                .padding(.bottom, 8)
            }
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 16) {
                    screenshotRow
                    backgroundGallery
                    magicPresetRow
                    mediaWell
                    styleGrid
                    borderSection
                    shadowSection
                    lightControl
                    visibilitySection
                    detailsSection
                    if showsText || showsStroke || showsPixel || showsBlur || model.selected != nil {
                        caption("Mark")
                        markControls
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, railInset)
                .padding(.bottom, 18)
            }
        }
        .shotliGlass(.panel, radius: ShotliGlass.radiusPanel)
    }

    private var rightRail: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    caption("Padding")
                    HStack(spacing: 2) {
                        densityButton("Tight", padding: 28)
                        densityButton("Even", padding: 72)
                        densityButton("Airy", padding: 120)
                    }
                    .padding(3)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.black.opacity(0.05)))
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Padding")
                }
                VStack(alignment: .leading, spacing: 8) {
                    zoomRow
                    tiltRow
                }
            }
            .padding(railInset)

            Divider()
                .padding(.horizontal, railInset)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("This picture")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(ink)
                    Spacer(minLength: 8)
                    Button("Fit") { model.fit() }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(accent)
                        .help("Fit the picture in the window (⌘0)")
                        .accessibilityLabel("Fit the picture in the window")
                }
                layoutCard(model.style)
            }
            .padding(.horizontal, railInset)
            .padding(.top, 14)

            caption("Layout presets")
                .padding(.horizontal, railInset)
                .padding(.top, 18)
                .padding(.bottom, 8)

            ScrollView(.vertical) {
                VStack(spacing: 12) {
                    ForEach(Presets.all) { preset in
                        presetCard(preset)
                    }
                }
                .padding(.horizontal, railInset)
                .padding(.bottom, 14)
            }
        }
        .shotliGlass(.panel, radius: ShotliGlass.radiusPanel)
    }

    private var zoomRow: some View {
        HStack(spacing: 8) {
            Text("Zoom")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(ink)
                .frame(width: 44, alignment: .leading)
            Slider(value: Binding(get: { model.zoomMultiplier }, set: { model.setZoomMultiplier($0) }), in: 0.4...2)
                .accessibilityLabel("Zoom")
            Text("\(Int((model.zoomMultiplier * 100).rounded()))%")
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .trailing)
                .accessibilityHidden(true)
        }
    }

    private var tiltRow: some View {
        let tilted = abs(model.style.tiltX) + abs(model.style.tiltY) > 0.5
        return HStack(spacing: 2) {
            Button(action: { model.setTilt(x: 8, y: -14) }) {
                Text("Tilt")
                    .font(.system(size: 12, weight: tilted ? .semibold : .medium))
                    .foregroundColor(tilted ? ink : .secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(tilted ? Color.white.opacity(0.78) : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(Color.black.opacity(tilted ? 0.06 : 0), lineWidth: 0.5)
                            )
                    )
            }
            .buttonStyle(PressFadeButtonStyle())
            .help("Tilt the picture")
            .accessibilityLabel("Tilt the picture")
            .accessibilityAddTraits(tilted ? .isSelected : AccessibilityTraits())
            Button(action: { model.setTilt(x: 0, y: 0) }) {
                Text("Precision")
                    .font(.system(size: 12, weight: tilted ? .medium : .semibold))
                    .foregroundColor(tilted ? .secondary : ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(tilted ? Color.clear : Color.white.opacity(0.78))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(Color.black.opacity(tilted ? 0 : 0.06), lineWidth: 0.5)
                            )
                    )
            }
            .buttonStyle(PressFadeButtonStyle())
            .help("Precision mode keeps the picture straight")
            .accessibilityLabel("Precision mode")
            .accessibilityAddTraits(tilted ? AccessibilityTraits() : .isSelected)
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.black.opacity(0.05)))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tilt")
    }

    private func presetCard(_ preset: Preset) -> some View {
        let active = preset.style == model.style
        let hovered = hoveredPreset == preset.id
        return Button(action: { model.applyPreset(preset) }) {
            VStack(alignment: .leading, spacing: 6) {
                layoutCard(preset.style)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(active ? 0.9 : 0), lineWidth: 1)
                            .padding(2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(active ? accent : (hovered ? Color.black.opacity(0.2) : Color.clear), lineWidth: active ? 2 : 1)
                    )
                Text(preset.name)
                    .font(.system(size: 12, weight: active ? .semibold : .medium))
                    .foregroundColor(active ? ink : .secondary)
                    .lineLimit(1)
                    .padding(.horizontal, 2)
            }
            .padding(4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(hovered && !active ? Color.black.opacity(0.035) : Color.clear)
            )
        }
        .buttonStyle(PressFadeButtonStyle())
        .onHover { hovering in
            if hovering {
                hoveredPreset = preset.id
            } else if hoveredPreset == preset.id {
                hoveredPreset = nil
            }
        }
        .help(preset.name)
        .accessibilityLabel("\(preset.name) layout")
        .accessibilityAddTraits(active ? .isSelected : AccessibilityTraits())
    }

    private var pictureKey: String {
        guard let picture = model.picture else { return "" }
        return "\(UInt(bitPattern: Unmanaged.passUnretained(picture.image).toOpaque()))"
    }

    private func refreshMagic() {
        guard let image = model.picture?.image else {
            magicColors = []
            magicBackgrounds = []
            return
        }
        let reading = MagicPalette.read(image)
        magicColors = reading.colors
        magicBackgrounds = reading.backgrounds
    }

    private func cycleMagic(_ step: Int) {
        if magicBackgrounds.isEmpty { refreshMagic() }
        guard !magicBackgrounds.isEmpty else {
            showMagic = true
            return
        }
        let current = magicBackgrounds.firstIndex { $0.background == model.style.background } ?? -1
        let next: Int
        if current < 0 {
            next = step < 0 ? magicBackgrounds.count - 1 : 0
        } else {
            next = (current + step + magicBackgrounds.count) % magicBackgrounds.count
        }
        model.setBackground(magicBackgrounds[next].background)
        showMagic = true
    }

    private func tabButton(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: on ? .semibold : .medium))
                .foregroundColor(on ? ink : .secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(on ? Color.white.opacity(0.78) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(Color.white.opacity(on ? 0.8 : 0), lineWidth: 0.6)
                        )
                )
        }
        .buttonStyle(PressFadeButtonStyle())
        .accessibilityLabel(title)
        .accessibilityAddTraits(on ? .isSelected : AccessibilityTraits())
    }

    private func densityButton(_ title: String, padding: CGFloat) -> some View {
        let on = abs(model.style.padding - padding) < 8
        return Button(action: {
            model.beginGesture()
            model.setPadding(padding)
            model.endGesture()
        }) {
            Text(title)
                .font(.system(size: 11, weight: on ? .semibold : .medium))
                .foregroundColor(on ? ink : .secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(on ? Color.white.opacity(0.78) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.black.opacity(on ? 0.06 : 0), lineWidth: 0.5)
                        )
                )
        }
        .buttonStyle(PressFadeButtonStyle())
        .help("\(title) padding")
        .accessibilityLabel("\(title) padding")
        .accessibilityAddTraits(on ? .isSelected : AccessibilityTraits())
    }

    private var pictureAspect: CGFloat {
        guard let picture = model.picture, picture.height > 1 else { return 16.0 / 10.0 }
        let crop = model.crop ?? CGRect(x: 0, y: 0, width: picture.width, height: picture.height)
        return max(0.2, crop.width / max(crop.height, 1))
    }

    private var shotImage: NSImage? {
        guard let picture = model.picture else { return nil }
        return NSImage(cgImage: picture.image, size: NSSize(width: picture.width, height: picture.height))
    }

    private func layoutCard(_ style: ShotliStyle) -> some View {
        let inset = 8 + min(style.padding, 140) / 18
        return ZStack {
            presetPreview(style.background)
            Group {
                if let shotImage {
                    Image(nsImage: shotImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                } else {
                    Color.white
                        .aspectRatio(pictureAspect, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
            .padding(inset)
            .shadow(color: Color.black.opacity(0.16), radius: 5, y: 3)
            if style.frame != .none {
                HStack(spacing: 2) {
                    Circle().fill(Color(nsColor: NSColor(hex: "#FF5F57")!)).frame(width: 4, height: 4)
                    Circle().fill(Color(nsColor: NSColor(hex: "#FEBC2E")!)).frame(width: 4, height: 4)
                    Circle().fill(Color(nsColor: NSColor(hex: "#28C840")!)).frame(width: 4, height: 4)
                    Text(style.frame.label)
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.94))
                .clipShape(Capsule())
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(8)
            }
        }
        .aspectRatio(16.0 / 10.0, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.black.opacity(0.06), lineWidth: 1))
    }

    private func stage<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            content()
            if dropTarget {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(accent, lineWidth: 2)
                    .padding(10)
                    .allowsHitTesting(false)
            }
            if let notice = model.notice {
                noticeBanner(notice)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: [.fileURL, .image, .png, .jpeg, .webP], isTargeted: $dropTarget) { providers in
            acceptDrop(providers)
        }
    }


    private var screenshotRow: some View {
        Button(action: { model.openPanel() }) {
            HStack(spacing: 10) {
                shotThumb
                    .frame(width: 42, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Screenshot")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(ink)
                    Text("Adapts To Media")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.06), radius: 8, y: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private var shotThumb: some View {
        Group {
            if let shotImage {
                Image(nsImage: shotImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.black.opacity(0.06)
            }
        }
    }

    private var magicPresetRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 4) {
                Button(action: {
                    refreshMagic()
                    showMagic.toggle()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "circle.grid.2x2.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(ink)
                        Text("Palette")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(ink)
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Backgrounds from the colours in this picture")
                Button(action: { cycleMagic(-1) }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Previous recommended background")
                Button(action: { cycleMagic(1) }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Next recommended background")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.black.opacity(showMagic ? 0.07 : 0.045)))
            if showMagic {
                magicPanel
            }
            Rectangle()
                .fill(Color.black.opacity(0.08))
                .frame(height: 1)
        }
    }

    private var magicPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            if magicBackgrounds.isEmpty {
                Text("Open a screenshot and Shotli will pick backgrounds from its colours.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Colours in this picture")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                HStack(spacing: 8) {
                    ForEach(magicColors) { color in
                        Button(action: { model.setBackground(color.wash) }) {
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color(nsColor: NSColor(hex: color.hex) ?? .gray))
                                    .frame(width: 28, height: 28)
                                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.black.opacity(0.12), lineWidth: 1))
                                Text(color.name)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                        .help("Use a \(color.name.lowercased()) background")
                    }
                    Spacer(minLength: 0)
                }
                Text("Recommended")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(magicBackgrounds) { item in
                        let active = item.background == model.style.background
                        Button(action: { model.setBackground(item.background) }) {
                            VStack(alignment: .leading, spacing: 4) {
                                ZStack {
                                    presetPreview(item.background)
                                    if let shotImage {
                                        Image(nsImage: shotImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                            .padding(8)
                                            .shadow(color: Color.black.opacity(0.18), radius: 3, y: 2)
                                    }
                                }
                                .frame(height: 68)
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(active ? accent : Color.black.opacity(0.08), lineWidth: active ? 2 : 1))
                                Text(item.name)
                                    .font(.system(size: 11, weight: active ? .semibold : .medium))
                                    .foregroundColor(active ? ink : .secondary)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var mediaWell: some View {
        VStack(alignment: .leading, spacing: 8) {
            caption("Media")
            Button(action: { model.openPanel() }) {
                VStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.black.opacity(0.045))
                            .frame(height: 96)
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white)
                            .frame(width: 56, height: 48)
                            .shadow(color: Color.black.opacity(0.07), radius: 5, y: 2)
                            .overlay(Image(systemName: "plus").font(.system(size: 18, weight: .medium)).foregroundColor(ink))
                    }
                    Text("Drop media or click to choose")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var styleGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            caption("Style")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 10) {
                ForEach(CardStyle.allCases, id: \.self) { card in
                    let active = model.style.card == card
                    Button(action: { model.setCard(card) }) {
                        VStack(spacing: 5) {
                            StyleStudy(card: card)
                                .frame(height: 54)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(active ? Color.black.opacity(0.82) : Color.black.opacity(0.06), lineWidth: active ? 2 : 1)
                                )
                            Text(card.title)
                                .font(.system(size: 10, weight: active ? .semibold : .medium))
                                .foregroundColor(active ? ink : .secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                    .buttonStyle(PressFadeButtonStyle())
                    .help(card.title)
                    .accessibilityLabel(card.title)
                    .accessibilityAddTraits(active ? .isSelected : AccessibilityTraits())
                }
            }
        }
    }

    private var borderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            caption("Border")
            HStack(spacing: 6) {
                cornerButton("Sharp", radius: 0, curve: 0)
                cornerButton("Curved", radius: 20, curve: 10)
                cornerButton("Round", radius: 48, curve: 18)
            }
            .padding(4)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.black.opacity(0.045)))
            metricSlider("Radius", value: Binding(get: { model.style.radius }, set: { model.beginGesture(); model.setRadius($0) }), range: 0...64)
        }
    }

    private func cornerButton(_ title: String, radius: CGFloat, curve: CGFloat) -> some View {
        let on = cornerIsOn(radius)
        return Button(action: { model.setCorner(radius) }) {
            VStack(spacing: 4) {
                CornerMark(radius: curve)
                    .stroke(ink, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                    .frame(width: 28, height: 22)
                Text(title)
                    .font(.system(size: 11, weight: on ? .semibold : .medium))
                    .foregroundColor(ink)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(on ? Color.white : Color.clear)
                    .shadow(color: on ? Color.black.opacity(0.08) : .clear, radius: 4, y: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(PressFadeButtonStyle())
        .help(title)
        .accessibilityLabel(title)
        .accessibilityAddTraits(on ? .isSelected : AccessibilityTraits())
    }

    private func cornerIsOn(_ radius: CGFloat) -> Bool {
        let current = model.style.radius
        if radius == 0 { return current < 2 }
        if radius == 20 { return current >= 2 && current < 36 }
        return current >= 36
    }

    private var shadowSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            caption("Shadow")
            HStack(spacing: 8) {
                ForEach(ShadowKind.allCases, id: \.self) { kind in
                    let active = model.style.shadowKind == kind
                    Button(action: { model.setShadowKind(kind) }) {
                        VStack(spacing: 5) {
                            ShadowStudy(kind: kind, image: shotImage)
                                .frame(height: 46)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(active ? Color.black.opacity(0.82) : Color.clear, lineWidth: 2)
                                )
                            Text(kind.title)
                                .font(.system(size: 10, weight: active ? .semibold : .medium))
                                .foregroundColor(active ? ink : .secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            metricSlider("Opacity", value: Binding(get: { model.style.shadowOpacity }, set: { model.beginGesture(); model.setShadowOpacity($0) }), range: 0...100)
        }
    }

    private var lightControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { adjustingLight.toggle() }) {
                HStack(spacing: 6) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 12, weight: .medium))
                    Text("Adjust Light")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            if adjustingLight {
                metricSlider("Light", value: Binding(get: { model.style.light }, set: { model.beginGesture(); model.setLight($0) }), range: -50...50)
            }
        }
    }

    private var visibilitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            caption("Visibility")
            Button(action: { model.setHideMockup(!model.style.hideMockup) }) {
                HStack(spacing: 8) {
                    Image(systemName: "eye.slash")
                        .font(.system(size: 13, weight: .medium))
                    Text("Hide Mockup")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(model.style.hideMockup ? Color.white : Color.black.opacity(0.05))
                        .shadow(color: model.style.hideMockup ? Color.black.opacity(0.06) : .clear, radius: 4, y: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            caption("Details")
            VStack(alignment: .leading, spacing: 10) {
                detailRow("Device", "Screenshot")
                detailRow("Screen pixels", "Adapts to media")
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
        }
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(ink)
        }
    }

    private func metricSlider(_ title: String, value: Binding<CGFloat>, range: ClosedRange<CGFloat>) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .shotliRoundedChip(radius: 8)
            Slider(value: value, in: range, onEditingChanged: { editing in
                if !editing { model.endGesture() }
            })
            Text("\(Int(value.wrappedValue.rounded()))")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(ink)
                .monospacedDigit()
                .frame(width: 32, alignment: .trailing)
        }
        .padding(.leading, 4)
        .padding(.trailing, 8)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.black.opacity(0.045)))
    }

    private func caption(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .kerning(0.6)
            .foregroundColor(.secondary)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var toolDock: some View {
        HStack(spacing: 0) {
            ForEach(Array(dockTools.enumerated()), id: \.element) { index, tool in
                if index == 4 || index == 7 || index == 9 || index == 11 {
                    Rectangle().fill(line).frame(width: 1, height: 14).padding(.horizontal, 3)
                }
                toolButton(tool, help: "\(tool.label) (\(shortcut(for: tool)))")
            }
        }
        .padding(.horizontal, 4)
        .frame(height: ShotliGlass.controlHeight)
        .shotliCapsuleChip()
        .fixedSize(horizontal: true, vertical: true)
    }

    private var markControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showsText, let text = selectedText {
                TextField("Text", text: Binding(
                    get: { text.text },
                    set: { model.replaceSelectedText($0) }
                ))
                .textFieldStyle(.roundedBorder)
                choiceRow(fontSizes.map { ("\(Int($0))", $0) }, selected: text.fontSize) { size in
                    model.setSelectedFontSize(size)
                }
            } else if model.tool == .text {
                choiceRow(fontSizes.map { ("\(Int($0))", $0) }, selected: model.brush.fontSize) { size in
                    model.brush.fontSize = size
                }
            }
            if showsStroke {
                choiceRow(strokeWidths.map { ("\(Int($0))", $0) }, selected: currentStroke) { width in
                    model.setSelectedStroke(width)
                }
            }
            if showsPixel {
                labelledSlider("Block size", value: pixelBinding, range: 4...48)
            }
            if showsBlur {
                labelledSlider("Blur radius", value: blurBinding, range: 2...40)
            }
            swatchRow(Presets.inks, selected: currentInk) { color in
                model.updateSelectedColor(color)
            }
            Button(action: { model.deleteSelected() }) {
                Text("Delete selected")
                    .frame(maxWidth: .infinity)
            }
            .disabled(model.selectedID == nil)
        }
    }

    private var backgroundGallery: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Backgrounds")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(ink)
            wallpaperShelf("Gradient", WallpaperID.fields, .gradient)
            wallpaperShelf("Glass", WallpaperID.glass, .glass)
            wallpaperShelf("Cosmic", WallpaperID.cosmic, .cosmic)
            wallpaperShelf("Mystic", WallpaperID.mystic, .mystic)
            wallpaperShelf("Desktop", WallpaperID.desktop, .desktop)
            wallpaperShelf("Abstract", WallpaperID.abstract, .abstract)
            wallpaperShelf("Earth", WallpaperID.earth, .earth)
            wallpaperShelf("Studio", WallpaperID.backdrops, .studio)
            wallpaperShelf("Scenes", WallpaperID.scenes, .scenes)
            gradientShelf
            wallpaperShelf("Pattern", WallpaperID.patterns, .pattern)
        }
        .onAppear(perform: seedLibrary)
    }

    private var activeBackgroundShelf: BackgroundShelf? {
        switch model.style.background {
        case .wallpaper(let id):
            if WallpaperID.fields.contains(id) { return .gradient }
            if WallpaperID.glass.contains(id) { return .glass }
            if WallpaperID.cosmic.contains(id) { return .cosmic }
            if WallpaperID.mystic.contains(id) { return .mystic }
            if WallpaperID.desktop.contains(id) { return .desktop }
            if WallpaperID.abstract.contains(id) { return .abstract }
            if WallpaperID.earth.contains(id) { return .earth }
            if WallpaperID.backdrops.contains(id) { return .studio }
            if WallpaperID.scenes.contains(id) { return .scenes }
            if WallpaperID.patterns.contains(id) { return .pattern }
            return nil
        case .gradient:
            return .linear
        case .color:
            return nil
        }
    }

    private func seedLibrary() {
        guard !didSeedLibrary else { return }
        didSeedLibrary = true
        expandedShelves = [activeBackgroundShelf?.rawValue ?? BackgroundShelf.gradient.rawValue]
    }

    private func shelfIsOpen(_ shelf: BackgroundShelf) -> Bool {
        expandedShelves.contains(shelf.rawValue)
    }

    private func toggleShelf(_ shelf: BackgroundShelf) {
        if expandedShelves.contains(shelf.rawValue) {
            expandedShelves.remove(shelf.rawValue)
        } else {
            expandedShelves.insert(shelf.rawValue)
        }
    }

    private func categoryHeading(_ title: String, _ shelf: BackgroundShelf) -> some View {
        let open = shelfIsOpen(shelf)
        return Button(action: { toggleShelf(shelf) }) {
            HStack(spacing: 6) {
                Image(systemName: open ? "chevron.down" : "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 10, alignment: .center)
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .kerning(0.6)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(open ? "Expanded" : "Collapsed")
        .help(open ? "Collapse \(title)" : "Expand \(title)")
    }

    @ViewBuilder
    private func wallpaperShelf(_ title: String, _ items: [WallpaperID], _ shelf: BackgroundShelf) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            categoryHeading(title, shelf)
            if shelfIsOpen(shelf) {
                HStack(spacing: thumbGap) {
                    ForEach(rowWallpapers(items)) { wallpaper in
                        wallpaperSwatch(wallpaper, height: thumbHeight)
                    }
                    if items.count > 3 {
                        moreSwatch(title) {
                            gradientPopover = nil
                            backgroundShelf = shelf
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var gradientShelf: some View {
        VStack(alignment: .leading, spacing: 8) {
            categoryHeading("Linear", .linear)
            if shelfIsOpen(.linear) {
                HStack(spacing: thumbGap) {
                    ForEach(rowGradients(Presets.gradients), id: \.name) { gradient in
                        gradientSwatch(gradient, height: thumbHeight, showsColours: true)
                    }
                    if Presets.gradients.count > 3 {
                        moreSwatch("Linear") {
                            gradientPopover = nil
                            backgroundShelf = .linear
                        }
                    }
                }
            }
        }
    }

    private func rowWallpapers(_ items: [WallpaperID]) -> [WallpaperID] {
        let head = Array(items.prefix(3))
        guard case .wallpaper(let selected) = model.style.background,
              let index = items.firstIndex(of: selected),
              index >= 3 else { return head }
        return Array(items.prefix(2)) + [selected]
    }

    private func rowGradients(_ items: [(name: String, from: String, mid: String, to: String, angle: CGFloat)]) -> [(name: String, from: String, mid: String, to: String, angle: CGFloat)] {
        let head = Array(items.prefix(3))
        guard case .gradient(let from, let mid, let to, _) = model.style.background,
              let match = items.first(where: { $0.from == from && $0.mid == mid && $0.to == to }),
              !head.contains(where: { $0.name == match.name }) else { return head }
        return Array(items.prefix(2)) + [match]
    }

    private func wallpaperSwatch(_ wallpaper: WallpaperID, height: CGFloat) -> some View {
        wallpaperChoice(wallpaper, height: height)
    }

    private func wallpaperChoice(_ wallpaper: WallpaperID, height: CGFloat) -> some View {
        let active: Bool = {
            if case .wallpaper(let selected) = model.style.background { return selected == wallpaper }
            return false
        }()
        return SelectWell(height: height, active: active, help: wallpaper.label, label: "Use \(wallpaper.label) background", action: {
            model.setBackground(.wallpaper(wallpaper))
            gradientPopover = nil
        }) {
            wallpaperPreview(wallpaper)
        }
    }

    private func gradientSwatch(_ gradient: (name: String, from: String, mid: String, to: String, angle: CGFloat), height: CGFloat, showsColours: Bool = false) -> some View {
        ZStack(alignment: .topTrailing) {
            gradientChoice(gradient, height: height)
            if showsColours {
                PlusButton(label: "Flat colours from \(gradient.name)", presented: gradientPresented(gradient.name)) {
                    gradientColourPopover(gradient)
                }
            }
        }
    }

    private func gradientChoice(_ gradient: (name: String, from: String, mid: String, to: String, angle: CGFloat), height: CGFloat) -> some View {
        let active: Bool = {
            if case .gradient(let from, let mid, let to, _) = model.style.background {
                return gradient.from == from && gradient.mid == mid && gradient.to == to
            }
            return false
        }()
        return SelectWell(height: height, active: active, help: gradient.name, label: "Use \(gradient.name) background", action: {
            model.setBackground(.gradient(from: gradient.from, mid: gradient.mid, to: gradient.to, angle: gradient.angle))
            gradientPopover = nil
        }) {
            LinearGradient(
                colors: [Color(nsColor: NSColor(hex: gradient.from)!), Color(nsColor: NSColor(hex: gradient.mid)!), Color(nsColor: NSColor(hex: gradient.to)!)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func gradientPresented(_ name: String) -> Binding<Bool> {
        Binding(
            get: { gradientPopover == name },
            set: { on in
                gradientPopover = on ? name : (gradientPopover == name ? nil : gradientPopover)
            }
        )
    }

    private func gradientColourPopover(_ gradient: (name: String, from: String, mid: String, to: String, angle: CGFloat)) -> some View {
        let selected: String? = {
            if case .color(let hex) = model.style.background { return hex }
            return nil
        }()
        return VStack(alignment: .leading, spacing: 8) {
            Text(gradient.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(ink)
            Text("FLAT COLOUR")
                .font(.system(size: 10, weight: .semibold))
                .kerning(0.6)
                .foregroundColor(.secondary)
            swatchRow(gradientStops(gradient), selected: selected) { hex in
                model.setBackground(.color(hex))
                gradientPopover = nil
            }
        }
        .padding(12)
        .frame(width: 180, alignment: .leading)
        .shotliGlass(.compact, radius: 14, shadow: false)
        .onExitCommand { gradientPopover = nil }
    }

    private func gradientStops(_ gradient: (name: String, from: String, mid: String, to: String, angle: CGFloat)) -> [String] {
        var stops: [String] = []
        for hex in [gradient.from, gradient.mid, gradient.to] where !stops.contains(hex) {
            stops.append(hex)
        }
        return stops
    }

    private func moreSwatch(_ title: String, action: @escaping () -> Void) -> some View {
        LibraryMoreTile(title: title, action: action)
    }

    private func swatchStroke(_ active: Bool) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(active ? accent : Color.black.opacity(0.08), lineWidth: active ? 2 : 1)
    }

    private func backgroundBrowser(_ shelf: BackgroundShelf) -> some View {
        ZStack {
            Color.black.opacity(0.22)
                .ignoresSafeArea()
                .onTapGesture { backgroundShelf = nil }
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(shelf.title)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(ink)
                    Spacer()
                    Button(action: { backgroundShelf = nil }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(ink)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.black.opacity(0.06)))
                    }
                    .buttonStyle(.plain)
                    .help("Close")
                }
                .padding(.horizontal, 22)
                .padding(.top, 20)
                .padding(.bottom, 14)
                ScrollView {
                    if shelf == .linear {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 14) {
                            ForEach(Presets.gradients, id: \.name) { gradient in
                                VStack(spacing: 6) {
                                    gradientSwatch(gradient, height: 92)
                                    Text(gradient.name)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(ink)
                                }
                            }
                        }
                    } else {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 14) {
                            ForEach(shelf.wallpapers) { wallpaper in
                                VStack(spacing: 6) {
                                    wallpaperSwatch(wallpaper, height: 92)
                                    Text(wallpaper.label)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(ink)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 22)
            }
            .frame(width: 680, height: 520)
            .shotliGlass(.panel, radius: ShotliGlass.radiusOverlay)
        }
        .onExitCommand { backgroundShelf = nil }
    }

    private var backgroundControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            caption("Colour")
            swatchRow(Presets.colors, selected: {
                if case .color(let selected) = model.style.background { return selected }
                return nil
            }()) { model.setBackground(.color($0)) }
            wallpaperGrid("Scenes", WallpaperID.scenes, columns: 2, height: 86)
            caption("Gradient")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(Array(Presets.gradients.enumerated()), id: \.offset) { _, gradient in
                    let active: Bool = {
                        if case .gradient(let from, let mid, let to, _) = model.style.background {
                            return gradient.from == from && gradient.mid == mid && gradient.to == to
                        }
                        return false
                    }()
                    Button(action: { model.setBackground(.gradient(from: gradient.from, mid: gradient.mid, to: gradient.to, angle: gradient.angle)) }) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(LinearGradient(colors: [Color(nsColor: NSColor(hex: gradient.from)!), Color(nsColor: NSColor(hex: gradient.mid)!), Color(nsColor: NSColor(hex: gradient.to)!)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(height: 48)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(active ? accent : Color.black.opacity(0.08), lineWidth: active ? 2 : 1))
                    }
                    .buttonStyle(.plain)
                    .help(gradient.name)
                }
            }
            wallpaperGrid("Pattern", WallpaperID.patterns, columns: 3, height: 48)
        }
    }

    private func wallpaperGrid(_ title: String, _ items: [WallpaperID], columns: Int, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            caption(title)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns), spacing: 10) {
                ForEach(items) { wallpaper in
                    let active: Bool = {
                        if case .wallpaper(let selected) = model.style.background { return selected == wallpaper }
                        return false
                    }()
                    Button(action: { model.setBackground(.wallpaper(wallpaper)) }) {
                        VStack(spacing: 4) {
                            wallpaperPreview(wallpaper)
                                .frame(height: height)
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(active ? accent : Color.black.opacity(0.08), lineWidth: active ? 2 : 1)
                                )
                            Text(wallpaper.label)
                                .font(.system(size: 11, weight: active ? .semibold : .regular))
                                .foregroundColor(active ? ink : .secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var layoutControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            labelledSlider("Padding", value: Binding(get: { model.style.padding }, set: { model.beginGesture(); model.setPadding($0) }), range: 0...200)
            labelledSlider("Corner radius", value: Binding(get: { model.style.radius }, set: { model.beginGesture(); model.setRadius($0) }), range: 0...64)
            labelledSlider("Shadow", value: Binding(get: { model.style.shadow }, set: { model.beginGesture(); model.setShadow($0) }), range: 0...100)
            caption("Frame")
            framePicker
            Button(action: { model.resetCrop() }) {
                Text("Reset crop").frame(maxWidth: .infinity)
            }
            .disabled(model.crop == nil)
            Button(action: { model.removeRedactions() }) {
                Text("Remove redactions").frame(maxWidth: .infinity)
            }
            .disabled(!hasRedactions)
        }
    }

    private var framePicker: some View {
        HStack(spacing: 8) {
            ForEach(FrameStyle.allCases) { frame in
                let active = model.style.frame == frame
                Button(action: { model.setFrame(frame) }) {
                    VStack(spacing: 4) {
                        frameGlyph(frame)
                            .frame(height: 40)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(nsColor: NSColor(srgbRed: 0.96, green: 0.96, blue: 0.97, alpha: 1)))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(active ? accent : Color.black.opacity(0.06), lineWidth: active ? 2 : 1)
                            )
                        Text(frame.label)
                            .font(.system(size: 10, weight: active ? .semibold : .regular))
                            .foregroundColor(active ? ink : .secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func frameGlyph(_ frame: FrameStyle) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 1, y: 1)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            if frame != .none {
                HStack(spacing: 2) {
                    Circle().fill(Color(nsColor: NSColor(hex: "#FF5F57")!)).frame(width: 4, height: 4)
                    Circle().fill(Color(nsColor: NSColor(hex: "#FEBC2E")!)).frame(width: 4, height: 4)
                    Circle().fill(Color(nsColor: NSColor(hex: "#28C840")!)).frame(width: 4, height: 4)
                    Spacer(minLength: 0)
                }
                .padding(.leading, 16)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            caption(title)
            content()
        }
        .padding(.horizontal, 14)
        .padding(.top, 18)
    }

    private func noticeBanner(_ text: String) -> some View {
        VStack {
            Spacer()
            HStack(spacing: 8) {
                Text(text)
                    .font(.system(size: 12))
                    .foregroundColor(ink)
                Button(action: { model.notice = nil }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .shotliGlass(.panel, radius: 16)
            .padding(.bottom, 16)
        }
        .allowsHitTesting(true)
    }

    private func toolButton(_ tool: Tool, help: String, wide: Bool = false) -> some View {
        let active = model.tool == tool
        return Button(action: { model.tool = tool }) {
            Image(systemName: tool.symbol)
                .font(.system(size: 13, weight: active ? .semibold : .regular))
                .frame(maxWidth: wide ? .infinity : nil)
                .frame(width: wide ? nil : 26, height: 26)
                .foregroundColor(active ? accent : ink)
                .background(RoundedRectangle(cornerRadius: 6).fill(active ? accent.opacity(0.16) : Color.clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(PressFadeButtonStyle())
        .help(help)
        .accessibilityLabel(help)
        .accessibilityAddTraits(active ? .isSelected : AccessibilityTraits())
    }

    private func iconButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(ink)
                .frame(width: 28, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressFadeButtonStyle())
        .help(help)
        .accessibilityLabel(help)
    }

    private func labelledSlider(_ title: String, value: Binding<CGFloat>, range: ClosedRange<CGFloat>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.system(size: 12)).foregroundColor(ink)
                Spacer()
                Text("\(Int(value.wrappedValue.rounded()))")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            Slider(value: value, in: range, onEditingChanged: { editing in
                if !editing { model.endGesture() }
            })
        }
    }

    private func choiceRow(_ options: [(String, CGFloat)], selected: CGFloat, choose: @escaping (CGFloat) -> Void) -> some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.1) { option in
                Button(action: { choose(option.1) }) {
                    Text(option.0)
                        .font(.system(size: 12))
                        .frame(maxWidth: .infinity)
                        .frame(height: 26)
                        .foregroundColor(ink)
                        .background(RoundedRectangle(cornerRadius: 6).fill(option.1 == selected ? accent.opacity(0.14) : Color.black.opacity(0.04)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func swatchRow(_ colors: [String], selected: String?, choose: @escaping (String) -> Void) -> some View {
        HStack(spacing: 6) {
            ForEach(colors, id: \.self) { color in
                Button(action: { choose(color) }) {
                    ZStack {
                        if color == "transparent" {
                            checker
                        } else {
                            RoundedRectangle(cornerRadius: 5).fill(Color(nsColor: NSColor(hex: color) ?? .clear))
                        }
                    }
                    .frame(width: 22, height: 22)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(Color.white.opacity(selected == color ? 0.9 : 0), lineWidth: 1)
                            .padding(1.5)
                    )
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(selected == color ? accent : Color.black.opacity(0.15), lineWidth: selected == color ? 2 : 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var checker: some View {
        ZStack(alignment: .topLeading) {
            Color.white
            Color.black.opacity(0.08).frame(width: 11, height: 11)
            Color.black.opacity(0.08).frame(width: 11, height: 11).offset(x: 11, y: 11)
        }
        .frame(width: 22, height: 22)
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    @ViewBuilder
    private func presetPreview(_ background: Background) -> some View {
        switch background {
        case .color(let hex):
            if hex == "transparent" {
                checker
            } else {
                Color(nsColor: NSColor(hex: hex) ?? .white)
            }
        case .gradient(let from, let mid, let to, _):
            LinearGradient(
                colors: [Color(nsColor: NSColor(hex: from)!), Color(nsColor: NSColor(hex: mid ?? to)!), Color(nsColor: NSColor(hex: to)!)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .wallpaper(let id):
            wallpaperPreview(id)
        }
    }

    @ViewBuilder
    private func wallpaperPreview(_ id: WallpaperID) -> some View {
        if WallpaperID.patterns.contains(id) {
            patternSwatch(id)
        } else if let image = SceneThumbs.image(id) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Color(nsColor: NSColor(hex: "#E7E5E4")!)
        }
    }

    @ViewBuilder
    private func patternSwatch(_ id: WallpaperID) -> some View {
        switch id {
        case .dots: Color(nsColor: NSColor(hex: "#E8E6E3")!)
        case .grid: Color(nsColor: NSColor(hex: "#F7F7F7")!)
        case .diagonal: Color(nsColor: NSColor(hex: "#EEF2FF")!)
        case .stripes: Color(nsColor: NSColor(hex: "#F4F1EC")!)
        case .mesh: Color(nsColor: NSColor(hex: "#F6F7F8")!)
        case .cross: Color(nsColor: NSColor(hex: "#F4F7FB")!)
        default: Color(nsColor: NSColor(hex: "#F4F4F5")!)
        }
    }

    private var selectedText: TextMark? {
        if case .text(let mark) = model.selected { return mark }
        return nil
    }

    private var selectedShape: ShapeMark? {
        if case .shape(let mark) = model.selected { return mark }
        return nil
    }

    private var showsText: Bool {
        selectedText != nil || model.tool == .text
    }

    private var showsStroke: Bool {
        switch model.selected {
        case .shape(let mark): return mark.kind != .pixelate && mark.kind != .blur
        case .line, .draw: return true
        default: break
        }
        switch model.tool {
        case .rect, .rectFill, .circle, .line, .arrow, .draw: return true
        default: return false
        }
    }

    private var showsPixel: Bool {
        selectedShape?.kind == .pixelate || model.tool == .pixelate
    }

    private var showsBlur: Bool {
        selectedShape?.kind == .blur || model.tool == .blur
    }

    private var hasRedactions: Bool {
        model.annotations.contains { annotation in
            if case .shape(let mark) = annotation { return mark.kind == .pixelate || mark.kind == .blur }
            return false
        }
    }

    private var currentStroke: CGFloat {
        switch model.selected {
        case .shape(let mark): return mark.strokeWidth
        case .line(let mark): return mark.strokeWidth
        case .draw(let mark): return mark.strokeWidth
        default: return model.brush.strokeWidth
        }
    }

    private var currentInk: String? {
        model.selected?.color ?? model.brush.color
    }

    private var pixelBinding: Binding<CGFloat> {
        Binding(
            get: { selectedShape?.kind == .pixelate ? (selectedShape?.amount ?? model.brush.pixelSize) : model.brush.pixelSize },
            set: { value in
                model.beginGesture()
                model.brush.pixelSize = value
                if selectedShape?.kind == .pixelate { model.updateSelectedAmount(value) }
            }
        )
    }

    private var blurBinding: Binding<CGFloat> {
        Binding(
            get: { selectedShape?.kind == .blur ? (selectedShape?.amount ?? model.brush.blur) : model.brush.blur },
            set: { value in
                model.beginGesture()
                model.brush.blur = value
                if selectedShape?.kind == .blur { model.updateSelectedAmount(value) }
            }
        )
    }

    private func shortcut(for tool: Tool) -> String {
        switch tool {
        case .select: return "V"
        case .crop: return "K"
        case .rect: return "R"
        case .rectFill: return "F"
        case .circle: return "C"
        case .line: return "L"
        case .arrow: return "A"
        case .draw: return "D"
        case .text: return "T"
        case .marker: return "N"
        case .pixelate: return "P"
        case .blur: return "B"
        }
    }

    private func acceptDrop(_ providers: [NSItemProvider]) -> Bool {
        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else if let found = item as? URL {
                    url = found
                } else if let found = item as? NSURL {
                    url = found as URL
                } else {
                    url = nil
                }
                guard let url else { return }
                DispatchQueue.main.async { model.load(url: url) }
            }
            return true
        }
        if #available(macOS 13, *), let provider = providers.first(where: { $0.canLoadObject(ofClass: NSImage.self) }) {
            provider.loadObject(ofClass: NSImage.self) { object, _ in
                guard let image = object as? NSImage, let tiff = image.tiffRepresentation else { return }
                DispatchQueue.main.async { model.loadImageData(tiff, name: "Dropped image.png") }
            }
            return true
        }
        return false
    }

    private func configureWindow() {
        guard !didConfigure else { return }
        didConfigure = true
        DispatchQueue.main.async {
            guard let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.canBecomeMain }) else { return }
            window.title = "Shotli"
            window.isReleasedWhenClosed = false
            ScreenCapture.shared.editorWindow = window
            window.delegate = WindowKeeper.shared
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.styleMask.insert(.fullSizeContentView)
            window.titlebarSeparatorStyle = .none
            window.isMovableByWindowBackground = false
            TitlebarClicks.install(on: window)
            window.minSize = NSSize(width: 1100, height: 720)
            window.backgroundColor = ShotliGlass.workspaceBottom
            if window.contentRect(forFrameRect: window.frame).width < 1000 {
                window.setContentSize(NSSize(width: 1180, height: 760))
                window.center()
            }
        }
    }
}

struct PressFadeButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? ShotliGlass.pressedOpacity : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: ShotliGlass.duration), value: configuration.isPressed)
    }
}

private struct SelectWell<Content: View>: View {
    var height: CGFloat
    var active: Bool
    var help: String
    var label: String
    var action: () -> Void
    var content: Content
    @State private var hovering = false
    @FocusState private var focused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(height: CGFloat, active: Bool, help: String, label: String, action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.height = height
        self.active = active
        self.help = help
        self.label = label
        self.action = action
        self.content = content()
    }

    var body: some View {
        Button(action: action) {
            Color.clear
                .frame(height: height)
                .frame(maxWidth: .infinity)
                .overlay { content.allowsHitTesting(false) }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(stroke)
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(PressFadeButtonStyle())
        .help(help)
        .accessibilityLabel(label)
        .accessibilityAddTraits(active ? .isSelected : AccessibilityTraits())
        .focused($focused)
        .onHover { hovering = $0 }
        .animation(reduceMotion ? nil : .easeOut(duration: ShotliGlass.duration), value: hovering)
    }

    private var stroke: some View {
        ZStack {
            if active || focused {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.92), lineWidth: 1)
                    .padding(2)
            }
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(active || focused ? accent : (hovering ? Color.black.opacity(0.28) : Color.black.opacity(0.10)), lineWidth: active || focused ? 2 : 1)
        }
        .allowsHitTesting(false)
    }
}

private struct PlusButton<Popover: View>: View {
    var label: String
    @Binding var presented: Bool
    var popover: Popover
    @State private var hovering = false
    @FocusState private var focused: Bool

    init(label: String, presented: Binding<Bool>, @ViewBuilder popover: () -> Popover) {
        self.label = label
        self._presented = presented
        self.popover = popover()
    }

    var body: some View {
        Button(action: { presented.toggle() }) {
            Image(systemName: "plus")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(ink)
                .frame(width: 16, height: 16)
                .background(Circle().fill(hovering || focused || presented ? Color.white.opacity(0.92) : Color.white))
                .overlay(Circle().stroke(focused || presented ? accent : Color.black.opacity(0.12), lineWidth: focused || presented ? 1.5 : 0.5))
                .shadow(color: Color.black.opacity(0.14), radius: 1.5, y: 0.5)
                .contentShape(Circle())
        }
        .buttonStyle(PressFadeButtonStyle())
        .padding(4)
        .accessibilityLabel(label)
        .help(label)
        .focused($focused)
        .onHover { hovering = $0 }
        .popover(isPresented: $presented, arrowEdge: .trailing) { popover }
    }
}

private struct LibraryMoreTile: View {
    var title: String
    var action: () -> Void
    @State private var hovering = false
    @FocusState private var focused: Bool

    var body: some View {
        Button(action: action) {
            ZStack {
                Color.clear
                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(ink)
            }
            .frame(height: thumbHeight)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(hovering ? Color.black.opacity(0.08) : Color.black.opacity(0.05)))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(focused ? 0.9 : 0), lineWidth: 1)
                    .padding(2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(focused ? accent : Color.black.opacity(hovering ? 0.28 : 0.10), lineWidth: focused ? 2 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(PressFadeButtonStyle())
        .help("More \(title.lowercased()) backgrounds")
        .accessibilityLabel("More \(title.lowercased()) backgrounds")
        .focused($focused)
        .onHover { hovering = $0 }
    }
}

private struct CornerMark: Shape {
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let left = rect.minX + rect.width * 0.18
        let top = rect.minY + rect.height * 0.12
        let bottom = rect.maxY - rect.height * 0.16
        let right = rect.maxX - rect.width * 0.06
        path.move(to: CGPoint(x: left, y: top))
        if radius < 1 {
            path.addLine(to: CGPoint(x: left, y: bottom))
            path.addLine(to: CGPoint(x: right, y: bottom))
        } else {
            path.addArc(
                tangent1End: CGPoint(x: left, y: bottom),
                tangent2End: CGPoint(x: right, y: bottom),
                radius: min(radius, rect.width * 0.7)
            )
            path.addLine(to: CGPoint(x: right, y: bottom))
        }
        return path
    }
}

private struct StyleStudy: View {
    let card: CardStyle

    var body: some View {
        GeometryReader { geo in
            ZStack {
                backdrop
                cardBody(geo.size)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var backdrop: some View {
        Group {
            switch card {
            case .liquid:
                ZStack {
                    Color(nsColor: NSColor(srgbRed: 0.98, green: 0.58, blue: 0.24, alpha: 1))
                    DiagonalStripes()
                }
            case .glassDark:
                Color(nsColor: NSColor(srgbRed: 0.80, green: 0.81, blue: 0.84, alpha: 1))
            default:
                Color(nsColor: NSColor(srgbRed: 0.90, green: 0.90, blue: 0.92, alpha: 1))
            }
        }
    }

    private func cardBody(_ size: CGSize) -> some View {
        let radius: CGFloat = card == .border ? 16 : 24
        return RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(fill)
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(edge, lineWidth: edgeWidth)
            )
            .frame(width: size.width * 1.55, height: size.height * 1.75)
            .position(x: size.width * 0.95, y: size.height * 0.98)
    }

    private var fill: Color {
        switch card {
        case .glassLight: return Color.white.opacity(0.82)
        case .glassDark: return Color(nsColor: NSColor(srgbRed: 0.11, green: 0.12, blue: 0.15, alpha: 0.92))
        case .liquid: return Color.white.opacity(0.42)
        case .insetLight: return Color(nsColor: NSColor(srgbRed: 0.95, green: 0.95, blue: 0.96, alpha: 1))
        case .insetDark: return Color(nsColor: NSColor(srgbRed: 0.16, green: 0.17, blue: 0.20, alpha: 1))
        case .outline: return Color.white.opacity(0.35)
        case .retro: return Color(nsColor: NSColor(srgbRed: 0.91, green: 0.89, blue: 0.85, alpha: 1))
        case .border, .default: return Color.white
        }
    }

    private var edge: Color {
        switch card {
        case .glassLight, .liquid: return Color.white.opacity(0.95)
        case .glassDark: return Color.white.opacity(0.4)
        case .insetLight: return Color.black.opacity(0.18)
        case .insetDark: return Color.black.opacity(0.55)
        case .outline: return Color.black.opacity(0.75)
        case .border: return Color.black
        case .retro: return Color(nsColor: NSColor(srgbRed: 0.23, green: 0.20, blue: 0.17, alpha: 1))
        case .default: return Color.black.opacity(0.08)
        }
    }

    private var edgeWidth: CGFloat {
        switch card {
        case .border: return 5
        case .insetLight, .insetDark: return 6
        case .retro: return 2.5
        case .outline: return 1.5
        case .glassLight, .glassDark, .liquid: return 2
        case .default: return 1
        }
    }
}

private struct DiagonalStripes: View {
    var body: some View {
        GeometryReader { geo in
            Path { path in
                var x = -geo.size.height
                while x < geo.size.width + geo.size.height {
                    path.move(to: CGPoint(x: x, y: geo.size.height))
                    path.addLine(to: CGPoint(x: x + geo.size.height, y: 0))
                    x += 7
                }
            }
            .stroke(Color(nsColor: NSColor(srgbRed: 0.86, green: 0.34, blue: 0.08, alpha: 0.9)), lineWidth: 3)
        }
    }
}

private struct ShadowStudy: View {
    let kind: ShadowKind
    let image: NSImage?

    private var adaptiveFill: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                LinearGradient(
                    colors: [
                        Color(nsColor: NSColor(srgbRed: 0.98, green: 0.55, blue: 0.28, alpha: 1)),
                        Color(nsColor: NSColor(srgbRed: 0.86, green: 0.28, blue: 0.18, alpha: 1))
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: NSColor(srgbRed: 0.93, green: 0.93, blue: 0.94, alpha: 1)))
            switch kind {
            case .none:
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white)
                    .padding(9)
            case .spread:
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.28), radius: 6, y: 4)
                    .padding(10)
            case .hug:
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.45), radius: 1.2, y: 1)
                    .padding(8)
            case .adaptive:
                Color.clear
                    .overlay(adaptiveFill)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding(4)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private enum TemplateFilter: String, CaseIterable {
    case all, image, angled
    var title: String {
        switch self {
        case .all: return "All"
        case .image: return "Image"
        case .angled: return "Angled"
        }
    }
    var symbol: String {
        switch self {
        case .all: return "square.grid.2x2.fill"
        case .image: return "photo"
        case .angled: return "rotate.right"
        }
    }
    var kind: TemplateKind? {
        switch self {
        case .all: return nil
        case .image: return .image
        case .angled: return .angled
        }
    }
}

private struct TemplatesPanel: View {
    @ObservedObject var model: EditorModel
    var shot: NSImage?
    var onClose: () -> Void
    @State private var filter: TemplateFilter = .all
    @State private var group: String?

    var body: some View {
        ZStack {
            Color.black.opacity(0.22)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)
            VStack(alignment: .leading, spacing: 0) {
                header
                filters
                    .padding(.horizontal, 22)
                    .padding(.bottom, 8)
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        if let group {
                            section(group, templates: TemplateLibrary.inGroup(group, kind: filter.kind), limit: nil)
                        } else {
                            ForEach(TemplateLibrary.groups, id: \.self) { name in
                                let items = TemplateLibrary.inGroup(name, kind: filter.kind)
                                if !items.isEmpty {
                                    section(name, templates: items, limit: 2)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 22)
                }
            }
            .frame(width: 720, height: 620)
            .shotliGlass(.panel, radius: ShotliGlass.radiusOverlay)
        }
    }

    private var header: some View {
        HStack {
            if group != nil {
                Button(action: { group = nil }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(ink)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }
            Text(group ?? "Templates")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(ink)
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(ink)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.black.opacity(0.06)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 22)
        .padding(.top, 20)
        .padding(.bottom, 14)
    }

    private var filters: some View {
        HStack(spacing: 8) {
            ForEach(TemplateFilter.allCases, id: \.self) { item in
                let on = filter == item
                Button(action: { filter = item }) {
                    HStack(spacing: 6) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 12, weight: .semibold))
                        Text(item.title)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(on ? .white : ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(on ? Color.black : Color.clear))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    private func section(_ name: String, templates: [ShotTemplate], limit: Int?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ink)
                Spacer()
                if limit != nil, templates.count > 2 {
                    Button(action: { group = name }) {
                        Text("See all")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(ink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.black.opacity(0.06)))
                    }
                    .buttonStyle(.plain)
                }
            }
            let shown = limit == nil ? templates : Array(templates.prefix(limit ?? templates.count))
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                ForEach(shown) { template in
                    Button(action: {
                        model.applyTemplate(template)
                        onClose()
                    }) {
                        VStack(spacing: 8) {
                            TemplateCard(template: template, shot: shot)
                            Text(template.name)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct TemplateCard: View {
    let template: ShotTemplate
    let shot: NSImage?

    var body: some View {
        ZStack {
            TemplateBackground(background: template.style.background)
            GeometryReader { geo in
                let width = min(geo.size.width * 0.8, geo.size.height * 1.45)
                shotFace
                    .frame(width: width)
                    .rotation3DEffect(.degrees(template.style.tiltX), axis: (x: 1, y: 0, z: 0), perspective: 0.4)
                    .rotation3DEffect(.degrees(template.style.tiltY), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
                    .shadow(color: Color.black.opacity(0.28), radius: 18, y: 14)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, y: 1)
                    .position(
                        x: geo.size.width * (0.5 + template.style.shiftX * 0.18),
                        y: geo.size.height * (0.5 + template.style.shiftY * 0.08)
                    )
            }
        }
        .frame(height: 196)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var shotFace: some View {
        VStack(spacing: 0) {
            if template.style.frame != .none {
                HStack(spacing: 3) {
                    Circle().fill(Color(nsColor: NSColor(hex: "#FF5F57")!)).frame(width: 6, height: 6)
                    Circle().fill(Color(nsColor: NSColor(hex: "#FEBC2E")!)).frame(width: 6, height: 6)
                    Circle().fill(Color(nsColor: NSColor(hex: "#28C840")!)).frame(width: 6, height: 6)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 8)
                .frame(height: 18)
                .frame(maxWidth: .infinity)
                .background(template.style.frame == .browser ? Color(nsColor: NSColor(hex: "#F3F3F3")!) : Color(nsColor: NSColor(hex: "#ECECEC")!))
            }
            if let shot {
                Image(nsImage: shot)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Color.white
                    .aspectRatio(16.0 / 10.0, contentMode: .fit)
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct TemplateBackground: View {
    let background: Background

    var body: some View {
        switch background {
        case .color(let hex):
            Color(nsColor: NSColor(hex: hex) ?? .white)
        case .gradient(let from, let mid, let to, _):
            LinearGradient(
                colors: [Color(nsColor: NSColor(hex: from)!), Color(nsColor: NSColor(hex: mid ?? to)!), Color(nsColor: NSColor(hex: to)!)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .wallpaper(let id):
            Color.clear
                .overlay {
                    if let image = SceneThumbs.image(id) {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color(nsColor: NSColor(srgbRed: 0.93, green: 0.93, blue: 0.94, alpha: 1))
                    }
                }
                .clipped()
        }
    }
}

private enum TitlebarClicks {
    private static var installed = false

    static func install(on window: NSWindow) {
        _ = window.standardWindowButton(.closeButton)
        guard !installed, let cls = NSClassFromString("NSTitlebarContainerView") else { return }
        let selector = #selector(NSView.hitTest(_:))
        guard let method = class_getInstanceMethod(cls, selector) else { return }
        installed = true
        let block: @convention(block) (AnyObject, NSPoint) -> NSView? = { object, point in
            guard let view = object as? NSView else { return nil }
            let local = view.convert(point, from: view.superview)
            for kind in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
                guard let button = view.window?.standardWindowButton(kind), !button.isHidden else { continue }
                let inButton = button.convert(local, from: view)
                if button.bounds.insetBy(dx: -6, dy: -6).contains(inButton) { return button }
            }
            return nil
        }
        method_setImplementation(method, imp_implementationWithBlock(block))
    }
}
