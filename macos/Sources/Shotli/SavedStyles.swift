import AppKit
import Foundation

struct SavedStyle: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var style: StyleFile

    var preset: Preset {
        Preset(id: "saved-\(id)", name: name, style: style.style)
    }
}

final class StyleStore: ObservableObject {
    static let shared = StyleStore()

    private struct File: Codable {
        var version: Int
        var defaultID: String?
        var styles: [SavedStyle]
    }

    @Published private(set) var styles: [SavedStyle] = []
    @Published private(set) var defaultID: String?

    private let version = 1

    private init() {
        reload()
    }

    /// Follows the projects root, so the verify run stays out of real data.
    private var storeURL: URL {
        ShotliProjects.root.deletingLastPathComponent().appendingPathComponent("styles.json")
    }

    var defaultStyle: ShotliStyle? {
        styles.first { $0.id == defaultID }?.style.style
    }

    func reload() {
        guard let data = try? Data(contentsOf: storeURL),
              let file = try? JSONDecoder().decode(File.self, from: data),
              file.version == version else {
            styles = []
            defaultID = nil
            return
        }
        styles = file.styles
        defaultID = file.defaultID
    }

    @discardableResult
    func add(name: String, style: ShotliStyle) -> SavedStyle {
        let saved = SavedStyle(id: UUID().uuidString, name: name, style: StyleFile(style))
        styles.append(saved)
        save()
        return saved
    }

    func rename(_ id: String, to name: String) {
        guard let index = styles.firstIndex(where: { $0.id == id }) else { return }
        styles[index].name = name
        save()
    }

    func delete(_ id: String) {
        styles.removeAll { $0.id == id }
        if defaultID == id { defaultID = nil }
        save()
    }

    /// The style every new screenshot opens with. Nil keeps the current look.
    func setDefault(_ id: String?) {
        defaultID = id
        save()
    }

    private func save() {
        let file = File(version: version, defaultID: defaultID, styles: styles)
        guard let data = try? JSONEncoder().encode(file) else { return }
        let url = storeURL
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}

enum StylePrompt {
    static func name(title: String, action: String, initial: String) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.addButton(withTitle: action)
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.stringValue = initial
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let trimmed = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

extension ShotliStyle {
    /// A style applied from a list leaves the picture's device alone, as presets do.
    func keepingDevice(of current: ShotliStyle) -> ShotliStyle {
        var next = self
        next.deviceID = current.deviceID
        next.deviceFinish = current.deviceFinish
        next.deviceFit = current.deviceFit
        next.deviceScale = current.deviceScale
        return next
    }
}

extension EditorModel {
    func saveCurrentStyle() {
        let suggested = "Style \(StyleStore.shared.styles.count + 1)"
        guard let name = StylePrompt.name(title: "Name this style", action: "Save", initial: suggested) else { return }
        StyleStore.shared.add(name: name, style: style)
        notice = "Saved \(name)"
    }

    func renameStyle(_ saved: SavedStyle) {
        guard let name = StylePrompt.name(title: "Rename this style", action: "Rename", initial: saved.name) else { return }
        StyleStore.shared.rename(saved.id, to: name)
    }
}
