import AppKit
import SwiftUI
import UniformTypeIdentifiers

private let accent = Color(nsColor: NSColor(hex: "#3478F6")!)
private let ink = Color(nsColor: NSColor(hex: "#222222")!)
private let line = Color(nsColor: NSColor(hex: "#DADADA")!)
private let workspace = Color(nsColor: NSColor(srgbRed: 0.945, green: 0.945, blue: 0.945, alpha: 1))

private enum BackgroundKind: String, CaseIterable, Identifiable {
    case color, gradient, wallpaper
    var id: String { rawValue }
    var label: String {
        switch self {
        case .color: return "Colour"
        case .gradient: return "Gradient"
        case .wallpaper: return "Wallpaper"
        }
    }
}

struct EditorView: View {
    @ObservedObject var model: EditorModel
    @State private var dropTarget = false
    @State private var didConfigure = false
    @State private var showBackground = false

    private let dockTools: [Tool] = [.select, .rect, .rectFill, .circle, .line, .arrow, .draw, .text, .marker, .pixelate, .blur, .crop]
    private let fontSizes: [CGFloat] = [18, 24, 32, 44]
    private let strokeWidths: [CGFloat] = [2, 4, 6, 8]

    var body: some View {
        VStack(spacing: 0) {
            header
            if model.picture == nil {
                stage {
                    LibraryHome(onOpen: { model.openPanel() })
                }
            } else {
                HStack(spacing: 0) {
                    stage {
                        CanvasView(model: model)
                    }
                    .overlay(alignment: .bottom) {
                        toolDock
                            .padding(.bottom, 16)
                    }
                    Divider()
                    inspector
                        .frame(width: 280)
                        .background(Color.white)
                }
            }
        }
        .background(workspace)
        .onAppear(perform: configureWindow)
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

    private var header: some View {
        ZStack {
            WindowDrag()
            HStack(spacing: 8) {
                if model.picture != nil {
                    Button(action: { model.showLibrary() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(ink)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .help("Back to your screenshots (⌘L)")
                    Spacer(minLength: 8)
                    iconButton("arrow.uturn.backward", help: "Undo") { model.undo() }
                        .disabled(!model.canUndo)
                    iconButton("arrow.uturn.forward", help: "Redo") { model.redo() }
                        .disabled(!model.canRedo)
                    Button(action: { model.exportPNG() }) {
                        Text("Export PNG")
                    }
                    .help("Export PNG (⌘S)")
                } else {
                    Button(action: { model.openPanel() }) {
                        Label("Open", systemImage: "folder")
                    }
                    .help("Open a screenshot (⌘O)")
                    Spacer(minLength: 8)
                }
            }
            .padding(.leading, 86)
            .padding(.trailing, 12)
        }
        .frame(height: 52)
        .background(Color.white)
        .overlay(Rectangle().frame(height: 1).foregroundColor(line), alignment: .bottom)
    }

    private var inspector: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Look")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(ink)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    lookRow
                        .padding(.top, 8)
                    backgroundRow
                    if showsText || showsStroke || showsPixel || showsBlur || model.selected != nil {
                        section("Mark") { markControls }
                    }
                    section("Layout") { layoutControls }
                    Color.clear.frame(height: 12)
                }
            }
            Button(action: { model.showLibrary() }) {
                Text("Done")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(accent)
            .controlSize(.large)
            .help("Back to your screenshots")
            .padding(12)
        }
    }

    private var lookRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Presets.all) { preset in
                    let active = preset.style == model.style
                    Button(action: { model.applyPreset(preset) }) {
                        Text(preset.name)
                            .font(.system(size: 12))
                            .padding(.horizontal, 10)
                            .frame(height: 28)
                            .foregroundColor(active ? .white : ink)
                            .background(Capsule().fill(active ? Color(nsColor: NSColor(hex: "#222222")!) : Color.black.opacity(0.05)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var backgroundRow: some View {
        Button(action: { showBackground = true }) {
            HStack(spacing: 8) {
                Text("Background")
                    .font(.system(size: 13))
                    .foregroundColor(ink)
                Spacer()
                presetPreview(model.style.background)
                    .frame(width: 16, height: 16)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black.opacity(0.1), lineWidth: 1))
                Text(backgroundTitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .frame(height: 36)
            .background(RoundedRectangle(cornerRadius: 8).stroke(line))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showBackground, arrowEdge: .leading) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Background")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Button("None") {
                        model.setBackground(.color("transparent"))
                        showBackground = false
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
                backgroundControls
            }
            .padding(14)
            .frame(width: 300)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    private var toolDock: some View {
        HStack(spacing: 1) {
            ForEach(Array(dockTools.enumerated()), id: \.element) { index, tool in
                if index == 4 || index == 7 || index == 9 || index == 11 {
                    Rectangle().fill(line).frame(width: 1, height: 16).padding(.horizontal, 4)
                }
                toolButton(tool, help: "\(tool.label) (\(shortcut(for: tool)))")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(Color.white).shadow(color: Color.black.opacity(0.12), radius: 16, y: 6)
        )
        .overlay(Capsule().stroke(Color.black.opacity(0.08), lineWidth: 1))
    }

    private var backgroundTitle: String {
        switch model.style.background {
        case .color(let hex):
            return hex == "transparent" ? "None" : "Colour"
        case .gradient(let from, let to, _):
            return Presets.gradients.first(where: { $0.1 == from && $0.2 == to })?.0 ?? "Gradient"
        case .wallpaper(let id):
            return id.label
        }
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

    private var backgroundControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Background", selection: Binding(
                get: { backgroundKind },
                set: { kind in
                    switch kind {
                    case .color: model.setBackground(.color("#F1F1F1"))
                    case .gradient: model.setBackground(.gradient(from: "#F7F7F7", to: "#D9DEE7", angle: 180))
                    case .wallpaper: model.setBackground(.wallpaper(.dots))
                    }
                }
            )) {
                ForEach(BackgroundKind.allCases) { kind in
                    Text(kind.label).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch model.style.background {
            case .color(let selected):
                swatchRow(Presets.colors, selected: selected) { model.setBackground(.color($0)) }
            case .gradient(let from, let to, _):
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(Array(Presets.gradients.enumerated()), id: \.offset) { _, gradient in
                        let active = gradient.1 == from && gradient.2 == to
                        Button(action: { model.setBackground(.gradient(from: gradient.1, to: gradient.2, angle: gradient.3)) }) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(LinearGradient(colors: [Color(nsColor: NSColor(hex: gradient.1)!), Color(nsColor: NSColor(hex: gradient.2)!)], startPoint: .top, endPoint: .bottom))
                                .frame(height: 36)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(active ? accent : line, lineWidth: active ? 2 : 1))
                        }
                        .buttonStyle(.plain)
                        .help(gradient.0)
                    }
                }
            case .wallpaper(let selected):
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(WallpaperID.allCases) { wallpaper in
                        Button(action: { model.setBackground(.wallpaper(wallpaper)) }) {
                            ZStack {
                                wallpaperPreview(wallpaper)
                                Text(wallpaper.label)
                                    .font(.system(size: 10, weight: .medium))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color.white.opacity(0.86))
                                    .cornerRadius(4)
                            }
                            .frame(height: 36)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(selected == wallpaper ? accent : line, lineWidth: selected == wallpaper ? 2 : 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var layoutControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            labelledSlider("Padding", value: Binding(get: { model.style.padding }, set: { model.beginGesture(); model.setPadding($0) }), range: 0...200)
            labelledSlider("Corner radius", value: Binding(get: { model.style.radius }, set: { model.beginGesture(); model.setRadius($0) }), range: 0...64)
            labelledSlider("Shadow", value: Binding(get: { model.style.shadow }, set: { model.beginGesture(); model.setShadow($0) }), range: 0...100)
            Picker("Frame", selection: Binding(get: { model.style.frame }, set: { model.setFrame($0) })) {
                ForEach(FrameStyle.allCases) { frame in
                    Text(frame.label).tag(frame)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
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

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            content()
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
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
            .background(
                Capsule().fill(Color.white).shadow(color: Color.black.opacity(0.12), radius: 10, y: 4)
            )
            .padding(.bottom, 16)
        }
        .allowsHitTesting(true)
    }

    private func toolButton(_ tool: Tool, help: String, wide: Bool = false) -> some View {
        let active = model.tool == tool
        return Button(action: { model.tool = tool }) {
            Image(systemName: tool.symbol)
                .font(.system(size: 14))
                .frame(maxWidth: wide ? .infinity : nil)
                .frame(width: wide ? nil : 28, height: 28)
                .foregroundColor(ink)
                .background(RoundedRectangle(cornerRadius: 6).fill(active ? accent.opacity(0.14) : Color.clear))
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func iconButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private var headerDivider: some View {
        Rectangle().fill(line).frame(width: 1, height: 18)
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
        case .gradient(let from, let to, _):
            LinearGradient(
                colors: [Color(nsColor: NSColor(hex: from)!), Color(nsColor: NSColor(hex: to)!)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .wallpaper(let id):
            wallpaperPreview(id)
        }
    }

    @ViewBuilder
    private func wallpaperPreview(_ id: WallpaperID) -> some View {
        switch id {
        case .dots: Color(nsColor: NSColor(hex: "#E8E6E3")!)
        case .grid: Color(nsColor: NSColor(hex: "#F7F7F7")!)
        case .diagonal: Color(nsColor: NSColor(hex: "#EEF2FF")!)
        case .stripes: Color(nsColor: NSColor(hex: "#F4F1EC")!)
        case .mesh: Color(nsColor: NSColor(hex: "#F6F7F8")!)
        case .cross: Color(nsColor: NSColor(hex: "#F4F7FB")!)
        }
    }

    private var backgroundKind: BackgroundKind {
        switch model.style.background {
        case .color: return .color
        case .gradient: return .gradient
        case .wallpaper: return .wallpaper
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
            window.delegate = WindowKeeper.shared
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.styleMask.insert(.fullSizeContentView)
            window.isMovableByWindowBackground = false
            window.minSize = NSSize(width: 980, height: 680)
            window.backgroundColor = NSColor(srgbRed: 0.945, green: 0.945, blue: 0.945, alpha: 1)
            if window.contentRect(forFrameRect: window.frame).width < 1000 {
                window.setContentSize(NSSize(width: 1180, height: 760))
                window.center()
            }
        }
    }
}

private struct WindowDrag: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class DragView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }
    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}
