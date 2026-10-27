import AppKit
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ShotliProjects {
    static var rootOverride: URL?

    static var root: URL {
        if let rootOverride { return rootOverride }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
                .appendingPathComponent("Library/Application Support", isDirectory: true)
        return base
            .appendingPathComponent("Shotli", isDirectory: true)
            .appendingPathComponent("Projects", isDirectory: true)
    }

    static var displayRoot: String {
        let path = root.path
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}

struct ProjectRecord: Identifiable, Equatable {
    var id: String
    var folder: URL
    var name: String
    var modified: Date
    var compositions: Int
    var thumbnail: URL?
}

struct CompositionRecord: Identifiable, Equatable {
    var id: String
    var name: String
    var modified: Date
    var previewURL: URL?
}

struct ProjectAsset: Codable, Equatable {
    var path: String
    var sha256: String
}

struct PointFile: Codable, Equatable {
    var x: Double
    var y: Double
}

struct CropFile: Codable, Equatable {
    var x: Double
    var y: Double
    var w: Double
    var h: Double

    init(_ rect: CGRect) {
        x = Double(rect.origin.x)
        y = Double(rect.origin.y)
        w = Double(rect.size.width)
        h = Double(rect.size.height)
    }

    var rect: CGRect { CGRect(x: x, y: y, width: w, height: h) }
}

struct BackgroundFile: Codable, Equatable {
    var kind: String
    var color: String?
    var from: String?
    var mid: String?
    var to: String?
    var angle: Double?
    var wallpaper: String?

    init(_ background: Background) {
        switch background {
        case .color(let value):
            kind = "color"
            color = value
        case .gradient(let from, let mid, let to, let angle):
            kind = "gradient"
            self.from = from
            self.mid = mid
            self.to = to
            self.angle = Double(angle)
        case .wallpaper(let id):
            kind = "wallpaper"
            wallpaper = id.rawValue
        }
    }

    var background: Background {
        switch kind {
        case "gradient":
            return .gradient(from: from ?? "#FFFFFF", mid: mid, to: to ?? "#000000", angle: CGFloat(angle ?? 135))
        case "wallpaper":
            if let wallpaper, let id = WallpaperID(rawValue: wallpaper) { return .wallpaper(id) }
            return .color("#FFFFFF")
        default:
            return .color(color ?? "#FFFFFF")
        }
    }
}

struct StyleFile: Codable, Equatable {
    var padding: Double
    var radius: Double
    var shadow: Double
    var frame: String
    var canvas: String
    var canvasWidth: Double
    var canvasHeight: Double
    var background: BackgroundFile
    var card: String
    var shadowKind: String
    var shadowOpacity: Double
    var light: Double
    var hideMockup: Bool
    var tiltX: Double
    var tiltY: Double
    var shiftX: Double
    var shiftY: Double

    init(_ style: ShotliStyle) {
        padding = Double(style.padding)
        radius = Double(style.radius)
        shadow = Double(style.shadow)
        frame = style.frame.rawValue
        canvas = style.canvas.rawValue
        canvasWidth = Double(style.canvasWidth)
        canvasHeight = Double(style.canvasHeight)
        background = BackgroundFile(style.background)
        card = style.card.rawValue
        shadowKind = style.shadowKind.rawValue
        shadowOpacity = Double(style.shadowOpacity)
        light = Double(style.light)
        hideMockup = style.hideMockup
        tiltX = Double(style.tiltX)
        tiltY = Double(style.tiltY)
        shiftX = Double(style.shiftX)
        shiftY = Double(style.shiftY)
    }

    var style: ShotliStyle {
        var next = ShotliStyle(
            padding: CGFloat(padding),
            radius: CGFloat(radius),
            shadow: CGFloat(shadow),
            frame: FrameStyle(rawValue: frame) ?? .none,
            canvas: CanvasRatio(rawValue: canvas) ?? .auto,
            canvasWidth: CGFloat(canvasWidth),
            canvasHeight: CGFloat(canvasHeight),
            background: background.background
        )
        next.card = CardStyle(rawValue: card) ?? .default
        next.shadowKind = ShadowKind(rawValue: shadowKind) ?? .spread
        next.shadowOpacity = CGFloat(shadowOpacity)
        next.light = CGFloat(light)
        next.hideMockup = hideMockup
        next.tiltX = CGFloat(tiltX)
        next.tiltY = CGFloat(tiltY)
        next.shiftX = CGFloat(shiftX)
        next.shiftY = CGFloat(shiftY)
        return next
    }
}

struct AnnotationFile: Codable, Equatable {
    var type: String
    var id: String
    var kind: String?
    var color: String?
    var strokeWidth: Double?
    var x: Double?
    var y: Double?
    var w: Double?
    var h: Double?
    var amount: Double?
    var arrow: Bool?
    var x2: Double?
    var y2: Double?
    var points: [PointFile]?
    var text: String?
    var fontSize: Double?
    var n: Int?

    init(_ annotation: Annotation) {
        switch annotation {
        case .shape(let mark):
            type = "shape"
            id = mark.id
            kind = mark.kind.rawValue
            color = mark.color
            strokeWidth = Double(mark.strokeWidth)
            x = Double(mark.x)
            y = Double(mark.y)
            w = Double(mark.w)
            h = Double(mark.h)
            amount = Double(mark.amount)
        case .line(let mark):
            type = "line"
            id = mark.id
            arrow = mark.arrow
            color = mark.color
            strokeWidth = Double(mark.strokeWidth)
            x = Double(mark.x)
            y = Double(mark.y)
            x2 = Double(mark.x2)
            y2 = Double(mark.y2)
        case .draw(let mark):
            type = "draw"
            id = mark.id
            color = mark.color
            strokeWidth = Double(mark.strokeWidth)
            points = mark.points.map { PointFile(x: Double($0.x), y: Double($0.y)) }
        case .text(let mark):
            type = "text"
            id = mark.id
            color = mark.color
            x = Double(mark.x)
            y = Double(mark.y)
            text = mark.text
            fontSize = Double(mark.fontSize)
        case .marker(let mark):
            type = "marker"
            id = mark.id
            color = mark.color
            x = Double(mark.x)
            y = Double(mark.y)
            n = mark.n
        }
    }

    var annotation: Annotation? {
        switch type {
        case "shape":
            guard let kind, let shape = ShapeKind(rawValue: kind) else { return nil }
            return .shape(ShapeMark(
                id: id,
                kind: shape,
                color: color ?? "#E5484D",
                strokeWidth: CGFloat(strokeWidth ?? 4),
                x: CGFloat(x ?? 0),
                y: CGFloat(y ?? 0),
                w: CGFloat(w ?? 0),
                h: CGFloat(h ?? 0),
                amount: CGFloat(amount ?? 0)
            ))
        case "line":
            return .line(LineMark(
                id: id,
                arrow: arrow ?? false,
                color: color ?? "#E5484D",
                strokeWidth: CGFloat(strokeWidth ?? 4),
                x: CGFloat(x ?? 0),
                y: CGFloat(y ?? 0),
                x2: CGFloat(x2 ?? 0),
                y2: CGFloat(y2 ?? 0)
            ))
        case "draw":
            return .draw(DrawMark(
                id: id,
                color: color ?? "#E5484D",
                strokeWidth: CGFloat(strokeWidth ?? 4),
                points: (points ?? []).map { CGPoint(x: $0.x, y: $0.y) }
            ))
        case "text":
            return .text(TextMark(
                id: id,
                color: color ?? "#222222",
                x: CGFloat(x ?? 0),
                y: CGFloat(y ?? 0),
                text: text ?? "",
                fontSize: CGFloat(fontSize ?? 24)
            ))
        case "marker":
            return .marker(MarkerMark(
                id: id,
                color: color ?? "#E5484D",
                x: CGFloat(x ?? 0),
                y: CGFloat(y ?? 0),
                n: n ?? 1
            ))
        default:
            return nil
        }
    }
}

struct CompositionFile: Codable, Equatable {
    var id: String
    var name: String
    var created: String
    var modified: String
    var source: String?
    var sourceSHA256: String?
    var thumbnail: String?
    var crop: CropFile?
    var style: StyleFile
    var annotations: [AnnotationFile]
}

struct ProjectFile: Codable, Equatable {
    var version: Int
    var id: String
    var name: String
    var created: String
    var modified: String
    var compositions: [CompositionFile]
    var assets: [ProjectAsset]
}

struct CompositionDraft {
    var id: String?
    var name: String
    var sourceData: Data?
    var sourceFileName: String
    var sourceSHA256: String?
    var reuseRelative: String?
    var crop: CGRect?
    var style: ShotliStyle
    var annotations: [Annotation]
    var thumbnail: CGImage?
}

struct ProjectSaveOutcome {
    var file: ProjectFile
    var compositionID: String
    var relative: String?
}

enum ProjectError: LocalizedError {
    case invalidName(String)
    case alreadyExists(String)
    case missingFolder
    case missingSource
    case unreadable(String)
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidName(let message): return message
        case .alreadyExists(let name): return "A project named “\(name)” already exists."
        case .missingFolder: return "That project folder is missing."
        case .missingSource: return "The screenshot for this composition is missing."
        case .unreadable(let message): return message
        case .writeFailed(let message): return message
        }
    }
}

enum ProjectStore {
    static func stamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    static func date(_ value: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value) ?? .distantPast
    }

    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func folderName(for name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.count > 80 { return nil }
        if trimmed == "." || trimmed == ".." || trimmed.hasPrefix(".") { return nil }
        if trimmed.contains("/") || trimmed.contains(":") || trimmed.contains("\\") { return nil }
        if trimmed.unicodeScalars.contains(where: { $0.value < 32 }) { return nil }
        return trimmed
    }

    static func validationError(for name: String, excluding: URL? = nil, root: URL? = nil) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Name the project before creating it." }
        guard let safe = folderName(for: trimmed) else {
            return "Use a name without slashes, colons, or a leading dot."
        }
        if nameTaken(safe, excluding: excluding, root: root) {
            return "A project named “\(safe)” already exists."
        }
        return nil
    }

    static func suggestedName(in root: URL? = nil) -> String {
        let base = "Untitled Project"
        if !nameTaken(base, root: root) { return base }
        var extra = 2
        while nameTaken("\(base) \(extra)", root: root) { extra += 1 }
        return "\(base) \(extra)"
    }

    static func nameTaken(_ name: String, excluding: URL? = nil, root: URL? = nil) -> Bool {
        guard let safe = folderName(for: name) else { return false }
        let folderRoot = root ?? ShotliProjects.root
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: folderRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return false }
        return items.contains { item in
            if let excluding, samePath(item, excluding) { return false }
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: item.path, isDirectory: &isDirectory), isDirectory.boolValue else { return false }
            return item.lastPathComponent.caseInsensitiveCompare(safe) == .orderedSame
        }
    }

    static func list(in root: URL? = nil) -> [ProjectRecord] {
        let folderRoot = root ?? ShotliProjects.root
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: folderRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        return items.compactMap { url in
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else { return nil }
            guard let file = try? read(url) else { return nil }
            if file.version != 1 { return nil }
            let thumb = url.appendingPathComponent("thumb.png")
            let hasThumb = FileManager.default.fileExists(atPath: thumb.path)
            return ProjectRecord(
                id: url.path,
                folder: url,
                name: file.name,
                modified: date(file.modified),
                compositions: file.compositions.count,
                thumbnail: hasThumb ? thumb : nil
            )
        }
    }

    static func create(name: String, root: URL? = nil) throws -> URL {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let safe = folderName(for: trimmed) else {
            throw ProjectError.invalidName("Use a name without slashes, colons, or a leading dot.")
        }
        let folderRoot = root ?? ShotliProjects.root
        if nameTaken(safe, root: folderRoot) {
            throw ProjectError.alreadyExists(safe)
        }
        do {
            try FileManager.default.createDirectory(at: folderRoot, withIntermediateDirectories: true)
        } catch {
            throw ProjectError.writeFailed("Shotli couldn't create the projects folder.")
        }
        let folder = folderRoot.appendingPathComponent(safe, isDirectory: true)
        if FileManager.default.fileExists(atPath: folder.path) {
            throw ProjectError.alreadyExists(safe)
        }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
            try FileManager.default.createDirectory(at: folder.appendingPathComponent("Assets", isDirectory: true), withIntermediateDirectories: false)
            try FileManager.default.createDirectory(at: folder.appendingPathComponent("Screenshots", isDirectory: true), withIntermediateDirectories: false)
            try FileManager.default.createDirectory(at: folder.appendingPathComponent("Exports", isDirectory: true), withIntermediateDirectories: false)
            let now = stamp(Date())
            let file = ProjectFile(
                version: 1,
                id: UUID().uuidString,
                name: safe,
                created: now,
                modified: now,
                compositions: [],
                assets: []
            )
            try write(file, to: folder)
        } catch {
            try? FileManager.default.removeItem(at: folder)
            if let project = error as? ProjectError { throw project }
            throw ProjectError.writeFailed("Shotli couldn't create that project.")
        }
        return folder
    }

    static func read(_ folder: URL) throws -> ProjectFile {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw ProjectError.missingFolder
        }
        let primary = folder.appendingPathComponent("project.json")
        let backup = folder.appendingPathComponent("project.json.bak")
        if let file = decode(primary), file.version == 1 { return file }
        if let file = decode(backup), file.version == 1 { return file }
        if let file = decode(primary), file.version > 1 {
            throw ProjectError.unreadable("This project was saved by a newer Shotli.")
        }
        throw ProjectError.unreadable("The project file couldn't be read.")
    }

    static func write(_ file: ProjectFile, to folder: URL) throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw ProjectError.missingFolder
        }
        let dest = folder.appendingPathComponent("project.json")
        let backup = folder.appendingPathComponent("project.json.bak")
        let data: Data
        do {
            data = try encode(file)
        } catch {
            throw ProjectError.writeFailed("Shotli couldn't prepare the project file.")
        }
        if FileManager.default.fileExists(atPath: dest.path) {
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.copyItem(at: dest, to: backup)
        }
        do {
            try data.write(to: dest, options: .atomic)
        } catch {
            throw ProjectError.writeFailed("Shotli couldn't save the project. \(error.localizedDescription)")
        }
    }

    @discardableResult
    static func saveComposition(_ draft: CompositionDraft, in folder: URL) throws -> ProjectSaveOutcome {
        guard FileManager.default.fileExists(atPath: folder.path) else { throw ProjectError.missingFolder }
        var file: ProjectFile
        do {
            file = try read(folder)
        } catch let error as ProjectError {
            throw error
        } catch {
            throw ProjectError.unreadable("The project file couldn't be read.")
        }
        var relative = draft.reuseRelative
        if let reuse = relative {
            let existing = try resolve(reuse, in: folder)
            if !FileManager.default.fileExists(atPath: existing.path) { relative = nil }
        }
        if relative == nil {
            guard let data = draft.sourceData else { throw ProjectError.missingSource }
            let sha = draft.sourceSHA256 ?? sha256(data)
            relative = try importData(data, fileName: draft.sourceFileName, sha256: sha, into: folder, file: &file)
        }
        let sha = draft.sourceSHA256 ?? file.assets.first(where: { $0.path == relative })?.sha256
        let now = stamp(Date())
        let id = draft.id ?? UUID().uuidString
        var composition = CompositionFile(
            id: id,
            name: compositionName(draft.name),
            created: now,
            modified: now,
            source: relative,
            sourceSHA256: sha,
            thumbnail: draft.thumbnail == nil ? nil : thumbnailRelative(id),
            crop: draft.crop.map(CropFile.init),
            style: StyleFile(draft.style),
            annotations: draft.annotations.map(AnnotationFile.init)
        )
        if let index = file.compositions.firstIndex(where: { $0.id == id }) {
            composition.created = file.compositions[index].created
            if composition.thumbnail == nil { composition.thumbnail = file.compositions[index].thumbnail }
            file.compositions[index] = composition
        } else {
            file.compositions.append(composition)
        }
        file.modified = now
        if let thumbnail = draft.thumbnail {
            do {
                if let relative = thumbnailRelative(id) {
                    let dest = try resolve(relative, in: folder)
                    try FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try writePNG(thumbnail, to: dest)
                }
                try writePNG(thumbnail, to: folder.appendingPathComponent("thumb.png"))
            } catch let error as ProjectError {
                throw error
            } catch {
                throw ProjectError.writeFailed("Shotli couldn't update the project thumbnail.")
            }
        }
        try write(file, to: folder)
        guard FileManager.default.fileExists(atPath: folder.appendingPathComponent("project.json").path) else {
            throw ProjectError.writeFailed("Shotli couldn't save the project.")
        }
        return ProjectSaveOutcome(file: file, compositionID: id, relative: relative)
    }

    static func rename(folder: URL, to name: String) throws -> URL {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let safe = folderName(for: trimmed) else {
            throw ProjectError.invalidName("Use a name without slashes, colons, or a leading dot.")
        }
        var file = try read(folder)
        let parent = folder.deletingLastPathComponent()
        if nameTaken(safe, excluding: folder, root: parent) {
            throw ProjectError.alreadyExists(safe)
        }
        file.name = safe
        file.modified = stamp(Date())
        try write(file, to: folder)
        let dest = parent.appendingPathComponent(safe, isDirectory: true)
        if samePath(folder, dest) { return folder }
        do {
            if dest.path.lowercased() == folder.path.lowercased() {
                let bridge = parent.appendingPathComponent(".\(UUID().uuidString)", isDirectory: true)
                try FileManager.default.moveItem(at: folder, to: bridge)
                try FileManager.default.moveItem(at: bridge, to: dest)
            } else {
                try FileManager.default.moveItem(at: folder, to: dest)
            }
        } catch {
            throw ProjectError.writeFailed("Shotli couldn't rename that project folder.")
        }
        return dest
    }

    static func duplicate(folder: URL) throws -> URL {
        let file = try read(folder)
        let parent = folder.deletingLastPathComponent()
        var copyName = "\(file.name) copy"
        var extra = 2
        while nameTaken(copyName, root: parent) || folderName(for: copyName) == nil {
            copyName = "\(file.name) copy \(extra)"
            extra += 1
            if extra > 500 { throw ProjectError.writeFailed("Shotli couldn't find a name for the copy.") }
        }
        guard let safe = folderName(for: copyName) else {
            throw ProjectError.writeFailed("Shotli couldn't name the copy.")
        }
        let dest = parent.appendingPathComponent(safe, isDirectory: true)
        do {
            try FileManager.default.copyItem(at: folder, to: dest)
        } catch {
            throw ProjectError.writeFailed("Shotli couldn't copy that project.")
        }
        do {
            var copy = try read(dest)
            let now = stamp(Date())
            copy.id = UUID().uuidString
            copy.name = safe
            copy.created = now
            copy.modified = now
            copy.compositions = copy.compositions.map { item in
                var next = item
                next.id = UUID().uuidString
                return next
            }
            try write(copy, to: dest)
        } catch {
            try? FileManager.default.removeItem(at: dest)
            throw ProjectError.writeFailed("Shotli couldn't finish the copy.")
        }
        return dest
    }

    static func delete(folder: URL) throws {
        let root = (ShotliProjects.rootOverride ?? ShotliProjects.root).standardizedFileURL.path
        let path = folder.standardizedFileURL.path
        guard path.hasPrefix(root + "/") else {
            throw ProjectError.writeFailed("That folder is outside Shotli's projects.")
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw ProjectError.missingFolder
        }
        do {
            try FileManager.default.trashItem(at: folder, resultingItemURL: nil)
        } catch {
            if rootOverrideIsActive {
                try? FileManager.default.removeItem(at: folder)
            } else {
                throw ProjectError.writeFailed("Shotli couldn't move that project to the Trash.")
            }
        }
        if FileManager.default.fileExists(atPath: folder.path) {
            throw ProjectError.writeFailed("The project folder is still there.")
        }
    }

    private static var rootOverrideIsActive: Bool {
        ShotliProjects.rootOverride != nil
    }

    static func compositionRecords(in folder: URL) -> [CompositionRecord] {
        guard let file = try? read(folder) else { return [] }
        let sorted = file.compositions.sorted { date($0.modified) > date($1.modified) }
        return sorted.enumerated().map { index, composition in
            CompositionRecord(
                id: composition.id,
                name: composition.name,
                modified: date(composition.modified),
                previewURL: previewURL(for: composition, in: folder, preferCover: index == 0)
            )
        }
    }

    static func renderMissingThumbnails(in folder: URL) throws {
        var file = try read(folder)
        var changed = false
        for index in file.compositions.indices {
            let composition = file.compositions[index]
            if let relative = composition.thumbnail,
               relative != "thumb.png",
               let existing = try? resolve(relative, in: folder),
               FileManager.default.fileExists(atPath: existing.path) {
                continue
            }
            guard let relative = thumbnailRelative(composition.id) else { continue }
            let dest = try resolve(relative, in: folder)
            if FileManager.default.fileExists(atPath: dest.path) {
                if file.compositions[index].thumbnail != relative {
                    file.compositions[index].thumbnail = relative
                    changed = true
                }
                continue
            }
            guard let source = composition.source,
                  let sourceURL = try? resolve(source, in: folder),
                  let data = try? Data(contentsOf: sourceURL),
                  let image = imageForThumbnail(data) else { continue }
            let picture = LoadedPicture(image: image, name: sourceURL.lastPathComponent, scaled: false)
            let marks = composition.annotations.compactMap(\.annotation)
            guard let rendered = renderComposition(
                picture: picture,
                crop: composition.crop?.rect,
                style: composition.style.style,
                annotations: marks,
                draft: nil,
                interactive: false
            ) else { continue }
            try FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            try writePNG(rendered, to: dest)
            file.compositions[index].thumbnail = relative
            changed = true
        }
        if changed {
            try write(file, to: folder)
        }
    }

    static func thumbnailRelative(_ id: String) -> String? {
        let cleaned = String(String.UnicodeScalarView(id.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) || $0 == "-" }))
        guard !cleaned.isEmpty, cleaned.count < 80 else { return nil }
        return "Thumbnails/\(cleaned).png"
    }

    static func resolve(_ relative: String, in folder: URL) throws -> URL {
        if relative.hasPrefix("/") || relative.contains("\\") || relative.contains("..") {
            throw ProjectError.unreadable("The project refers to a file outside its folder.")
        }
        let parts = relative.split(separator: "/").map(String.init)
        if parts.isEmpty || parts.contains("..") || parts.contains(".") {
            throw ProjectError.unreadable("The project refers to a file outside its folder.")
        }
        return parts.reduce(folder) { $0.appendingPathComponent($1) }
    }

    private static func previewURL(for composition: CompositionFile, in folder: URL, preferCover: Bool) -> URL? {
        if let relative = composition.thumbnail,
           relative != "thumb.png",
           let url = try? resolve(relative, in: folder),
           FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        if let relative = thumbnailRelative(composition.id),
           let url = try? resolve(relative, in: folder),
           FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        if let source = composition.source,
           let url = try? resolve(source, in: folder),
           FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        if preferCover {
            let cover = folder.appendingPathComponent("thumb.png")
            if FileManager.default.fileExists(atPath: cover.path) { return cover }
        }
        return nil
    }

    private static func imageForThumbnail(_ data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 1600,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private static func importData(
        _ data: Data,
        fileName: String,
        sha256 hash: String,
        into folder: URL,
        file: inout ProjectFile
    ) throws -> String {
        if let existing = file.assets.first(where: { $0.sha256 == hash }) {
            if let url = try? resolve(existing.path, in: folder), FileManager.default.fileExists(atPath: url.path) {
                return existing.path
            }
        }
        let screenshots = folder.appendingPathComponent("Screenshots", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: screenshots, withIntermediateDirectories: true)
        } catch {
            throw ProjectError.writeFailed("Shotli couldn't create the Screenshots folder.")
        }
        let cleaned = sanitizedFileName(fileName)
        var candidate = cleaned
        var dest = screenshots.appendingPathComponent(candidate)
        var extra = 2
        while FileManager.default.fileExists(atPath: dest.path) {
            let base = (cleaned as NSString).deletingPathExtension
            let ext = (cleaned as NSString).pathExtension
            candidate = ext.isEmpty ? "\(base)-\(extra)" : "\(base)-\(extra).\(ext)"
            dest = screenshots.appendingPathComponent(candidate)
            extra += 1
        }
        do {
            try data.write(to: dest, options: .atomic)
        } catch {
            throw ProjectError.writeFailed("Shotli couldn't copy the screenshot into the project.")
        }
        let relative = "Screenshots/\(candidate)"
        file.assets.append(ProjectAsset(path: relative, sha256: hash))
        return relative
    }

    private static func sanitizedFileName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let scalars = trimmed.unicodeScalars.map { scalar -> Character in
            if scalar.value < 32 || "/:\\".unicodeScalars.contains(scalar) { return "-" }
            return Character(scalar)
        }
        var text = String(scalars)
        if text.isEmpty || text == "." || text == ".." { text = "Screenshot.png" }
        if (text as NSString).pathExtension.isEmpty { text += ".png" }
        if text.hasPrefix(".") { text = "Screenshot" + text }
        return text
    }

    private static func compositionName(_ name: String) -> String {
        let base = (name as NSString).deletingPathExtension
        let trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Composition" : trimmed
    }

    private static func samePath(_ lhs: URL, _ rhs: URL) -> Bool {
        lhs.standardizedFileURL.path == rhs.standardizedFileURL.path
    }

    private static func encode(_ file: ProjectFile) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(file)
    }

    private static func decode(_ url: URL) -> ProjectFile? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ProjectFile.self, from: data)
    }

    private static func writePNG(_ image: CGImage, to url: URL) throws {
        let temp = url.deletingLastPathComponent().appendingPathComponent(".\(UUID().uuidString).png")
        guard let destination = CGImageDestinationCreateWithURL(temp as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw ProjectError.writeFailed("Shotli couldn't update the project thumbnail.")
        }
        CGImageDestinationAddImage(destination, image, nil)
        if !CGImageDestinationFinalize(destination) {
            try? FileManager.default.removeItem(at: temp)
            throw ProjectError.writeFailed("Shotli couldn't update the project thumbnail.")
        }
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                _ = try FileManager.default.replaceItemAt(url, withItemAt: temp)
            } else {
                try FileManager.default.moveItem(at: temp, to: url)
            }
        } catch {
            try? FileManager.default.removeItem(at: temp)
            throw ProjectError.writeFailed("Shotli couldn't update the project thumbnail.")
        }
    }
}

enum ProjectVerify {
    static func run() -> Int {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("shotli-projects-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            ShotliProjects.rootOverride = root
            defer {
                ShotliProjects.rootOverride = nil
                try? FileManager.default.removeItem(at: root)
            }
            try checkProjects(in: root)
            print("projects verified")
            return 0
        } catch {
            ShotliProjects.rootOverride = nil
            try? FileManager.default.removeItem(at: root)
            fputs("projects verify failed: \(error)\n", stderr)
            return 1
        }
    }

    private static func checkProjects(in root: URL) throws {
        if ProjectStore.validationError(for: "", root: root) == nil { throw Failure("empty name was accepted") }
        if ProjectStore.validationError(for: "Bad/Name", root: root) == nil { throw Failure("slash name was accepted") }
        if ProjectStore.suggestedName(in: root) != "Untitled Project" { throw Failure("default name") }
        let before = try folders(in: root)
        if ProjectStore.validationError(for: "Untitled Project", root: root) != nil { throw Failure("default name was invalid") }
        if try folders(in: root) != before { throw Failure("validation created a folder") }

        let folder = try ProjectStore.create(name: "BM.studio Homepage", root: root)
        if folder.lastPathComponent != "BM.studio Homepage" { throw Failure("folder name") }
        for part in ["project.json", "Assets", "Screenshots", "Exports"] {
            if !FileManager.default.fileExists(atPath: folder.appendingPathComponent(part).path) {
                throw Failure("missing \(part)")
            }
        }
        let created = try ProjectStore.read(folder)
        if created.version != 1 || created.compositions.isEmpty == false || created.name != "BM.studio Homepage" {
            throw Failure("new project file")
        }
        do {
            _ = try ProjectStore.create(name: "bm.studio homepage", root: root)
            throw Failure("duplicate create reported success")
        } catch let error as ProjectError {
            if case .alreadyExists = error {} else { throw error }
        }
        if try folders(in: root) != 1 { throw Failure("duplicate create wrote a folder") }

        let original = root.deletingLastPathComponent().appendingPathComponent("shotli-original-\(UUID().uuidString).png")
        let png = try tinyPNG()
        try png.write(to: original, options: .atomic)
        let originalBytes = try Data(contentsOf: original)
        var style = Presets.all[0].style
        style.padding = 72
        style.radius = 18
        style.shadow = 40
        style.frame = .browser
        style.canvas = .sixteenNine
        style.background = .gradient(from: "#111111", mid: "#2255AA", to: "#EEEEEE", angle: 42)
        style.card = .glassLight
        style.shadowKind = .hug
        style.shadowOpacity = 55
        style.light = 12
        style.hideMockup = true
        style.tiltX = 3
        style.tiltY = -4
        style.shiftX = 0.1
        style.shiftY = -0.2
        let mark = Annotation.text(TextMark(id: "t1", color: "#112233", x: 8, y: 9, text: "Hello", fontSize: 21))
        let draft = CompositionDraft(
            id: nil,
            name: "Capture.png",
            sourceData: originalBytes,
            sourceFileName: "Capture.png",
            sourceSHA256: ProjectStore.sha256(originalBytes),
            reuseRelative: nil,
            crop: CGRect(x: 4, y: 6, width: 20, height: 18),
            style: style,
            annotations: [mark],
            thumbnail: tinyImage()
        )
        let first = try ProjectStore.saveComposition(draft, in: folder)
        if try Data(contentsOf: original) != originalBytes { throw Failure("original screenshot changed") }
        if FileManager.default.fileExists(atPath: original.path) == false { throw Failure("original screenshot moved") }
        let screenshots = try files(in: folder.appendingPathComponent("Screenshots"))
        if screenshots.count != 1 { throw Failure("screenshot copy count \(screenshots.count)") }
        if !FileManager.default.fileExists(atPath: folder.appendingPathComponent("thumb.png").path) { throw Failure("thumbnail") }
        let loaded = try ProjectStore.read(folder)
        guard let composition = loaded.compositions.first else { throw Failure("composition missing") }
        if composition.id != first.compositionID { throw Failure("composition id") }
        let restored = composition.style.style
        if restored.padding != 72 || restored.radius != 18 || restored.frame != .browser || restored.card != .glassLight || restored.shadowKind != .hug || restored.hideMockup != true {
            throw Failure("style round trip")
        }
        if abs(restored.shiftX - 0.1) > 0.001 || abs(restored.tiltY - (-4)) > 0.001 { throw Failure("style position") }
        if case .gradient(let from, let mid, let to, let angle) = restored.background {
            if from != "#111111" || mid != "#2255AA" || to != "#EEEEEE" || abs(angle - 42) > 0.001 {
                throw Failure("background round trip")
            }
        } else {
            throw Failure("background round trip")
        }
        if composition.crop?.rect != draft.crop { throw Failure("crop round trip") }
        if composition.annotations.compactMap(\.annotation) != [mark] { throw Failure("annotation round trip") }
        if loaded.assets.count != 1 { throw Failure("asset record") }

        var again = draft
        again.id = nil
        again.reuseRelative = nil
        _ = try ProjectStore.saveComposition(again, in: folder)
        let screenshotsAfter = try files(in: folder.appendingPathComponent("Screenshots"))
        if screenshotsAfter.count != 1 { throw Failure("second save duplicated the screenshot") }
        let two = try ProjectStore.read(folder)
        if two.compositions.count != 2 || two.assets.count != 1 { throw Failure("second composition") }
        let thumbs = try files(in: folder.appendingPathComponent("Thumbnails"))
        if thumbs.count != 2 { throw Failure("composition thumbnails \(thumbs.count)") }
        if two.compositions[0].source != two.compositions[1].source { throw Failure("compositions do not share the asset") }

        var updated = draft
        updated.id = first.compositionID
        updated.reuseRelative = first.relative
        updated.sourceData = nil
        updated.style.padding = 90
        _ = try ProjectStore.saveComposition(updated, in: folder)
        let rewritten = try ProjectStore.read(folder)
        if rewritten.compositions.count != 2 { throw Failure("update appended a composition") }
        if rewritten.compositions[0].style.padding != 90 { throw Failure("update missed padding") }
        if try files(in: folder.appendingPathComponent("Screenshots")).count != 1 { throw Failure("update duplicated the screenshot") }
        if !FileManager.default.fileExists(atPath: folder.appendingPathComponent("project.json.bak").path) { throw Failure("backup") }

        let renamed = try ProjectStore.rename(folder: folder, to: "App Redesign")
        if FileManager.default.fileExists(atPath: folder.path) { throw Failure("old folder remained") }
        let renamedFile = try ProjectStore.read(renamed)
        if renamedFile.name != "App Redesign" || renamedFile.id != created.id { throw Failure("rename metadata") }
        if renamedFile.compositions[0].source != rewritten.compositions[0].source { throw Failure("rename broke the asset path") }

        let copy = try ProjectStore.duplicate(folder: renamed)
        var copyFile = try ProjectStore.read(copy)
        if copyFile.id == renamedFile.id { throw Failure("duplicate kept the same id") }
        copyFile.name = "Copy touched"
        try ProjectStore.write(copyFile, to: copy)
        if try ProjectStore.read(renamed).name != "App Redesign" { throw Failure("duplicate was not independent") }

        let gone = renamed
        try ProjectStore.delete(folder: copy)
        if FileManager.default.fileExists(atPath: copy.path) { throw Failure("duplicate folder remained") }
        try FileManager.default.removeItem(at: gone)
        var orphan = draft
        orphan.id = nil
        orphan.reuseRelative = nil
        orphan.sourceData = originalBytes
        do {
            _ = try ProjectStore.saveComposition(orphan, in: gone)
            throw Failure("save reported success after the folder was removed")
        } catch is ProjectError {
        }
        let blocker = root.appendingPathComponent("blocked")
        try Data([1]).write(to: blocker)
        do {
            _ = try ProjectStore.create(name: "Nope", root: blocker)
            throw Failure("create reported success inside a file")
        } catch is ProjectError {
        }
        try? FileManager.default.removeItem(at: original)
        try checkPopoverSave()
        try checkLibraryKeys()
    }

    private static func checkPopoverSave() throws {
        var session = PopoverSaveSession()
        guard let first = session.begin(projectID: "project-a") else { throw Failure("save did not start") }
        if session.begin(projectID: "project-b") != nil { throw Failure("duplicate save started") }
        if session.succeed(projectID: "project-a", name: "bm", generation: first + 9) { throw Failure("stale success") }
        if session.fail(projectID: "project-b", message: "no", generation: first) { throw Failure("wrong project failed") }
        if !session.succeed(projectID: "project-a", name: "bm", generation: first) { throw Failure("success rejected") }
        if case .success(let id, let name) = session.phase, id == "project-a", name == "bm" {} else {
            throw Failure("success state")
        }
        let token = session.armDismiss()
        if !session.shouldDismiss(token: token) { throw Failure("success did not arm dismiss") }
        session.invalidateDismiss()
        if session.shouldDismiss(token: token) { throw Failure("cancelled dismiss still active") }
        session.clearFinished()
        if session.phase != .idle { throw Failure("clear left a phase") }
        guard let failed = session.begin(projectID: "project-a") else { throw Failure("retry did not start") }
        let message = "Couldn't save this project. Try again."
        if !session.fail(projectID: "project-a", message: message, generation: failed) { throw Failure("failure rejected") }
        if case .failure(let id, let text) = session.phase, id == "project-a", text == message {} else {
            throw Failure("failure state")
        }
        if session.shouldDismiss(token: session.armDismiss()) { throw Failure("failure armed a dismiss") }
        guard let retry = session.begin(projectID: "project-a") else { throw Failure("retry after failure blocked") }
        if session.generation != retry || session.phase.savingID != "project-a" { throw Failure("retry state") }
    }

    private static func checkLibraryKeys() throws {
        if !LibraryKeyGate.shouldPassThrough(modalPresented: true, namingSheet: false, savePopover: false, hostHasSheet: false, eventOnHost: true, hostIsKey: true, editingText: false) {
            throw Failure("modal swallowed keys")
        }
        if !LibraryKeyGate.shouldPassThrough(modalPresented: false, namingSheet: true, savePopover: false, hostHasSheet: false, eventOnHost: true, hostIsKey: true, editingText: false) {
            throw Failure("new project sheet swallowed keys")
        }
        if !LibraryKeyGate.shouldPassThrough(modalPresented: false, namingSheet: false, savePopover: true, hostHasSheet: false, eventOnHost: true, hostIsKey: true, editingText: false) {
            throw Failure("save popover swallowed keys")
        }
        if !LibraryKeyGate.shouldPassThrough(modalPresented: false, namingSheet: false, savePopover: false, hostHasSheet: true, eventOnHost: true, hostIsKey: true, editingText: false) {
            throw Failure("attached sheet swallowed keys")
        }
        if !LibraryKeyGate.shouldPassThrough(modalPresented: false, namingSheet: false, savePopover: false, hostHasSheet: false, eventOnHost: false, hostIsKey: true, editingText: false) {
            throw Failure("other window swallowed keys")
        }
        if !LibraryKeyGate.shouldPassThrough(modalPresented: false, namingSheet: false, savePopover: false, hostHasSheet: false, eventOnHost: true, hostIsKey: false, editingText: false) {
            throw Failure("inactive window swallowed keys")
        }
        if !LibraryKeyGate.shouldPassThrough(modalPresented: false, namingSheet: false, savePopover: false, hostHasSheet: false, eventOnHost: true, hostIsKey: true, editingText: true) {
            throw Failure("text field swallowed keys")
        }
        if LibraryKeyGate.shouldPassThrough(modalPresented: false, namingSheet: false, savePopover: false, hostHasSheet: false, eventOnHost: true, hostIsKey: true, editingText: false) {
            throw Failure("library delete was not handled")
        }
    }

    private static func folders(in root: URL) throws -> Int {
        let items = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
        return items.filter { url in
            var isDirectory: ObjCBool = false
            return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
        }.count
    }

    private static func files(in folder: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
    }

    private static func tinyImage() -> CGImage {
        let context = CGContext(
            data: nil,
            width: 8,
            height: 8,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(NSColor(srgbRed: 0.2, green: 0.4, blue: 0.9, alpha: 1).cgColor)
        context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        return context.makeImage()!
    }

    private static func tinyPNG() throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            throw Failure("png")
        }
        CGImageDestinationAddImage(destination, tinyImage(), nil)
        if !CGImageDestinationFinalize(destination) { throw Failure("png finalize") }
        return data as Data
    }

    private struct Failure: LocalizedError {
        var message: String
        var errorDescription: String? { message }
        init(_ message: String) { self.message = message }
    }
}

enum PopoverSavePhase: Equatable {
    case idle
    case saving(String)
    case success(id: String, name: String)
    case failure(id: String, message: String)

    var isSaving: Bool {
        if case .saving = self { return true }
        return false
    }

    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    var savingID: String? {
        if case .saving(let id) = self { return id }
        return nil
    }
}

struct PopoverSaveSession: Equatable {
    private(set) var phase: PopoverSavePhase = .idle
    private(set) var generation = 0
    private(set) var dismissToken = 0

    var isSaving: Bool { phase.isSaving }

    mutating func begin(projectID: String) -> Int? {
        if phase.isSaving { return nil }
        generation += 1
        dismissToken += 1
        phase = .saving(projectID)
        return generation
    }

    mutating func succeed(projectID: String, name: String, generation: Int) -> Bool {
        guard self.generation == generation, case .saving(let current) = phase, current == projectID else { return false }
        phase = .success(id: projectID, name: name)
        return true
    }

    mutating func fail(projectID: String, message: String, generation: Int) -> Bool {
        guard self.generation == generation, case .saving(let current) = phase, current == projectID else { return false }
        phase = .failure(id: projectID, message: message)
        return true
    }

    mutating func armDismiss() -> Int {
        dismissToken += 1
        return dismissToken
    }

    func shouldDismiss(token: Int) -> Bool {
        token == dismissToken && phase.isSuccess
    }

    mutating func invalidateDismiss() {
        dismissToken += 1
    }

    mutating func clearFinished() {
        if phase.isSaving { return }
        invalidateDismiss()
        phase = .idle
    }
}

enum ProjectSaveState: Equatable {
    case idle
    case unsaved
    case saving
    case saved
    case failed(String)

    var label: String {
        switch self {
        case .idle: return ""
        case .unsaved: return "Not saved"
        case .saving: return "Saving…"
        case .saved: return "Saved"
        case .failed: return "Save failed"
        }
    }

    var isFailure: Bool {
        if case .failed = self { return true }
        return false
    }
}
