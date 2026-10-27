import AppKit
import Combine
import ImageIO
import os
import UniformTypeIdentifiers

private let projectSaveLog = Logger(subsystem: "co.uk.bymichael.shotli", category: "projects")

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
        Preset(id: "floating", name: "Floating Card", style: style(88, 22, 56, .none, .color("#FFFFFF"))),
        Preset(id: "studio", name: "Studio", style: style(80, 16, 42, .none, .wallpaper(.studio))),
        Preset(id: "soft", name: "Soft", style: style(68, 22, 30, .none, .wallpaper(.porcelain))),
        Preset(id: "browser", name: "Browser", style: style(60, 12, 36, .browser, .wallpaper(.tide))),
        Preset(id: "window", name: "Window", style: style(52, 10, 24, .desktop, .wallpaper(.dots))),
        Preset(id: "tilted", name: "Tilted", style: tilted()),
        Preset(id: "pastel", name: "Pastel", style: style(84, 24, 34, .none, .wallpaper(.glacier))),
        Preset(id: "signal", name: "Signal", style: style(76, 18, 48, .none, .wallpaper(.bloom))),
        Preset(id: "midnight", name: "Midnight", style: style(68, 14, 50, .browser, .wallpaper(.ink))),
    ]

    static func style(_ padding: CGFloat, _ radius: CGFloat, _ shadow: CGFloat, _ frame: FrameStyle, _ background: Background) -> ShotliStyle {
        ShotliStyle(padding: padding, radius: radius, shadow: shadow, frame: frame, canvas: .auto, canvasWidth: 0, canvasHeight: 0, background: background)
    }

    static func tilted() -> ShotliStyle {
        var style = style(72, 16, 40, .none, .wallpaper(.porcelain))
        style.tiltX = 8
        style.tiltY = -16
        return style
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
    var layers: [ShotLayer]
    var selectedLayerID: String?
    var activeLayoutID: String?
    var layerGap: CGFloat
}

let chromeHeight: CGFloat = 46
private let maxEdge: CGFloat = 4096
private let maxBytes = 25 * 1024 * 1024

final class EditorModel: ObservableObject {
    static let shared = EditorModel()

    @Published var picture: LoadedPicture?
    @Published var layers: [ShotLayer] = []
    @Published var selectedLayerID: String?
    @Published var activeLayoutID: String?
    @Published var layerGap: CGFloat = 0.04
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
    @Published var popoverSave = PopoverSaveSession()
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
    private var saveAfterPopover = false
    private var popoverSuccessHold = false

    private init() {}

    var selected: Annotation? {
        annotations.first { $0.id == selectedID }
    }

    var screenshotCount: Int {
        if layers.count >= 2 { return layers.count }
        return picture == nil ? 0 : 1
    }

    var layoutHeadline: String {
        switch screenshotCount {
        case 2: return "Two screenshots"
        case 3...: return "\(screenshotCount) screenshots"
        default: return "Layout presets"
        }
    }

    var layoutNote: String? {
        switch screenshotCount {
        case 2: return "These layouts place both screenshots."
        case 3: return "Three-Panel is for three pictures. A composition holds up to 6."
        case 4...: return "These layouts place every screenshot. A composition holds up to 6."
        default: return nil
        }
    }

    func openPanel() {
        importFile(into: nil, screenshotsOnly: true)
    }

    func importFile(into folder: URL?, screenshotsOnly: Bool) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = screenshotsOnly
            ? [.png, .jpeg, .webP]
            : [.png, .jpeg, .heic, .tiff, .webP]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = screenshotsOnly ? "Choose a screenshot" : "Choose an image"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if let folder {
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
                compositionID = nil
                sourceRelative = nil
                showSaveProjects = false
            } catch {
                notice = error.localizedDescription
                saveState = .failed(error.localizedDescription)
                return
            }
        }
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
            notice = "Shotli couldn't read that image. Use a PNG, JPEG, HEIC, TIFF, or WebP file."
            return
        }
        rememberSource(data, name: url.lastPathComponent, origin: url)
        replacePicture(loaded, adopting: projectFolder != nil)
    }

    func addScreenshots() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic, .tiff, .webP]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.message = "Add screenshots to this composition"
        guard panel.runModal() == .OK else { return }
        addImages(from: panel.urls)
    }

    func addImages(from urls: [URL]) {
        let files = urls.filter { !$0.hasDirectoryPath }
        guard !files.isEmpty else { return }
        if picture == nil {
            load(url: files[0])
            let rest = Array(files.dropFirst())
            if picture != nil, !rest.isEmpty { appendImages(rest) }
            return
        }
        appendImages(files)
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
            notice = "Shotli couldn't read that image. Use a PNG, JPEG, HEIC, TIFF, or WebP file."
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
        let returnFolder = projectFolder
        let returnName = projectName
        quietChanges()
        picture = nil
        resetLayers()
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
        if let returnFolder {
            let count = (try? ProjectStore.read(returnFolder))?.compositions.count ?? 0
            LibraryModel.shared.openContents(ProjectRecord(
                id: returnFolder.path,
                folder: returnFolder,
                name: returnName ?? returnFolder.lastPathComponent,
                modified: Date(),
                compositions: count,
                thumbnail: nil
            ))
        }
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
        guard let image = renderOutput() else {
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
        guard let image = renderOutput(),
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
              let image = renderOutput(),
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

    func applyLayout(_ preset: ShotLayoutPreset) {
        guard layers.count >= preset.minimum, layers.count <= preset.maximum else {
            notice = preset.minimum == preset.maximum
                ? "\(preset.name) needs \(preset.minimum) screenshots."
                : "\(preset.name) needs at least \(preset.minimum) screenshots."
            return
        }
        pushUndo()
        activeLayoutID = preset.id.rawValue
        assign(preset)
    }

    func setLayerGap(_ value: CGFloat) {
        beginGesture()
        layerGap = min(0.10, max(0.02, value))
        guard let preset = ShotLayouts.preset(id: activeLayoutID, count: layers.count) else { return }
        assign(preset)
    }

    func selectLayer(_ id: String) {
        selectedLayerID = id
        selectedID = nil
    }

    func duplicateLayer(_ id: String) {
        guard let layer = layers.first(where: { $0.id == id }) else { return }
        guard layers.count < ShotLayouts.maximum else {
            notice = "This composition holds 6 screenshots."
            return
        }
        pushUndo()
        var copy = layer
        copy.id = UUID().uuidString
        copy.order = (layers.map(\.order).max() ?? 0) + 1
        copy.x = min(0.7, layer.x + 0.04)
        copy.y = min(0.7, layer.y + 0.04)
        layers.append(copy)
        if ShotLayouts.preset(id: activeLayoutID, count: layers.count) == nil {
            reflowToFitCount()
        }
        selectedLayerID = copy.id
        selectedID = nil
    }

    func removeLayer(_ id: String) {
        guard layers.count >= 2, let index = layers.firstIndex(where: { $0.id == id }) else { return }
        pushUndo()
        let removingPrimary = index == 0
        layers.remove(at: index)
        if removingPrimary {
            annotations = []
            crop = nil
            selectedID = nil
            if let next = layers.first { adoptLayerSource(next) }
        }
        if layers.count < 2 {
            if let only = layers.first { adoptLayerSource(only) }
            layers = []
            selectedLayerID = nil
            activeLayoutID = nil
            return
        }
        if ShotLayouts.preset(id: activeLayoutID, count: layers.count) == nil {
            reflowToFitCount()
        }
        if selectedLayerID == id { selectedLayerID = nil }
    }

    func sendLayer(_ id: String, forward: Bool) {
        let sorted = layers.sorted { $0.order < $1.order }
        guard let place = sorted.firstIndex(where: { $0.id == id }) else { return }
        let neighbor = forward ? place + 1 : place - 1
        guard sorted.indices.contains(neighbor) else { return }
        guard let index = layers.firstIndex(where: { $0.id == id }),
              let other = layers.firstIndex(where: { $0.id == sorted[neighbor].id }) else { return }
        pushUndo()
        let order = layers[index].order
        layers[index].order = layers[other].order
        layers[other].order = order
    }

    func moveLayer(id: String, x: CGFloat, y: CGFloat) {
        guard let index = layers.firstIndex(where: { $0.id == id }) else { return }
        layers[index].x = min(0.92, max(-0.15, x))
        layers[index].y = min(0.92, max(-0.15, y))
    }

    func resizeLayer(id: String, width: CGFloat, height: CGFloat) {
        guard let index = layers.firstIndex(where: { $0.id == id }) else { return }
        layers[index].width = min(1.05, max(0.12, width))
        layers[index].height = min(1.05, max(0.12, height))
    }

    func pixelSize(for id: String) -> CGSize {
        guard let layer = layers.first(where: { $0.id == id }) else { return CGSize(width: 1, height: 1) }
        return layerPixelSize(layer, primaryID: layers.first?.id, picture: picture, crop: crop)
    }

    func renderOutput(interactive: Bool = false, draft: Annotation? = nil, cropDraft: CGRect? = nil) -> CGImage? {
        renderShot(
            picture: picture,
            crop: crop,
            style: style,
            annotations: annotations,
            layers: layers,
            draft: draft,
            interactive: interactive,
            cropDraft: cropDraft,
            selectedID: selectedID,
            selectedLayerID: selectedLayerID
        )
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
        updateSelectedLayer { $0.radius = value }
    }

    func setShadow(_ value: CGFloat) {
        var next = style
        next.shadow = value
        style = next
        updateSelectedLayer { $0.shadow = value }
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
        if let id = selectedID {
            pushUndo()
            annotations.removeAll { $0.id == id }
            selectedID = nil
            return
        }
        if let id = selectedLayerID {
            removeLayer(id)
        }
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
        resetLayers()
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
                resetLayers()
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

    func openComposition(_ id: String, in folder: URL) {
        if let message = flushBoundSave() {
            notice = message
            saveState = .failed(message)
            return
        }
        do {
            let file = try ProjectStore.read(folder)
            guard let composition = file.compositions.first(where: { $0.id == id }) else {
                throw ProjectError.missingSource
            }
            quietChanges()
            projectFolder = folder
            projectID = file.id
            projectName = file.name
            showSaveProjects = false
            try apply(composition, in: folder)
            saveState = .saved
            notice = nil
        } catch {
            saveState = .failed(error.localizedDescription)
            notice = error.localizedDescription
        }
    }

    func prepareSavePopover() {
        if popoverSave.isSaving { return }
        popoverSuccessHold = false
        var session = popoverSave
        session.clearFinished()
        popoverSave = session
    }

    func notePopoverClosed() {
        if popoverSave.isSaving || popoverSuccessHold { return }
        var session = popoverSave
        if session.phase.isSuccess {
            session.clearFinished()
        } else {
            session.invalidateDismiss()
        }
        popoverSave = session
    }

    func saveCurrent(into folder: URL, recordID: String? = nil, removeFolderOnFailure: Bool = false) {
        let id = recordID ?? folder.path
        var session = popoverSave
        guard let generation = session.begin(projectID: id) else { return }
        popoverSave = session
        saveState = .saving
        saveTicket += 1
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.showSaveProjects = true
            self.performPopoverSave(folder: folder, recordID: id, generation: generation, removeFolderOnFailure: removeFolderOnFailure)
        }
    }

    func scheduleProjectSave() {
        if popoverSave.isSaving {
            saveAfterPopover = true
            return
        }
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
            adoptSavedSources(outcome, folder: folder)
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
            adoptSavedSources(outcome, folder: folder)
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
            adoptSavedSources(outcome, folder: folder)
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
        restoreLayers(composition.layers, in: folder)
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

    private func performPopoverSave(folder: URL, recordID: String, generation: Int, removeFolderOnFailure: Bool) {
        guard popoverSave.generation == generation else { return }
        guard picture != nil else {
            finishPopoverSave(
                error: ProjectError.writeFailed("Open a screenshot before saving it to a project."),
                folder: folder,
                recordID: recordID,
                generation: generation,
                removeFolderOnFailure: false
            )
            return
        }
        let started = snapshot()
        let same = projectFolder?.standardizedFileURL.path == folder.standardizedFileURL.path
        if !same, let message = flushBoundSave() {
            finishPopoverSave(
                error: ProjectError.writeFailed(message),
                folder: folder,
                recordID: recordID,
                generation: generation,
                removeFolderOnFailure: removeFolderOnFailure
            )
            return
        }
        saveState = .saving
        guard var draft = makeDraft(id: same ? compositionID : nil, reuse: same ? sourceRelative : nil) else {
            finishPopoverSave(
                error: ProjectError.writeFailed("Couldn't save this screenshot."),
                folder: folder,
                recordID: recordID,
                generation: generation,
                removeFolderOnFailure: removeFolderOnFailure
            )
            return
        }
        ensureSource(&draft)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result: Result<ProjectSaveOutcome, Error>
            do {
                result = .success(try ProjectStore.saveComposition(draft, in: folder))
            } catch {
                result = .failure(error)
            }
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let outcome):
                    self.applyPopoverSave(outcome, folder: folder, recordID: recordID, generation: generation, started: started)
                case .failure(let error):
                    self.finishPopoverSave(
                        error: error,
                        folder: folder,
                        recordID: recordID,
                        generation: generation,
                        removeFolderOnFailure: removeFolderOnFailure
                    )
                }
            }
        }
    }

    private func applyPopoverSave(_ outcome: ProjectSaveOutcome, folder: URL, recordID: String, generation: Int, started: Snapshot) {
        var session = popoverSave
        guard session.succeed(projectID: recordID, name: outcome.file.name, generation: generation) else { return }
        popoverSave = session
        let edited = snapshot() != started
        quietChanges()
        projectFolder = folder
        projectID = outcome.file.id
        projectName = outcome.file.name
        compositionID = outcome.compositionID
        adoptSavedSources(outcome, folder: folder)
        saveState = .saved
        notice = "Saved to \(outcome.file.name)"
        LibraryModel.shared.refresh()
        if edited || saveAfterPopover {
            saveAfterPopover = false
            quietUntil = .distantPast
            scheduleProjectSave()
        }
        var dismissSession = popoverSave
        let token = dismissSession.armDismiss()
        popoverSave = dismissSession
        popoverSuccessHold = true
        showSaveProjects = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            guard let self, self.popoverSave.shouldDismiss(token: token) else { return }
            self.showSaveProjects = false
            self.popoverSuccessHold = false
            var done = self.popoverSave
            done.clearFinished()
            self.popoverSave = done
        }
    }

    private func finishPopoverSave(error: Error, folder: URL, recordID: String, generation: Int, removeFolderOnFailure: Bool) {
        let message = saveFailureMessage(error)
        projectSaveLog.error("Save to project failed: \(message, privacy: .public)")
        if removeFolderOnFailure {
            rollbackEmptyProject(folder)
        }
        var session = popoverSave
        guard session.fail(projectID: recordID, message: message, generation: generation) else { return }
        popoverSave = session
        saveState = .failed(message)
        notice = message
        showSaveProjects = true
        saveAfterPopover = false
    }

    private func rollbackEmptyProject(_ folder: URL) {
        do {
            let file = try ProjectStore.read(folder)
            guard file.compositions.isEmpty else { return }
            try ProjectStore.delete(folder: folder)
            LibraryModel.shared.refresh()
        } catch {
            let message = saveFailureMessage(error)
            projectSaveLog.error("Couldn't remove the unfinished project: \(message, privacy: .public)")
        }
    }

    private func saveFailureMessage(_ error: Error) -> String {
        let raw = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.contains("/") || trimmed.contains("\\") || trimmed.contains(NSHomeDirectory()) {
            return "Couldn't save this project. Try again."
        }
        return trimmed
    }

    private func makeDraft(id: String?, reuse: String?) -> CompositionDraft? {
        guard let picture else { return nil }
        let thumbnail = renderOutput()
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
            thumbnail: thumbnail,
            layers: layerDrafts(primaryReuse: reuse)
        )
    }

    private func ensureSource(_ draft: inout CompositionDraft) {
        let primaryReady = draft.reuseRelative.flatMap { reuse -> Bool? in
            guard let folder = projectFolder, let url = try? ProjectStore.resolve(reuse, in: folder) else { return nil }
            return FileManager.default.fileExists(atPath: url.path)
        } == true
        if !primaryReady {
            draft.reuseRelative = nil
        }
        if primaryReady, draft.layers.allSatisfy({ $0.reuseRelative != nil || $0.sourceData != nil }) {
            return
        }
        if primaryReady {
            fillLayerSources(&draft)
            return
        }
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
        fillLayerSources(&draft)
    }

    private func fillLayerSources(_ draft: inout CompositionDraft) {
        for index in draft.layers.indices where draft.layers[index].sourceData == nil && draft.layers[index].reuseRelative == nil {
            if index == 0, let data = draft.sourceData {
                draft.layers[index].sourceData = data
                draft.layers[index].sourceSHA256 = draft.sourceSHA256
                draft.layers[index].sourceFileName = draft.sourceFileName
                continue
            }
            guard let layer = layers.first(where: { $0.id == draft.layers[index].id }), let png = pngData(layer.image) else { continue }
            draft.layers[index].sourceData = png
            draft.layers[index].sourceSHA256 = ProjectStore.sha256(png)
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

    private func resetLayers() {
        layers = []
        selectedLayerID = nil
        activeLayoutID = nil
        layerGap = 0.04
    }

    private func appendImages(_ urls: [URL]) {
        var incoming: [(LoadedPicture, Data, String, String)] = []
        var skipped = 0
        var failed = 0
        var seen = Set(layers.compactMap(\.sourceSHA))
        if let sourceSHA { seen.insert(sourceSHA) }
        for url in urls {
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else {
                failed += 1
                continue
            }
            if data.count > maxBytes {
                failed += 1
                continue
            }
            let sha = ProjectStore.sha256(data)
            if seen.contains(sha) {
                skipped += 1
                continue
            }
            guard let loaded = decodeImage(data, name: url.lastPathComponent) else {
                failed += 1
                continue
            }
            seen.insert(sha)
            incoming.append((loaded, data, sha, url.lastPathComponent))
        }
        let room = ShotLayouts.maximum - screenshotCount
        if room <= 0 {
            notice = "This composition holds 6 screenshots."
            return
        }
        let accepted = Array(incoming.prefix(room))
        let overflow = incoming.count - accepted.count
        guard !accepted.isEmpty else {
            notice = skipped > 0
                ? "Those screenshots are already in this composition."
                : "Shotli couldn't read that image. Use a PNG, JPEG, HEIC, TIFF, or WebP file."
            return
        }
        pushUndo()
        seedPrimaryLayer()
        let start = layers.count
        for (offset, item) in accepted.enumerated() {
            layers.append(ShotLayer(
                id: UUID().uuidString,
                image: item.0.image,
                name: item.0.name,
                x: 0,
                y: 0,
                width: 0.4,
                height: 0.4,
                radius: style.radius,
                shadow: style.shadow,
                order: start + offset,
                sourceRelative: nil,
                sourceSHA: item.2,
                sourceData: item.1,
                sourceFileName: item.3
            ))
        }
        reflowToFitCount()
        selectedLayerID = layers.last?.id
        selectedID = nil
        var message = accepted.count == 1 ? "Added a screenshot." : "Added \(accepted.count) screenshots."
        if skipped > 0 { message += " Duplicates were left out." }
        if failed > 0 { message += " One file couldn't be read." }
        if overflow > 0 { message += " This composition holds 6 screenshots." }
        notice = message
    }

    private func seedPrimaryLayer() {
        guard layers.isEmpty, let picture else { return }
        layers = [ShotLayer(
            id: UUID().uuidString,
            image: picture.image,
            name: picture.name,
            x: 0,
            y: 0,
            width: 1,
            height: 1,
            radius: style.radius,
            shadow: style.shadow,
            order: 0,
            sourceRelative: sourceRelative,
            sourceSHA: sourceSHA,
            sourceData: sourceData,
            sourceFileName: sourceFileName
        )]
    }

    private func reflowToFitCount() {
        guard layers.count >= 2 else { return }
        let preset = ShotLayouts.preset(id: activeLayoutID, count: layers.count) ?? ShotLayouts.choices(for: layers.count).first
        guard let preset else { return }
        activeLayoutID = preset.id.rawValue
        assign(preset)
    }

    private func assign(_ preset: ShotLayoutPreset) {
        let frames = ShotLayouts.boxes(preset.id, count: layers.count, gap: layerGap)
        for index in layers.indices {
            guard index < frames.count else { break }
            layers[index].x = frames[index].x
            layers[index].y = frames[index].y
            layers[index].width = frames[index].width
            layers[index].height = frames[index].height
            layers[index].radius = frames[index].radius
            layers[index].shadow = frames[index].shadow
            layers[index].order = index
        }
    }

    private func adoptLayerSource(_ layer: ShotLayer) {
        picture = LoadedPicture(image: layer.image, name: layer.name, scaled: picture?.scaled ?? false)
        sourceRelative = layer.sourceRelative
        sourceData = layer.sourceData
        sourceSHA = layer.sourceSHA
        sourceFileName = layer.sourceFileName ?? layer.name
    }

    private func updateSelectedLayer(_ change: (inout ShotLayer) -> Void) {
        guard layers.count >= 2 else { return }
        if let id = selectedLayerID, let index = layers.firstIndex(where: { $0.id == id }) {
            change(&layers[index])
            return
        }
        for index in layers.indices { change(&layers[index]) }
    }

    private func layerDrafts(primaryReuse: String?) -> [LayerDraft] {
        guard layers.count >= 2 else { return [] }
        return layers.enumerated().map { index, layer in
            LayerDraft(
                id: layer.id,
                name: layer.name,
                sourceData: layer.sourceData ?? (index == 0 ? sourceData : nil),
                sourceFileName: layer.sourceFileName ?? layer.name,
                sourceSHA256: layer.sourceSHA ?? (index == 0 ? sourceSHA : nil),
                reuseRelative: layer.sourceRelative ?? (index == 0 ? primaryReuse : nil),
                x: Double(layer.x),
                y: Double(layer.y),
                width: Double(layer.width),
                height: Double(layer.height),
                radius: Double(layer.radius),
                shadow: Double(layer.shadow),
                order: layer.order
            )
        }
    }

    private func restoreLayers(_ stored: [LayerFile]?, in folder: URL) {
        selectedLayerID = nil
        activeLayoutID = nil
        guard let stored, stored.count >= 2 else {
            layers = []
            return
        }
        var loaded: [ShotLayer] = []
        for file in stored {
            guard let url = try? ProjectStore.resolve(file.source, in: folder),
                  let data = try? Data(contentsOf: url),
                  data.count <= maxBytes,
                  let image = decodeImage(data, name: url.lastPathComponent) else { continue }
            loaded.append(ShotLayer(
                id: file.id,
                image: image.image,
                name: file.name,
                x: CGFloat(file.x),
                y: CGFloat(file.y),
                width: CGFloat(file.width),
                height: CGFloat(file.height),
                radius: CGFloat(file.radius),
                shadow: CGFloat(file.shadow),
                order: file.order,
                sourceRelative: file.source,
                sourceSHA: file.sourceSHA256 ?? ProjectStore.sha256(data),
                sourceData: nil,
                sourceFileName: url.lastPathComponent
            ))
        }
        guard loaded.count >= 2 else {
            layers = []
            return
        }
        layers = loaded
        adoptLayerSource(loaded[0])
    }

    private func adoptSavedSources(_ outcome: ProjectSaveOutcome, folder: URL) {
        sourceRelative = outcome.relative
        if let relative = outcome.relative, let url = try? ProjectStore.resolve(relative, in: folder) {
            sourceOrigin = url
        }
        sourceData = nil
        guard let saved = outcome.file.compositions.first(where: { $0.id == outcome.compositionID })?.layers else { return }
        for file in saved {
            guard let index = layers.firstIndex(where: { $0.id == file.id }) else { continue }
            layers[index].sourceRelative = file.source
            layers[index].sourceSHA = file.sourceSHA256
            layers[index].sourceData = nil
        }
        if let first = layers.first, first.sourceRelative == nil {
            layers[0].sourceRelative = outcome.relative
        }
    }

    private func snapshot() -> Snapshot {
        Snapshot(
            crop: crop,
            style: style,
            annotations: annotations,
            selectedID: selectedID,
            layers: layers,
            selectedLayerID: selectedLayerID,
            activeLayoutID: activeLayoutID,
            layerGap: layerGap
        )
    }

    private func restore(_ snap: Snapshot) {
        crop = snap.crop
        style = snap.style
        annotations = snap.annotations
        selectedID = snap.selectedID
        layers = snap.layers
        selectedLayerID = snap.selectedLayerID
        activeLayoutID = snap.activeLayoutID
        layerGap = snap.layerGap
        if let first = layers.first { adoptLayerSource(first) }
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
