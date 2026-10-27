import AppKit
import CoreImage

private let sharedCIContext = CIContext(options: nil)

func renderComposition(
    picture: LoadedPicture?,
    crop: CGRect?,
    style: ShotliStyle,
    annotations: [Annotation],
    draft: Annotation?,
    interactive: Bool,
    cropDraft: CGRect? = nil,
    selectedID: String? = nil,
    omitBackground: Bool = false
) -> CGImage? {
    guard let picture else { return nil }
    let layout = composition(picture: picture, crop: crop, style: style)
    let tilted = !style.hideMockup && (abs(style.tiltX) > 0.4 || abs(style.tiltY) > 0.4)
    if tilted, let context = bitmapContext(layout.size) {
        let painter = Painter(context: context, height: layout.size.height)
        if !omitBackground {
            painter.drawBackground(style.background, layout.size)
        }
        let placed = shiftedCardLayout(layout)
        if let layer = renderFlat(
            picture: picture, crop: crop, style: style, annotations: annotations, draft: draft,
            interactive: interactive, cropDraft: cropDraft, selectedID: selectedID,
            layout: placed.layout, paintBackground: false
        ) {
            let warped = warpCard(layer, tiltX: style.tiltX, tiltY: style.tiltY)
            let dest = CGRect(
                x: layout.window.minX - placed.margin,
                y: layout.window.minY - placed.margin,
                width: CGFloat(warped.width),
                height: CGFloat(warped.height)
            )
            context.draw(warped, in: painter.cg(dest))
        }
        return context.makeImage()
    }
    return renderFlat(
        picture: picture, crop: crop, style: style, annotations: annotations, draft: draft,
        interactive: interactive, cropDraft: cropDraft, selectedID: selectedID,
        layout: layout, paintBackground: !omitBackground
    )
}

func renderBackdrop(_ background: Background, size: CGSize) -> CGImage? {
    guard let context = bitmapContext(size) else { return nil }
    Painter(context: context, height: size.height).drawBackground(background, size)
    return context.makeImage()
}

/// Background for the editor stage. The picture can shrink, and this keeps the same colour filling the view.
func renderStageBackdrop(background: Background, canvas: CGSize, dest: CGRect, viewSize: CGSize, screen: CGFloat) -> CGImage? {
    guard canvas.width > 1, canvas.height > 1, viewSize.width > 1, viewSize.height > 1, dest.width > 1, dest.height > 1 else { return nil }
    let scaleX = dest.width / canvas.width
    let scaleY = dest.height / canvas.height
    guard scaleX > 0, scaleY > 0, scaleX.isFinite, scaleY.isFinite else { return nil }
    let pixelScale = max(1, screen)
    let pixels = CGSize(width: max(1, viewSize.width * pixelScale), height: max(1, viewSize.height * pixelScale))
    guard let context = bitmapContext(pixels) else { return nil }
    let region = CGRect(
        x: -dest.minX / scaleX,
        y: -dest.minY / scaleY,
        width: viewSize.width / scaleX,
        height: viewSize.height / scaleY
    )
    context.scaleBy(x: pixelScale, y: pixelScale)
    context.translateBy(x: dest.minX, y: viewSize.height - dest.maxY)
    context.scaleBy(x: scaleX, y: scaleY)
    Painter(context: context, height: canvas.height).drawBackground(background, canvas, cover: region)
    return context.makeImage()
}

func warpMotionCard(_ image: CGImage, tiltX: CGFloat, tiltY: CGFloat) -> CGImage {
    if abs(tiltX) < 0.15, abs(tiltY) < 0.15 { return image }
    return warpCard(image, tiltX: tiltX, tiltY: tiltY)
}

private func renderFlat(
    picture: LoadedPicture,
    crop: CGRect?,
    style: ShotliStyle,
    annotations: [Annotation],
    draft: Annotation?,
    interactive: Bool,
    cropDraft: CGRect?,
    selectedID: String?,
    layout: Composition,
    paintBackground: Bool
) -> CGImage? {
    guard let context = bitmapContext(layout.size) else { return nil }
    let painter = Painter(context: context, height: layout.size.height)
    let cropRect = activeCrop(picture: picture, crop: crop) ?? .zero
    var style = style
    let span = min(layout.image.width, layout.image.height)
    style.radius = cornerRadius(style.radius, span: span)
    let radius = style.radius

    func paintMarks() {
        let all = draft == nil ? annotations : annotations + [draft!]
        for annotation in all {
            if case .shape(let mark) = annotation, mark.kind == .pixelate || mark.kind == .blur {
                painter.drawRedaction(picture.image, mark, layout: layout, crop: cropRect)
            }
        }
        for annotation in all {
            if case .shape(let mark) = annotation, mark.kind == .pixelate || mark.kind == .blur { continue }
            painter.drawAnnotation(annotation, layout: layout, crop: cropRect)
        }
        if interactive, let cropDraft {
            painter.drawCropOverlay(visible: cropRect, draft: cropDraft, layout: layout)
        }
        if interactive, let selectedID, let selected = all.first(where: { $0.id == selectedID }), selected.id != draft?.id {
            painter.drawSelection(selected, layout: layout, crop: cropRect)
        }
    }

    if style.hideMockup {
        painter.drawImage(picture.image, crop: cropRect, dest: layout.image)
        painter.applyLight(style.light, rect: layout.image)
        paintMarks()
        return context.makeImage()
    }

    if paintBackground {
        painter.drawBackground(style.background, layout.size)
    }
    context.saveGState()
    painter.applyStyledShadow(style, tint: adaptiveTint(picture.image))
    painter.paintCard(layout.window, style: style)
    context.restoreGState()

    if style.frame == .browser {
        painter.drawBrowserChrome(layout.window, radius: radius, name: picture.name)
    } else if style.frame == .desktop {
        painter.drawDesktopChrome(layout.window, radius: radius, name: picture.name)
    }

    context.saveGState()
    painter.clipRound(layout.window, radius: radius)
    if style.frame == .none {
        let inner = max(0, radius - cardRim(style))
        painter.clipRound(layout.image, radius: inner)
    } else {
        context.clip(to: painter.cg(layout.image))
    }
    painter.drawImage(picture.image, crop: cropRect, dest: layout.image)
    painter.applyLight(style.light, rect: layout.image)
    paintMarks()
    context.restoreGState()
    painter.paintCardEdge(layout.window, style: style)
    return context.makeImage()
}

private func bitmapContext(_ size: CGSize) -> CGContext? {
    let width = Int(ceil(size.width))
    let height = Int(ceil(size.height))
    guard width > 0, height > 0 else { return nil }
    return CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )
}

private func shiftedCardLayout(_ layout: Composition) -> (layout: Composition, margin: CGFloat) {
    let margin = tiltMargin(max(layout.window.width, layout.window.height))
    let dx = margin - layout.window.minX
    let dy = margin - layout.window.minY
    return (
        Composition(
            image: layout.image.offsetBy(dx: dx, dy: dy),
            window: layout.window.offsetBy(dx: dx, dy: dy),
            size: CGSize(width: layout.window.width + margin * 2, height: layout.window.height + margin * 2)
        ),
        margin
    )
}

private func warpCard(_ image: CGImage, tiltX: CGFloat, tiltY: CGFloat) -> CGImage {
    let input = CIImage(cgImage: image)
    let width = input.extent.width
    let height = input.extent.height
    guard width > 2, height > 2, let filter = CIFilter(name: "CIPerspectiveTransform") else { return image }
    let yaw = tiltY * .pi / 180
    let pitch = tiltX * .pi / 180
    let yawPull = sin(abs(yaw)) * width * 0.2
    let pitchPull = sin(abs(pitch)) * height * 0.14
    var topLeft = CGPoint(x: 0, y: height)
    var topRight = CGPoint(x: width, y: height)
    var bottomLeft = CGPoint(x: 0, y: 0)
    var bottomRight = CGPoint(x: width, y: 0)
    if tiltY > 0 {
        topRight.x -= yawPull
        bottomRight.x -= yawPull
        topRight.y -= height * 0.035 * sin(abs(yaw))
        bottomRight.y += height * 0.035 * sin(abs(yaw))
    } else if tiltY < 0 {
        topLeft.x += yawPull
        bottomLeft.x += yawPull
        topLeft.y -= height * 0.035 * sin(abs(yaw))
        bottomLeft.y += height * 0.035 * sin(abs(yaw))
    }
    if tiltX > 0 {
        topLeft.y -= pitchPull
        topRight.y -= pitchPull
        topLeft.x += width * 0.025 * sin(abs(pitch))
        topRight.x -= width * 0.025 * sin(abs(pitch))
    } else if tiltX < 0 {
        bottomLeft.y += pitchPull
        bottomRight.y += pitchPull
        bottomLeft.x += width * 0.02 * sin(abs(pitch))
        bottomRight.x -= width * 0.02 * sin(abs(pitch))
    }
    filter.setValue(input, forKey: kCIInputImageKey)
    filter.setValue(CIVector(cgPoint: topLeft), forKey: "inputTopLeft")
    filter.setValue(CIVector(cgPoint: topRight), forKey: "inputTopRight")
    filter.setValue(CIVector(cgPoint: bottomLeft), forKey: "inputBottomLeft")
    filter.setValue(CIVector(cgPoint: bottomRight), forKey: "inputBottomRight")
    let bounds = CGRect(x: 0, y: 0, width: width, height: height)
    guard let output = filter.outputImage, let rendered = sharedCIContext.createCGImage(output, from: bounds) else { return image }
    return rendered
}

private enum SceneOp {
    case vertical([(CGFloat, String)])
    case glow(CGFloat, CGFloat, CGFloat, String, CGFloat)
    case disc(CGFloat, CGFloat, CGFloat, String)
    case hill(CGFloat, CGFloat, CGFloat, CGFloat, String)
    case band(CGFloat, CGFloat, CGFloat, CGFloat, String, CGFloat, CGFloat)
    case oval(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, String, CGFloat)
    case ring(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, String, CGFloat)
    case stars
    case vignette(String, CGFloat)
}

private struct Painter {
    let context: CGContext
    let height: CGFloat

    func cg(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.minX, y: height - rect.maxY, width: rect.width, height: rect.height)
    }

    func cg(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x, y: height - point.y)
    }

    func visual(_ point: CGPoint, layout: Composition, crop: CGRect) -> CGPoint {
        CGPoint(x: layout.image.minX + (point.x - crop.minX), y: layout.image.minY + (point.y - crop.minY))
    }

    func visual(_ rect: CGRect, layout: Composition, crop: CGRect) -> CGRect {
        CGRect(
            x: layout.image.minX + (rect.minX - crop.minX),
            y: layout.image.minY + (rect.minY - crop.minY),
            width: rect.width,
            height: rect.height
        )
    }

    func drawBackground(_ background: Background, _ size: CGSize) {
        drawBackground(background, size, cover: CGRect(origin: .zero, size: size))
    }

    func drawBackground(_ background: Background, _ size: CGSize, cover: CGRect) {
        let area = CGRect(origin: .zero, size: size).union(cover)
        switch background {
        case .color(let hex):
            if hex == "transparent" {
                drawChecker(area)
                return
            }
            context.setFillColor(paint(hex))
            context.fill(cg(area))
        case .gradient(let from, let mid, let to, let angle):
            let radians = (angle - 90) * .pi / 180
            let length = abs(size.width * cos(radians)) + abs(size.height * sin(radians))
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let delta = CGPoint(x: cos(radians) * length / 2, y: sin(radians) * length / 2)
            var stops = [paint(from), paint(to)]
            var locations: [CGFloat] = [0, 1]
            if let mid {
                stops.insert(paint(mid), at: 1)
                locations = [0, 0.5, 1]
            }
            let colors = stops as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations) else { return }
            let extends = area.width > size.width + 0.5 || area.height > size.height + 0.5 || area.minX < -0.5 || area.minY < -0.5
            let options: CGGradientDrawingOptions = extends ? [.drawsBeforeStartLocation, .drawsAfterEndLocation] : []
            context.drawLinearGradient(gradient, start: cg(CGPoint(x: center.x - delta.x, y: center.y - delta.y)), end: cg(CGPoint(x: center.x + delta.x, y: center.y + delta.y)), options: options)
        case .wallpaper(let id):
            if let base = wallpaperBase(id) {
                context.setFillColor(paint(base))
                context.fill(cg(area))
            }
            drawWallpaper(id, size)
        }
    }

    func wallpaperBase(_ id: WallpaperID) -> String? {
        switch id {
        case .dots: return "#E8E6E3"
        case .grid: return "#F7F7F7"
        case .diagonal: return "#EEF2FF"
        case .stripes: return "#F4F1EC"
        case .mesh: return "#F6F7F8"
        case .cross: return "#F4F7FB"
        default: return nil
        }
    }

    func drawChecker(_ area: CGRect) {
        context.setFillColor(NSColor.white.cgColor)
        context.fill(cg(area))
        context.setFillColor(NSColor(srgbRed: 0.925, green: 0.925, blue: 0.925, alpha: 1).cgColor)
        let step: CGFloat = 12
        var y = floor(area.minY / step) * step
        while y < area.maxY {
            let row = Int(floor(y / step))
            let odd = ((row % 2) + 2) % 2 == 1
            var x = floor(area.minX / (step * 2)) * (step * 2) + (odd ? step : 0)
            while x < area.maxX {
                context.fill(cg(CGRect(x: x, y: y, width: step, height: step)))
                x += step * 2
            }
            y += step
        }
    }

    func drawWallpaper(_ id: WallpaperID, _ size: CGSize) {
        switch id {
        case .dots:
            context.setFillColor(paint("#E8E6E3"))
            context.fill(CGRect(origin: .zero, size: size))
            context.setFillColor(paint("#C9C5BF"))
            var y: CGFloat = 9
            while y < size.height {
                var x: CGFloat = 9
                while x < size.width {
                    context.fillEllipse(in: cg(CGRect(x: x - 1.2, y: y - 1.2, width: 2.4, height: 2.4)))
                    x += 18
                }
                y += 18
            }
        case .grid:
            context.setFillColor(paint("#F7F7F7"))
            context.fill(CGRect(origin: .zero, size: size))
            context.setStrokeColor(paint("#E4E4E4"))
            context.setLineWidth(1)
            var y: CGFloat = 0
            while y < size.height {
                context.move(to: cg(CGPoint(x: 0, y: y)))
                context.addLine(to: cg(CGPoint(x: size.width, y: y)))
                y += 18
            }
            var x: CGFloat = 0
            while x < size.width {
                context.move(to: cg(CGPoint(x: x, y: 0)))
                context.addLine(to: cg(CGPoint(x: x, y: size.height)))
                x += 18
            }
            context.strokePath()
        case .diagonal:
            context.setFillColor(paint("#EEF2FF"))
            context.fill(CGRect(origin: .zero, size: size))
            context.setStrokeColor(paint("#D9E2FF"))
            context.setLineWidth(1)
            var offset: CGFloat = -size.height
            while offset < size.width {
                context.move(to: cg(CGPoint(x: offset, y: size.height)))
                context.addLine(to: cg(CGPoint(x: offset + size.height, y: 0)))
                offset += 16
            }
            context.strokePath()
        case .stripes:
            context.setFillColor(paint("#F4F1EC"))
            context.fill(CGRect(origin: .zero, size: size))
            context.setFillColor(paint("#EBE4D8"))
            var y: CGFloat = 0
            while y < size.height {
                context.fill(cg(CGRect(x: 0, y: y, width: size.width, height: 8)))
                y += 16
            }
        case .mesh:
            context.setFillColor(paint("#F6F7F8"))
            context.fill(CGRect(origin: .zero, size: size))
            let blobs: [(CGFloat, CGFloat, String)] = [(0.2, 0.2, "#FDE2E4"), (0.82, 0.18, "#DBEAFE"), (0.55, 0.85, "#D1FAE5"), (0.1, 0.75, "#FEF3C7")]
            for blob in blobs {
                let center = CGPoint(x: size.width * blob.0, y: size.height * blob.1)
                let radius = max(size.width, size.height) * 0.45
                let colors = [paint(blob.2, alpha: 0.95), paint(blob.2, alpha: 0)] as CFArray
                guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) else { continue }
                context.drawRadialGradient(gradient, startCenter: cg(center), startRadius: 0, endCenter: cg(center), endRadius: radius, options: [])
            }
        case .cross:
            context.setFillColor(paint("#F4F7FB"))
            context.fill(CGRect(origin: .zero, size: size))
            context.setStrokeColor(paint("#DBE3F0"))
            context.setLineWidth(1)
            var y: CGFloat = 0
            while y < size.height {
                context.move(to: cg(CGPoint(x: 0, y: y)))
                context.addLine(to: cg(CGPoint(x: size.width, y: y)))
                y += 18
            }
            var x: CGFloat = 0
            while x < size.width {
                context.move(to: cg(CGPoint(x: x, y: 0)))
                context.addLine(to: cg(CGPoint(x: x, y: size.height)))
                x += 18
            }
            context.strokePath()
        default:
            drawScene(id, size)
        }
    }

    func drawScene(_ id: WallpaperID, _ size: CGSize) {
        if SceneLibrary.render(id, painter: self, size: size) { return }
        switch id {
        case .dusk:
            vertical(size, [(0, "#FF8A5B"), (0.42, "#F6B7C5"), (0.72, "#7C6BD4"), (1, "#2A2148")])
            glow(size, 0.22, 0.62, 0.42, "#FFB088", 0.95)
            disc(size, 0.22, 0.6, 0.055, "#FFE1C4")
            skyline(size, size.height, "#1C1430", "#2C2144", "#F8E2A0", 3, 1)
        case .night:
            vertical(size, [(0, "#070B18"), (0.55, "#1A2744"), (1, "#0A0E1A")])
            stars(size)
            glow(size, 0.8, 0.16, 0.22, "#D7E2FF", 0.45)
            disc(size, 0.8, 0.16, 0.04, "#F7F3E8")
            skyline(size, size.height, "#070910", "#141A28", "#FFE08A", 4, 2)
        case .harbour:
            drawHarbour(size)
        case .hills:
            vertical(size, [(0, "#FFD7C2"), (0.45, "#F7A58A"), (1, "#E7C4EE")])
            glow(size, 0.72, 0.3, 0.28, "#FFE7C2", 0.9)
            disc(size, 0.72, 0.3, 0.05, "#FFF6E8")
            hill(size, 0.58, 0.06, 1.4, 0.4, "#C47B9B")
            hill(size, 0.7, 0.05, 1.8, 1.7, "#8E5A78")
            hill(size, 0.84, 0.045, 1.2, 0.2, "#3D2A3E")
        case .aurora:
            vertical(size, [(0, "#07111F"), (0.6, "#10243A"), (1, "#071018")])
            stars(size)
            glow(size, 0.28, 0.42, 0.5, "#5EEAD4", 0.55)
            glow(size, 0.72, 0.36, 0.48, "#A78BFA", 0.5)
            glow(size, 0.5, 0.55, 0.36, "#34D399", 0.35)
            band(size, 0.34, 0.07, 1.6, 0.4, "#5EEAD4", 0.16, 0.55)
            band(size, 0.46, 0.08, 1.3, 2.1, "#67E8F9", 0.14, 0.4)
            band(size, 0.4, 0.06, 2.1, 1.1, "#C4B5FD", 0.12, 0.45)
            hill(size, 0.86, 0.035, 1.5, 0.6, "#071018")
        case .sorbet:
            vertical(size, [(0, "#FFE4E6"), (0.5, "#FFF6E8"), (1, "#E0F2FE")])
            glow(size, 0.16, 0.22, 0.55, "#FB7185", 0.9)
            glow(size, 0.8, 0.16, 0.5, "#C4B5FD", 0.92)
            glow(size, 0.58, 0.78, 0.55, "#6EE7B7", 0.85)
            glow(size, 0.18, 0.76, 0.42, "#FDE68A", 0.8)
            glow(size, 0.86, 0.62, 0.4, "#7DD3FC", 0.75)
            glow(size, 0.46, 0.4, 0.32, "#F9A8D4", 0.7)
        case .studio:
            vertical(size, [(0, "#E7E9EF"), (0.48, "#C9CED8"), (1, "#B4BAC6")])
            glow(size, 0.4, 0.36, 0.42, "#FFFFFF", 1)
            glow(size, 0.72, 0.12, 0.28, "#F4F6FA", 0.75)
            vignette(size, "#5C6270", 0.5)
        case .porcelain:
            vertical(size, [(0, "#F3E6D8"), (0.5, "#E4D0BC"), (1, "#CDB49C")])
            glow(size, 0.55, 0.3, 0.4, "#FFF8F1", 0.96)
            vignette(size, "#8C7058", 0.38)
        case .bloom:
            vertical(size, [(0, "#FFD8C4"), (1, "#FF8B6C")])
            glow(size, 0.14, 0.42, 0.55, "#FF5418", 0.95)
            glow(size, 0.84, 0.28, 0.5, "#FF4D8D", 0.92)
            glow(size, 0.52, 0.78, 0.46, "#FFC48A", 0.88)
            glow(size, 0.4, 0.18, 0.28, "#FFE7A8", 0.7)
        case .tide:
            vertical(size, [(0, "#8FD4FF"), (0.46, "#4C6BFF"), (1, "#7A4DFF")])
            glow(size, 0.55, 0.42, 0.4, "#EAF4FF", 0.55)
            glow(size, 0.18, 0.2, 0.38, "#5CE1FF", 0.72)
            glow(size, 0.86, 0.74, 0.38, "#C084FC", 0.68)
        case .sand:
            vertical(size, [(0, "#F8E6D0"), (0.58, "#E6C6A0"), (1, "#C9A078")])
            glow(size, 0.4, 0.26, 0.5, "#FFF6EA", 0.88)
            glow(size, 0.8, 0.72, 0.34, "#E09A68", 0.42)
        case .ink:
            vertical(size, [(0, "#1A1D27"), (1, "#0B0D13")])
            glow(size, 0.48, 0.34, 0.46, "#3A4258", 0.92)
            glow(size, 0.5, 0.3, 0.16, "#F4F6FB", 0.38)
            glow(size, 0.14, 0.8, 0.3, "#243056", 0.85)
        case .citrus:
            vertical(size, [(0, "#FFE58A"), (0.5, "#FF8A3D"), (1, "#FF5D73")])
            glow(size, 0.28, 0.28, 0.46, "#FFF3B0", 0.92)
            glow(size, 0.76, 0.66, 0.4, "#FF4D6A", 0.75)
        case .glacier:
            vertical(size, [(0, "#F5FBFF"), (0.5, "#D5E6FF"), (1, "#E6DCF8")])
            glow(size, 0.32, 0.26, 0.48, "#FFFFFF", 0.95)
            glow(size, 0.8, 0.72, 0.4, "#B7C6FF", 0.55)
            glow(size, 0.14, 0.8, 0.32, "#C8F3EA", 0.5)
        case .clay:
            vertical(size, [(0, "#F6D6C6"), (0.55, "#E08970"), (1, "#8C3E3A")])
            glow(size, 0.34, 0.3, 0.42, "#FFD8C2", 0.82)
            glow(size, 0.76, 0.62, 0.34, "#C4504A", 0.55)
        case .moss:
            vertical(size, [(0, "#D7E7C8"), (0.45, "#3E7A55"), (1, "#143028")])
            glow(size, 0.3, 0.28, 0.42, "#E7F5C8", 0.78)
            glow(size, 0.74, 0.64, 0.34, "#1F6B4A", 0.62)
        default:
            context.setFillColor(paint("#E7E5E4"))
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    func drawHarbour(_ size: CGSize) {
        let ground = size.height * 0.58
        vertical(size, [(0, "#F3C7A2"), (0.4, "#8EADD4"), (1, "#1B3A5C")])
        context.saveGState()
        context.clip(to: cg(CGRect(x: 0, y: ground, width: size.width, height: size.height - ground)))
        let colors = [paint("#245074"), paint("#0E2438")] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
            context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: height - ground), end: CGPoint(x: 0, y: 0), options: [])
        }
        context.restoreGState()
        glow(size, 0.7, 0.42, 0.24, "#F8D7B0", 0.8)
        disc(size, 0.7, 0.4, 0.035, "#FFF1DE")
        skyline(size, ground, "#101820", "#1C2A3A", "#F6E7B2", 4, 3)
        context.saveGState()
        context.setAlpha(0.32)
        reflectSkyline(size, ground, "#101820", "#1C2A3A")
        context.restoreGState()
        context.setFillColor(paint("#0E2438", alpha: 0.28))
        var y = ground + 6
        var index = 0
        while y < size.height {
            context.fill(cg(CGRect(x: 0, y: y, width: size.width, height: index % 2 == 0 ? 2 : 5)))
            y += 12
            index += 1
        }
        context.setFillColor(paint("#FFECD6", alpha: 0.55))
        context.fill(cg(CGRect(x: 0, y: ground - 1, width: size.width, height: 1.5)))
    }

    func vertical(_ size: CGSize, _ stops: [(CGFloat, String)]) {
        let colors = stops.map { paint($0.1) } as CFArray
        let locations = stops.map { $0.0 }
        locations.withUnsafeBufferPointer { buffer in
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: buffer.baseAddress) else { return }
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: size.width / 2, y: size.height),
                end: CGPoint(x: size.width / 2, y: 0),
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )
        }
    }

    func vignette(_ size: CGSize, _ hex: String, _ alpha: CGFloat) {
        let center = cg(CGPoint(x: size.width / 2, y: size.height / 2))
        let colors = [paint(hex, alpha: 0), paint(hex, alpha: alpha)] as CFArray
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) else { return }
        context.drawRadialGradient(
            gradient,
            startCenter: center,
            startRadius: min(size.width, size.height) * 0.28,
            endCenter: center,
            endRadius: max(size.width, size.height) * 0.72,
            options: []
        )
    }

    func glow(_ size: CGSize, _ x: CGFloat, _ y: CGFloat, _ radius: CGFloat, _ hex: String, _ alpha: CGFloat) {
        let center = cg(CGPoint(x: size.width * x, y: size.height * y))
        let r = max(size.width, size.height) * radius
        let colors = [paint(hex, alpha: alpha), paint(hex, alpha: 0)] as CFArray
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) else { return }
        context.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: r, options: [])
    }

    func disc(_ size: CGSize, _ x: CGFloat, _ y: CGFloat, _ radius: CGFloat, _ hex: String) {
        let r = min(size.width, size.height) * radius
        let center = CGPoint(x: size.width * x, y: size.height * y)
        context.setFillColor(paint(hex))
        context.fillEllipse(in: cg(CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)))
    }

    func stars(_ size: CGSize) {
        let points: [(CGFloat, CGFloat, CGFloat)] = [
            (0.06, 0.08, 1.1), (0.14, 0.16, 0.7), (0.22, 0.05, 1.3), (0.31, 0.12, 0.6),
            (0.4, 0.07, 0.9), (0.48, 0.18, 0.5), (0.57, 0.06, 1.2), (0.66, 0.14, 0.7),
            (0.74, 0.04, 0.8), (0.83, 0.11, 1.4), (0.91, 0.07, 0.6), (0.18, 0.28, 0.5),
            (0.35, 0.22, 0.4), (0.62, 0.24, 0.6), (0.88, 0.22, 0.5),
        ]
        context.setFillColor(paint("#FFFFFF", alpha: 0.88))
        for star in points {
            let r = star.2 * min(size.width, size.height) / 420
            let center = CGPoint(x: size.width * star.0, y: size.height * star.1)
            context.fillEllipse(in: cg(CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)))
        }
    }

    func towers() -> [(CGFloat, CGFloat, CGFloat)] {
        [
            (0, 0.07, 0.28), (0.07, 0.045, 0.18), (0.115, 0.1, 0.46), (0.215, 0.06, 0.26),
            (0.275, 0.05, 0.16), (0.325, 0.13, 0.38), (0.455, 0.035, 0.56), (0.49, 0.08, 0.3),
            (0.57, 0.11, 0.42), (0.68, 0.055, 0.22), (0.735, 0.09, 0.36), (0.825, 0.06, 0.2),
            (0.885, 0.115, 0.32),
        ]
    }

    func skyline(_ size: CGSize, _ ground: CGFloat, _ color: String, _ alt: String, _ light: String, _ every: Int, _ seed: Int) {
        for (index, tower) in towers().enumerated() {
            let bw = size.width * max(0.02, tower.1 - 0.012)
            let bh = size.height * tower.2
            let bx = size.width * tower.0
            let top = ground - bh
            context.setFillColor(paint(index % 2 == 0 ? color : alt))
            context.fill(cg(CGRect(x: bx, y: top, width: bw, height: bh)))
            if tower.2 > 0.4 {
                let capW = bw * 0.55
                let capH = bh * 0.12
                context.fill(cg(CGRect(x: bx + (bw - capW) / 2, y: top - capH, width: capW, height: capH)))
                context.fill(cg(CGRect(x: bx + bw / 2 - 1.2, y: top - capH - bh * 0.08, width: 2.4, height: bh * 0.08)))
            }
            windows(bx, top, bw, bh, light, every, seed)
        }
    }

    func reflectSkyline(_ size: CGSize, _ ground: CGFloat, _ color: String, _ alt: String) {
        for (index, tower) in towers().enumerated() {
            let bw = size.width * max(0.02, tower.1 - 0.012)
            let bh = size.height * tower.2 * 0.7
            let bx = size.width * tower.0
            context.setFillColor(paint(index % 2 == 0 ? color : alt))
            context.fill(cg(CGRect(x: bx, y: ground, width: bw, height: bh)))
        }
    }

    func windows(_ bx: CGFloat, _ by: CGFloat, _ bw: CGFloat, _ bh: CGFloat, _ light: String, _ every: Int, _ seed: Int) {
        let gapX = max(5, bw * 0.16)
        let gapY = max(6, gapX * 1.15)
        let winW = max(1.4, gapX * 0.42)
        let winH = winW * 1.25
        var row = 0
        var y = by + bh * 0.08
        while y + winH < by + bh - 2 {
            var col = 0
            var x = bx + bw * 0.16
            while x + winW < bx + bw * 0.88 {
                if (col * 3 + row * 5 + seed) % every == 0 {
                    context.setFillColor(paint(light, alpha: 0.92))
                    context.fill(cg(CGRect(x: x, y: y, width: winW, height: winH)))
                }
                x += gapX
                col += 1
            }
            y += gapY
            row += 1
        }
    }

    func hill(_ size: CGSize, _ base: CGFloat, _ amp: CGFloat, _ waves: CGFloat, _ phase: CGFloat, _ hex: String) {
        let path = CGMutablePath()
        let steps = 48
        for step in 0...steps {
            let t = CGFloat(step) / CGFloat(steps)
            let point = cg(CGPoint(
                x: size.width * t,
                y: size.height * base + sin(t * waves * .pi * 2 + phase) * size.height * amp
            ))
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.addLine(to: cg(CGPoint(x: size.width, y: size.height)))
        path.addLine(to: cg(CGPoint(x: 0, y: size.height)))
        path.closeSubpath()
        context.addPath(path)
        context.setFillColor(paint(hex))
        context.fillPath()
    }

    func oval(_ size: CGSize, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ rotation: CGFloat, _ hex: String, _ alpha: CGFloat) {
        context.saveGState()
        let center = cg(CGPoint(x: size.width * x, y: size.height * y))
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: rotation)
        context.setFillColor(paint(hex, alpha: alpha))
        let width = size.width * w
        let height = size.height * h
        context.fillEllipse(in: CGRect(x: -width / 2, y: -height / 2, width: width, height: height))
        context.restoreGState()
    }

    func ring(_ size: CGSize, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ rotation: CGFloat, _ hex: String, _ line: CGFloat) {
        context.saveGState()
        let center = cg(CGPoint(x: size.width * x, y: size.height * y))
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: rotation)
        context.setStrokeColor(paint(hex, alpha: 0.85))
        context.setLineWidth(max(size.width, size.height) * line)
        let width = size.width * w
        let height = size.height * h
        context.strokeEllipse(in: CGRect(x: -width / 2, y: -height / 2, width: width, height: height))
        context.restoreGState()
    }

    func play(_ op: SceneOp, _ size: CGSize) {
        switch op {
        case .vertical(let stops):
            vertical(size, stops)
        case .glow(let x, let y, let radius, let hex, let alpha):
            glow(size, x, y, radius, hex, alpha)
        case .disc(let x, let y, let radius, let hex):
            disc(size, x, y, radius, hex)
        case .hill(let base, let amp, let waves, let phase, let hex):
            hill(size, base, amp, waves, phase, hex)
        case .band(let base, let amp, let waves, let phase, let hex, let thickness, let alpha):
            band(size, base, amp, waves, phase, hex, thickness, alpha)
        case .oval(let x, let y, let w, let h, let rotation, let hex, let alpha):
            oval(size, x, y, w, h, rotation, hex, alpha)
        case .ring(let x, let y, let w, let h, let rotation, let hex, let line):
            ring(size, x, y, w, h, rotation, hex, line)
        case .stars:
            stars(size)
        case .vignette(let hex, let alpha):
            vignette(size, hex, alpha)
        }
    }

    func band(_ size: CGSize, _ base: CGFloat, _ amp: CGFloat, _ waves: CGFloat, _ phase: CGFloat, _ hex: String, _ thickness: CGFloat, _ alpha: CGFloat) {
        let path = CGMutablePath()
        let steps = 48
        for step in 0...steps {
            let t = CGFloat(step) / CGFloat(steps)
            let point = cg(CGPoint(
                x: size.width * t,
                y: size.height * base + sin(t * waves * .pi * 2 + phase) * size.height * amp
            ))
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        context.saveGState()
        context.addPath(path)
        context.setStrokeColor(paint(hex, alpha: alpha))
        context.setLineWidth(size.height * thickness)
        context.setLineCap(.round)
        context.strokePath()
        context.restoreGState()
    }

    func applyStyledShadow(_ style: ShotliStyle, tint: NSColor) {
        guard style.shadowKind != .none, style.shadow > 0, style.shadowOpacity > 0.5 else { return }
        let depth = style.shadow / 100
        let gain = style.shadowOpacity / 40
        let alpha = min(0.85, (0.05 + depth * 0.4) * gain)
        switch style.shadowKind {
        case .none:
            return
        case .hug:
            let color = NSColor(srgbRed: 0.05, green: 0.05, blue: 0.05, alpha: min(0.9, alpha * 1.15)).cgColor
            context.setShadow(offset: CGSize(width: 0, height: -(1 + depth * 3)), blur: 2 + depth * 10, color: color)
        case .adaptive:
            var red: CGFloat = 0.93
            var green: CGFloat = 0.42
            var blue: CGFloat = 0.18
            var tintAlpha: CGFloat = 1
            let resolved = tint.usingColorSpace(.sRGB) ?? tint
            resolved.getRed(&red, green: &green, blue: &blue, alpha: &tintAlpha)
            let color = NSColor(srgbRed: red, green: green, blue: blue, alpha: min(0.9, 0.35 + alpha)).cgColor
            context.setShadow(offset: CGSize(width: 0, height: -(8 + depth * 20)), blur: 20 + depth * 46, color: color)
        case .spread:
            let color = NSColor(srgbRed: 0.08, green: 0.08, blue: 0.08, alpha: alpha).cgColor
            context.setShadow(offset: CGSize(width: 0, height: -(2 + depth * 26)), blur: 8 + depth * 72, color: color)
        }
    }

    func applyLight(_ amount: CGFloat, rect: CGRect) {
        guard abs(amount) > 0.4, rect.width > 1, rect.height > 1 else { return }
        context.saveGState()
        context.clip(to: cg(rect))
        if amount > 0 {
            context.setBlendMode(.plusLighter)
            context.setFillColor(NSColor.white.withAlphaComponent(min(0.8, amount / 55)).cgColor)
        } else {
            context.setBlendMode(.multiply)
            let shade = max(0.2, 1 + amount / 55)
            context.setFillColor(NSColor(srgbRed: shade, green: shade, blue: shade, alpha: 1).cgColor)
        }
        context.fill(cg(rect))
        context.restoreGState()
    }

    func paintCard(_ window: CGRect, style: ShotliStyle) {
        let radius = style.radius
        switch style.card {
        case .outline:
            fillRound(window, radius: radius, color: style.frame == .none ? NSColor.white : NSColor(srgbRed: 0.956, green: 0.956, blue: 0.956, alpha: 1))
        case .glassLight:
            fillRound(window, radius: radius, color: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.72))
        case .glassDark:
            fillRound(window, radius: radius, color: NSColor(srgbRed: 16 / 255, green: 18 / 255, blue: 27 / 255, alpha: 0.62))
        case .liquid:
            fillRound(window, radius: radius, color: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.4))
        case .insetLight:
            fillRound(window, radius: radius, color: NSColor(srgbRed: 0.953, green: 0.953, blue: 0.957, alpha: 1))
        case .insetDark:
            fillRound(window, radius: radius, color: NSColor(srgbRed: 0.086, green: 0.090, blue: 0.110, alpha: 1))
        case .retro:
            fillRound(window, radius: radius, color: NSColor(srgbRed: 0.906, green: 0.886, blue: 0.855, alpha: 1))
        case .border, .default:
            let card = style.frame == .none ? NSColor.white : NSColor(srgbRed: 0.956, green: 0.956, blue: 0.956, alpha: 1)
            fillRound(window, radius: radius, color: card)
        }
    }

    func paintCardEdge(_ window: CGRect, style: ShotliStyle) {
        let radius = style.radius
        switch style.card {
        case .outline:
            context.setStrokeColor(paint("#171717"))
            context.setLineWidth(3)
            strokeRound(window.insetBy(dx: 1.5, dy: 1.5), radius: max(0, radius - 1.5))
        case .border:
            context.setStrokeColor(paint("#171717"))
            context.setLineWidth(8)
            strokeRound(window.insetBy(dx: 4, dy: 4), radius: max(0, radius - 4))
        case .glassLight, .liquid:
            context.setStrokeColor(NSColor.white.withAlphaComponent(0.9).cgColor)
            context.setLineWidth(2)
            strokeRound(window.insetBy(dx: 1.5, dy: 1.5), radius: max(0, radius - 1.5))
        case .glassDark:
            context.setStrokeColor(NSColor.white.withAlphaComponent(0.45).cgColor)
            context.setLineWidth(2)
            strokeRound(window.insetBy(dx: 1.5, dy: 1.5), radius: max(0, radius - 1.5))
        case .insetLight, .insetDark:
            context.saveGState()
            clipRound(window, radius: radius)
            context.setStrokeColor(style.card == .insetDark ? NSColor.black.withAlphaComponent(0.65).cgColor : NSColor.black.withAlphaComponent(0.16).cgColor)
            context.setLineWidth(18)
            strokeRound(window.insetBy(dx: 1, dy: 1), radius: max(0, radius - 1))
            context.restoreGState()
        case .retro:
            context.setStrokeColor(NSColor(srgbRed: 0.227, green: 0.204, blue: 0.173, alpha: 1).cgColor)
            context.setLineWidth(3)
            strokeRound(window.insetBy(dx: 1.5, dy: 1.5), radius: max(0, radius - 1.5))
        case .default:
            context.setStrokeColor(NSColor.black.withAlphaComponent(0.12).cgColor)
            context.setLineWidth(1)
            strokeRound(window.insetBy(dx: 0.5, dy: 0.5), radius: max(0, radius - 0.5))
        }
    }

    func fillRound(_ rect: CGRect, radius: CGFloat, color: NSColor) {
        context.setFillColor(color.cgColor)
        context.addPath(roundPath(rect, radius: radius))
        context.fillPath()
    }

    func strokeRound(_ rect: CGRect, radius: CGFloat) {
        context.addPath(roundPath(rect, radius: radius))
        context.strokePath()
    }

    func clipRound(_ rect: CGRect, radius: CGFloat) {
        context.addPath(roundPath(rect, radius: radius))
        context.clip()
    }

    func roundPath(_ rect: CGRect, radius: CGFloat) -> CGPath {
        let r = max(0, min(radius, abs(rect.width) / 2, abs(rect.height) / 2))
        return CGPath(roundedRect: cg(rect), cornerWidth: r, cornerHeight: r, transform: nil)
    }

    func drawBrowserChrome(_ window: CGRect, radius: CGFloat, name: String) {
        context.saveGState()
        clipRound(window, radius: radius)
        let chrome = min(chromeHeight, window.height)
        context.setFillColor(paint("#F3F3F3"))
        context.fill(cg(CGRect(x: window.minX, y: window.minY, width: window.width, height: chrome)))
        context.setStrokeColor(paint("#E3E3E3"))
        context.setLineWidth(1)
        context.move(to: cg(CGPoint(x: window.minX, y: window.minY + chrome)))
        context.addLine(to: cg(CGPoint(x: window.maxX, y: window.minY + chrome)))
        context.strokePath()
        let colors = ["#FF5F57", "#FEBC2E", "#28C840"]
        for (index, color) in colors.enumerated() {
            let dot = CGRect(x: window.minX + 14.5 + CGFloat(index) * 16, y: window.minY + chrome / 2 - 5.5, width: 11, height: 11)
            context.setFillColor(paint(color))
            context.fillEllipse(in: cg(dot))
        }
        if window.width > 180 {
            let pillWidth = min(280, max(80, window.width * 0.42))
            let pill = CGRect(x: window.midX - pillWidth / 2, y: window.minY + (chrome - 22) / 2, width: pillWidth, height: 22)
            context.setFillColor(NSColor.white.cgColor)
            context.addPath(CGPath(roundedRect: cg(pill), cornerWidth: 6, cornerHeight: 6, transform: nil))
            context.fillPath()
            fillText(fit(displayName(name), maxWidth: pillWidth - 20, font: NSFont.systemFont(ofSize: 12)), x: window.midX, y: window.minY + chrome / 2 - 7, font: NSFont.systemFont(ofSize: 12), color: NSColor(hex: "#8A8A8A") ?? .gray, align: .center)
        }
        context.restoreGState()
    }

    func drawDesktopChrome(_ window: CGRect, radius: CGFloat, name: String) {
        context.saveGState()
        clipRound(window, radius: radius)
        context.setFillColor(paint("#ECECEC"))
        context.fill(cg(CGRect(x: window.minX, y: window.minY, width: window.width, height: chromeHeight)))
        context.setStrokeColor(paint("#DEDEDE"))
        context.move(to: cg(CGPoint(x: window.minX, y: window.minY + chromeHeight)))
        context.addLine(to: cg(CGPoint(x: window.maxX, y: window.minY + chromeHeight)))
        context.strokePath()
        for (index, color) in ["#FF5F57", "#FEBC2E", "#28C840"].enumerated() {
            let dot = CGRect(x: window.minX + 13 + CGFloat(index) * 15, y: window.minY + chromeHeight / 2 - 5, width: 10, height: 10)
            context.setFillColor(paint(color))
            context.fillEllipse(in: cg(dot))
        }
        let font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        fillText(fit(displayName(name), maxWidth: window.width - 120, font: font), x: window.midX, y: window.minY + chromeHeight / 2 - 8, font: font, color: NSColor(hex: "#4B4B4B") ?? .darkGray, align: .center)
        context.restoreGState()
    }

    func drawImage(_ image: CGImage, crop: CGRect, dest: CGRect) {
        guard crop.width > 0, crop.height > 0 else { return }
        let scaleX = dest.width / crop.width
        let scaleY = dest.height / crop.height
        let full = CGRect(
            x: dest.minX - crop.minX * scaleX,
            y: dest.minY - crop.minY * scaleY,
            width: CGFloat(image.width) * scaleX,
            height: CGFloat(image.height) * scaleY
        )
        context.saveGState()
        context.interpolationQuality = .high
        context.clip(to: cg(dest))
        context.draw(image, in: cg(full))
        context.restoreGState()
    }

    func drawRedaction(_ image: CGImage, _ mark: ShapeMark, layout: Composition, crop: CGRect) {
        let rect = normalized(CGRect(x: mark.x, y: mark.y, width: mark.w, height: mark.h))
        guard rect.width >= 2, rect.height >= 2 else { return }
        let block = mark.kind == .pixelate ? max(4, mark.amount) : max(2, mark.amount)
        let cols = max(1, Int((rect.width / block).rounded()))
        let rows = max(1, Int((rect.height / block).rounded()))
        guard let small = CGContext(
            data: nil, width: cols, height: rows, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return }
        let source = CGRect(
            x: rect.minX / CGFloat(image.width) * CGFloat(cols),
            y: 0, width: 0, height: 0
        )
        _ = source
        let imageRect = CGRect(
            x: -rect.minX / rect.width * CGFloat(cols),
            y: -(CGFloat(image.height) - rect.maxY) / rect.height * CGFloat(rows),
            width: CGFloat(image.width) / rect.width * CGFloat(cols),
            height: CGFloat(image.height) / rect.height * CGFloat(rows)
        )
        small.interpolationQuality = mark.kind == .pixelate ? .none : .medium
        small.draw(image, in: imageRect)
        guard let tiny = small.makeImage() else { return }
        context.saveGState()
        context.interpolationQuality = mark.kind == .pixelate ? .none : .medium
        context.clip(to: cg(visual(rect, layout: layout, crop: crop)))
        context.draw(tiny, in: cg(visual(rect, layout: layout, crop: crop)))
        context.restoreGState()
    }

    func drawAnnotation(_ annotation: Annotation, layout: Composition, crop: CGRect) {
        switch annotation {
        case .shape(let mark):
            guard mark.kind != .pixelate && mark.kind != .blur else { return }
            let rect = visual(normalized(CGRect(x: mark.x, y: mark.y, width: mark.w, height: mark.h)), layout: layout, crop: crop)
            context.setStrokeColor(paint(mark.color))
            context.setFillColor(paint(mark.color))
            context.setLineWidth(mark.strokeWidth)
            context.setLineJoin(.round)
            if mark.kind == .rectFill {
                context.saveGState()
                context.setAlpha(0.22)
                context.fill(cg(rect))
                context.restoreGState()
            }
            if mark.kind == .circle {
                context.strokeEllipse(in: cg(rect))
            } else {
                context.stroke(cg(rect))
            }
        case .line(let mark):
            let start = visual(CGPoint(x: mark.x, y: mark.y), layout: layout, crop: crop)
            let end = visual(CGPoint(x: mark.x2, y: mark.y2), layout: layout, crop: crop)
            context.setStrokeColor(paint(mark.color))
            context.setFillColor(paint(mark.color))
            context.setLineWidth(mark.strokeWidth)
            context.setLineCap(.round)
            context.move(to: cg(start))
            context.addLine(to: cg(end))
            context.strokePath()
            if mark.arrow { drawArrow(from: start, to: end, width: mark.strokeWidth) }
        case .draw(let mark):
            guard mark.points.count > 1 else { return }
            context.setStrokeColor(paint(mark.color))
            context.setLineWidth(mark.strokeWidth)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.beginPath()
            context.move(to: cg(visual(mark.points[0], layout: layout, crop: crop)))
            for point in mark.points.dropFirst() {
                context.addLine(to: cg(visual(point, layout: layout, crop: crop)))
            }
            context.strokePath()
        case .text(let mark):
            let font = NSFont.systemFont(ofSize: mark.fontSize)
            let color = NSColor(hex: mark.color) ?? .black
            let lines = mark.text.components(separatedBy: "\n")
            for (index, line) in lines.enumerated() {
                let origin = visual(CGPoint(x: mark.x, y: mark.y + CGFloat(index) * mark.fontSize * 1.25), layout: layout, crop: crop)
                fillText(line, x: origin.x, y: origin.y, font: font, color: color, align: .left)
            }
        case .marker(let mark):
            let center = visual(CGPoint(x: mark.x, y: mark.y), layout: layout, crop: crop)
            context.setFillColor(paint(mark.color))
            context.fillEllipse(in: cg(CGRect(x: center.x - 15, y: center.y - 15, width: 30, height: 30)))
            let ink = readableInk(mark.color)
            let font = NSFont.systemFont(ofSize: 13, weight: .semibold)
            fillText("\(mark.n)", x: center.x, y: center.y - 8, font: font, color: NSColor(hex: ink) ?? .white, align: .center)
        }
    }

    func drawArrow(from start: CGPoint, to end: CGPoint, width: CGFloat) {
        let angle = atan2(end.y - start.y, end.x - start.x)
        let length = 8 + width * 2.2
        let a = CGPoint(x: end.x - length * cos(angle - 0.42), y: end.y - length * sin(angle - 0.42))
        let b = CGPoint(x: end.x - length * cos(angle + 0.42), y: end.y - length * sin(angle + 0.42))
        context.beginPath()
        context.move(to: cg(end))
        context.addLine(to: cg(a))
        context.addLine(to: cg(b))
        context.closePath()
        context.fillPath()
    }

    func drawCropOverlay(visible: CGRect, draft: CGRect, layout: Composition) {
        let rect = visual(normalized(draft), layout: layout, crop: visible)
        let full = visual(visible, layout: layout, crop: visible)
        context.saveGState()
        let path = CGMutablePath()
        path.addRect(cg(full))
        path.addRect(cg(rect))
        context.addPath(path)
        context.setFillColor(NSColor.black.withAlphaComponent(0.45).cgColor)
        context.fillPath(using: .evenOdd)
        context.setStrokeColor(paint("#3478F6"))
        context.setLineWidth(1.5)
        context.setLineDash(phase: 0, lengths: [5, 4])
        context.stroke(cg(rect))
        context.restoreGState()
    }

    func drawSelection(_ annotation: Annotation, layout: Composition, crop: CGRect) {
        context.saveGState()
        context.setStrokeColor(paint("#3478F6"))
        context.setLineWidth(1)
        context.setLineDash(phase: 0, lengths: [4, 3])
        if case .marker(let mark) = annotation {
            let center = visual(CGPoint(x: mark.x, y: mark.y), layout: layout, crop: crop)
            context.strokeEllipse(in: cg(CGRect(x: center.x - 18, y: center.y - 18, width: 36, height: 36)))
        } else {
            let box = visual(bounds(of: annotation).insetBy(dx: -2, dy: -2), layout: layout, crop: crop)
            context.stroke(cg(box))
        }
        context.setLineDash(phase: 0, lengths: [])
        context.setFillColor(NSColor.white.cgColor)
        for handle in handles(of: annotation) {
            let point = visual(handle.1, layout: layout, crop: crop)
            let square = CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)
            context.fill(cg(square))
            context.stroke(cg(square))
        }
        context.restoreGState()
    }

    func fillText(_ text: String, x: CGFloat, y: CGFloat, font: NSFont, color: NSColor, align: NSTextAlignment) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let size = (text as NSString).size(withAttributes: attrs)
        var drawX = x
        if align == .center { drawX = x - size.width / 2 }
        if align == .right { drawX = x - size.width }
        let cgY = height - y - size.height
        context.saveGState()
        context.translateBy(x: drawX, y: cgY + size.height)
        context.scaleBy(x: 1, y: -1)
        (text as NSString).draw(at: .zero, withAttributes: attrs)
        context.restoreGState()
    }

    func fit(_ text: String, maxWidth: CGFloat, font: NSFont) -> String {
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        if (text as NSString).size(withAttributes: attrs).width <= maxWidth { return text }
        var value = text
        while value.count > 1 && (("\(value)…" as NSString).size(withAttributes: attrs).width > maxWidth) {
            value.removeLast()
        }
        return value + "…"
    }
}

private enum SceneLibrary {
    static func render(_ id: WallpaperID, painter: Painter, size: CGSize) -> Bool {
        guard let ops = catalog(id) else { return false }
        for op in ops { painter.play(op, size) }
        return true
    }

    static func catalog(_ id: WallpaperID) -> [SceneOp]? {
        switch id {
        case .flare:
            return [
                .vertical([(0, "#FF4B6E"), (0.55, "#FF7A59"), (1, "#FFB086")]),
                .glow(0.12, 0.28, 0.55, "#FF2D55", 0.95),
                .glow(0.84, 0.22, 0.48, "#FF8A3D", 0.9),
                .glow(0.48, 0.72, 0.42, "#FFD0A8", 0.75),
                .glow(0.62, 0.4, 0.22, "#FFFFFF", 0.35),
            ]
        case .iris:
            return [
                .vertical([(0, "#5B4DFF"), (0.5, "#7C5CFF"), (1, "#3B82F6")]),
                .glow(0.18, 0.24, 0.5, "#C084FC", 0.85),
                .glow(0.82, 0.18, 0.46, "#67E8F9", 0.7),
                .glow(0.55, 0.78, 0.48, "#F9A8D4", 0.8),
                .glow(0.42, 0.42, 0.2, "#FFFFFF", 0.28),
            ]
        case .blush:
            return [
                .vertical([(0, "#FFE4EC"), (0.5, "#FFC7D4"), (1, "#FFC4A8")]),
                .glow(0.16, 0.3, 0.5, "#FB7185", 0.7),
                .glow(0.84, 0.24, 0.46, "#FDBA74", 0.75),
                .glow(0.5, 0.74, 0.4, "#FFFFFF", 0.85),
            ]
        case .prism:
            return [
                .vertical([(0, "#120C2E"), (1, "#1E1648")]),
                .glow(0.2, 0.22, 0.48, "#7C3AED", 0.9),
                .glow(0.78, 0.3, 0.42, "#22D3EE", 0.75),
                .glow(0.55, 0.72, 0.4, "#F472B6", 0.7),
                .band(0.42, 0.08, 1.1, 0.4, "#E0E7FF", 0.04, 0.55),
            ]
        case .ripple:
            return [
                .vertical([(0, "#123A8F"), (1, "#38BDF8")]),
                .band(0.26, 0.06, 1.5, 0.2, "#FFFFFF", 0.07, 0.4),
                .band(0.38, 0.08, 1.7, 1.2, "#E0F2FE", 0.14, 0.55),
                .band(0.52, 0.05, 1.3, 2.1, "#7DD3FC", 0.16, 0.5),
                .band(0.66, 0.07, 1.6, 0.7, "#1D4ED8", 0.12, 0.45),
                .band(0.8, 0.04, 2.1, 1.5, "#FFFFFF", 0.05, 0.55),
                .glow(0.18, 0.32, 0.28, "#FFFFFF", 0.28),
            ]
        case .emberglass:
            return [
                .vertical([(0, "#C2410C"), (0.5, "#F97316"), (1, "#FBBF24")]),
                .band(0.24, 0.05, 1.8, 0.3, "#FFF7ED", 0.06, 0.45),
                .band(0.4, 0.08, 1.4, 1.4, "#FFEDD5", 0.16, 0.55),
                .band(0.56, 0.06, 2.0, 0.6, "#EA580C", 0.14, 0.4),
                .band(0.72, 0.05, 1.5, 2.2, "#FFFFFF", 0.05, 0.5),
                .glow(0.7, 0.3, 0.3, "#FEF3C7", 0.4),
            ]
        case .gilt:
            return [
                .vertical([(0, "#F8E7B5"), (0.55, "#E8B15A"), (1, "#C4842A")]),
                .band(0.22, 0.03, 2.4, 0.2, "#FFFBEB", 0.035, 0.7),
                .band(0.36, 0.04, 2.2, 1.1, "#FDE68A", 0.05, 0.65),
                .band(0.5, 0.035, 2.6, 0.5, "#FFFFFF", 0.03, 0.55),
                .band(0.66, 0.04, 2.1, 1.8, "#B45309", 0.045, 0.35),
                .band(0.8, 0.03, 2.5, 0.9, "#FFF7ED", 0.03, 0.6),
            ]
        case .current:
            return [
                .vertical([(0, "#082F49"), (0.45, "#0369A1"), (1, "#38BDF8")]),
                .band(0.3, 0.07, 1.2, 0.4, "#E0F2FE", 0.1, 0.35),
                .band(0.46, 0.09, 1.4, 1.6, "#7DD3FC", 0.18, 0.45),
                .band(0.62, 0.06, 1.1, 0.8, "#FFFFFF", 0.08, 0.4),
                .band(0.76, 0.05, 1.6, 2.2, "#0C4A6E", 0.12, 0.4),
                .glow(0.5, 0.4, 0.25, "#F0F9FF", 0.3),
            ]
        case .nebula:
            return [
                .vertical([(0, "#070614"), (1, "#140C28")]),
                .stars,
                .glow(0.22, 0.32, 0.5, "#7C3AED", 0.85),
                .glow(0.74, 0.28, 0.46, "#EC4899", 0.7),
                .glow(0.5, 0.7, 0.4, "#312E81", 0.9),
                .glow(0.62, 0.42, 0.16, "#F5D0FE", 0.35),
            ]
        case .void:
            return [
                .vertical([(0, "#050508"), (1, "#0C0A12")]),
                .stars,
                .glow(0.78, 0.22, 0.42, "#4C1D95", 0.8),
                .glow(0.3, 0.7, 0.36, "#1E1B4B", 0.9),
                .disc(0.78, 0.22, 0.02, "#EDE9FE"),
            ]
        case .orbit:
            return [
                .vertical([(0, "#070B18"), (1, "#111827")]),
                .stars,
                .glow(0.62, 0.4, 0.4, "#1D4ED8", 0.7),
                .disc(0.62, 0.4, 0.09, "#93C5FD"),
                .disc(0.6, 0.38, 0.05, "#1E3A8A"),
                .ring(0.62, 0.4, 0.34, 0.1, -0.4, "#DBEAFE", 0.012),
            ]
        case .pulsar:
            return [
                .vertical([(0, "#140818"), (1, "#2A0A22")]),
                .stars,
                .glow(0.4, 0.42, 0.5, "#BE185D", 0.85),
                .glow(0.72, 0.3, 0.36, "#7C3AED", 0.75),
                .disc(0.4, 0.42, 0.025, "#FDF2F8"),
                .glow(0.4, 0.42, 0.12, "#FFFFFF", 0.45),
            ]
        case .veil:
            return [
                .vertical([(0, "#F8F9FC"), (1, "#EEF2FF")]),
                .glow(0.22, 0.72, 0.55, "#93C5FD", 0.85),
                .glow(0.78, 0.24, 0.4, "#C4B5FD", 0.45),
                .glow(0.5, 0.4, 0.3, "#FFFFFF", 0.8),
            ]
        case .halo:
            return [
                .vertical([(0, "#F4F7FF"), (1, "#E0E7FF")]),
                .glow(0.5, 0.48, 0.42, "#FFFFFF", 0.95),
                .band(0.46, 0.08, 1.2, 0.5, "#60A5FA", 0.1, 0.45),
                .band(0.52, 0.06, 1.4, 1.2, "#A78BFA", 0.06, 0.35),
                .glow(0.5, 0.5, 0.16, "#DBEAFE", 0.7),
            ]
        case .drift:
            return [
                .vertical([(0, "#F8F7FC"), (1, "#F3E8FF")]),
                .glow(0.18, 0.3, 0.4, "#C4B5FD", 0.55),
                .glow(0.8, 0.62, 0.48, "#7DD3FC", 0.5),
                .glow(0.46, 0.78, 0.32, "#F9A8D4", 0.35),
                .glow(0.55, 0.36, 0.22, "#FFFFFF", 0.8),
            ]
        case .linen:
            return [
                .vertical([(0, "#F7F4EF"), (1, "#E7E5E4")]),
                .glow(0.3, 0.28, 0.4, "#FFFFFF", 0.9),
                .glow(0.72, 0.74, 0.42, "#93C5FD", 0.35),
                .glow(0.16, 0.8, 0.3, "#F5D0C8", 0.4),
            ]
        case .peaks:
            return [
                .vertical([(0, "#8EC8F5"), (0.55, "#E8F4FF"), (1, "#F8FBFF")]),
                .disc(0.74, 0.28, 0.06, "#FFF7ED"),
                .glow(0.74, 0.28, 0.2, "#FFFFFF", 0.7),
                .hill(0.58, 0.07, 1.3, 0.4, "#9BBBE0"),
                .hill(0.7, 0.09, 1.6, 1.3, "#4C78B8"),
                .hill(0.84, 0.07, 1.15, 0.3, "#1E3A5F"),
            ]
        case .coast:
            return [
                .vertical([(0, "#F7D7B5"), (0.42, "#8ECAE6"), (1, "#1D4E89")]),
                .hill(0.52, 0.02, 0.6, 0.2, "#1E6091"),
                .band(0.5, 0.012, 1.2, 0.4, "#FFFFFF", 0.012, 0.7),
                .oval(0.22, 0.7, 0.18, 0.16, 0.2, "#1C1917", 1),
                .oval(0.7, 0.66, 0.28, 0.14, -0.3, "#292524", 1),
                .oval(0.86, 0.78, 0.16, 0.12, 0.4, "#44403C", 1),
                .glow(0.7, 0.3, 0.18, "#FFF7ED", 0.55),
            ]
        case .shore:
            return [
                .vertical([(0, "#FB923C"), (0.4, "#FDBA74"), (0.7, "#7DD3FC"), (1, "#0369A1")]),
                .disc(0.72, 0.32, 0.07, "#FFF7ED"),
                .glow(0.72, 0.32, 0.28, "#FED7AA", 0.8),
                .hill(0.62, 0.015, 0.8, 0.2, "#0284C7"),
                .hill(0.8, 0.04, 1.1, 0.6, "#F5D0A9"),
            ]
        case .ridge:
            return [
                .vertical([(0, "#312E81"), (0.4, "#7C3AED"), (0.7, "#F9A8D4"), (1, "#1E1B4B")]),
                .hill(0.55, 0.05, 1.4, 0.3, "#6D28D9"),
                .hill(0.68, 0.06, 1.7, 1.2, "#4C1D95"),
                .hill(0.82, 0.05, 1.2, 0.5, "#1E1B4B"),
                .glow(0.3, 0.24, 0.22, "#FDE68A", 0.45),
            ]
        case .fold:
            return [
                .vertical([(0, "#1D4ED8"), (1, "#2563EB")]),
                .oval(0.28, 0.4, 0.7, 0.55, 0.5, "#FB923C", 1),
                .oval(0.72, 0.58, 0.62, 0.48, -0.4, "#1E3A8A", 1),
                .oval(0.48, 0.72, 0.5, 0.28, 0.2, "#FEF3C7", 1),
            ]
        case .swell:
            return [
                .vertical([(0, "#2A1848"), (1, "#3B0764")]),
                .oval(0.3, 0.38, 0.7, 0.5, 0.6, "#F59E0B", 1),
                .oval(0.7, 0.55, 0.6, 0.55, -0.5, "#E879F9", 1),
                .oval(0.46, 0.74, 0.55, 0.3, 0.15, "#38BDF8", 1),
            ]
        case .dune:
            return [
                .vertical([(0, "#FF7A3C"), (1, "#FDBA74")]),
                .oval(0.62, 0.42, 0.8, 0.5, -0.35, "#1D4ED8", 1),
                .oval(0.28, 0.62, 0.6, 0.4, 0.4, "#FFF7ED", 1),
                .hill(0.78, 0.06, 1.3, 0.8, "#C2410C"),
            ]
        case .petal:
            return [
                .vertical([(0, "#FF5C8A"), (1, "#FB7185")]),
                .oval(0.3, 0.36, 0.55, 0.42, 0.7, "#FDBA74", 1),
                .oval(0.68, 0.4, 0.5, 0.46, -0.5, "#FDE68A", 1),
                .oval(0.48, 0.68, 0.62, 0.36, 0.2, "#7C3AED", 0.9),
            ]
        case .canyon:
            return [
                .vertical([(0, "#FED7AA"), (0.4, "#EA580C"), (1, "#7C2D12")]),
                .glow(0.3, 0.28, 0.4, "#FFEDD5", 0.75),
                .hill(0.62, 0.06, 1.4, 0.4, "#C2410C"),
                .hill(0.78, 0.05, 1.2, 1.5, "#7C2D12"),
            ]
        case .canopy:
            return [
                .vertical([(0, "#ECFCCB"), (0.45, "#65A30D"), (1, "#14532D")]),
                .glow(0.24, 0.26, 0.36, "#FDE68A", 0.7),
                .hill(0.6, 0.07, 1.5, 0.3, "#3F6212"),
                .hill(0.78, 0.05, 1.2, 1.4, "#14532D"),
            ]
        case .mesa:
            return [
                .vertical([(0, "#DDD6FE"), (0.4, "#A78BFA"), (1, "#F5D0A9")]),
                .glow(0.7, 0.24, 0.28, "#FDE68A", 0.7),
                .hill(0.64, 0.05, 1.3, 0.6, "#C4B5FD"),
                .hill(0.8, 0.06, 1.1, 1.2, "#D6A37A"),
            ]
        case .basin:
            return [
                .vertical([(0, "#BAE6FD"), (0.45, "#0284C7"), (1, "#0F766E")]),
                .glow(0.5, 0.36, 0.3, "#E0F2FE", 0.55),
                .hill(0.62, 0.04, 1.2, 0.4, "#0F766E"),
                .oval(0.3, 0.74, 0.36, 0.16, 0.2, "#D9F99D", 1),
                .hill(0.84, 0.04, 1.4, 1.1, "#115E59"),
            ]
        default:
            return nil
        }
    }
}

func renderSceneThumbnail(_ id: WallpaperID) -> NSImage? {
    let width = 240
    let height = 144
    guard let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    let painter = Painter(context: context, height: CGFloat(height))
    painter.drawWallpaper(id, CGSize(width: width, height: height))
    guard let image = context.makeImage() else { return nil }
    return NSImage(cgImage: image, size: NSSize(width: width, height: height))
}

private func displayName(_ filename: String) -> String {
    let ns = filename as NSString
    let base = ns.deletingPathExtension
    return base.isEmpty ? filename : base
}

private func adaptiveTint(_ image: CGImage) -> NSColor {
    let cols = 4
    let rows = 4
    let fallback = NSColor(srgbRed: 0.93, green: 0.42, blue: 0.18, alpha: 1)
    guard let ctx = CGContext(
        data: nil, width: cols, height: rows, bitsPerComponent: 8, bytesPerRow: cols * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ), let data = ctx.data else { return fallback }
    ctx.interpolationQuality = .medium
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: cols, height: rows))
    let ptr = data.bindMemory(to: UInt8.self, capacity: cols * rows * 4)
    var bestScore: CGFloat = -1
    var best = fallback
    for index in 0..<(cols * rows) {
        let red = CGFloat(ptr[index * 4]) / 255
        let green = CGFloat(ptr[index * 4 + 1]) / 255
        let blue = CGFloat(ptr[index * 4 + 2]) / 255
        let maxC = max(red, green, blue)
        let minC = min(red, green, blue)
        let score = (maxC - minC) * 2 + maxC * 0.2
        if score > bestScore {
            bestScore = score
            let average = (red + green + blue) / 3
            best = NSColor(
                srgbRed: min(1, average + (red - average) * 1.45),
                green: min(1, average + (green - average) * 1.45),
                blue: min(1, average + (blue - average) * 1.45),
                alpha: 1
            )
        }
    }
    return best
}

private func paint(_ hex: String, alpha: CGFloat = 1) -> CGColor {
    (NSColor(hex: hex) ?? .black).withAlphaComponent(alpha).cgColor
}

private func readableInk(_ hex: String) -> String {
    guard let color = NSColor(hex: hex)?.usingColorSpace(.sRGB) else { return "#FFFFFF" }
    let luminance = color.redComponent * 0.2126 + color.greenComponent * 0.7152 + color.blueComponent * 0.0722
    return luminance > 0.66 ? "#222222" : "#FFFFFF"
}

extension NSColor {
    convenience init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value == "transparent" { return nil }
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let number = Int(value, radix: 16) else { return nil }
        self.init(
            srgbRed: CGFloat((number >> 16) & 0xFF) / 255,
            green: CGFloat((number >> 8) & 0xFF) / 255,
            blue: CGFloat(number & 0xFF) / 255,
            alpha: 1
        )
    }
}
