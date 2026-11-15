import AppKit
import SwiftUI

/// A complete composition: background, size and place on the canvas, depth, corners, angle, and shape of the export.
/// Applying one only sets ordinary style values, so everything stays editable afterwards.
struct Recipe: Identifiable {
    let id: String
    let name: String
    let summary: String
    let collection: RecipeCollection
    var background: Background
    /// How much of the composition's width the screenshot takes before the canvas shape adds room.
    var fill: CGFloat = 0.82
    var canvas: CanvasRatio = .sixteenNine
    var shiftX: CGFloat = 0
    var shiftY: CGFloat = 0
    var radius: CGFloat = 18
    var shadow: CGFloat = 40
    var shadowKind: ShadowKind = .spread
    var shadowOpacity: CGFloat = 46
    var tiltX: CGFloat = 0
    var tiltY: CGFloat = 0
    var frame: FrameStyle = .none
    var card: CardStyle = .default
    var decor: Decor = .none

    /// The style for a screenshot of this size. Padding follows the size, so the screenshot fills the same share of any canvas.
    func style(for shot: CGSize?) -> ShotliStyle {
        let span = max(shot?.width ?? 1600, shot?.height ?? 1000, 1)
        let padding = (span * (1 - fill) / (2 * fill)).rounded()
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
        style.shadowKind = shadow > 0 ? shadowKind : .none
        style.shadowOpacity = shadowOpacity
        style.tiltX = tiltX
        style.tiltY = tiltY
        style.shiftX = shiftX
        style.shiftY = shiftY
        style.decor = decor
        return style
    }

    var angled: Bool { abs(tiltX) + abs(tiltY) > 0.5 }
}

enum RecipeCollection: String, CaseIterable, Identifiable {
    case startupLaunch, darkStudio, editorial, playful, perspective, showcase, minimal, productMarketing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .startupLaunch: return "Startup Launch"
        case .darkStudio: return "Dark Studio"
        case .editorial: return "Editorial"
        case .playful: return "Playful"
        case .perspective: return "Perspective"
        case .showcase: return "Showcase"
        case .minimal: return "Minimal"
        case .productMarketing: return "Product Marketing"
        }
    }

    var symbol: String {
        switch self {
        case .startupLaunch: return "paperplane"
        case .darkStudio: return "moon.stars"
        case .editorial: return "newspaper"
        case .playful: return "face.smiling"
        case .perspective: return "rotate.3d"
        case .showcase: return "rectangle.on.rectangle"
        case .minimal: return "circle"
        case .productMarketing: return "megaphone"
        }
    }
}

enum RecipeLibrary {
    static func recipe(_ id: String) -> Recipe? {
        all.first { $0.id == id }
    }

    static func inCollection(_ collection: RecipeCollection) -> [Recipe] {
        all.filter { $0.collection == collection }
    }

    private static func gradient(_ name: String) -> Background {
        guard let found = Presets.gradients.first(where: { $0.name == name }) else { return .color("#FFFFFF") }
        return .gradient(from: found.from, mid: found.mid, to: found.to, angle: found.angle)
    }

    static let all: [Recipe] = [
        // Startup Launch
        Recipe(id: "launch-day", name: "Launch Day", summary: "Warm glow, big centred hero.", collection: .startupLaunch,
               background: .wallpaper(.flare), fill: 0.78, radius: 20, shadow: 52, decor: .spotlight),
        Recipe(id: "seed-round", name: "Seed Round", summary: "Violet field, a confident lean.", collection: .startupLaunch,
               background: .wallpaper(.iris), fill: 0.8, shiftX: -0.08, radius: 22, shadow: 46, tiltX: 10, tiltY: -18),
        Recipe(id: "hunt", name: "Front Page", summary: "Grainy gradient, browser chrome.", collection: .startupLaunch,
               background: .wallpaper(.grain), fill: 0.8, radius: 14, shadow: 44, frame: .browser, decor: .stack),
        Recipe(id: "rising", name: "Rising", summary: "Rises from the bottom edge.", collection: .startupLaunch,
               background: .wallpaper(.prism), fill: 0.86, canvas: .fourThree, shiftY: 1, radius: 20, shadow: 48),

        // Dark Studio
        Recipe(id: "spotlight", name: "Spotlight", summary: "Ink backdrop under a soft light.", collection: .darkStudio,
               background: .wallpaper(.ink), fill: 0.8, radius: 20, shadow: 60, shadowOpacity: 60, decor: .spotlight),
        Recipe(id: "after-hours", name: "After Hours", summary: "Dark grain with a browser frame.", collection: .darkStudio,
               background: .wallpaper(.noise), fill: 0.8, radius: 14, shadow: 56, shadowOpacity: 64, frame: .browser),
        Recipe(id: "nebula", name: "Nebula", summary: "Deep space, slight tilt.", collection: .darkStudio,
               background: .wallpaper(.nebula), fill: 0.78, radius: 20, shadow: 50, tiltX: 8, tiltY: 14),
        Recipe(id: "void", name: "Void", summary: "Dark glass card on black.", collection: .darkStudio,
               background: .wallpaper(.void), fill: 0.8, radius: 22, shadow: 44, card: .glassDark),

        // Editorial
        Recipe(id: "paper", name: "Paper", summary: "Quiet page, tight corners.", collection: .editorial,
               background: .wallpaper(.paper), fill: 0.76, canvas: .fourThree, radius: 8, shadow: 30, shadowKind: .hug, shadowOpacity: 40),
        Recipe(id: "linen", name: "Linen", summary: "Soft cloth tones, 3:2 print.", collection: .editorial,
               background: .wallpaper(.linen), fill: 0.78, canvas: .threeTwo, radius: 12, shadow: 34),
        Recipe(id: "marble", name: "Marble", summary: "Stone and a desktop window.", collection: .editorial,
               background: .wallpaper(.marble), fill: 0.78, radius: 10, shadow: 36, frame: .desktop),
        Recipe(id: "fabric", name: "Fabric", summary: "Woven texture, close shadow.", collection: .editorial,
               background: .wallpaper(.fabric), fill: 0.8, canvas: .fourThree, radius: 12, shadow: 32, shadowKind: .hug),

        // Playful
        Recipe(id: "bloom", name: "Bloom", summary: "Colour bursts behind a stack.", collection: .playful,
               background: .wallpaper(.bloom), fill: 0.76, shiftX: 0.16, radius: 24, shadow: 34, decor: .stack),
        Recipe(id: "petal", name: "Petal", summary: "Bright shapes, playful tilt.", collection: .playful,
               background: .wallpaper(.petal), fill: 0.76, radius: 24, shadow: 42, tiltX: 12, tiltY: 22),
        Recipe(id: "citrus", name: "Citrus", summary: "Zesty colour, leaning left.", collection: .playful,
               background: .wallpaper(.citrus), fill: 0.78, shiftX: -0.1, radius: 22, shadow: 34, tiltX: 8, tiltY: -22),
        Recipe(id: "sorbet", name: "Sorbet", summary: "Pastel square for social posts.", collection: .playful,
               background: .wallpaper(.sorbet), fill: 0.74, canvas: .square, radius: 26, shadow: 36),

        // Perspective
        Recipe(id: "lean-left", name: "Lean Left", summary: "Turns away to the left.", collection: .perspective,
               background: .wallpaper(.porcelain), fill: 0.8, radius: 22, shadow: 48, tiltX: 14, tiltY: -26),
        Recipe(id: "lean-right", name: "Lean Right", summary: "Turns away to the right.", collection: .perspective,
               background: .wallpaper(.glacier), fill: 0.8, radius: 22, shadow: 48, tiltX: 14, tiltY: 26),
        Recipe(id: "hero-angle", name: "Hero Angle", summary: "Desert light, low camera.", collection: .perspective,
               background: .wallpaper(.canyon), fill: 0.78, shiftX: 0.08, radius: 18, shadow: 40, tiltX: 10, tiltY: 18),
        Recipe(id: "sand-lean", name: "Sand", summary: "Warm 3:2 with a gentle turn.", collection: .perspective,
               background: .wallpaper(.sand), fill: 0.8, canvas: .threeTwo, shiftX: -0.16, radius: 16, shadow: 36, tiltX: 10, tiltY: 22),

        // Showcase
        Recipe(id: "studio", name: "Studio", summary: "Seamless studio sweep.", collection: .showcase,
               background: .wallpaper(.studio), fill: 0.8, shiftX: 0.22, radius: 18, shadow: 40),
        Recipe(id: "gallery", name: "Gallery", summary: "Mounted on a glass plate.", collection: .showcase,
               background: .wallpaper(.porcelain), fill: 0.74, radius: 18, shadow: 36, decor: .plate),
        Recipe(id: "ripple", name: "Ripple", summary: "Blue glass waves.", collection: .showcase,
               background: .wallpaper(.ripple), fill: 0.8, radius: 22, shadow: 32),
        Recipe(id: "peaks", name: "Peaks", summary: "Mountain desktop, centred.", collection: .showcase,
               background: .wallpaper(.peaks), fill: 0.8, radius: 16, shadow: 36, frame: .desktop),

        // Minimal
        Recipe(id: "clean", name: "Clean", summary: "White canvas, soft shadow.", collection: .minimal,
               background: .color("#FFFFFF"), fill: 0.86, radius: 14, shadow: 28),
        Recipe(id: "mist", name: "Mist", summary: "Barely-there gradient.", collection: .minimal,
               background: gradient("Mist"), fill: 0.84, radius: 18, shadow: 30),
        Recipe(id: "graph", name: "Graph", summary: "Fine grid, desktop window.", collection: .minimal,
               background: .wallpaper(.grid), fill: 0.82, radius: 10, shadow: 24, frame: .desktop),
        Recipe(id: "dots", name: "Dots", summary: "Dotted paper, close shadow.", collection: .minimal,
               background: .wallpaper(.dots), fill: 0.84, canvas: .fourThree, radius: 12, shadow: 26, shadowKind: .hug),

        // Product Marketing
        Recipe(id: "feature", name: "Feature", summary: "Browser on a tide gradient.", collection: .productMarketing,
               background: .wallpaper(.tide), fill: 0.82, radius: 14, shadow: 32, frame: .browser),
        Recipe(id: "feature-tilt", name: "Feature Tilt", summary: "The same browser, angled.", collection: .productMarketing,
               background: .wallpaper(.tide), fill: 0.8, shiftX: 0.08, radius: 14, shadow: 36, tiltX: 8, tiltY: 20, frame: .browser),
        Recipe(id: "sea-glass", name: "Sea Glass", summary: "Cool gradient, frosted card.", collection: .productMarketing,
               background: gradient("Sea Glass"), fill: 0.78, radius: 24, shadow: 30, card: .glassLight),
        Recipe(id: "ember", name: "Ember", summary: "Glowing amber with a stack.", collection: .productMarketing,
               background: .wallpaper(.emberglass), fill: 0.78, radius: 20, shadow: 40, decor: .stack),
    ]
}

/// Favourite and recently used recipes, kept between launches.
final class RecipeStore: ObservableObject {
    static let shared = RecipeStore()
    @Published private(set) var favourites: [String]
    @Published private(set) var recents: [String]
    private let favouritesKey = "shotli.recipeFavourites"
    private let recentsKey = "shotli.recipeRecents"

    private init() {
        favourites = UserDefaults.standard.stringArray(forKey: favouritesKey) ?? []
        recents = UserDefaults.standard.stringArray(forKey: recentsKey) ?? []
    }

    func isFavourite(_ id: String) -> Bool { favourites.contains(id) }

    func toggleFavourite(_ id: String) {
        if let index = favourites.firstIndex(of: id) {
            favourites.remove(at: index)
        } else {
            favourites.insert(id, at: 0)
        }
        UserDefaults.standard.set(favourites, forKey: favouritesKey)
    }

    func noteUsed(_ id: String) {
        recents.removeAll { $0 == id }
        recents.insert(id, at: 0)
        if recents.count > 6 { recents.removeLast(recents.count - 6) }
        UserDefaults.standard.set(recents, forKey: recentsKey)
    }
}

/// Real renders of each recipe with the person's own screenshot, made off the main thread and kept until the picture changes.
final class RecipeThumbs: ObservableObject {
    static let shared = RecipeThumbs()
    @Published private(set) var images: [String: NSImage] = [:]
    private var pending: Set<String> = []
    private var source: (key: String, picture: LoadedPicture)?
    private let queue = DispatchQueue(label: "shotli.recipe-thumbs", qos: .userInitiated)

    func image(_ recipe: Recipe, picture: LoadedPicture?, crop: CGRect?) -> NSImage? {
        let base = baseKey(picture, crop)
        let key = "\(recipe.id)|\(base)"
        if let found = images[key] { return found }
        guard !pending.contains(key) else { return nil }
        pending.insert(key)
        let small = smallPicture(picture, crop: crop, key: base)
        queue.async {
            let style = recipe.style(for: CGSize(width: small.width, height: small.height))
            let rendered = renderShot(
                picture: small, crop: nil, style: style, annotations: [], layers: [],
                draft: nil, interactive: false
            )
            let thumb = rendered.map { NSImage(cgImage: $0, size: NSSize(width: $0.width, height: $0.height)) }
            DispatchQueue.main.async {
                self.pending.remove(key)
                if base != self.source?.key { return }
                // Renders for an earlier picture are no use once another one is open.
                if self.images.keys.contains(where: { !$0.hasSuffix("|\(base)") }) {
                    self.images = self.images.filter { $0.key.hasSuffix("|\(base)") }
                }
                if let thumb { self.images[key] = thumb }
            }
        }
        return nil
    }

    private func baseKey(_ picture: LoadedPicture?, _ crop: CGRect?) -> String {
        guard let picture else { return "sample" }
        let id = ObjectIdentifier(picture.image).hashValue
        let area = crop.map { "\(Int($0.minX)),\(Int($0.minY)),\(Int($0.width)),\(Int($0.height))" } ?? "full"
        return "\(id)-\(area)"
    }

    /// A small copy of the cropped screenshot, so a page of previews renders quickly.
    private func smallPicture(_ picture: LoadedPicture?, crop: CGRect?, key: String) -> LoadedPicture {
        if let source, source.key == key { return source.picture }
        let made = Self.shrink(picture, crop: crop) ?? Self.sample
        source = (key, made)
        return made
    }

    private static func shrink(_ picture: LoadedPicture?, crop: CGRect?) -> LoadedPicture? {
        guard let picture else { return nil }
        var image = picture.image
        if let crop = activeCrop(picture: picture, crop: crop), let cut = image.cropping(to: crop.integral) {
            image = cut
        }
        let longest = CGFloat(max(image.width, image.height))
        let scale = min(1, 480 / max(longest, 1))
        let size = CGSize(width: max(1, CGFloat(image.width) * scale), height: max(1, CGFloat(image.height) * scale))
        guard let context = CGContext(
            data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(origin: .zero, size: size))
        guard let small = context.makeImage() else { return nil }
        return LoadedPicture(image: small, name: picture.name, scaled: true)
    }

    /// A plain app window for previews before a screenshot is open.
    private static let sample: LoadedPicture = {
        let size = CGSize(width: 480, height: 300)
        let context = CGContext(
            data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        context.setFillColor(NSColor(srgbRed: 0.945, green: 0.948, blue: 0.962, alpha: 1).cgColor)
        context.fill(CGRect(x: 0, y: 0, width: 120, height: size.height))
        context.setFillColor(NSColor(srgbRed: 18.0 / 255.0, green: 120.0 / 255.0, blue: 180.0 / 255.0, alpha: 1).cgColor)
        context.fill(CGRect(x: 150, y: 220, width: 150, height: 22))
        context.setFillColor(NSColor(srgbRed: 0.88, green: 0.89, blue: 0.91, alpha: 1).cgColor)
        for row in 0..<4 {
            context.fill(CGRect(x: 150, y: 170 - CGFloat(row) * 34, width: CGFloat(280 - row * 30), height: 14))
        }
        return LoadedPicture(image: context.makeImage()!, name: "Sample", scaled: true)
    }()
}

private enum RecipeFilter: Hashable {
    case all, favourites
    case collection(RecipeCollection)
}

/// Screenshot Recipes: complete compositions, previewed with the person's own screenshot.
struct RecipeLibraryView: View {
    @ObservedObject var model: EditorModel
    var onChangeBackground: () -> Void
    @ObservedObject private var store = RecipeStore.shared
    @ObservedObject private var thumbs = RecipeThumbs.shared
    @State private var filter: RecipeFilter = .all
    @State private var query = ""
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var ink: Color { ShotliGlass.ink(colorScheme) }
    private let columns = [GridItem(.flexible(), spacing: 10, alignment: .top), GridItem(.flexible(), spacing: 10, alignment: .top)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if model.activeRecipeID != nil || model.recipeOrigin != nil {
                statusCard
            }
            LibrarySearchField(text: $query, prompt: "Search recipes")
            filters
            content
        }
        .onDisappear { model.previewStyle = nil }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Recipes")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(ink)
            Text("A finished look in one click. Everything stays editable.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// What the canvas is using now, with a way back to the original and a shortcut to Background Studio.
    private var statusCard: some View {
        let recipe = model.activeRecipeID.flatMap(RecipeLibrary.recipe)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(ShotliGlass.accent)
                Text(recipe?.name ?? "Your composition")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(ink)
                    .lineLimit(1)
                if recipe != nil && model.recipeCustomised {
                    Text("Edited")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(ShotliGlass.quiet(colorScheme)))
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 6) {
                statusButton("photo.on.rectangle", "Background", help: "Change only the background", action: onChangeBackground)
                if model.recipeOrigin != nil {
                    statusButton("arrow.uturn.backward", "Original", help: "Go back to the composition from before any recipe") {
                        model.restoreOriginal()
                    }
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(ShotliGlass.selectedCard(colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(ShotliGlass.hairline(colorScheme), lineWidth: 1)
        )
        .transition(.opacity)
    }

    private func statusButton(_ symbol: String, _ title: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 10, weight: .semibold))
                Text(title).font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(ink)
            .padding(.horizontal, 10)
            .frame(height: 24)
            .shotliCapsuleChip()
            .contentShape(Capsule())
        }
        .buttonStyle(PressFadeButtonStyle())
        .help(help)
        .accessibilityLabel(help)
    }

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                chip("All", "square.grid.2x2", .all)
                chip("Favourites", filter == .favourites && query.isEmpty ? "heart.fill" : "heart", .favourites)
                ForEach(RecipeCollection.allCases) { collection in
                    chip(collection.title, collection.symbol, .collection(collection))
                }
            }
            .padding(.vertical, 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Recipe collections")
    }

    private func chip(_ title: String, _ symbol: String, _ item: RecipeFilter) -> some View {
        LibraryChip(title: title, symbol: symbol, on: filter == item && query.isEmpty) {
            query = ""
            withAnimation(reduceMotion ? nil : .easeOut(duration: ShotliGlass.duration)) { filter = item }
        }
    }

    @ViewBuilder
    private var content: some View {
        let term = query.trimmingCharacters(in: .whitespaces).lowercased()
        if !term.isEmpty {
            let found = RecipeLibrary.all.filter {
                $0.name.lowercased().contains(term)
                    || $0.summary.lowercased().contains(term)
                    || $0.collection.title.lowercased().contains(term)
            }
            if found.isEmpty {
                emptyState("magnifyingglass", "No recipe called “\(query)”", "Try a mood like dark, warm, or minimal.")
            } else {
                grid(found)
            }
        } else {
            switch filter {
            case .all:
                overview
            case .favourites:
                let saved = store.favourites.compactMap(RecipeLibrary.recipe)
                if saved.isEmpty {
                    emptyState("heart", "No favourite recipes yet", "Point at a recipe and click the heart to keep it here.")
                } else {
                    grid(saved)
                }
            case .collection(let collection):
                grid(RecipeLibrary.inCollection(collection))
            }
        }
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 18) {
            let recent = store.recents.compactMap(RecipeLibrary.recipe)
            if !recent.isEmpty {
                section("Recent", nil) { grid(Array(recent.prefix(2))) }
            }
            ForEach(RecipeCollection.allCases) { collection in
                section(collection.title, { filter = .collection(collection) }) {
                    grid(Array(RecipeLibrary.inCollection(collection).prefix(2)))
                }
            }
        }
    }

    private func section<Content: View>(_ title: String, _ seeAll: (() -> Void)?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .kerning(0.6)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let seeAll {
                    Button(action: {
                        withAnimation(reduceMotion ? nil : .easeOut(duration: ShotliGlass.duration)) { seeAll() }
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
                    .accessibilityLabel("See all \(title) recipes")
                }
            }
            content()
        }
    }

    private func grid(_ recipes: [Recipe]) -> some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(recipes) { recipe in
                RecipeCard(
                    recipe: recipe,
                    thumb: thumbs.image(recipe, picture: model.picture, crop: model.crop),
                    active: model.activeRecipeID == recipe.id,
                    edited: model.activeRecipeID == recipe.id && model.recipeCustomised,
                    favourite: store.isFavourite(recipe.id),
                    apply: { model.applyRecipe(recipe) },
                    preview: { on in preview(recipe, on) },
                    toggleFavourite: { store.toggleFavourite(recipe.id) },
                    backgroundOnly: {
                        model.previewStyle = nil
                        model.setBackground(recipe.background)
                        BackgroundStore.shared.noteUsed(recipe.background)
                    }
                )
            }
        }
    }

    private func preview(_ recipe: Recipe, _ on: Bool) {
        let style = model.recipeStyle(recipe)
        if on {
            if style != model.style { model.previewStyle = style }
        } else if model.previewStyle == style {
            model.previewStyle = nil
        }
    }

    private func emptyState(_ symbol: String, _ title: String, _ detail: String) -> some View {
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
}

/// One recipe: a live render with the person's screenshot, its name, and what it does.
private struct RecipeCard: View {
    var recipe: Recipe
    var thumb: NSImage?
    var active: Bool
    var edited: Bool
    var favourite: Bool
    var apply: () -> Void
    var preview: (Bool) -> Void
    var toggleFavourite: () -> Void
    var backgroundOnly: () -> Void
    @State private var hovering = false
    @State private var hoverToken = 0
    @FocusState private var focused: Bool
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let radius: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Button(action: apply) {
                    Color.clear
                        .aspectRatio(1.4, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .overlay { face.allowsHitTesting(false) }
                        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                        .overlay(edge)
                        .overlay(alignment: .bottomTrailing) { check }
                        .shadow(color: Color.black.opacity(hovering ? 0.18 : 0.07), radius: hovering ? 10 : 4, y: hovering ? 5 : 2)
                        .scaleEffect(hovering && !reduceMotion ? 1.03 : 1)
                        .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                }
                .buttonStyle(PressFadeButtonStyle())
                .focused($focused)
                .help(recipe.summary)
                .accessibilityLabel("\(recipe.name) recipe. \(recipe.summary)")
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
                    .padding(5)
                    .help(favourite ? "Remove from Favourites" : "Add to Favourites")
                    .accessibilityHidden(true)
                    .transition(.opacity)
                }
            }
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(recipe.name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(ShotliGlass.ink(colorScheme))
                        .lineLimit(1)
                    if edited {
                        Circle()
                            .fill(ShotliGlass.accent)
                            .frame(width: 5, height: 5)
                            .help("Edited since you applied it")
                    }
                }
                Text(recipe.summary)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 2)
        }
        .onHover(perform: hover)
        .animation(reduceMotion ? nil : .easeOut(duration: ShotliGlass.duration), value: hovering)
        .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.75), value: active)
        .contextMenu {
            Button("Apply Recipe", action: apply)
            Button("Use Background Only", action: backgroundOnly)
            Divider()
            Button(favourite ? "Remove from Favourites" : "Add to Favourites", action: toggleFavourite)
        }
    }

    @ViewBuilder
    private var face: some View {
        if let thumb {
            Image(nsImage: thumb)
                .resizable()
                .scaledToFill()
                .transition(.opacity)
        } else {
            // While the render is on its way, show the background on its own.
            BackgroundSwatch(background: recipe.background)
                .overlay(ProgressView().controlSize(.small).opacity(0.6))
        }
    }

    private func hover(_ on: Bool) {
        hovering = on
        hoverToken += 1
        let token = hoverToken
        if on {
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
