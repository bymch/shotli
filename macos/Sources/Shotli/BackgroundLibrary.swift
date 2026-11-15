import AppKit
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// Pictures people add as their own backgrounds. They live in Application Support, so projects can point at them by name.
enum CustomBackgrounds {
    private static let lock = NSLock()
    private static var cache: [String: CGImage] = [:]
    static let types: [UTType] = [.png, .jpeg, .heic, .tiff, .webP]

    static var folder: URL {
        ShotliProjects.root
            .deletingLastPathComponent()
            .appendingPathComponent("Backgrounds", isDirectory: true)
    }

    static func url(_ name: String) -> URL {
        folder.appendingPathComponent(name)
    }

    /// The picture at a size that keeps exports sharp without holding a huge original in memory.
    static func image(_ name: String) -> CGImage? {
        lock.lock()
        defer { lock.unlock() }
        if let found = cache[name] { return found }
        guard let source = CGImageSourceCreateWithURL(url(name) as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 4096,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        cache[name] = image
        return image
    }

    static func names() -> [String] {
        let keys: [URLResourceKey] = [.creationDateKey]
        guard let items = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else { return [] }
        return items
            .filter { item in types.contains { UTType(filenameExtension: item.pathExtension)?.conforms(to: $0) == true } }
            .sorted {
                let left = (try? $0.resourceValues(forKeys: Set(keys)).creationDate) ?? .distantPast
                let right = (try? $1.resourceValues(forKeys: Set(keys)).creationDate) ?? .distantPast
                return left > right
            }
            .map(\.lastPathComponent)
    }

    static func add(_ source: URL) throws -> String {
        let accessed = source.startAccessingSecurityScopedResource()
        defer { if accessed { source.stopAccessingSecurityScopedResource() } }
        guard CGImageSourceCreateWithURL(source as CFURL, nil).flatMap({ CGImageSourceCreateImageAtIndex($0, 0, nil) }) != nil else {
            throw CocoaError(.fileReadCorruptFile)
        }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let ext = source.pathExtension.isEmpty ? "png" : source.pathExtension.lowercased()
        let name = "\(UUID().uuidString).\(ext)"
        try FileManager.default.copyItem(at: source, to: url(name))
        return name
    }

    static func remove(_ name: String) {
        try? FileManager.default.removeItem(at: url(name))
        lock.lock()
        cache[name] = nil
        lock.unlock()
    }
}

/// Recently used and favourite backgrounds, kept between launches.
final class BackgroundStore: ObservableObject {
    static let shared = BackgroundStore()
    @Published private(set) var favourites: [Background] = []
    @Published private(set) var recents: [Background] = []
    @Published private(set) var customs: [String] = []
    private let favouritesKey = "shotli.backgroundFavourites"
    private let recentsKey = "shotli.backgroundRecents"

    private init() {
        favourites = Self.load(favouritesKey)
        recents = Self.load(recentsKey)
        customs = CustomBackgrounds.names()
    }

    func isFavourite(_ background: Background) -> Bool {
        favourites.contains(background)
    }

    func toggleFavourite(_ background: Background) {
        if let index = favourites.firstIndex(of: background) {
            favourites.remove(at: index)
        } else {
            favourites.insert(background, at: 0)
        }
        Self.save(favourites, favouritesKey)
    }

    func noteUsed(_ background: Background) {
        recents.removeAll { $0 == background }
        recents.insert(background, at: 0)
        if recents.count > 9 { recents.removeLast(recents.count - 9) }
        Self.save(recents, recentsKey)
    }

    @discardableResult
    func addCustom(_ urls: [URL]) -> [Background] {
        var added: [Background] = []
        for url in urls {
            if let name = try? CustomBackgrounds.add(url) { added.append(.image(name)) }
        }
        customs = CustomBackgrounds.names()
        return added
    }

    func removeCustom(_ name: String) {
        CustomBackgrounds.remove(name)
        customs = CustomBackgrounds.names()
        favourites.removeAll { $0 == .image(name) }
        recents.removeAll { $0 == .image(name) }
        Self.save(favourites, favouritesKey)
        Self.save(recents, recentsKey)
    }

    private static func load(_ key: String) -> [Background] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let files = try? JSONDecoder().decode([BackgroundFile].self, from: data) else { return [] }
        return files.map(\.background).filter { background in
            if case .image(let name) = background {
                return FileManager.default.fileExists(atPath: CustomBackgrounds.url(name).path)
            }
            return true
        }
    }

    private static func save(_ list: [Background], _ key: String) {
        guard let data = try? JSONEncoder().encode(list.map(BackgroundFile.init)) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

struct LibraryItem: Identifiable {
    var background: Background
    var name: String
    var group: String

    var id: String { Self.key(background) }

    static func key(_ background: Background) -> String {
        switch background {
        case .color(let hex): return "color:\(hex)"
        case .gradient(let from, let mid, let to, let angle): return "gradient:\(from)-\(mid ?? "")-\(to)-\(Int(angle))"
        case .wallpaper(let id): return "wallpaper:\(id.rawValue)"
        case .image(let name): return "image:\(name)"
        }
    }
}

enum LibraryCategory: String, CaseIterable, Identifiable {
    case all, favourites, presets, gradients, textures, abstract, scenes, custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .favourites: return "Favourites"
        case .presets: return "Presets"
        case .gradients: return "Gradients"
        case .textures: return "Textures"
        case .abstract: return "Abstract"
        case .scenes: return "Scenes"
        case .custom: return "Custom"
        }
    }

    var symbol: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .favourites: return "heart"
        case .presets: return "sparkles"
        case .gradients: return "circle.lefthalf.filled"
        case .textures: return "square.grid.3x3.square"
        case .abstract: return "scribble.variable"
        case .scenes: return "mountain.2"
        case .custom: return "photo.on.rectangle.angled"
        }
    }

    /// The fixed collection, in groups. Favourites and Custom come from the store instead.
    var groups: [(title: String, items: [LibraryItem])] {
        func walls(_ group: String, _ ids: [WallpaperID]) -> (title: String, items: [LibraryItem]) {
            (group, ids.map { LibraryItem(background: .wallpaper($0), name: $0.label, group: group) })
        }
        switch self {
        case .presets:
            return [walls("Glass", WallpaperID.glass), walls("Studio", WallpaperID.backdrops)]
        case .gradients:
            let linear = Presets.gradients.map {
                LibraryItem(background: .gradient(from: $0.from, mid: $0.mid, to: $0.to, angle: $0.angle), name: $0.name, group: "Linear")
            }
            let solid = Presets.colors.map { hex in
                LibraryItem(background: .color(hex), name: hex == "transparent" ? "Transparent" : hex, group: "Solid")
            }
            return [walls("Soft", WallpaperID.fields), ("Linear", linear), ("Solid", solid)]
        case .textures:
            return [walls("Materials", WallpaperID.textures), walls("Patterns", WallpaperID.patterns)]
        case .abstract:
            return [walls("Abstract", WallpaperID.abstract), walls("Mystic", WallpaperID.mystic), walls("Cosmic", WallpaperID.cosmic)]
        case .scenes:
            return [walls("Scenes", WallpaperID.scenes), walls("Desktop", WallpaperID.desktop), walls("Earth", WallpaperID.earth)]
        case .all, .favourites, .custom:
            return []
        }
    }

    static let browsable: [LibraryCategory] = [.presets, .gradients, .textures, .abstract, .scenes]

    static var everything: [LibraryItem] {
        browsable.flatMap { category in category.groups.flatMap(\.items) }
    }
}

enum LibraryThumbs {
    private static var walls: [String: NSImage] = [:]
    private static var pictures: [String: NSImage] = [:]

    static func wallpaper(_ id: WallpaperID) -> NSImage? {
        if let found = walls[id.rawValue] { return found }
        guard let rendered = renderSceneThumbnail(id) else { return nil }
        walls[id.rawValue] = rendered
        return rendered
    }

    static func custom(_ name: String) -> NSImage? {
        if let found = pictures[name] { return found }
        guard let source = CGImageSourceCreateWithURL(CustomBackgrounds.url(name) as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 360,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let thumb = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        pictures[name] = thumb
        return thumb
    }
}

/// What a background looks like, at any size.
struct BackgroundSwatch: View {
    var background: Background

    var body: some View {
        switch background {
        case .color(let hex):
            if hex == "transparent" {
                Checkerboard()
            } else {
                Color(nsColor: NSColor(hex: hex) ?? .white)
            }
        case .gradient(let from, let mid, let to, _):
            LinearGradient(
                colors: [hex(from), hex(mid ?? to), hex(to)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .wallpaper(let id):
            if let image = LibraryThumbs.wallpaper(id) {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                Color(nsColor: NSColor(hex: "#E7E5E4")!)
            }
        case .image(let name):
            if let image = LibraryThumbs.custom(name) {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                Checkerboard()
            }
        }
    }

    private func hex(_ value: String) -> Color {
        Color(nsColor: NSColor(hex: value) ?? .white)
    }
}

private struct Checkerboard: View {
    var body: some View {
        GeometryReader { geo in
            let step: CGFloat = 8
            Path { path in
                var y: CGFloat = 0
                var row = 0
                while y < geo.size.height {
                    var x: CGFloat = row % 2 == 0 ? 0 : step
                    while x < geo.size.width {
                        path.addRect(CGRect(x: x, y: y, width: step, height: step))
                        x += step * 2
                    }
                    y += step
                    row += 1
                }
            }
            .fill(Color.black.opacity(0.08))
            .background(Color.white)
        }
    }
}

/// The background library: search, categories, and a grid of live thumbnails.
struct BackgroundLibraryView: View {
    @ObservedObject var model: EditorModel
    var wide = false
    var onExpand: (() -> Void)?
    var onClose: (() -> Void)?
    @ObservedObject private var store = BackgroundStore.shared
    @State private var category: LibraryCategory = .all
    @State private var query = ""
    @State private var dropTarget = false
    @FocusState private var searching: Bool
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var ink: Color { ShotliGlass.ink(colorScheme) }
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: wide ? 12 : 8, alignment: .top), count: wide ? 5 : 3)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            searchField
            categoryBar
            content
        }
        .onDisappear { model.previewBackground = nil }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Backgrounds")
                .font(.system(size: wide ? 22 : 13, weight: .semibold))
                .foregroundColor(ink)
            Spacer(minLength: 0)
            if let onExpand {
                headerButton("arrow.up.left.and.arrow.down.right", help: "Browse every background", action: onExpand)
            }
            if let onClose {
                headerButton("xmark", help: "Close", action: onClose)
            }
        }
    }

    private func headerButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(ink)
                .frame(width: 26, height: 26)
                .background(Circle().fill(ShotliGlass.quiet(colorScheme)))
                .contentShape(Circle())
        }
        .buttonStyle(PressFadeButtonStyle())
        .help(help)
        .accessibilityLabel(help)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
            TextField("Search backgrounds", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($searching)
                .onExitCommand {
                    query = ""
                    searching = false
                }
            if !query.isEmpty {
                Button(action: { query = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(
            RoundedRectangle(cornerRadius: ShotliGlass.radiusChip, style: .continuous)
                .fill(ShotliGlass.search(colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: ShotliGlass.radiusChip, style: .continuous)
                .stroke(searching ? ShotliGlass.accent.opacity(0.6) : ShotliGlass.hairline(colorScheme), lineWidth: searching ? 1.5 : 1)
        )
        .background(
            Button("") { searching = true }
                .keyboardShortcut("f", modifiers: .command)
                .opacity(0)
                .accessibilityHidden(true)
        )
    }

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(LibraryCategory.allCases) { item in
                    categoryChip(item)
                }
            }
            .padding(.vertical, 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Background categories")
    }

    private func categoryChip(_ item: LibraryCategory) -> some View {
        let on = category == item && query.isEmpty
        return Button(action: {
            query = ""
            withAnimation(reduceMotion ? nil : .easeOut(duration: ShotliGlass.duration)) { category = item }
        }) {
            HStack(spacing: 5) {
                Image(systemName: on && item == .favourites ? "heart.fill" : item.symbol)
                    .font(.system(size: 10, weight: .semibold))
                Text(item.title)
                    .font(.system(size: 11, weight: on ? .semibold : .medium))
                    .lineLimit(1)
            }
            .foregroundColor(on ? ShotliGlass.selectedControlInk(colorScheme) : ink)
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(
                Capsule().fill(on ? ShotliGlass.selectedControl(colorScheme) : ShotliGlass.quiet(colorScheme))
            )
            .contentShape(Capsule())
        }
        .buttonStyle(PressFadeButtonStyle())
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(on ? .isSelected : AccessibilityTraits())
    }

    @ViewBuilder
    private var content: some View {
        let term = query.trimmingCharacters(in: .whitespaces).lowercased()
        if !term.isEmpty {
            let found = (LibraryCategory.everything + customItems).filter {
                $0.name.lowercased().contains(term) || $0.group.lowercased().contains(term)
            }
            if found.isEmpty {
                emptyState(symbol: "magnifyingglass", title: "Nothing called “\(query)”", detail: "Try a colour, a mood, or a category like Glass or Marble.")
            } else {
                grid(found)
            }
        } else {
            switch category {
            case .all: overview
            case .favourites: favouritesView
            case .custom: customView
            default: grouped(category.groups)
            }
        }
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 18) {
            if !store.recents.isEmpty {
                section("Recent", action: nil) {
                    grid(store.recents.prefix(wide ? 5 : 3).map { item(for: $0, group: "Recent") })
                }
            }
            if !store.favourites.isEmpty {
                section("Favourites", action: { category = .favourites }) {
                    grid(store.favourites.prefix(wide ? 5 : 3).map { item(for: $0, group: "Favourites") })
                }
            }
            ForEach(LibraryCategory.browsable) { shelf in
                section(shelf.title, action: { category = shelf }) {
                    grid(Array(shelf.groups.flatMap(\.items).prefix(wide ? 10 : 6)))
                }
            }
            section("Custom", action: { category = .custom }) {
                if store.customs.isEmpty {
                    customDropZone(compact: true)
                } else {
                    customGrid(limit: wide ? 9 : 5)
                }
            }
        }
    }

    private func grouped(_ groups: [(title: String, items: [LibraryItem])]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(groups, id: \.title) { group in
                VStack(alignment: .leading, spacing: 8) {
                    subheading(group.title)
                    grid(group.items)
                }
            }
        }
    }

    @ViewBuilder
    private var favouritesView: some View {
        if store.favourites.isEmpty {
            emptyState(symbol: "heart", title: "No favourites yet", detail: "Point at any background and click the heart to keep it here.")
        } else {
            grid(store.favourites.map { item(for: $0, group: "Favourites") })
        }
    }

    @ViewBuilder
    private var customView: some View {
        if store.customs.isEmpty {
            customDropZone(compact: false)
        } else {
            customGrid(limit: nil)
        }
    }

    private var customItems: [LibraryItem] {
        store.customs.enumerated().map { index, name in
            LibraryItem(background: .image(name), name: "Custom \(store.customs.count - index)", group: "Custom")
        }
    }

    private func customGrid(limit: Int?) -> some View {
        let items = limit.map { Array(customItems.prefix($0)) } ?? customItems
        return LazyVGrid(columns: columns, spacing: wide ? 14 : 10) {
            addTile
            ForEach(items) { item in
                tile(item)
            }
        }
        .onDrop(of: [UTType.fileURL], isTargeted: $dropTarget, perform: acceptDrop)
    }

    private var addTile: some View {
        Button(action: chooseImages) {
            VStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                Text("Add")
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)
            .aspectRatio(1.45, contentMode: .fit)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(dropTarget ? ShotliGlass.accent : ShotliGlass.line(colorScheme), style: StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(PressFadeButtonStyle())
        .help("Add your own background image")
        .accessibilityLabel("Add your own background image")
    }

    private func customDropZone(compact: Bool) -> some View {
        Button(action: chooseImages) {
            VStack(spacing: compact ? 6 : 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(LinearGradient(
                            colors: [Color(nsColor: NSColor(hex: "#F78529")!), Color(nsColor: NSColor(hex: "#7A42E8")!)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: compact ? 30 : 44, height: compact ? 30 : 44)
                        .rotationEffect(.degrees(-8))
                        .opacity(0.9)
                    Image(systemName: "photo")
                        .font(.system(size: compact ? 13 : 18, weight: .semibold))
                        .foregroundColor(.white)
                }
                Text("Your own backgrounds")
                    .font(.system(size: compact ? 12 : 13, weight: .semibold))
                    .foregroundColor(ink)
                Text(compact ? "Drop an image or click to choose." : "Drop an image here or click to choose one. It stays on this Mac.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(compact ? 14 : 24)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(dropTarget ? ShotliGlass.selectedCard(colorScheme) : ShotliGlass.quiet(colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(dropTarget ? ShotliGlass.accent : ShotliGlass.line(colorScheme), style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(PressFadeButtonStyle())
        .onDrop(of: [UTType.fileURL], isTargeted: $dropTarget, perform: acceptDrop)
        .accessibilityLabel("Add your own background image")
    }

    private func emptyState(symbol: String, title: String, detail: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(ShotliGlass.emptyIcon(colorScheme))
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(ink)
                .multilineTextAlignment(.center)
            Text(detail)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
    }

    private func section<Content: View>(_ title: String, action: (() -> Void)?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                subheading(title)
                if let action {
                    Button(action: {
                        withAnimation(reduceMotion ? nil : .easeOut(duration: ShotliGlass.duration)) { action() }
                    }) {
                        HStack(spacing: 2) {
                            Text("See all")
                            Image(systemName: "chevron.right").font(.system(size: 8, weight: .bold))
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(ShotliGlass.accent)
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .accessibilityLabel("See all \(title.lowercased())")
                }
            }
            content()
        }
    }

    private func subheading(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .kerning(0.6)
            .foregroundColor(.secondary)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func grid(_ items: [LibraryItem]) -> some View {
        if !items.isEmpty {
            LazyVGrid(columns: columns, spacing: wide ? 14 : 10) {
                ForEach(items) { item in
                    tile(item)
                }
            }
        }
    }

    private func tile(_ item: LibraryItem) -> some View {
        LibraryTile(
            item: item,
            active: model.style.background == item.background,
            favourite: store.isFavourite(item.background),
            showsName: wide || item.group != "Solid",
            apply: { apply(item.background) },
            preview: { on in preview(item.background, on) },
            toggleFavourite: { store.toggleFavourite(item.background) },
            remove: removal(for: item.background),
            flatColours: flatColours(for: item.background)
        )
    }

    private func item(for background: Background, group: String) -> LibraryItem {
        if let known = (LibraryCategory.everything + customItems).first(where: { $0.background == background }) {
            return known
        }
        return LibraryItem(background: background, name: "Background", group: group)
    }

    private func removal(for background: Background) -> (() -> Void)? {
        guard case .image(let name) = background else { return nil }
        return {
            if model.style.background == background { model.setBackground(Presets.all[0].style.background) }
            store.removeCustom(name)
        }
    }

    private func flatColours(for background: Background) -> [String] {
        guard case .gradient(let from, let mid, let to, _) = background else { return [] }
        var stops: [String] = []
        for hex in [from, mid ?? to, to] where !stops.contains(hex) { stops.append(hex) }
        return stops
    }

    private func apply(_ background: Background) {
        model.previewBackground = nil
        model.setBackground(background)
        store.noteUsed(background)
    }

    private func preview(_ background: Background, _ on: Bool) {
        if on {
            if model.style.background != background { model.previewBackground = background }
        } else if model.previewBackground == background {
            model.previewBackground = nil
        }
    }

    private func chooseImages() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = CustomBackgrounds.types
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.message = "Choose pictures to use as backgrounds"
        guard panel.runModal() == .OK else { return }
        addImages(panel.urls)
    }

    private func acceptDrop(_ providers: [NSItemProvider]) -> Bool {
        let files = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard !files.isEmpty else { return false }
        for provider in files {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url: URL? = (item as? Data).flatMap { URL(dataRepresentation: $0, relativeTo: nil) } ?? (item as? URL)
                guard let url else { return }
                DispatchQueue.main.async { addImages([url]) }
            }
        }
        return true
    }

    private func addImages(_ urls: [URL]) {
        let added = store.addCustom(urls)
        if let first = added.first {
            category = .custom
            apply(first)
        } else if !urls.isEmpty {
            model.notice = "Shotli couldn't read that image. Use a PNG, JPEG, HEIC, TIFF, or WebP file."
        }
    }
}

/// One background in the library. Resting the pointer on it previews it on the canvas.
private struct LibraryTile: View {
    var item: LibraryItem
    var active: Bool
    var favourite: Bool
    var showsName: Bool
    var apply: () -> Void
    var preview: (Bool) -> Void
    var toggleFavourite: () -> Void
    var remove: (() -> Void)?
    var flatColours: [String]
    @State private var hovering = false
    @State private var hoverToken = 0
    @FocusState private var focused: Bool
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var model = EditorModel.shared

    private let radius: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ZStack(alignment: .topTrailing) {
                Button(action: apply) {
                    Color.clear
                        .aspectRatio(1.45, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .overlay { BackgroundSwatch(background: item.background).allowsHitTesting(false) }
                        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                        .overlay(edge)
                        .overlay(alignment: .bottomTrailing) { check }
                        .shadow(color: Color.black.opacity(hovering ? 0.16 : 0.06), radius: hovering ? 8 : 3, y: hovering ? 4 : 1)
                        .scaleEffect(hovering && !reduceMotion ? 1.03 : 1)
                        .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                }
                .buttonStyle(PressFadeButtonStyle())
                .focused($focused)
                .help(item.name)
                .accessibilityLabel("\(item.name) background")
                .accessibilityAddTraits(active ? .isSelected : AccessibilityTraits())
                .accessibilityAction(named: favourite ? "Remove from Favourites" : "Add to Favourites", toggleFavourite)
                if hovering || favourite {
                    Button(action: toggleFavourite) {
                        Image(systemName: favourite ? "heart.fill" : "heart")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(favourite ? Color(nsColor: NSColor(hex: "#F03B47")!) : ShotliGlass.ink(.light))
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(Color.white.opacity(0.92)))
                            .shadow(color: Color.black.opacity(0.18), radius: 2, y: 1)
                            .contentShape(Circle())
                    }
                    .buttonStyle(PressFadeButtonStyle())
                    .padding(4)
                    .help(favourite ? "Remove from Favourites" : "Add to Favourites")
                    .accessibilityHidden(true)
                    .transition(.opacity)
                }
            }
            if showsName {
                Text(item.name)
                    .font(.system(size: 10, weight: active ? .semibold : .medium))
                    .foregroundColor(active ? ShotliGlass.ink(colorScheme) : .secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.leading, 2)
            }
        }
        .onHover(perform: hover)
        .animation(reduceMotion ? nil : .easeOut(duration: ShotliGlass.duration), value: hovering)
        .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.75), value: active)
        .contextMenu {
            Button("Use Background", action: apply)
            Button(favourite ? "Remove from Favourites" : "Add to Favourites", action: toggleFavourite)
            if !flatColours.isEmpty {
                Divider()
                ForEach(flatColours, id: \.self) { hex in
                    Button("Use Flat \(hex)") { model.setBackground(.color(hex)) }
                }
            }
            if let remove {
                Divider()
                Button("Delete Background", action: remove)
            }
        }
    }

    private func hover(_ on: Bool) {
        hovering = on
        hoverToken += 1
        let token = hoverToken
        if on {
            // A short rest before previewing, so sweeping across the grid doesn't repaint the canvas each time.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                if token == hoverToken, hovering { preview(true) }
            }
        } else {
            preview(false)
        }
    }

    private var edge: some View {
        ZStack {
            if active || focused {
                RoundedRectangle(cornerRadius: radius - 2, style: .continuous)
                    .stroke(ShotliGlass.focusRing(colorScheme), lineWidth: 1.5)
                    .padding(2)
            }
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(
                    active || focused ? ShotliGlass.accent : (hovering ? ShotliGlass.line(colorScheme) : ShotliGlass.hairline(colorScheme)),
                    lineWidth: active || focused ? 2 : 1
                )
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var check: some View {
        if active {
            Image(systemName: "checkmark")
                .font(.system(size: 8, weight: .heavy))
                .foregroundColor(.white)
                .frame(width: 16, height: 16)
                .background(Circle().fill(ShotliGlass.accent))
                .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                .padding(5)
                .transition(.scale.combined(with: .opacity))
                .allowsHitTesting(false)
        }
    }
}
