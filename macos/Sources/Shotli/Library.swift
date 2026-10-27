import AppKit
import Combine
import ImageIO
import SwiftUI

enum LibrarySource: String, CaseIterable, Identifiable {
    case recent, screenshots, desktop, pictures, shotli
    var id: String { rawValue }
    var title: String {
        switch self {
        case .recent: return "Recent"
        case .screenshots: return "Screenshots"
        case .desktop: return "Desktop"
        case .pictures: return "Pictures"
        case .shotli: return "Shotli"
        }
    }
    var symbol: String {
        switch self {
        case .recent: return "clock"
        case .screenshots: return "camera.viewfinder"
        case .desktop: return "menubar.dock.rectangle"
        case .pictures: return "photo.on.rectangle"
        case .shotli: return "square.grid.2x2"
        }
    }
    var detail: String {
        switch self {
        case .recent: return "Last 30 days"
        case .screenshots: return "Where macOS saves screenshots"
        case .desktop: return "Pictures on the Desktop"
        case .pictures: return "Pictures folder"
        case .shotli: return "Captures from the Shotli menu"
        }
    }
}

struct LibraryShot: Identifiable, Equatable {
    var id: String
    var url: URL
    var name: String
    var modified: Date
}

final class LibraryModel: ObservableObject {
    static let shared = LibraryModel()
    @Published var source: LibrarySource
    @Published var showingSettings = false
    @Published var kindFilter: ShotKind?
    @Published var kinds: [String: ShotKind] = [:]
    var texts: [String: String] = [:]
    @Published var kindCounts: [ShotKind: Int] = [:]
    @Published var sorting = false
    @Published var shots: [LibraryShot] = []
    @Published var counts: [LibrarySource: Int] = [:]
    @Published var thumbs: [String: NSImage] = [:]
    @Published var message: String?
    @Published var query = ""
    @Published var selected: Set<String> = []

    private var cache: [LibrarySource: [LibraryShot]] = [:]
    private var notes: [LibrarySource: String] = [:]
    private var selectionAnchor: String?
    private var refreshToken = 0

    private init() {
        source = ShotliSettings.shared.startIn
    }

    func select(_ source: LibrarySource) {
        let leavingSettings = showingSettings || kindFilter != nil
        showingSettings = false
        kindFilter = nil
        guard source != self.source else {
            if leavingSettings {
                clearSelection()
                apply()
            }
            return
        }
        self.source = source
        clearSelection()
        apply()
        warm(refreshToken)
    }

    func showSettings() {
        guard !showingSettings else { return }
        showingSettings = true
        kindFilter = nil
        clearSelection()
    }

    func selectKind(_ kind: ShotKind) {
        let same = kindFilter == kind && !showingSettings
        showingSettings = false
        kindFilter = kind
        clearSelection()
        if same { return }
        apply()
    }

    func noteReading(id: String, kind: ShotKind, text: String?) {
        var changed = kinds[id] != kind
        kinds[id] = kind
        if let text, texts[id] != text {
            texts[id] = text
            changed = true
        }
        if changed { apply() }
    }

    func fileSelected(as kind: ShotKind) {
        let chosen = allShots().filter { selected.contains($0.id) }
        guard !chosen.isEmpty else { return }
        for shot in chosen {
            kinds[shot.id] = kind
            ShotSorter.shared.file(shot, as: kind)
        }
        apply()
    }

    func setSorting(_ value: Bool) {
        guard sorting != value else { return }
        sorting = value
        if kindFilter != nil { apply() }
    }

    func allShots() -> [LibraryShot] {
        var seen = Set<String>()
        return LibrarySource.allCases.flatMap { cache[$0] ?? [] }.filter { seen.insert($0.id).inserted }
    }

    func step(_ offset: Int) {
        guard !showingSettings, kindFilter == nil else { return }
        let order = LibrarySource.allCases
        guard let index = order.firstIndex(of: source) else { return }
        let next = order[(index + offset + order.count) % order.count]
        select(next)
    }

    func updateQuery(_ value: String) {
        query = value
        apply()
    }

    func refresh() {
        refreshToken += 1
        let token = refreshToken
        DispatchQueue.global(qos: .userInitiated).async {
            let catalog = LibraryScan.catalog()
            DispatchQueue.main.async {
                guard token == self.refreshToken else { return }
                self.cache = catalog.shots
                self.notes = catalog.notes
                self.counts = Dictionary(uniqueKeysWithValues: LibrarySource.allCases.map { source in
                    (source, catalog.shots[source]?.count ?? 0)
                })
                let keep = Set(catalog.shots.values.flatMap { $0.map(\.id) })
                self.thumbs = self.thumbs.filter { keep.contains($0.key) }
                let everything = self.allShots()
                let readings = ShotSorter.shared.knownReadings(in: everything)
                self.kinds = Dictionary(uniqueKeysWithValues: readings.map { ($0.key, $0.value.kind) })
                self.texts = Dictionary(uniqueKeysWithValues: readings.compactMap { item -> (String, String)? in
                    guard let text = item.value.text else { return nil }
                    return (item.key, text)
                })
                self.apply()
                self.warm(token)
                ShotSorter.shared.schedule(everything)
            }
        }
    }

    private func apply() {
        recomputeKindCounts()
        let base: [LibraryShot]
        if let kindFilter {
            base = allShots().filter { kinds[$0.id] == kindFilter }.sorted { $0.modified > $1.modified }
        } else {
            base = cache[source] ?? []
        }
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let searched = needle.isEmpty ? base : base.filter {
            $0.name.lowercased().contains(needle) || (texts[$0.id]?.lowercased().contains(needle) ?? false)
        }
        shots = searched
        if !needle.isEmpty {
            message = searched.isEmpty ? "Nothing matches “\(query.trimmingCharacters(in: .whitespacesAndNewlines))”." : nil
        } else if let kindFilter, searched.isEmpty {
            message = sorting ? "Shotli is still sorting screenshots." : "No \(kindFilter.emptyNoun) yet."
        } else {
            message = searched.isEmpty ? notes[source] : nil
        }
        let visible = Set(shots.map(\.id))
        selected = selected.intersection(visible)
        if let anchor = selectionAnchor, !visible.contains(anchor) { selectionAnchor = selected.first }
    }

    private func recomputeKindCounts() {
        var counts: [ShotKind: Int] = [:]
        for shot in allShots() {
            if let kind = kinds[shot.id] { counts[kind, default: 0] += 1 }
        }
        kindCounts = counts
    }

    func selectOnly(_ id: String) {
        selected = [id]
        selectionAnchor = id
    }

    func toggle(_ id: String) {
        if selected.contains(id) {
            selected.remove(id)
        } else {
            selected.insert(id)
        }
        selectionAnchor = id
    }

    func extend(to id: String) {
        let anchor = selectionAnchor ?? selected.first ?? id
        guard let start = shots.firstIndex(where: { $0.id == anchor }),
              let end = shots.firstIndex(where: { $0.id == id }) else {
            selectOnly(id)
            return
        }
        let lower = min(start, end)
        let upper = max(start, end)
        selected = Set(shots[lower...upper].map(\.id))
        selectionAnchor = anchor
    }

    func selectAll() {
        selected = Set(shots.map(\.id))
        if selectionAnchor == nil { selectionAnchor = shots.first?.id }
    }

    func clearSelection() {
        selected = []
        selectionAnchor = nil
    }

    func choose(_ id: String) {
        let flags = NSEvent.modifierFlags
        if flags.contains(.command) {
            toggle(id)
        } else if flags.contains(.shift) {
            extend(to: id)
        } else {
            selectOnly(id)
        }
    }

    func deleteSelected() {
        let chosen = shots.filter { selected.contains($0.id) }
        guard !chosen.isEmpty else { return }
        if ShotliSettings.shared.confirmDelete {
            let alert = NSAlert()
            alert.messageText = "Are you sure?"
            alert.informativeText = chosen.count == 1
                ? "“\(chosen[0].name)” will be moved to the Trash."
                : "\(chosen.count) screenshots will be moved to the Trash."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Move to Trash")
            alert.addButton(withTitle: "Cancel")
            NSApp.activate(ignoringOtherApps: true)
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        let paths = Set(chosen.map(\.id))
        for shot in chosen {
            try? FileManager.default.trashItem(at: shot.url, resultingItemURL: nil)
        }
        for key in Array(cache.keys) {
            guard var list = cache[key] else { continue }
            list.removeAll { paths.contains($0.id) }
            cache[key] = list
        }
        counts = Dictionary(uniqueKeysWithValues: LibrarySource.allCases.map { source in
            (source, cache[source]?.count ?? 0)
        })
        clearSelection()
        apply()
        refresh()
    }

    private func warm(_ token: Int) {
        var seen = Set<String>()
        let visible = shots
        let rest = LibrarySource.allCases.flatMap { cache[$0] ?? [] }
        let ordered = (visible + rest).filter { seen.insert($0.id).inserted }
        let known = Set(thumbs.keys)
        DispatchQueue.global(qos: .utility).async {
            for shot in ordered where !known.contains(shot.id) {
                guard token == self.refreshToken else { return }
                guard let image = LibraryScan.thumbnail(shot.url) else { continue }
                DispatchQueue.main.async {
                    guard token == self.refreshToken else { return }
                    self.thumbs[shot.id] = image
                }
            }
        }
    }
}

enum LibraryFolders {
    static var home: URL { FileManager.default.homeDirectoryForCurrentUser }
    static var desktop: URL { home.appendingPathComponent("Desktop") }
    static var pictures: URL { home.appendingPathComponent("Pictures") }
    static var documents: URL { home.appendingPathComponent("Documents") }
    static var downloads: URL { home.appendingPathComponent("Downloads") }
    static var shotli: URL { pictures.appendingPathComponent("Shotli") }

    static var screenshots: URL {
        if let value = CFPreferencesCopyAppValue("location" as CFString, "com.apple.screencapture" as CFString) as? String,
           !value.trimmingCharacters(in: .whitespaces).isEmpty {
            return URL(fileURLWithPath: (value as NSString).expandingTildeInPath)
        }
        let dedicated = pictures.appendingPathComponent("Screenshots")
        if FileManager.default.fileExists(atPath: dedicated.path) { return dedicated }
        return desktop
    }

    static func archive(_ url: URL) -> URL {
        let folder = shotli
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        var dest = folder.appendingPathComponent("Shotli \(stamp).png")
        var extra = 2
        while FileManager.default.fileExists(atPath: dest.path) {
            dest = folder.appendingPathComponent("Shotli \(stamp)-\(extra).png")
            extra += 1
        }
        do {
            try FileManager.default.copyItem(at: url, to: dest)
            return dest
        } catch {
            return url
        }
    }
}

private enum LibraryScan {
    struct Result {
        var shots: [LibraryShot]
        var message: String?
    }

    static func catalog() -> (shots: [LibrarySource: [LibraryShot]], notes: [LibrarySource: String]) {
        let desktop = listed(LibraryFolders.desktop, empty: "No pictures on the Desktop.")
        let pictures = listed(LibraryFolders.pictures, empty: "No pictures in Pictures.")
        let screenshots = listed(LibraryFolders.screenshots, empty: "No screenshots in \(LibraryFolders.screenshots.lastPathComponent) yet.")
        let shotli = listed(LibraryFolders.shotli, empty: "Captures from the Shotli menu are saved here.")
        let recentShots = (shotli.shots + screenshots.shots + desktop.shots + pictures.shots)
            .uniqued()
            .filter { Date().timeIntervalSince($0.modified) < 60 * 60 * 24 * 30 }
            .sorted { $0.modified > $1.modified }
        let recent = Result(
            shots: Array(recentShots.prefix(80)),
            message: recentShots.isEmpty ? "Nothing from the last 30 days. Captures you make from the menu bar land in Shotli." : nil
        )
        var shots: [LibrarySource: [LibraryShot]] = [:]
        var notes: [LibrarySource: String] = [:]
        for (source, result) in [(LibrarySource.recent, recent), (.screenshots, screenshots), (.desktop, desktop), (.pictures, pictures), (.shotli, shotli)] {
            shots[source] = result.shots
            if let message = result.message { notes[source] = message }
        }
        return (shots, notes)
    }

    static func thumbnail(_ url: URL) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 360,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }

    private static func listed(_ folder: URL, empty: String) -> Result {
        let found = images(in: folder)
        if FileManager.default.fileExists(atPath: folder.path) {
            ShotliPermissions.shared.note(folder: folder, allowed: found.readable)
        }
        let shots = found.shots.sorted { $0.modified > $1.modified }
        if shots.isEmpty, !found.readable, FileManager.default.fileExists(atPath: folder.path) {
            return Result(shots: [], message: "Shotli can't read \(folder.lastPathComponent). Allow it in Settings.")
        }
        return Result(shots: Array(shots.prefix(200)), message: shots.isEmpty ? empty : nil)
    }

    private static func images(in folder: URL) -> (shots: [LibraryShot], readable: Bool) {
        let keys: [URLResourceKey] = [.contentModificationDateKey, .isRegularFileKey, .isHiddenKey]
        let items: [URL]
        do {
            items = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])
        } catch {
            return ([], false)
        }
        let allowed: Set<String> = ["png", "jpg", "jpeg", "webp", "tif", "tiff", "heic"]
        let shots = items.compactMap { url -> LibraryShot? in
            guard allowed.contains(url.pathExtension.lowercased()) else { return nil }
            let values = try? url.resourceValues(forKeys: Set(keys))
            guard values?.isRegularFile == true, values?.isHidden != true else { return nil }
            return LibraryShot(id: url.path, url: url, name: url.lastPathComponent, modified: values?.contentModificationDate ?? .distantPast)
        }
        return (shots, true)
    }
}

private extension Array where Element == LibraryShot {
    func uniqued() -> [LibraryShot] {
        var seen = Set<String>()
        return filter { seen.insert($0.id).inserted }
    }
}

struct LibraryHome: View {
    @ObservedObject private var library = LibraryModel.shared
    @Namespace private var selection
    var onOpen: () -> Void

    private let columns = [GridItem(.adaptive(minimum: 168, maximum: 240), spacing: 14)]
    private let accent = Color(nsColor: NSColor(hex: "#3478F6")!)
    private let ink = Color(nsColor: NSColor(hex: "#222222")!)

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            content
        }
        .onAppear { library.refresh() }
        .background(
            LibraryKeys(
                onUp: { library.step(-1) },
                onDown: { library.step(1) },
                onSelectAll: { if !library.showingSettings { library.selectAll() } },
                onDelete: { if !library.showingSettings { library.deleteSelected() } },
                onClear: { if !library.showingSettings { library.clearSelection() } }
            )
            .frame(width: 0, height: 0)
        )
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Library")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 14)
                        .padding(.top, 16)
                        .padding(.bottom, 6)
                    ForEach(LibrarySource.allCases) { source in
                        sourceButton(source)
                    }
                    Text("Sort")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 14)
                        .padding(.top, 16)
                        .padding(.bottom, 6)
                    ForEach(ShotKind.allCases) { kind in
                        kindButton(kind)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer(minLength: 0)
            Button(action: onOpen) {
                Label("Open a screenshot…", systemImage: "folder")
                    .font(.system(size: 12))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 2)
            settingsButton
                .padding(.bottom, 12)
        }
        .frame(width: 220)
        .background(Color.white)
        .animation(.spring(response: 0.38, dampingFraction: 0.84), value: library.source)
        .animation(.spring(response: 0.38, dampingFraction: 0.84), value: library.showingSettings)
        .animation(.spring(response: 0.38, dampingFraction: 0.84), value: library.kindFilter)
    }

    private var settingsButton: some View {
        sidebarRow("Settings", symbol: "gearshape", count: nil, selected: library.showingSettings) {
            library.showSettings()
        }
    }

    private func sourceButton(_ source: LibrarySource) -> some View {
        let selected = library.source == source && !library.showingSettings && library.kindFilter == nil
        return sidebarRow(source.title, symbol: source.symbol, count: library.counts[source] ?? 0, selected: selected) {
            library.select(source)
        }
    }

    private func kindButton(_ kind: ShotKind) -> some View {
        let selected = library.kindFilter == kind && !library.showingSettings
        return sidebarRow(kind.title, symbol: kind.symbol, count: library.kindCounts[kind] ?? 0, selected: selected) {
            library.selectKind(kind)
        }
    }

    private func sidebarRow(_ title: String, symbol: String, count: Int?, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 13))
                Spacer(minLength: 4)
                if let count, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(selected ? Color.white.opacity(0.85) : .secondary)
                }
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 28)
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .foregroundColor(selected ? .white : ink)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(accent)
                        .matchedGeometryEffect(id: "library-source", in: selection)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }

    private var content: some View {
        Group {
            if library.showingSettings {
                SettingsPane()
            } else {
                libraryContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.18), value: library.showingSettings)
    }

    private var libraryContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(library.kindFilter?.title ?? library.source.title)
                        .font(.system(size: 18, weight: .semibold))
                    Text(headerDetail)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 12)
                if !library.shots.isEmpty {
                    headerButton(allSelected ? "Deselect" : "Select All") {
                        if allSelected { library.clearSelection() } else { library.selectAll() }
                    }
                }
                if !library.selected.isEmpty {
                    headerButton("Delete") { library.deleteSelected() }
                }
                searchField
            }
            .padding(.horizontal, 22)
            .padding(.top, 16)
            .padding(.bottom, 12)
            ZStack(alignment: .topLeading) {
                ScrollView {
                    if library.shots.isEmpty {
                        empty
                            .padding(.horizontal, 22)
                    } else {
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(library.shots) { shot in
                                ShotCard(
                                    shot: shot,
                                    image: library.thumbs[shot.id],
                                    selected: library.selected.contains(shot.id),
                                    showsCheck: !library.selected.isEmpty,
                                    kindTitle: library.kinds[shot.id]?.title,
                                    onChoose: { library.choose(shot.id) },
                                    onToggle: { library.toggle(shot.id) },
                                    onOpen: { EditorModel.shared.load(url: shot.url) },
                                    onDelete: {
                                        if !library.selected.contains(shot.id) { library.selectOnly(shot.id) }
                                        library.deleteSelected()
                                    },
                                    onSelectAll: { library.selectAll() },
                                    onFile: { kind in
                                        if !library.selected.contains(shot.id) { library.selectOnly(shot.id) }
                                        library.fileSelected(as: kind)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 22)
                        .padding(.bottom, 24)
                    }
                }
                .id(library.kindFilter?.rawValue ?? library.source.rawValue)
                .transition(.opacity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .animation(.easeInOut(duration: 0.18), value: library.source)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: NSColor(srgbRed: 0.945, green: 0.945, blue: 0.945, alpha: 1)))
    }

    private var headerDetail: String {
        if !library.selected.isEmpty { return "\(library.selected.count) selected" }
        if library.kindFilter != nil {
            return library.sorting ? "Sorting on this Mac…" : "Sorted on this Mac"
        }
        return library.source.detail
    }

    private var allSelected: Bool {
        !library.shots.isEmpty && library.selected.count == library.shots.count
    }

    private func headerButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(ink)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.black.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
            TextField("Search text", text: Binding(get: { library.query }, set: { library.updateQuery($0) }))
                .textFieldStyle(.plain)
                .font(.system(size: 12))
            if !library.query.isEmpty {
                Button(action: { library.updateQuery("") }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .frame(width: 196, height: 28)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.black.opacity(0.08), lineWidth: 1))
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(library.message ?? "Nothing here yet.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Text("You can also drop a PNG, JPEG, or WebP onto this window.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.06), lineWidth: 1))
    }
}

private struct ShotCard: View {
    var shot: LibraryShot
    var image: NSImage?
    var selected: Bool
    var showsCheck: Bool
    var kindTitle: String? = nil
    var onChoose: () -> Void
    var onToggle: () -> Void
    var onOpen: () -> Void
    var onDelete: () -> Void
    var onSelectAll: () -> Void
    var onFile: (ShotKind) -> Void
    @State private var hovered = false

    private let accent = Color(nsColor: NSColor(hex: "#3478F6")!)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white)
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(8)
                }
                if showsCheck || hovered || selected {
                    Button(action: onToggle) {
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(selected ? accent : Color.white)
                            .shadow(color: Color.black.opacity(0.35), radius: 2, y: 1)
                            .frame(width: 22, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(6)
                    .help(selected ? "Deselect" : "Select")
                }
            }
            .frame(height: 128)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.black.opacity(hovered ? 0.14 : 0.06), lineWidth: 1)
            )
            Text(shot.name)
                .font(.system(size: 12))
                .foregroundColor(Color(nsColor: NSColor(hex: "#222222")!))
                .lineLimit(1)
            HStack(spacing: 4) {
                if let kindTitle {
                    Text(kindTitle)
                    Text("·")
                }
                Text(shot.modified, style: .relative)
            }
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .lineLimit(1)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(selected ? accent.opacity(0.08) : (hovered ? Color.white : Color.white.opacity(0.001)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(selected ? accent : Color.clear, lineWidth: 2)
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .gesture(
            TapGesture(count: 2).onEnded { onOpen() }
                .exclusively(before: TapGesture(count: 1).onEnded { onChoose() })
        )
        .onHover { hovered = $0 }
        .animation(.easeOut(duration: 0.16), value: hovered)
        .animation(.easeOut(duration: 0.16), value: selected)
        .animation(.easeOut(duration: 0.2), value: image != nil)
        .contextMenu {
            Button("Open", action: onOpen)
            Button("Show in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([shot.url])
            }
            Divider()
            Menu("File as") {
                ForEach(ShotKind.allCases) { kind in
                    Button {
                        onFile(kind)
                    } label: {
                        if kind.title == kindTitle {
                            Label(kind.title, systemImage: "checkmark")
                        } else {
                            Text(kind.title)
                        }
                    }
                }
            }
            Divider()
            Button("Select All", action: onSelectAll)
            Button("Delete", action: onDelete)
        }
        .help("\(shot.name). Drag into another app.")
        .onDrag {
            let provider = NSItemProvider(contentsOf: shot.url) ?? NSItemProvider()
            provider.suggestedName = shot.name
            return provider
        }
    }
}

private struct LibraryKeys: NSViewRepresentable {
    var onUp: () -> Void
    var onDown: () -> Void
    var onSelectAll: () -> Void
    var onDelete: () -> Void
    var onClear: () -> Void

    func makeNSView(context: Context) -> KeyView {
        let view = KeyView()
        view.onUp = onUp
        view.onDown = onDown
        view.onSelectAll = onSelectAll
        view.onDelete = onDelete
        view.onClear = onClear
        return view
    }

    func updateNSView(_ view: KeyView, context: Context) {
        view.onUp = onUp
        view.onDown = onDown
        view.onSelectAll = onSelectAll
        view.onDelete = onDelete
        view.onClear = onClear
    }

    final class KeyView: NSView {
        var onUp: (() -> Void)?
        var onDown: (() -> Void)?
        var onSelectAll: (() -> Void)?
        var onDelete: (() -> Void)?
        var onClear: (() -> Void)?
        private var monitor: Any?

        deinit {
            if let monitor { NSEvent.removeMonitor(monitor) }
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window == nil {
                if let monitor { NSEvent.removeMonitor(monitor) }
                monitor = nil
                return
            }
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, self.window != nil, NSApp.modalWindow == nil else { return event }
                let responder = self.window?.firstResponder
                if responder is NSTextView || responder is NSTextField { return event }
                if event.keyCode == 126 {
                    self.onUp?()
                    return nil
                }
                if event.keyCode == 125 {
                    self.onDown?()
                    return nil
                }
                if event.keyCode == 53 {
                    self.onClear?()
                    return nil
                }
                if event.keyCode == 51 || event.keyCode == 117 {
                    self.onDelete?()
                    return nil
                }
                let flags = event.modifierFlags
                if flags.contains(.command), !flags.contains(.shift), !flags.contains(.option),
                   event.charactersIgnoringModifiers?.lowercased() == "a" {
                    self.onSelectAll?()
                    return nil
                }
                return event
            }
        }
    }
}
