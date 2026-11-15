import AppKit
import ObjectiveC
import SwiftUI
import UniformTypeIdentifiers

private let accent = ShotliGlass.accent
private let leftRailMin: CGFloat = 232
private let leftRailIdeal: CGFloat = 280
private let rightRailMin: CGFloat = 248
private let rightRailIdeal: CGFloat = 292
private let railInset: CGFloat = 14

private enum LeftRailMode: String, CaseIterable {
    case recipes, backgrounds
    var title: String {
        switch self {
        case .recipes: return "Recipes"
        case .backgrounds: return "Backgrounds"
        }
    }
}

private enum InspectorTab {
    case layout, style
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
    @AppStorage("shotli.leftRail") private var railMode = LeftRailMode.recipes.rawValue
    @State private var showLibrary = false
    @State private var inspectorTab: InspectorTab = .layout
    @State private var hoveredPreset: String?
    @State private var showMagic = false
    @State private var magicColors: [MagicColor] = []
    @State private var magicBackgrounds: [MagicBackground] = []
    @State private var settingsSheet = false
    @ObservedObject private var settings = ShotliSettings.shared
    @Environment(\.colorScheme) private var colorScheme
    private var ink: Color { ShotliGlass.ink(colorScheme) }
    private var line: Color { ShotliGlass.line(colorScheme) }
    @ObservedObject private var projectPrompt = ProjectPrompt.shared
    @ObservedObject private var savedStyles = StyleStore.shared
    @ObservedObject private var exportSettings = ExportSettings.shared
    @State private var showExportOptions = false
    @State private var showStyles = false
    private let dockTools: [Tool] = [.select, .rect, .rectFill, .circle, .line, .arrow, .draw, .text, .marker, .pixelate, .blur, .crop]
    private let fontSizes: [CGFloat] = [18, 24, 32, 44]
    private let strokeWidths: [CGFloat] = [2, 4, 6, 8]

    var body: some View {
        VStack(spacing: 0) {
            if model.picture == nil && model.projectFolder == nil {
                stage {
                    LibraryHome(onOpen: { model.openPanel() })
                }
            } else if showMotion && model.picture != nil {
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
                                    .overlay {
                                        if model.picture == nil {
                                            emptyProject
                                        }
                                    }
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: ShotliGlass.radiusPanel, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: ShotliGlass.radiusPanel, style: .continuous)
                                .stroke(ShotliGlass.hairline(colorScheme), lineWidth: 1)
                                .allowsHitTesting(false)
                        )
                        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.32 : 0.07), radius: 22, y: 10)
                        if model.picture != nil {
                        HStack(spacing: 8) {
                            stageChip("move.3d", "Motion", help: "Open Motion Studio") { showMotion = true }
                            stageChip("text.viewfinder", "Copy Text", help: "Copy the words in this picture (⌘⇧T)") { model.copyText() }
                            stageChip("eye.slash", "Hide Sensitive Info", help: "Find emails, numbers, and keys to hide (⌘⇧H)") { model.showHideSensitive = true }
                                .popover(isPresented: $model.showHideSensitive, arrowEdge: .top) {
                                    SensitivePopover(model: model)
                                }
                        }
                        }
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
        .shotliAppearance()
        .overlay {
            if showLibrary {
                libraryBrowser
            }
        }
        .onAppear {
            refreshMagic()
            configureWindow()
        }
        .onChange(of: pictureKey) { _ in
            refreshMagic()
            if model.picture == nil {
                model.previewStyle = nil
                showMotion = false
                showLibrary = false
                model.previewBackground = nil
            }
        }
        .onChange(of: model.style) { _ in model.scheduleProjectSave() }
        .onChange(of: model.annotations) { _ in model.scheduleProjectSave() }
        .onChange(of: model.crop) { _ in model.scheduleProjectSave() }
        .onChange(of: model.layers) { _ in model.scheduleProjectSave() }
        .onChange(of: colorScheme) { _ in
            settings.appearance.apply()
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
        .sheet(isPresented: $projectPrompt.naming, onDismiss: { projectPrompt.cancel() }) {
            NewProjectSheet(prompt: projectPrompt)
        }
    }

    private var studioBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                if model.picture != nil || model.projectFolder != nil {
                    iconButton("chevron.left", help: "Library") { model.showLibrary() }
                    projectTitle
                        .frame(minWidth: 72, idealWidth: 160, maxWidth: 240, alignment: .leading)
                    if model.picture != nil {
                    Button(action: { railMode = LeftRailMode.recipes.rawValue }) {
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(LinearGradient(colors: [Color(nsColor: NSColor(hex: "#F78529")!), Color(nsColor: NSColor(hex: "#7A42E8")!)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 16, height: 16)
                            Text("Recipes")
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .foregroundColor(ink)
                        .padding(.horizontal, 4)
                        .frame(height: 32)
                        .fixedSize(horizontal: true, vertical: false)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(2)
                    .help("Screenshot Recipes: complete looks in one click")
                    }
                }
            }
            .padding(.leading, 8)
            .frame(minWidth: leftRailMin, alignment: .leading)

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
                    iconButton("xmark.circle", help: "Start Over") { model.startOver() }
                    toolDock
                }
            }
            .frame(minWidth: 240, idealWidth: 520, maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .layoutPriority(1)

            if model.picture != nil {
                HStack(spacing: 8) {
                    saveProjectButton
                    exportButton
                }
                .padding(.trailing, 8)
                .fixedSize(horizontal: true, vertical: false)
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

    private var projectTitle: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(model.projectName ?? "Screenshot")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(ink)
                .lineLimit(1)
                .truncationMode(.tail)
            if !model.saveState.label.isEmpty {
                Text(model.saveState.label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(model.saveState.isFailure ? ShotliGlass.error(colorScheme) : .secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var emptyProject: some View {
        VStack(spacing: 10) {
            Text("Add an image to your project")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(ink)
                .multilineTextAlignment(.center)
            Text("Open a screenshot or image to start creating.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 8) {
                Button(action: { model.importFile(into: model.projectFolder, screenshotsOnly: true) }) {
                    Text("Open Screenshot")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .frame(height: 30)
                        .background(Capsule().fill(accent))
                }
                .buttonStyle(PressFadeButtonStyle())
                .accessibilityLabel("Open Screenshot")
                Button(action: { model.importFile(into: model.projectFolder, screenshotsOnly: false) }) {
                    Text("Open Image")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(ink)
                        .padding(.horizontal, 12)
                        .frame(height: 30)
                        .shotliCapsuleChip()
                }
                .buttonStyle(PressFadeButtonStyle())
                .accessibilityLabel("Open Image")
            }
            .padding(.top, 4)
        }
        .padding(24)
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func stageChip(_ symbol: String, _ title: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundColor(ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .shotliGlass(.compact, radius: 18)
        }
        .buttonStyle(PressFadeButtonStyle())
        .fixedSize(horizontal: true, vertical: true)
        .help(help)
        .accessibilityLabel(title)
    }

    private var saveProjectButton: some View {
        Button(action: {
            model.prepareSavePopover()
            model.showSaveProjects = true
        }) {
            HStack(spacing: 6) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 12, weight: .semibold))
                Text("Save to Project")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(ink)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .shotliCapsuleChip()
            .contentShape(Capsule())
        }
        .buttonStyle(PressFadeButtonStyle())
        .help("Save this composition into a project folder")
        .accessibilityLabel("Save to Project")
        .popover(isPresented: $model.showSaveProjects, arrowEdge: .bottom) {
            SaveProjectPopover(model: model)
        }
    }

    private var exportButton: some View {
        HStack(spacing: 0) {
            Button(action: { model.exportImage() }) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Export")
                        .font(.system(size: 13, weight: .semibold))
                    Text(exportSettings.summary)
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
            .help("Export \(exportSettings.summary) (⌘S)")
            .accessibilityLabel("Export \(exportSettings.summary)")
            Button(action: { showExportOptions = true }) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 20, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressFadeButtonStyle())
            .help("Export format and size")
            .accessibilityLabel("Export format and size")
            .popover(isPresented: $showExportOptions, arrowEdge: .bottom) {
                ExportOptionsForm()
            }
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

    /// The left side is the creative library: the screenshots in this composition, then backgrounds to put behind them.
    /// Recipes are whole compositions; Backgrounds are single assets. Each has its own tab so they stay distinct.
    private var leftRail: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                ForEach(LeftRailMode.allCases, id: \.self) { mode in
                    tabButton(mode.title, on: railMode == mode.rawValue) { railMode = mode.rawValue }
                }
            }
            .padding(3)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(ShotliGlass.quiet(colorScheme)))
            .padding(.horizontal, railInset)
            .padding(.top, railInset)
            .padding(.bottom, 12)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Library")
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        screenshotRow
                        if model.picture != nil {
                            addScreenshotButton
                        }
                    }
                    if railMode == LeftRailMode.recipes.rawValue {
                        RecipeLibraryView(model: model, onChangeBackground: { railMode = LeftRailMode.backgrounds.rawValue })
                    } else {
                        BackgroundLibraryView(model: model, onExpand: { showLibrary = true })
                        magicPresetRow
                        mediaWell
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, railInset)
                .padding(.bottom, 18)
            }
        }
        .shotliGlass(.panel, radius: ShotliGlass.radiusPanel)
    }

    private var libraryBrowser: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .onTapGesture { showLibrary = false }
            ScrollView(.vertical) {
                BackgroundLibraryView(model: model, wide: true, onClose: { showLibrary = false })
                    .padding(22)
            }
            .frame(width: 760, height: 580)
            .shotliGlass(.panel, radius: ShotliGlass.radiusOverlay)
        }
        .onExitCommand { showLibrary = false }
    }

    private var frameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            caption("Frame")
            HStack(spacing: 4) {
                tabButton("Mockup", on: model.style.frame == .none) {
                    model.setFrame(.none)
                }
                tabButton("Frame", on: model.style.frame != .none) {
                    if model.style.frame == .none { model.setFrame(.browser) }
                }
            }
            .padding(3)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(ShotliGlass.quiet(colorScheme)))
            if model.style.frame != .none {
                HStack(spacing: 4) {
                    tabButton("Browser", on: model.style.frame == .browser) { model.setFrame(.browser) }
                    tabButton("Window", on: model.style.frame == .desktop) { model.setFrame(.desktop) }
                }
                .padding(3)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(ShotliGlass.quiet(colorScheme)))
            }
        }
    }

    private var editingMark: Bool {
        showsText || showsStroke || showsPixel || showsBlur || model.selected != nil
    }

    /// The right side follows the selection: a mark's settings while one is selected or being drawn, the picture's otherwise.
    private var rightRail: some View {
        Group {
            if editingMark {
                markPanel
            } else {
                picturePanel
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .shotliGlass(.panel, radius: ShotliGlass.radiusPanel)
    }

    private var markPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(markTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(ink)
                Spacer(minLength: 8)
                Button("Done") {
                    model.selectedID = nil
                    model.tool = .select
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(accent)
                .help("Back to the picture settings")
            }
            .padding(.horizontal, railInset)
            .padding(.top, railInset)
            .padding(.bottom, 12)
            Divider()
                .padding(.horizontal, railInset)
            ScrollView(.vertical) {
                markControls
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(railInset)
            }
        }
    }

    private var markTitle: String {
        switch model.selected {
        case .text: return "Text"
        case .line(let mark): return mark.arrow ? "Arrow" : "Line"
        case .draw: return "Drawing"
        case .marker: return "Step"
        case .shape(let mark):
            switch mark.kind {
            case .rect: return "Box"
            case .rectFill: return "Filled box"
            case .circle: return "Circle"
            case .pixelate: return "Pixelate"
            case .blur: return "Blur"
            }
        case nil: break
        }
        switch model.tool {
        case .text: return "Text"
        case .arrow: return "Arrow"
        case .line: return "Line"
        case .draw: return "Drawing"
        case .rect: return "Box"
        case .rectFill: return "Filled box"
        case .circle: return "Circle"
        case .pixelate: return "Pixelate"
        case .blur: return "Blur"
        default: return "Mark"
        }
    }

    /// With nothing marked, the inspector shows the picture: how it sits on the canvas, or how it looks.
    private var picturePanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                styleButton
                HStack(spacing: 4) {
                    tabButton("Layout", on: inspectorTab == .layout) { inspectorTab = .layout }
                    tabButton("Style", on: inspectorTab == .style) { inspectorTab = .style }
                }
                .padding(3)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(ShotliGlass.quiet(colorScheme)))
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Inspector")
            }
            .padding(.horizontal, railInset)
            .padding(.top, railInset)
            .padding(.bottom, 12)
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 18) {
                    if inspectorTab == .layout {
                        layoutInspector
                    } else {
                        styleInspector
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, railInset)
                .padding(.bottom, railInset)
            }
        }
    }

    @ViewBuilder
    private var layoutInspector: some View {
        VStack(alignment: .leading, spacing: 8) {
            caption("Padding")
            HStack(spacing: 2) {
                densityButton("Tight", padding: 28)
                densityButton("Even", padding: 72)
                densityButton("Airy", padding: 120)
            }
            .padding(3)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(ShotliGlass.quiet(colorScheme)))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Padding")
            percentSlider(
                "Size",
                value: Binding(get: { model.screenshotFill }, set: { model.beginGesture(); model.setScreenshotFill($0) }),
                range: 0.4...0.98,
                help: "How much of the canvas the screenshot fills"
            )
        }
        canvasPicker
        if model.canPosition {
            positionPicker
        }
        VStack(alignment: .leading, spacing: 8) {
            zoomRow
            tiltRow
            if abs(model.style.tiltX) + abs(model.style.tiltY) > 0.5 {
                metricSlider("Turn", value: Binding(get: { model.style.tiltY }, set: { model.beginGesture(); model.setTiltAngles(x: model.style.tiltX, y: $0) }), range: -40...40)
                metricSlider("Lean", value: Binding(get: { model.style.tiltX }, set: { model.beginGesture(); model.setTiltAngles(x: $0, y: model.style.tiltY) }), range: -30...30)
            }
        }
        if model.screenshotCount >= 2 {
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                caption(model.layoutHeadline)
                if let note = model.layoutNote {
                    Text(note)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            layerStrip
            ForEach(ShotLayouts.choices(for: model.screenshotCount)) { preset in
                layoutPresetCard(preset)
            }
        }
    }

    @ViewBuilder
    private var styleInspector: some View {
        frameSection
        styleGrid
        borderSection
        shadowSection
        decorSection
        lightControl
        visibilitySection
        detailsSection
    }

    private var styleName: String {
        if let saved = savedStyles.styles.first(where: { $0.style.style == model.style }) { return saved.name }
        if let preset = Presets.all.first(where: { $0.style == model.style }) { return preset.name }
        return "Custom"
    }

    private var styleButton: some View {
        Button(action: { showStyles.toggle() }) {
            HStack(spacing: 10) {
                layoutCard(model.style)
                    .frame(width: 56)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Style")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text(styleName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(ink)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(ShotliGlass.surface(colorScheme))
                    .shadow(color: Color.black.opacity(0.06), radius: 8, y: 2)
            )
        }
        .buttonStyle(.plain)
        .help("Choose a style")
        .accessibilityLabel("Style, \(styleName)")
        .popover(isPresented: $showStyles, arrowEdge: .leading) {
            stylePicker
        }
    }

    private var stylePicker: some View {
        let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        return ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 14) {
                myStyles
                caption("Presets")
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Presets.all) { preset in
                        presetCard(preset)
                    }
                }
            }
            .padding(16)
        }
        .frame(width: 420, height: 540)
    }

    private var myStyles: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                caption("My styles")
                Spacer()
                iconButton("plus", help: "Save this look as a style") { model.saveCurrentStyle() }
                    .frame(height: 20)
            }
            if savedStyles.styles.isEmpty {
                Text("Save the current look with +. Right-click a saved style to open new screenshots with it.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(savedStyles.styles) { saved in
                presetCard(saved.preset)
                    .overlay(alignment: .topTrailing) {
                        if savedStyles.defaultID == saved.id {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(accent)
                                .padding(8)
                                .help("New screenshots open with this style")
                        }
                    }
                    .contextMenu {
                        Button(savedStyles.defaultID == saved.id ? "Stop Using for New Screenshots" : "Use for New Screenshots") {
                            savedStyles.setDefault(savedStyles.defaultID == saved.id ? nil : saved.id)
                        }
                        Button("Rename…") { model.renameStyle(saved) }
                        Divider()
                        Button("Delete") { savedStyles.delete(saved.id) }
                    }
            }
            }
        }
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
            Button("Fit") { model.fit() }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(accent)
                .help("Fit the picture in the window (⌘0)")
                .accessibilityLabel("Fit the picture in the window")
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
                            .fill(tilted ? ShotliGlass.segment(colorScheme) : Color.clear)
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
                            .fill(tilted ? Color.clear : ShotliGlass.segment(colorScheme))
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
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(ShotliGlass.quiet(colorScheme)))
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
                            .stroke(active ? ShotliGlass.focusRing(colorScheme) : Color.clear, lineWidth: 1)
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
                        .fill(on ? ShotliGlass.segment(colorScheme) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(on ? ShotliGlass.segmentEdge(colorScheme) : Color.clear, lineWidth: 0.6)
                        )
                )
        }
        .buttonStyle(PressFadeButtonStyle())
        .accessibilityLabel(title)
        .accessibilityAddTraits(on ? .isSelected : AccessibilityTraits())
    }

    private var canvasPicker: some View {
        let fixed = model.style.canvasWidth > 0 && model.style.canvasHeight > 0
        return VStack(alignment: .leading, spacing: 8) {
            caption("Canvas")
            HStack(spacing: 2) {
                ForEach([CanvasRatio.auto, .sixteenNine, .fourThree, .square]) { ratio in
                    segment(
                        ratio == .auto ? "Fit" : ratio.label,
                        on: !fixed && model.style.canvas == ratio,
                        help: ratio == .auto ? "The canvas hugs the screenshot" : "A \(ratio.label) canvas with room to place the screenshot"
                    ) {
                        model.setCanvas(ratio)
                    }
                }
            }
            .padding(3)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(ShotliGlass.quiet(colorScheme)))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Canvas")
        }
    }

    private var positionPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            caption("Position")
            HStack(alignment: .center, spacing: 12) {
                VStack(spacing: 3) {
                    ForEach(-1...1, id: \.self) { row in
                        HStack(spacing: 3) {
                            ForEach(-1...1, id: \.self) { column in
                                positionCell(column: column, row: row)
                            }
                        }
                    }
                }
                .padding(4)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(ShotliGlass.quiet(colorScheme)))
                Text("Drag the screenshot on the canvas, or pick a spot.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func positionCell(column: Int, row: Int) -> some View {
        let on = model.isAligned(column: column, row: row)
        let names = ["Top", "Middle", "Bottom"]
        let sides = ["Left", "Center", "Right"]
        let name = row == 0 && column == 0 ? "Center" : "\(names[row + 1]) \(sides[column + 1])"
        return Button(action: { model.align(column: column, row: row) }) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(on ? accent : ShotliGlass.segment(colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .strokeBorder(Color.black.opacity(on ? 0 : 0.08), lineWidth: 0.5)
                )
                .frame(width: 18, height: 12)
        }
        .buttonStyle(PressFadeButtonStyle())
        .help(name)
        .accessibilityLabel(name)
        .accessibilityAddTraits(on ? .isSelected : AccessibilityTraits())
    }

    private func segment(_ title: String, on: Bool, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: on ? .semibold : .medium))
                .foregroundColor(on ? ink : .secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(on ? ShotliGlass.segment(colorScheme) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.black.opacity(on ? 0.06 : 0), lineWidth: 0.5)
                        )
                )
        }
        .buttonStyle(PressFadeButtonStyle())
        .help(help)
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
                        .fill(on ? ShotliGlass.segment(colorScheme) : Color.clear)
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
            Color.clear.overlay(presetPreview(style.background))
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
                    .fill(ShotliGlass.surface(colorScheme))
                    .shadow(color: Color.black.opacity(0.06), radius: 8, y: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private var addScreenshotButton: some View {
        Button(action: { model.addScreenshots() }) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                Text(model.screenshotCount >= ShotLayouts.maximum ? "6 screenshots" : "Add screenshot")
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundColor(ink)
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(ShotliGlass.quiet(colorScheme)))
        }
        .buttonStyle(.plain)
        .disabled(model.screenshotCount >= ShotLayouts.maximum)
        .help(model.screenshotCount >= ShotLayouts.maximum ? "This composition holds 6 screenshots." : "Add a screenshot to this composition")
        .accessibilityLabel("Add screenshot")
    }

    private var layerStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(model.layers.sorted { $0.order < $1.order }) { layer in
                let selected = model.selectedLayerID == layer.id
                HStack(spacing: 4) {
                    Button(action: { model.selectLayer(layer.id) }) {
                        Text(layer.name)
                            .font(.system(size: 11, weight: selected ? .semibold : .medium))
                            .foregroundColor(selected ? ink : .secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    layerIcon("square.on.square", help: "Duplicate") { model.duplicateLayer(layer.id) }
                    layerIcon("chevron.down", help: "Send backward") { model.sendLayer(layer.id, forward: false) }
                    layerIcon("chevron.up", help: "Bring forward") { model.sendLayer(layer.id, forward: true) }
                    layerIcon("trash", help: "Delete screenshot") { model.removeLayer(layer.id) }
                }
                .padding(.horizontal, 8)
                .frame(height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(selected ? ShotliGlass.selectedNav(colorScheme) : ShotliGlass.quiet(colorScheme))
                )
            }
            HStack(spacing: 8) {
                Text("Spacing")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(ink)
                    .frame(width: 54, alignment: .leading)
                Slider(
                    value: Binding(get: { model.layerGap }, set: { model.setLayerGap($0) }),
                    in: 0.02...0.10,
                    onEditingChanged: { editing in
                        if editing { model.beginGesture() } else { model.endGesture() }
                    }
                )
                .accessibilityLabel("Layout spacing")
            }
        }
    }

    private func layerIcon(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(width: 16, height: 16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }

    private func layoutPresetCard(_ preset: ShotLayoutPreset) -> some View {
        let active = model.activeLayoutID == preset.id.rawValue
        let hovered = hoveredPreset == preset.id.rawValue
        return Button(action: { model.applyLayout(preset) }) {
            VStack(alignment: .leading, spacing: 6) {
                LayoutSketch(boxes: ShotLayouts.boxes(preset.id, count: model.screenshotCount, gap: model.layerGap))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(active ? accent : (hovered ? Color.black.opacity(0.2) : Color.clear), lineWidth: active ? 2 : 1)
                    )
                Text(preset.name)
                    .font(.system(size: 12, weight: active ? .semibold : .medium))
                    .foregroundColor(active ? ink : .secondary)
                    .lineLimit(1)
                Text(preset.detail)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(PressFadeButtonStyle())
        .onHover { hovering in
            if hovering {
                hoveredPreset = preset.id.rawValue
            } else if hoveredPreset == preset.id.rawValue {
                hoveredPreset = nil
            }
        }
        .help(preset.detail)
        .accessibilityLabel("\(preset.name) layout")
        .accessibilityAddTraits(active ? .isSelected : AccessibilityTraits())
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
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(showMagic ? ShotliGlass.pressed(colorScheme) : ShotliGlass.quiet(colorScheme)))
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
                            .fill(ShotliGlass.quiet(colorScheme))
                            .frame(height: 96)
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(ShotliGlass.surface(colorScheme))
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
                                        .stroke(active ? ShotliGlass.emphasis(colorScheme) : ShotliGlass.hairline(colorScheme), lineWidth: active ? 2 : 1)
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
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(ShotliGlass.quiet(colorScheme)))
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
                    .fill(on ? ShotliGlass.segmentSolid(colorScheme) : Color.clear)
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
                                        .stroke(active ? ShotliGlass.emphasis(colorScheme) : Color.clear, lineWidth: 2)
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
            metricSlider("Depth", value: Binding(get: { model.style.shadow }, set: { model.beginGesture(); model.setShadow($0) }), range: 0...100)
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
                        .fill(model.style.hideMockup ? ShotliGlass.segmentSolid(colorScheme) : ShotliGlass.quiet(colorScheme))
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
                    .stroke(ShotliGlass.line(colorScheme), lineWidth: 1)
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

    private var decorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            caption("Decoration")
            HStack(spacing: 2) {
                ForEach(Decor.allCases, id: \.self) { decor in
                    segment(decor.title, on: model.style.decor == decor, help: "Decoration: \(decor.title)") {
                        model.setDecor(decor)
                    }
                }
            }
            .padding(3)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(ShotliGlass.quiet(colorScheme)))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Decoration")
        }
    }

    private func percentSlider(_ title: String, value: Binding<CGFloat>, range: ClosedRange<CGFloat>, help: String) -> some View {
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
            .accessibilityLabel(title)
            Text("\(Int((value.wrappedValue * 100).rounded()))%")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(ink)
                .monospacedDigit()
                .frame(width: 38, alignment: .trailing)
        }
        .padding(.leading, 4)
        .padding(.trailing, 8)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(ShotliGlass.quiet(colorScheme)))
        .help(help)
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
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(ShotliGlass.quiet(colorScheme)))
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
                caption("Size")
                choiceRow(fontSizes.map { ("\(Int($0))", $0) }, selected: text.fontSize) { size in
                    model.setSelectedFontSize(size)
                }
            } else if model.tool == .text {
                caption("Size")
                choiceRow(fontSizes.map { ("\(Int($0))", $0) }, selected: model.brush.fontSize) { size in
                    model.brush.fontSize = size
                }
            }
            if showsStroke {
                caption("Thickness")
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
            caption("Colour")
            swatchRow(Presets.inks, selected: currentInk) { color in
                model.updateSelectedColor(color)
            }
            if model.selectedID != nil {
                Button(action: { model.deleteSelected() }) {
                    Text("Delete")
                        .frame(maxWidth: .infinity)
                }
                .padding(.top, 4)
            }
        }
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
                                    .fill(ShotliGlass.surfaceSecondary(colorScheme))
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
                        .background(RoundedRectangle(cornerRadius: 6).fill(option.1 == selected ? ShotliGlass.selectedNav(colorScheme) : ShotliGlass.quiet(colorScheme)))
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
        case .image:
            BackgroundSwatch(background: background)
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
        guard !model.draggingOut else { return false }
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

private struct LayoutSketch: View {
    var boxes: [LayerBox]

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: NSColor(srgbRed: 0.93, green: 0.94, blue: 0.95, alpha: 1)))
                ForEach(Array(boxes.enumerated()), id: \.offset) { _, box in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.16), radius: 3, y: 1)
                        .frame(width: max(4, geo.size.width * box.width), height: max(4, geo.size.height * box.height))
                        .offset(x: geo.size.width * box.x, y: geo.size.height * box.y)
                }
            }
        }
        .frame(height: 78)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
