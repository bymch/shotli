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
    @Published var source: LibrarySource = .recent
    @Published var shots: [LibraryShot] = []
    @Published var counts: [LibrarySource: Int] = [:]
    @Published var thumbs: [String: NSImage] = [:]
    @Published var message: String?
    @Published var query = ""

    private var cache: [LibrarySource: [LibraryShot]] = [:]
    private var notes: [LibrarySource: String] = [:]
    private var refreshToken = 0
    private init() {}

    func select(_ source: LibrarySource) {
        guard source != self.source else { return }
        self.source = source
        apply()
        warm(refreshToken)
    }

    func step(_ offset: Int) {
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
                self.apply()
                self.warm(token)
            }
        }
    }

    private func apply() {
        let list = cache[source] ?? []
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if needle.isEmpty {
            shots = list
            message = list.isEmpty ? notes[source] : nil
        } else {
            shots = list.filter { $0.name.lowercased().contains(needle) }
            message = shots.isEmpty ? "Nothing matches “\(query.trimmingCharacters(in: .whitespacesAndNewlines))”." : nil
        }
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
        let shots = images(in: folder).sorted { $0.modified > $1.modified }
        if shots.isEmpty, !FileManager.default.isReadableFile(atPath: folder.path), FileManager.default.fileExists(atPath: folder.path) {
            return Result(shots: [], message: "Shotli can't read \(folder.lastPathComponent). Allow it in System Settings → Privacy & Security.")
        }
        return Result(shots: Array(shots.prefix(200)), message: shots.isEmpty ? empty : nil)
    }

    private static func images(in folder: URL) -> [LibraryShot] {
        let keys: [URLResourceKey] = [.contentModificationDateKey, .isRegularFileKey, .isHiddenKey]
        guard let items = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else {
            return []
        }
        let allowed: Set<String> = ["png", "jpg", "jpeg", "webp", "tif", "tiff", "heic"]
        return items.compactMap { url in
            guard allowed.contains(url.pathExtension.lowercased()) else { return nil }
            let values = try? url.resourceValues(forKeys: Set(keys))
            guard values?.isRegularFile == true, values?.isHidden != true else { return nil }
            return LibraryShot(id: url.path, url: url, name: url.lastPathComponent, modified: values?.contentModificationDate ?? .distantPast)
        }
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
        .background(LibraryKeys(onUp: { library.step(-1) }, onDown: { library.step(1) }).frame(width: 0, height: 0))
    }

    private var sidebar: some View {
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
            Spacer()
            Button(action: onOpen) {
                Label("Open a screenshot…", systemImage: "folder")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .padding(14)
        }
        .frame(width: 220)
        .background(Color.white)
        .animation(.spring(response: 0.38, dampingFraction: 0.84), value: library.source)
    }

    private func sourceButton(_ source: LibrarySource) -> some View {
        let selected = library.source == source
        let count = library.counts[source] ?? 0
        return Button(action: { library.select(source) }) {
            HStack(spacing: 8) {
                Image(systemName: source.symbol)
                    .frame(width: 16)
                Text(source.title)
                    .font(.system(size: 13))
                Spacer(minLength: 4)
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(selected ? Color.white.opacity(0.85) : .secondary)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 28)
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
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(library.source.title)
                        .font(.system(size: 18, weight: .semibold))
                    Text(library.source.detail)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 12)
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
                                ShotCard(shot: shot, image: library.thumbs[shot.id]) {
                                    EditorModel.shared.load(url: shot.url)
                                }
                            }
                        }
                        .padding(.horizontal, 22)
                        .padding(.bottom, 24)
                    }
                }
                .id(library.source)
                .transition(.opacity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .animation(.easeInOut(duration: 0.18), value: library.source)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: NSColor(srgbRed: 0.945, green: 0.945, blue: 0.945, alpha: 1)))
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
            TextField("Search", text: Binding(get: { library.query }, set: { library.updateQuery($0) }))
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
    var action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white)
                    if let image {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .padding(8)
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
                Text(shot.modified, style: .relative)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(hovered ? Color.white : Color.white.opacity(0.001))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .animation(.easeOut(duration: 0.16), value: hovered)
        .animation(.easeOut(duration: 0.2), value: image != nil)
        .contextMenu {
            Button("Open") { action() }
            Button("Show in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([shot.url])
            }
        }
        .help(shot.name)
    }
}

private struct LibraryKeys: NSViewRepresentable {
    var onUp: () -> Void
    var onDown: () -> Void

    func makeNSView(context: Context) -> KeyView {
        let view = KeyView()
        view.onUp = onUp
        view.onDown = onDown
        return view
    }

    func updateNSView(_ view: KeyView, context: Context) {
        view.onUp = onUp
        view.onDown = onDown
    }

    final class KeyView: NSView {
        var onUp: (() -> Void)?
        var onDown: (() -> Void)?
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
                guard let self, self.window != nil else { return event }
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
                return event
            }
        }
    }
}
