import AppKit
import Combine
import ImageIO
import UniformTypeIdentifiers

enum Tool: String, CaseIterable, Identifiable {
    case select, crop, rect, rectFill, circle, line, arrow, draw, text, marker, pixelate, blur
    var id: String { rawValue }
    var label: String {
        switch self {
        case .select: return "Select"
        case .crop: return "Crop"
        case .rect: return "Rectangle"
        case .rectFill: return "Fill"
        case .circle: return "Circle"
        case .line: return "Line"
        case .arrow: return "Arrow"
        case .draw: return "Draw"
        case .text: return "Text"
        case .marker: return "Number"
        case .pixelate: return "Pixelate"
        case .blur: return "Blur"
        }
    }
    var symbol: String {
        switch self {
        case .select: return "cursorarrow"
        case .crop: return "crop"
        case .rect: return "rectangle"
        case .rectFill: return "rectangle.fill"
        case .circle: return "circle"
        case .line: return "line.diagonal"
        case .arrow: return "arrow.up.right"
        case .draw: return "scribble"
        case .text: return "textformat"
        case .marker: return "1.circle"
        case .pixelate: return "square.grid.3x3.fill"
        case .blur: return "drop.halffull"
        }
    }
}

enum FrameStyle: String, CaseIterable, Identifiable {
    case none, browser, desktop
    var id: String { rawValue }
    var label: String {
        switch self {
        case .none: return "None"
        case .browser: return "Browser"
        case .desktop: return "Window"
        }
    }
}

enum CanvasRatio: String, CaseIterable, Identifiable {
    case auto, square, fourThree, threeTwo, sixteenNine
    var id: String { rawValue }
    var label: String {
        switch self {
        case .auto: return "Auto"
        case .square: return "1:1"
        case .fourThree: return "4:3"
        case .threeTwo: return "3:2"
        case .sixteenNine: return "16:9"
        }
    }
    var ratio: CGFloat? {
        switch self {
        case .auto: return nil
        case .square: return 1
        case .fourThree: return 4.0 / 3.0
        case .threeTwo: return 3.0 / 2.0
        case .sixteenNine: return 16.0 / 9.0
        }
    }
}

enum WallpaperID: String, CaseIterable, Identifiable {
    case dots, grid, diagonal, stripes, mesh, cross
    case dusk, night, harbour, hills, aurora, sorbet
    case studio, porcelain, bloom, tide, sand, ink, citrus, glacier, clay, moss
    case flare, iris, blush, prism
    case ripple, emberglass, gilt, current
    case nebula, void, orbit, pulsar
    case veil, halo, drift, linen
    case peaks, coast, shore, ridge
    case fold, swell, dune, petal
    case canyon, canopy, mesa, basin
    static let patterns: [WallpaperID] = [.dots, .grid, .diagonal, .stripes, .mesh, .cross]
    static let scenes: [WallpaperID] = [.dusk, .night, .harbour, .hills, .aurora, .sorbet]
    static let backdrops: [WallpaperID] = [.studio, .porcelain, .bloom, .tide, .sand, .ink, .citrus, .glacier, .clay, .moss]
    static let fields: [WallpaperID] = [.flare, .iris, .blush, .prism]
    static let glass: [WallpaperID] = [.ripple, .emberglass, .gilt, .current]
    static let cosmic: [WallpaperID] = [.nebula, .void, .orbit, .pulsar]
    static let mystic: [WallpaperID] = [.veil, .halo, .drift, .linen]
    static let desktop: [WallpaperID] = [.peaks, .coast, .shore, .ridge]
    static let abstract: [WallpaperID] = [.fold, .swell, .dune, .petal]
    static let earth: [WallpaperID] = [.canyon, .canopy, .mesa, .basin]
    var id: String { rawValue }
    var isScene: Bool { !Self.patterns.contains(self) }
    var label: String {
        switch self {
        case .dots: return "Dots"
        case .grid: return "Grid"
        case .diagonal: return "Diagonal"
        case .stripes: return "Stripes"
        case .mesh: return "Mesh"
        case .cross: return "Graph"
        case .dusk: return "Dusk"
        case .night: return "Night"
        case .harbour: return "Harbour"
        case .hills: return "Hills"
        case .aurora: return "Aurora"
        case .sorbet: return "Sorbet"
        case .studio: return "Studio"
        case .porcelain: return "Porcelain"
        case .bloom: return "Bloom"
        case .tide: return "Tide"
        case .sand: return "Sand"
        case .ink: return "Ink"
        case .citrus: return "Citrus"
        case .glacier: return "Glacier"
        case .clay: return "Clay"
        case .moss: return "Moss"
        case .flare: return "Flare"
        case .iris: return "Iris"
        case .blush: return "Blush"
        case .prism: return "Prism"
        case .ripple: return "Ripple"
        case .emberglass: return "Ember"
        case .gilt: return "Gilt"
        case .current: return "Current"
        case .nebula: return "Nebula"
        case .void: return "Void"
        case .orbit: return "Orbit"
        case .pulsar: return "Pulsar"
        case .veil: return "Veil"
        case .halo: return "Halo"
        case .drift: return "Drift"
        case .linen: return "Linen"
        case .peaks: return "Peaks"
        case .coast: return "Coast"
        case .shore: return "Shore"
        case .ridge: return "Ridge"
        case .fold: return "Fold"
        case .swell: return "Swell"
        case .dune: return "Dune"
        case .petal: return "Petal"
        case .canyon: return "Canyon"
        case .canopy: return "Canopy"
        case .mesa: return "Mesa"
        case .basin: return "Basin"
        }
    }
}

enum Background: Equatable {
    case color(String)
    case gradient(from: String, mid: String?, to: String, angle: CGFloat)
    case wallpaper(WallpaperID)
}

enum CardStyle: String, Equatable, Hashable, CaseIterable {
    case `default`, glassLight, glassDark, liquid, insetLight, insetDark, outline, border, retro
    var title: String {
        switch self {
        case .default: return "Default"
        case .glassLight: return "Glass Light"
        case .glassDark: return "Glass Dark"
        case .liquid: return "Liquid…"
        case .insetLight: return "Inset Light"
        case .insetDark: return "Inset Dark"
        case .outline: return "Outline"
        case .border: return "Border"
        case .retro: return "Retro"
        }
    }
}

enum ShadowKind: String, Equatable, Hashable, CaseIterable {
    case none, spread, hug, adaptive
    var title: String {
        switch self {
        case .none: return "None"
        case .spread: return "Spread"
        case .hug: return "Hug"
        case .adaptive: return "Adap…"
        }
    }
}

struct ShotliStyle: Equatable {
    var padding: CGFloat
    var radius: CGFloat
    var shadow: CGFloat
    var frame: FrameStyle
    var canvas: CanvasRatio
    var canvasWidth: CGFloat
    var canvasHeight: CGFloat
    var background: Background
    var card: CardStyle = .default
    var shadowKind: ShadowKind = .spread
    var shadowOpacity: CGFloat = 40
    var light: CGFloat = 0
    var hideMockup: Bool = false
    var tiltX: CGFloat = 0
    var tiltY: CGFloat = 0
    var shiftX: CGFloat = 0
    var shiftY: CGFloat = 0
}

struct Brush: Equatable {
    var color = "#E5484D"
    var strokeWidth: CGFloat = 4
    var pixelSize: CGFloat = 14
    var blur: CGFloat = 12
    var fontSize: CGFloat = 24
}

enum ShapeKind: String, Equatable { case rect, rectFill, circle, pixelate, blur }

struct ShapeMark: Equatable {
    var id: String
    var kind: ShapeKind
    var color: String
    var strokeWidth: CGFloat
    var x: CGFloat
    var y: CGFloat
    var w: CGFloat
    var h: CGFloat
    var amount: CGFloat
}

struct LineMark: Equatable {
    var id: String
    var arrow: Bool
    var color: String
    var strokeWidth: CGFloat
    var x: CGFloat
    var y: CGFloat
    var x2: CGFloat
    var y2: CGFloat
}

struct DrawMark: Equatable {
    var id: String
    var color: String
    var strokeWidth: CGFloat
    var points: [CGPoint]
}

struct TextMark: Equatable {
    var id: String
    var color: String
    var x: CGFloat
    var y: CGFloat
    var text: String
    var fontSize: CGFloat
}

struct MarkerMark: Equatable {
    var id: String
    var color: String
    var x: CGFloat
    var y: CGFloat
    var n: Int
}

enum Annotation: Equatable, Identifiable {
    case shape(ShapeMark)
    case line(LineMark)
    case draw(DrawMark)
    case text(TextMark)
    case marker(MarkerMark)

    var id: String {
        switch self {
        case .shape(let mark): return mark.id
        case .line(let mark): return mark.id
        case .draw(let mark): return mark.id
        case .text(let mark): return mark.id
        case .marker(let mark): return mark.id
        }
    }

    var color: String {
        switch self {
        case .shape(let mark): return mark.color
        case .line(let mark): return mark.color
        case .draw(let mark): return mark.color
        case .text(let mark): return mark.color
        case .marker(let mark): return mark.color
        }
    }
}

struct LoadedPicture {
    var image: CGImage
    var name: String
    var scaled: Bool
    var width: CGFloat { CGFloat(image.width) }
    var height: CGFloat { CGFloat(image.height) }
}

struct Preset: Identifiable, Equatable {
    var id: String
    var name: String
    var style: ShotliStyle
}

enum Presets {
    static let colors = ["#050506", "#F5F5F0", "#2B2E36", "#F03B47", "#F78529", "#F5BA3B", "#3B9C5C", "#2980E0", "#7A42E8", "#EDA89E", "#A8E6BA", "#A1C9F0", "#CCC2EB", "#FACCB0", "#BDD1B2", "#E8DEC2", "transparent"]
    static let inks = ["#E5484D", "#F5A524", "#3478F6", "#30A46C", "#8E4EC6", "#222222", "#FFFFFF"]
    static let gradients: [(name: String, from: String, mid: String, to: String, angle: CGFloat)] = [
        ("Aurora", "#FA4F94", "#6652F2", "#4AD6CC", 135),
        ("Cobalt", "#0A0D80", "#4230ED", "#6BABFA", 153),
        ("Peach", "#FA615C", "#FCB55C", "#E654A6", 135),
        ("Glass", "#DEF2F0", "#75C4DB", "#4087ED", 135),
        ("Plasma", "#140538", "#591FD6", "#F2426B", 225),
        ("Mango", "#FCBF33", "#F55436", "#AB30E3", 135),
        ("Mist", "#F0F0EB", "#CCE0F0", "#F2C2B2", 135),
        ("Lagoon", "#144C8A", "#40A3B8", "#B2EBC7", 315),
        ("Ember", "#2E0814", "#DB2B2E", "#FFAB40", 135),
        ("Violet", "#3D1482", "#9638F0", "#F56BBD", 153),
        ("Sea Glass", "#6EDBBF", "#409ECC", "#3859BF", 135),
        ("Citrus", "#FCE84C", "#70C74A", "#1F946B", 225),
        ("Amethyst", "#1A1447", "#5926A6", "#C263F2", 315),
        ("Sorbet", "#FF7D82", "#FFBD7A", "#8FC7FA", 135),
        ("Mineral", "#EDF5F2", "#A3B8D1", "#546B8C", 135),
        ("Dawn", "#FA9EC4", "#FAD178", "#6BB5F5", 315),
    ]

    static let all: [Preset] = [
        Preset(id: "clean", name: "Clean", style: style(56, 14, 28, .none, .color("#FFFFFF"))),
        Preset(id: "studio", name: "Studio", style: style(80, 16, 42, .none, .wallpaper(.studio))),
        Preset(id: "soft", name: "Soft", style: style(68, 22, 30, .none, .wallpaper(.porcelain))),
        Preset(id: "browser", name: "Browser", style: style(60, 12, 36, .browser, .wallpaper(.tide))),
        Preset(id: "window", name: "Window", style: style(52, 10, 24, .desktop, .wallpaper(.dots))),
        Preset(id: "pastel", name: "Pastel", style: style(84, 24, 34, .none, .wallpaper(.glacier))),
        Preset(id: "signal", name: "Signal", style: style(76, 18, 48, .none, .wallpaper(.bloom))),
        Preset(id: "midnight", name: "Midnight", style: style(68, 14, 50, .browser, .wallpaper(.ink))),
    ]

    static func style(_ padding: CGFloat, _ radius: CGFloat, _ shadow: CGFloat, _ frame: FrameStyle, _ background: Background) -> ShotliStyle {
        ShotliStyle(padding: padding, radius: radius, shadow: shadow, frame: frame, canvas: .auto, canvasWidth: 0, canvasHeight: 0, background: background)
    }
}

enum TemplateKind: String {
    case image, angled
}

struct ShotTemplate: Identifiable, Equatable {
    var id: String
    var name: String
    var group: String
    var kind: TemplateKind
    var style: ShotliStyle
}

enum TemplateLibrary {
    static let groups = ["Product promotion", "Abstract colour", "Colour"]

    static let all: [ShotTemplate] = [
        shot("stage", "Studio", "Product promotion", .image, 72, 18, 40, .none, .wallpaper(.studio), .sixteenNine, 0, 0, 0.22, 0),
        shot("lean", "Lean", "Product promotion", .angled, 64, 22, 48, .none, .wallpaper(.porcelain), .sixteenNine, 14, -26, -0.06, 0),
        shot("hero", "Sand", "Product promotion", .angled, 72, 16, 36, .none, .wallpaper(.sand), .threeTwo, 10, 22, -0.16, 0),
        shot("quiet", "Glass", "Product promotion", .image, 80, 26, 28, .none, .wallpaper(.glacier), .sixteenNine, 0, 0, 0, 0, card: .glassLight),
        shot("spotlight", "Spotlight", "Product promotion", .image, 68, 20, 48, .none, .wallpaper(.ink), .sixteenNine, 0, 0, 0, -0.06),
        shot("bloom", "Bloom", "Abstract colour", .image, 72, 24, 34, .none, .wallpaper(.bloom), .sixteenNine, 0, 0, 0.16, 0),
        shot("bloom-lean", "Bloom tilt", "Abstract colour", .angled, 64, 22, 42, .none, .wallpaper(.bloom), .sixteenNine, 12, 24, 0.08, 0),
        shot("tide", "Browser", "Abstract colour", .image, 64, 14, 32, .browser, .wallpaper(.tide), .sixteenNine, 0, 0, 0, 0),
        shot("tide-lean", "Browser tilt", "Abstract colour", .angled, 60, 14, 36, .browser, .wallpaper(.tide), .sixteenNine, 8, 20, 0.08, 0),
        shot("citrus", "Citrus", "Abstract colour", .angled, 68, 22, 34, .none, .wallpaper(.citrus), .sixteenNine, 8, -22, -0.1, 0),
        shot("clay", "Clay", "Abstract colour", .image, 76, 18, 30, .none, .wallpaper(.clay), .threeTwo, 0, 0, -0.18, 0),
        shot("moss", "Moss", "Abstract colour", .angled, 64, 20, 40, .none, .wallpaper(.moss), .sixteenNine, 10, 20, 0.1, 0),
        shot("ripple", "Ripple", "Colour", .image, 76, 22, 32, .none, .wallpaper(.ripple), .sixteenNine, 0, 0, 0, 0),
        shot("nebula", "Nebula", "Colour", .image, 72, 20, 44, .none, .wallpaper(.nebula), .sixteenNine, 0, 0, 0.08, 0),
        shot("peaks", "Peaks", "Colour", .image, 68, 16, 36, .none, .wallpaper(.peaks), .sixteenNine, 0, 0, 0, 0),
        shot("canyon", "Canyon", "Colour", .angled, 64, 18, 40, .none, .wallpaper(.canyon), .sixteenNine, 10, 18, 0.08, 0),
    ]

    static func inGroup(_ group: String, kind: TemplateKind?) -> [ShotTemplate] {
        all.filter { $0.group == group && (kind == nil || $0.kind == kind) }
    }

    private static func shot(
        _ id: String,
        _ name: String,
        _ group: String,
        _ kind: TemplateKind,
        _ padding: CGFloat,
        _ radius: CGFloat,
        _ shadow: CGFloat,
        _ frame: FrameStyle,
        _ background: Background,
        _ canvas: CanvasRatio,
        _ tiltX: CGFloat,
        _ tiltY: CGFloat,
        _ shiftX: CGFloat,
        _ shiftY: CGFloat,
        card: CardStyle = .default
    ) -> ShotTemplate {
        var style = ShotliStyle(
            padding: padding,
            radius: radius,
            shadow: shadow,
            frame: frame,
            canvas: canvas,
            canvasWidth: 0,
            canvasHeight: 0,
            background: background
        )
        style.card = card
        style.shadowKind = shadow > 0 ? .spread : .none
        style.shadowOpacity = 46
        style.tiltX = tiltX
        style.tiltY = tiltY
        style.shiftX = shiftX
        style.shiftY = shiftY
        return ShotTemplate(id: id, name: name, group: group, kind: kind, style: style)
    }
}

struct Snapshot: Equatable {
    var crop: CGRect?
    var style: ShotliStyle
    var annotations: [Annotation]
    var selectedID: String?
}

let chromeHeight: CGFloat = 46
private let maxEdge: CGFloat = 4096
private let maxBytes = 25 * 1024 * 1024

final class EditorModel: ObservableObject {
    static let shared = EditorModel()

    @Published var picture: LoadedPicture?
    @Published var crop: CGRect?
    @Published var style = Presets.all[0].style
    @Published var annotations: [Annotation] = []
    @Published var selectedID: String?
    @Published var tool: Tool = .select
    @Published var brush = Brush()
    @Published var notice: String?
    @Published var canUndo = false
    @Published var canRedo = false
    @Published var fitRequest = 0
    @Published var actualRequest = 0
    @Published var zoomInRequest = 0
    @Published var zoomOutRequest = 0
    @Published var zoomPercent = 100
    @Published var zoomMultiplier: CGFloat = 1
    @Published var zoomSetRequest = 0
    var zoomSetValue: CGFloat = 1
    @Published var projectFolder: URL?
    @Published var projectName: String?
    @Published var saveState: ProjectSaveState = .idle
    @Published var showSaveProjects = false
    var projectID: String?
    var compositionID: String?

    private var undoStack: [Snapshot] = []
    private var redoStack: [Snapshot] = []
    private var gestureStart: Snapshot?
    private var textUndoID: String?
    private var sourceOrigin: URL?
    private var sourceData: Data?
    private var sourceSHA: String?
    private var sourceFileName: String?
    private var sourceRelative: String?
    private var quietUntil = Date.distantPast
    private var saveTicket = 0

    private init() {}

    var selected: Annotation? {
        annotations.first { $0.id == selectedID }
    }

    func openPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .webP]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose a screenshot"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        load(url: url)
    }

    func load(url: URL) {
        if let message = flushBoundSave() {
            notice = message
            saveState = .failed(message)
            return
        }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            notice = "Couldn't read that file."
            return
        }
        if data.count > maxBytes {
            notice = "That image is over 25 MB. Choose a smaller file."
            return
        }
        guard let loaded = decodeImage(data, name: url.lastPathComponent) else {
            notice = "Use a PNG, JPEG, or WebP image."
            return
        }
        rememberSource(data, name: url.lastPathComponent, origin: url)
        replacePicture(loaded, adopting: projectFolder != nil)
    }

    func loadImageData(_ data: Data, name: String) {
        if let message = flushBoundSave() {
            notice = message
            saveState = .failed(message)
            return
        }
        if data.count > maxBytes {
            notice = "That image is over 25 MB. Choose a smaller file."
            return
        }
        guard let loaded = decodeImage(data, name: name) else {
            notice = "Use a PNG, JPEG, or WebP image."
            return
        }
        if let png = pngData(loaded.image) {
            rememberSource(png, name: name, origin: nil)
        } else {
            rememberSource(data, name: name, origin: nil)
        }
        replacePicture(loaded, adopting: projectFolder != nil)
    }

    func pasteImage() {
        if let message = flushBoundSave() {
            notice = message
            saveState = .failed(message)
            return
        }
        let board = NSPasteboard.general
        guard let objects = board.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
              let image = objects.first,
              let tiff = image.tiffRepresentation,
              let loaded = decodeImage(tiff, name: "Pasted image.png") else {
            notice = "Clipboard doesn't contain an image."
            return
        }
        if let png = pngData(loaded.image) {
            rememberSource(png, name: "Pasted image.png", origin: nil)
        }
        replacePicture(loaded, adopting: projectFolder != nil)
    }

    func useSample() {
        if let message = flushBoundSave() {
            notice = message
            saveState = .failed(message)
            return
        }
        let image = sampleScreenshot()
        if let png = pngData(image) {
            rememberSource(png, name: "Sample.png", origin: nil)
        }
        replacePicture(LoadedPicture(image: image, name: "Sample.png", scaled: false), adopting: projectFolder != nil)
    }

    func showLibrary() {
        if let message = flushBoundSave() {
            notice = message
            saveState = .failed(message)
            return
        }
        quietChanges()
        picture = nil
        crop = nil
        annotations = []
        selectedID = nil
        undoStack = []
        redoStack = []
        gestureStart = nil
        textUndoID = nil
        notice = nil
        projectFolder = nil
        projectID = nil
        projectName = nil
        compositionID = nil
        sourceOrigin = nil
        sourceData = nil
        sourceSHA = nil
        sourceFileName = nil
        sourceRelative = nil
        saveState = .idle
        showSaveProjects = false
        refreshHistory()
        LibraryModel.shared.refresh()
    }

    func exportPNG() {
        guard picture != nil else { return }
        let base = (picture?.name ?? "screenshot")
            .replacingOccurrences(of: "\\.[^.]+$", with: "", options: .regularExpression)
        let safe = base.replacingOccurrences(of: "[^A-Za-z0-9._-]+", with: "-", options: .regularExpression)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "shotli-\(safe.isEmpty ? "screenshot" : safe).png"
        panel.title = "Export PNG"
        if let folder = projectFolder {
            let exports = folder.appendingPathComponent("Exports", isDirectory: true)
            try? FileManager.default.createDirectory(at: exports, withIntermediateDirectories: true)
            panel.directoryURL = exports
        } else {
            panel.directoryURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let image = renderComposition(picture: picture, crop: crop, style: style, annotations: annotations, draft: nil, interactive: false) else {
            notice = "Couldn't create the PNG."
            return
        }
        do {
            try writePNG(image, to: url)
            notice = "Saved \(url.lastPathComponent)"
        } catch {
            notice = "Couldn't save the PNG."
        }
    }

    func copyPNG() {
        guard picture != nil else { return }
        guard let image = renderComposition(picture: picture, crop: crop, style: style, annotations: annotations, draft: nil, interactive: false),
              let png = pngData(image) else {
            notice = "Couldn't copy the picture."
            return
        }
        let board = NSPasteboard.general
        board.clearContents()
        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        board.writeObjects([nsImage])
        board.setData(png, forType: .png)
        notice = "Copied"
    }

    func shareFile() -> (url: URL, png: Data, preview: NSImage)? {
        guard picture != nil,
              let image = renderComposition(picture: picture, crop: crop, style: style, annotations: annotations, draft: nil, interactive: false),
              let png = pngData(image) else { return nil }
        let base = (picture?.name ?? "screenshot")
            .replacingOccurrences(of: "\\.[^.]+$", with: "", options: .regularExpression)
        let safe = base.replacingOccurrences(of: "[^A-Za-z0-9._-]+", with: "-", options: .regularExpression)
        let name = "Shotli-\(safe.isEmpty ? "screenshot" : safe)-\(UUID().uuidString.prefix(6)).png"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do { try png.write(to: url) } catch { return nil }
        let edge = max(CGFloat(image.width), CGFloat(image.height))
        let scale = edge > 1 ? min(1, 720 / edge) : 1
        let preview = NSImage(cgImage: image, size: NSSize(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale))
        return (url, png, preview)
    }

    func applyPreset(_ preset: Preset) {
        guard preset.style != style else { return }
        pushUndo()
        style = preset.style
    }

    func applyTemplate(_ template: ShotTemplate) {
        guard template.style != style else { return }
        pushUndo()
        style = template.style
    }

    func setTilt(x: CGFloat, y: CGFloat) {
        guard abs(style.tiltX - x) > 0.1 || abs(style.tiltY - y) > 0.1 else { return }
        edit {
            var next = style
            next.tiltX = x
            next.tiltY = y
            style = next
        }
    }

    func edit(_ apply: () -> Void) {
        let before = snapshot()
        apply()
        guard before != snapshot() else { return }
        undoStack.append(before)
        if undoStack.count > 60 { undoStack.removeFirst() }
        redoStack.removeAll()
        refreshHistory()
    }

    func setPadding(_ value: CGFloat) {
        var next = style
        next.padding = value
        style = next
    }

    func setRadius(_ value: CGFloat) {
        var next = style
        next.radius = value
        style = next
    }

    func setShadow(_ value: CGFloat) {
        var next = style
        next.shadow = value
        style = next
    }

    func setCard(_ card: CardStyle) {
        guard style.card != card else { return }
        edit {
            var next = style
            next.card = card
            switch card {
            case .default: next.radius = 22; next.shadowKind = .spread; next.shadow = 36
            case .glassLight: next.radius = 28; next.shadowKind = .spread; next.shadow = 28
            case .glassDark: next.radius = 28; next.shadowKind = .spread; next.shadow = 34
            case .liquid: next.radius = 32; next.shadowKind = .spread; next.shadow = 22
            case .insetLight, .insetDark: next.radius = 24; next.shadowKind = .hug; next.shadow = 8
            case .outline: next.radius = 18; next.shadowKind = .none; next.shadow = 0
            case .border: next.radius = 16; next.shadowKind = .spread; next.shadow = 18
            case .retro: next.radius = 18; next.shadowKind = .hug; next.shadow = 14
            }
            style = next
        }
    }

    func setShadowKind(_ kind: ShadowKind) {
        guard style.shadowKind != kind else { return }
        edit {
            var next = style
            next.shadowKind = kind
            if kind == .none { next.shadow = 0 }
            else if next.shadow < 8 { next.shadow = kind == .hug ? 12 : 36 }
            style = next
        }
    }

    func setShadowOpacity(_ value: CGFloat) {
        var next = style
        next.shadowOpacity = value
        style = next
    }

    func setLight(_ value: CGFloat) {
        var next = style
        next.light = value
        style = next
    }

    func setHideMockup(_ hidden: Bool) {
        guard style.hideMockup != hidden else { return }
        edit {
            var next = style
            next.hideMockup = hidden
            style = next
        }
    }

    func setCorner(_ radius: CGFloat) {
        edit {
            var next = style
            next.radius = radius
            style = next
        }
    }

    func setCanvas(_ canvas: CanvasRatio) {
        guard style.canvas != canvas || style.canvasWidth != 0 || style.canvasHeight != 0 else { return }
        edit {
            var next = style
            next.canvas = canvas
            next.canvasWidth = 0
            next.canvasHeight = 0
            style = next
        }
    }

    func setCanvasSize(width: CGFloat, height: CGFloat) {
        var next = style
        next.canvasWidth = max(1, width)
        next.canvasHeight = max(1, height)
        style = next
    }

    func setFrame(_ frame: FrameStyle) {
        guard style.frame != frame else { return }
        edit {
            var next = style
            next.frame = frame
            style = next
        }
    }

    func setBackground(_ background: Background) {
        guard style.background != background else { return }
        edit {
            var next = style
            next.background = background
            style = next
        }
    }

    func fit() {
        fitRequest += 1
    }

    func actualSize() {
        actualRequest += 1
    }

    func zoomIn() {
        zoomInRequest += 1
    }

    func zoomOut() {
        zoomOutRequest += 1
    }

    func setZoomMultiplier(_ value: CGFloat) {
        zoomSetValue = min(3, max(0.35, value))
        zoomSetRequest += 1
    }

    func startOver() {
        guard picture != nil else { return }
        if ShotliSettings.shared.confirmStartOver {
            let alert = NSAlert()
            alert.messageText = "Are you sure?"
            alert.informativeText = "This clears the screenshot you're editing."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Start Over")
            alert.addButton(withTitle: "Cancel")
            NSApp.activate(ignoringOtherApps: true)
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        tool = .select
        showLibrary()
    }

    func replaceSelectedText(_ text: String) {
        guard let id = selectedID, let index = annotations.firstIndex(where: { $0.id == id }) else { return }
        guard case .text(var mark) = annotations[index], mark.text != text else { return }
        if textUndoID != id {
            pushUndo()
            textUndoID = id
        }
        mark.text = text
        annotations[index] = .text(mark)
    }

    func setSelectedFontSize(_ size: CGFloat) {
        brush.fontSize = size
        guard let id = selectedID else { return }
        edit {
            guard let index = annotations.firstIndex(where: { $0.id == id }) else { return }
            if case .text(var mark) = annotations[index] {
                mark.fontSize = size
                annotations[index] = .text(mark)
            }
        }
    }

    func updateSelectedAmount(_ amount: CGFloat) {
        guard let id = selectedID, let index = annotations.firstIndex(where: { $0.id == id }) else { return }
        if case .shape(var mark) = annotations[index] {
            mark.amount = amount
            annotations[index] = .shape(mark)
        }
    }

    func beginGesture() {
        if gestureStart == nil { gestureStart = snapshot() }
    }

    func endGesture() {
        guard let start = gestureStart else { return }
        gestureStart = nil
        if start != snapshot() {
            undoStack.append(start)
            if undoStack.count > 60 { undoStack.removeFirst() }
            redoStack.removeAll()
            refreshHistory()
        }
    }

    func cancelGesture() {
        guard let start = gestureStart else { return }
        gestureStart = nil
        restore(start)
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(snapshot())
        restore(previous)
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(snapshot())
        restore(next)
    }

    func deleteSelected() {
        guard let id = selectedID else { return }
        pushUndo()
        annotations.removeAll { $0.id == id }
        selectedID = nil
    }

    func resetCrop() {
        guard crop != nil else { return }
        pushUndo()
        crop = nil
    }

    func removeRedactions() {
        let next = annotations.filter {
            if case .shape(let mark) = $0 { return mark.kind != .pixelate && mark.kind != .blur }
            return true
        }
        guard next.count != annotations.count else { return }
        pushUndo()
        annotations = next
        if !annotations.contains(where: { $0.id == selectedID }) { selectedID = nil }
    }

    func updateSelectedColor(_ color: String) {
        brush.color = color
        guard let id = selectedID else { return }
        edit {
            guard let index = annotations.firstIndex(where: { $0.id == id }) else { return }
            switch annotations[index] {
            case .shape(var mark):
                mark.color = color
                annotations[index] = .shape(mark)
            case .line(var mark):
                mark.color = color
                annotations[index] = .line(mark)
            case .draw(var mark):
                mark.color = color
                annotations[index] = .draw(mark)
            case .text(var mark):
                mark.color = color
                annotations[index] = .text(mark)
            case .marker(var mark):
                mark.color = color
                annotations[index] = .marker(mark)
            }
        }
    }

    func updateSelectedText(_ text: String) {
        guard let id = selectedID, let index = annotations.firstIndex(where: { $0.id == id }) else { return }
        if case .text(var mark) = annotations[index] {
            mark.text = text
            annotations[index] = .text(mark)
        }
    }

    func setSelectedStroke(_ width: CGFloat) {
        brush.strokeWidth = width
        guard let id = selectedID else { return }
        edit {
            guard let index = annotations.firstIndex(where: { $0.id == id }) else { return }
            switch annotations[index] {
            case .shape(var mark):
                mark.strokeWidth = width
                annotations[index] = .shape(mark)
            case .line(var mark):
                mark.strokeWidth = width
                annotations[index] = .line(mark)
            case .draw(var mark):
                mark.strokeWidth = width
                annotations[index] = .draw(mark)
            default:
                break
            }
        }
    }

    func nextMarkerNumber() -> Int {
        let numbers = annotations.compactMap { item -> Int? in
            if case .marker(let mark) = item { return mark.n }
            return nil
        }
        return (numbers.max() ?? 0) + 1
    }

    private func replacePicture(_ loaded: LoadedPicture, adopting: Bool) {
        quietChanges()
        picture = loaded
        crop = nil
        annotations = []
        selectedID = nil
        undoStack = []
        redoStack = []
        gestureStart = nil
        textUndoID = nil
        compositionID = nil
        sourceRelative = nil
        refreshHistory()
        fitRequest += 1
        if adopting, projectFolder != nil {
            commitNewComposition(scaled: loaded.scaled)
        } else {
            if projectFolder == nil {
                projectID = nil
                projectName = nil
            }
            saveState = .unsaved
            notice = loaded.scaled ? "Scaled to 4096px on the long edge so editing stays responsive." : nil
        }
    }

    func openProject(at folder: URL) {
        if let message = flushBoundSave() {
            notice = message
            saveState = .failed(message)
            return
        }
        do {
            let file = try ProjectStore.read(folder)
            quietChanges()
            projectFolder = folder
            projectID = file.id
            projectName = file.name
            showSaveProjects = false
            guard let latest = file.compositions.max(by: { ProjectStore.date($0.modified) < ProjectStore.date($1.modified) }) else {
                picture = nil
                crop = nil
                annotations = []
                selectedID = nil
                undoStack = []
                redoStack = []
                gestureStart = nil
                textUndoID = nil
                compositionID = nil
                clearSource()
                saveState = .saved
                notice = nil
                refreshHistory()
                return
            }
            try apply(latest, in: folder)
            saveState = .saved
            notice = nil
        } catch {
            saveState = .failed(error.localizedDescription)
            notice = error.localizedDescription
        }
    }

    func saveCurrent(into folder: URL) {
        guard picture != nil else {
            let message = "Open a screenshot before saving it to a project."
            saveState = .failed(message)
            notice = message
            return
        }
        let same = projectFolder?.standardizedFileURL.path == folder.standardizedFileURL.path
        if !same, let message = flushBoundSave() {
            notice = message
            return
        }
        saveTicket += 1
        do {
            let file = try ProjectStore.read(folder)
            guard var draft = makeDraft(id: same ? compositionID : nil, reuse: same ? sourceRelative : nil) else {
                throw ProjectError.writeFailed("Couldn't save this screenshot.")
            }
            ensureSource(&draft)
            let outcome = try ProjectStore.saveComposition(draft, in: folder)
            quietChanges()
            projectFolder = folder
            projectID = file.id
            projectName = outcome.file.name
            compositionID = outcome.compositionID
            sourceRelative = outcome.relative
            if let relative = outcome.relative, let url = try? ProjectStore.resolve(relative, in: folder) {
                sourceOrigin = url
            }
            sourceData = nil
            saveState = .saved
            notice = "Saved to \(outcome.file.name)"
            LibraryModel.shared.refresh()
        } catch {
            saveState = .failed(error.localizedDescription)
            notice = error.localizedDescription
        }
    }

    func scheduleProjectSave() {
        if Date() < quietUntil { return }
        guard picture != nil else { return }
        guard let folder = projectFolder, let compositionID else {
            if !saveState.isFailure { saveState = .unsaved }
            return
        }
        saveTicket += 1
        let ticket = saveTicket
        let boundID = compositionID
        saveState = .saving
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            self?.performSave(ticket: ticket, folder: folder, compositionID: boundID, announce: false)
        }
    }

    func noteProjectMoved(from old: URL, to new: URL, name: String) {
        guard let current = projectFolder, current.standardizedFileURL.path == old.standardizedFileURL.path else { return }
        projectFolder = new
        projectName = name
        if let relative = sourceRelative, let url = try? ProjectStore.resolve(relative, in: new) {
            sourceOrigin = url
        }
    }

    func quietChanges() {
        quietUntil = Date().addingTimeInterval(0.35)
    }

    @discardableResult
    func flushBoundSave() -> String? {
        saveTicket += 1
        guard let folder = projectFolder, let compositionID, picture != nil else { return nil }
        guard var draft = makeDraft(id: compositionID, reuse: sourceRelative) else {
            let message = "Couldn't save this project."
            saveState = .failed(message)
            return message
        }
        ensureSource(&draft)
        do {
            let outcome = try ProjectStore.saveComposition(draft, in: folder)
            self.compositionID = outcome.compositionID
            sourceRelative = outcome.relative
            if let relative = outcome.relative, let url = try? ProjectStore.resolve(relative, in: folder) {
                sourceOrigin = url
            }
            sourceData = nil
            saveState = .saved
            return nil
        } catch {
            saveState = .failed(error.localizedDescription)
            return error.localizedDescription
        }
    }

    private func performSave(ticket: Int, folder: URL, compositionID: String, announce: Bool) {
        guard ticket == saveTicket, self.compositionID == compositionID, projectFolder?.path == folder.path else { return }
        guard var draft = makeDraft(id: compositionID, reuse: sourceRelative) else {
            saveState = .failed("Couldn't save this project.")
            notice = "Couldn't save this project."
            return
        }
        ensureSource(&draft)
        do {
            let outcome = try ProjectStore.saveComposition(draft, in: folder)
            guard ticket == saveTicket else { return }
            self.compositionID = outcome.compositionID
            sourceRelative = outcome.relative
            if let relative = outcome.relative, let url = try? ProjectStore.resolve(relative, in: folder) {
                sourceOrigin = url
            }
            sourceData = nil
            projectName = outcome.file.name
            projectID = outcome.file.id
            saveState = .saved
            if announce { notice = "Saved to \(outcome.file.name)" }
        } catch {
            guard ticket == saveTicket else { return }
            saveState = .failed(error.localizedDescription)
            notice = error.localizedDescription
        }
    }

    private func commitNewComposition(scaled: Bool) {
        guard let folder = projectFolder else { return }
        saveTicket += 1
        guard var draft = makeDraft(id: nil, reuse: nil) else {
            let message = "Couldn't save this screenshot."
            saveState = .failed(message)
            notice = message
            return
        }
        ensureSource(&draft)
        do {
            let outcome = try ProjectStore.saveComposition(draft, in: folder)
            quietChanges()
            compositionID = outcome.compositionID
            sourceRelative = outcome.relative
            if let relative = outcome.relative, let url = try? ProjectStore.resolve(relative, in: folder) {
                sourceOrigin = url
            }
            sourceData = nil
            projectName = outcome.file.name
            projectID = outcome.file.id
            saveState = .saved
            if scaled {
                notice = "Saved to \(outcome.file.name). Scaled to 4096px on the long edge."
            } else {
                notice = "Saved to \(outcome.file.name)"
            }
        } catch {
            saveState = .failed(error.localizedDescription)
            notice = error.localizedDescription
        }
    }

    private func apply(_ composition: CompositionFile, in folder: URL) throws {
        quietChanges()
        if let relative = composition.source {
            let url = try ProjectStore.resolve(relative, in: folder)
            guard let data = try? Data(contentsOf: url) else { throw ProjectError.missingSource }
            if data.count > maxBytes { throw ProjectError.unreadable("That screenshot is over 25 MB.") }
            guard let loaded = decodeImage(data, name: url.lastPathComponent) else {
                throw ProjectError.unreadable("The screenshot in this project couldn't be read.")
            }
            picture = loaded
            sourceOrigin = url
            sourceData = nil
            sourceSHA = composition.sourceSHA256 ?? ProjectStore.sha256(data)
            sourceFileName = url.lastPathComponent
            sourceRelative = relative
        } else {
            picture = nil
            clearSource()
        }
        crop = composition.crop?.rect
        style = composition.style.style
        annotations = composition.annotations.compactMap(\.annotation)
        compositionID = composition.id
        selectedID = nil
        undoStack = []
        redoStack = []
        gestureStart = nil
        textUndoID = nil
        refreshHistory()
        fitRequest += 1
    }

    private func makeDraft(id: String?, reuse: String?) -> CompositionDraft? {
        guard let picture else { return nil }
        let thumbnail = renderComposition(
            picture: picture,
            crop: crop,
            style: style,
            annotations: annotations,
            draft: nil,
            interactive: false
        )
        return CompositionDraft(
            id: id,
            name: picture.name,
            sourceData: sourceData,
            sourceFileName: sourceFileName ?? picture.name,
            sourceSHA256: sourceSHA,
            reuseRelative: reuse,
            crop: crop,
            style: style,
            annotations: annotations,
            thumbnail: thumbnail
        )
    }

    private func ensureSource(_ draft: inout CompositionDraft) {
        if let reuse = draft.reuseRelative, let folder = projectFolder,
           let url = try? ProjectStore.resolve(reuse, in: folder),
           FileManager.default.fileExists(atPath: url.path) {
            return
        }
        draft.reuseRelative = nil
        if draft.sourceData == nil, let origin = sourceOrigin, let data = try? Data(contentsOf: origin) {
            draft.sourceData = data
            draft.sourceFileName = origin.lastPathComponent
        }
        if draft.sourceData == nil, let picture, let png = pngData(picture.image) {
            draft.sourceData = png
            if (draft.sourceFileName as NSString).pathExtension.isEmpty {
                draft.sourceFileName = "Screenshot.png"
            }
        }
        if draft.sourceSHA256 == nil, let data = draft.sourceData {
            draft.sourceSHA256 = ProjectStore.sha256(data)
        }
    }

    private func rememberSource(_ data: Data, name: String, origin: URL?) {
        sourceOrigin = origin
        sourceData = data
        sourceSHA = ProjectStore.sha256(data)
        sourceFileName = name
    }

    private func clearSource() {
        sourceOrigin = nil
        sourceData = nil
        sourceSHA = nil
        sourceFileName = nil
        sourceRelative = nil
    }

    private func snapshot() -> Snapshot {
        Snapshot(crop: crop, style: style, annotations: annotations, selectedID: selectedID)
    }

    private func restore(_ snap: Snapshot) {
        crop = snap.crop
        style = snap.style
        annotations = snap.annotations
        selectedID = snap.selectedID
        textUndoID = nil
        refreshHistory()
    }

    private func pushUndo() {
        undoStack.append(snapshot())
        if undoStack.count > 60 { undoStack.removeFirst() }
        redoStack.removeAll()
        refreshHistory()
    }

    private func refreshHistory() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }
}

private func decodeImage(_ data: Data, name: String) -> LoadedPicture? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
    var originalEdge: CGFloat = 0
    if let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
        let width = props[kCGImagePropertyPixelWidth] as? CGFloat ?? 0
        let height = props[kCGImagePropertyPixelHeight] as? CGFloat ?? 0
        originalEdge = max(width, height)
    }
    let options: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: maxEdge,
    ]
    guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
    return LoadedPicture(image: image, name: name, scaled: originalEdge > maxEdge)
}

private func pngData(_ image: CGImage) -> Data? {
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return nil }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { return nil }
    return data as Data
}

private func writePNG(_ image: CGImage, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw CocoaError(.fileWriteUnknown)
    }
    CGImageDestinationAddImage(destination, image, nil)
    if !CGImageDestinationFinalize(destination) { throw CocoaError(.fileWriteUnknown) }
}

func sampleScreenshot() -> CGImage {
    let width = 960
    let height = 600
    let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.translateBy(x: 0, y: CGFloat(height))
    context.scaleBy(x: 1, y: -1)
    context.setFillColor(NSColor(srgbRed: 0.95, green: 0.96, blue: 0.97, alpha: 1).cgColor)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.setFillColor(NSColor.white.cgColor)
    context.fill(CGRect(x: 36, y: 36, width: width - 72, height: height - 72))
    context.setFillColor(NSColor(srgbRed: 0.20, green: 0.47, blue: 0.96, alpha: 1).cgColor)
    context.fill(CGRect(x: 36, y: 36, width: width - 72, height: 56))
    ("Quarterly plan" as NSString).draw(at: CGPoint(x: 56, y: 52), withAttributes: [
        .font: NSFont.systemFont(ofSize: 18, weight: .semibold),
        .foregroundColor: NSColor.white,
    ])
    context.setFillColor(NSColor(srgbRed: 0.91, green: 0.93, blue: 0.95, alpha: 1).cgColor)
    for index in 0..<4 {
        let y = CGFloat(120 + index * 78)
        context.fill(CGRect(x: 72, y: y, width: CGFloat(480 - index * 36), height: 16))
        context.fill(CGRect(x: 72, y: y + 26, width: CGFloat(340 - index * 24), height: 10))
    }
    context.setFillColor(NSColor(srgbRed: 0.20, green: 0.47, blue: 0.96, alpha: 1).cgColor)
    context.fill(CGRect(x: width - 280, y: 140, width: 168, height: 108))
    context.setFillColor(NSColor(srgbRed: 0.85, green: 0.90, blue: 0.98, alpha: 1).cgColor)
    context.fill(CGRect(x: width - 280, y: 264, width: 168, height: 108))
    context.setFillColor(NSColor(srgbRed: 0.19, green: 0.64, blue: 0.42, alpha: 1).cgColor)
    context.fillEllipse(in: CGRect(x: width - 228, y: 420, width: 72, height: 72))
    return context.makeImage()!
}
