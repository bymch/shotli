import AppKit

struct LayerBox: Equatable {
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat
    var radius: CGFloat
    var shadow: CGFloat
}

struct ShotLayer: Identifiable, Equatable {
    var id: String
    var image: CGImage
    var name: String
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat
    var radius: CGFloat
    var shadow: CGFloat
    var order: Int
    var sourceRelative: String?
    var sourceSHA: String?
    var sourceData: Data?
    var sourceFileName: String?

    static func == (lhs: ShotLayer, rhs: ShotLayer) -> Bool {
        lhs.id == rhs.id
            && lhs.name == rhs.name
            && lhs.x == rhs.x
            && lhs.y == rhs.y
            && lhs.width == rhs.width
            && lhs.height == rhs.height
            && lhs.radius == rhs.radius
            && lhs.shadow == rhs.shadow
            && lhs.order == rhs.order
            && lhs.sourceRelative == rhs.sourceRelative
            && lhs.image === rhs.image
    }
}

struct LayerSlot {
    var id: String
    var slot: CGRect
    var fitted: CGRect
}

enum ShotLayoutID: String, CaseIterable, Identifiable {
    case sideBySide = "side-by-side"
    case stacked
    case overlappingCards = "overlapping-cards"
    case foregroundBackground = "foreground-background"
    case comparison
    case offsetPair = "offset-pair"
    case grid
    case collage
    case layeredStack = "layered-stack"
    case threePanel = "three-panel"
    case presentationBoard = "presentation-board"

    var id: String { rawValue }
}

struct ShotLayoutPreset: Identifiable, Equatable {
    var id: ShotLayoutID
    var name: String
    var minimum: Int
    var maximum: Int
    var detail: String
}

enum ShotLayouts {
    static let maximum = 6

    static let all: [ShotLayoutPreset] = [
        ShotLayoutPreset(id: .sideBySide, name: "Side by Side", minimum: 2, maximum: 2, detail: "Two pictures, equal columns"),
        ShotLayoutPreset(id: .stacked, name: "Stacked", minimum: 2, maximum: 2, detail: "Two pictures, one above the other"),
        ShotLayoutPreset(id: .overlappingCards, name: "Overlapping Cards", minimum: 2, maximum: 2, detail: "Two cards, the second in front"),
        ShotLayoutPreset(id: .foregroundBackground, name: "Foreground and Background", minimum: 2, maximum: 2, detail: "A small picture over a larger one"),
        ShotLayoutPreset(id: .comparison, name: "Comparison", minimum: 2, maximum: 2, detail: "Two pictures with a clear gap"),
        ShotLayoutPreset(id: .offsetPair, name: "Offset Pair", minimum: 2, maximum: 2, detail: "The second picture sits up and to the right"),
        ShotLayoutPreset(id: .grid, name: "Grid", minimum: 3, maximum: maximum, detail: "Equal cells for every picture"),
        ShotLayoutPreset(id: .collage, name: "Collage", minimum: 3, maximum: maximum, detail: "One large picture, the rest beside it"),
        ShotLayoutPreset(id: .layeredStack, name: "Layered Stack", minimum: 3, maximum: maximum, detail: "Pictures stacked with a small offset"),
        ShotLayoutPreset(id: .threePanel, name: "Three-Panel", minimum: 3, maximum: 3, detail: "Three equal columns"),
        ShotLayoutPreset(id: .presentationBoard, name: "Presentation Board", minimum: 3, maximum: maximum, detail: "One large picture, the rest along the bottom"),
    ]

    static func choices(for count: Int) -> [ShotLayoutPreset] {
        all.filter { count >= $0.minimum && count <= $0.maximum }
    }

    static func preset(id: String?, count: Int) -> ShotLayoutPreset? {
        guard let id, let kind = ShotLayoutID(rawValue: id) else { return nil }
        return choices(for: count).first { $0.id == kind }
    }

    static func boxes(_ id: ShotLayoutID, count: Int, gap: CGFloat) -> [LayerBox] {
        guard let preset = all.first(where: { $0.id == id }), count >= preset.minimum, count <= preset.maximum else { return [] }
        let g = min(0.08, max(0.02, gap))
        switch id {
        case .sideBySide:
            let width = (1 - g * 3) / 2
            let height: CGFloat = 0.78
            let y = (1 - height) / 2
            return [box(g, y, width, height), box(g * 2 + width, y, width, height)]
        case .stacked:
            let height = (1 - g * 3) / 2
            let width: CGFloat = 0.72
            let x = (1 - width) / 2
            return [box(x, g, width, height), box(x, g * 2 + height, width, height)]
        case .overlappingCards:
            return [
                box(0.06, 0.14, 0.58, 0.70, radius: 20, shadow: 18),
                box(0.34, 0.20, 0.58, 0.70, radius: 20, shadow: 36),
            ]
        case .foregroundBackground:
            return [
                box(0.08, 0.18, 0.80, 0.68, radius: 16, shadow: 14),
                box(0.34, 0.08, 0.46, 0.50, radius: 18, shadow: 40),
            ]
        case .comparison:
            let gutter = max(g, 0.07)
            let width = (1 - gutter * 3) / 2
            let height: CGFloat = 0.70
            let y = (1 - height) / 2
            return [
                box(gutter, y, width, height, radius: 8, shadow: 12),
                box(gutter * 2 + width, y, width, height, radius: 8, shadow: 12),
            ]
        case .offsetPair:
            return [
                box(0.05, 0.24, 0.60, 0.62, radius: 16, shadow: 16),
                box(0.32, 0.08, 0.60, 0.62, radius: 16, shadow: 34),
            ]
        case .grid:
            return grid(count: count, gap: g)
        case .collage:
            return collage(count: count, gap: g)
        case .layeredStack:
            return stack(count: count)
        case .threePanel:
            let width = (1 - g * 4) / 3
            let height: CGFloat = 0.76
            let y = (1 - height) / 2
            return (0..<3).map { index in
                box(g + CGFloat(index) * (width + g), y, width, height, radius: 12, shadow: 18)
            }
        case .presentationBoard:
            return board(count: count, gap: g)
        }
    }

    static func check() -> String? {
        if !choices(for: 1).isEmpty { return "one screenshot offered a multi layout" }
        let two = choices(for: 2).map(\.name)
        if two != ["Side by Side", "Stacked", "Overlapping Cards", "Foreground and Background", "Comparison", "Offset Pair"] {
            return "two-screenshot layouts"
        }
        let three = choices(for: 3).map(\.name)
        if three != ["Grid", "Collage", "Layered Stack", "Three-Panel", "Presentation Board"] {
            return "three-screenshot layouts"
        }
        if choices(for: 4).contains(where: { $0.id == .threePanel || $0.id == .sideBySide }) {
            return "a layout was offered for the wrong count"
        }
        if preset(id: ShotLayoutID.sideBySide.rawValue, count: 1) != nil { return "side by side accepted one screenshot" }
        if preset(id: ShotLayoutID.grid.rawValue, count: 2) != nil { return "grid accepted two screenshots" }
        if preset(id: ShotLayoutID.grid.rawValue, count: 3) == nil { return "grid refused three screenshots" }
        let side = boxes(.sideBySide, count: 2, gap: 0.04)
        if side.count != 2 || side[0].x + side[0].width > side[1].x + 0.001 { return "side by side overlapped" }
        let stacked = boxes(.stacked, count: 2, gap: 0.04)
        if stacked.count != 2 || stacked[0].y + stacked[0].height > stacked[1].y + 0.001 { return "stacked overlapped" }
        if !intersects(boxes(.overlappingCards, count: 2, gap: 0.04)) { return "overlapping cards stayed apart" }
        if !intersects(boxes(.offsetPair, count: 2, gap: 0.04)) { return "offset pair stayed apart" }
        if boxes(.sideBySide, count: 1, gap: 0.04).isEmpty == false { return "side by side ignored the count" }
        for count in 2...maximum {
            for preset in choices(for: count) {
                let frames = boxes(preset.id, count: count, gap: 0.04)
                if frames.count != count { return "\(preset.name) placed \(frames.count) of \(count)" }
                for frame in frames {
                    if frame.x < -0.001 || frame.y < -0.001 || frame.x + frame.width > 1.001 || frame.y + frame.height > 1.001 {
                        return "\(preset.name) left the canvas"
                    }
                    if frame.width < 0.05 || frame.height < 0.05 { return "\(preset.name) collapsed a picture" }
                }
            }
        }
        return nil
    }

    private static func intersects(_ frames: [LayerBox]) -> Bool {
        guard frames.count == 2 else { return false }
        let a = CGRect(x: frames[0].x, y: frames[0].y, width: frames[0].width, height: frames[0].height)
        let b = CGRect(x: frames[1].x, y: frames[1].y, width: frames[1].width, height: frames[1].height)
        return a.intersects(b)
    }

    private static func grid(count: Int, gap: CGFloat) -> [LayerBox] {
        let columns = max(1, Int(ceil(sqrt(Double(count)))))
        let rows = max(1, Int(ceil(Double(count) / Double(columns))))
        let width = (1 - gap * CGFloat(columns + 1)) / CGFloat(columns)
        let height = (1 - gap * CGFloat(rows + 1)) / CGFloat(rows)
        return (0..<count).map { index in
            let column = index % columns
            let row = index / columns
            return box(
                gap + CGFloat(column) * (width + gap),
                gap + CGFloat(row) * (height + gap),
                width,
                height,
                radius: 12,
                shadow: 16
            )
        }
    }

    private static func collage(count: Int, gap: CGFloat) -> [LayerBox] {
        let rest = max(1, count - 1)
        let left = CGFloat(0.56)
        let right = 1 - gap * 3 - left
        let height = (1 - gap * CGFloat(rest + 1)) / CGFloat(rest)
        var frames = [box(gap, gap, left, 1 - gap * 2, radius: 16, shadow: 28)]
        for index in 0..<rest {
            frames.append(box(gap * 2 + left, gap + CGFloat(index) * (height + gap), right, height, radius: 12, shadow: 14))
        }
        return frames
    }

    private static func stack(count: Int) -> [LayerBox] {
        let step = min(0.07, 0.32 / CGFloat(max(count, 1)))
        return (0..<count).map { index in
            let shift = step * CGFloat(index)
            return box(0.16 + shift, 0.10 + shift, 0.56, 0.60, radius: 18, shadow: 12 + CGFloat(index) * 6)
        }
    }

    private static func board(count: Int, gap: CGFloat) -> [LayerBox] {
        let rest = max(1, count - 1)
        let hero = CGFloat(0.58)
        let row = 1 - gap * 3 - hero
        let width = (1 - gap * CGFloat(rest + 1)) / CGFloat(rest)
        var frames = [box(gap, gap, 1 - gap * 2, hero, radius: 16, shadow: 24)]
        for index in 0..<rest {
            frames.append(box(gap + CGFloat(index) * (width + gap), gap * 2 + hero, width, row, radius: 10, shadow: 12))
        }
        return frames
    }

    private static func box(
        _ x: CGFloat,
        _ y: CGFloat,
        _ width: CGFloat,
        _ height: CGFloat,
        radius: CGFloat = 18,
        shadow: CGFloat = 28
    ) -> LayerBox {
        let w = min(0.96, max(0.08, width))
        let h = min(0.96, max(0.08, height))
        return LayerBox(
            x: min(max(0, x), 1 - w),
            y: min(max(0, y), 1 - h),
            width: w,
            height: h,
            radius: radius,
            shadow: shadow
        )
    }
}

func layerContentBox(canvas: CGSize, style: ShotliStyle, picture: LoadedPicture?) -> CGRect {
    let span = picture.map { max($0.width, $0.height) } ?? max(canvas.width, canvas.height)
    let pad = stagePad(style, span: span)
    return CGRect(x: pad, y: pad, width: max(1, canvas.width - pad * 2), height: max(1, canvas.height - pad * 2))
}

func layerSlots(layers: [ShotLayer], canvas: CGSize, style: ShotliStyle, picture: LoadedPicture?, crop: CGRect?) -> [LayerSlot] {
    let box = layerContentBox(canvas: canvas, style: style, picture: picture)
    let primary = layers.first?.id
    return layers.map { layer in
        let slot = CGRect(
            x: box.minX + layer.x * box.width,
            y: box.minY + layer.y * box.height,
            width: max(8, layer.width * box.width),
            height: max(8, layer.height * box.height)
        )
        let pixels = layerPixelSize(layer, primaryID: primary, picture: picture, crop: crop)
        return LayerSlot(id: layer.id, slot: slot, fitted: aspectFitRect(pixels, in: slot))
    }
}

func aspectFitRect(_ pixel: CGSize, in rect: CGRect) -> CGRect {
    guard pixel.width > 0, pixel.height > 0, rect.width > 0, rect.height > 0 else { return rect }
    let aspect = pixel.width / pixel.height
    let box = rect.width / max(rect.height, 0.001)
    var size = rect.size
    if aspect > box {
        size.height = rect.width / aspect
    } else {
        size.width = rect.height * aspect
    }
    return CGRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2, width: size.width, height: size.height)
}

func layerPixelSize(_ layer: ShotLayer, primaryID: String?, picture: LoadedPicture?, crop: CGRect?) -> CGSize {
    if layer.id == primaryID, let visible = activeCrop(picture: picture, crop: crop) {
        return CGSize(width: visible.width, height: visible.height)
    }
    return CGSize(width: CGFloat(layer.image.width), height: CGFloat(layer.image.height))
}
