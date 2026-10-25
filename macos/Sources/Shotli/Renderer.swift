import AppKit

func renderComposition(
    picture: LoadedPicture?,
    crop: CGRect?,
    style: ShotliStyle,
    annotations: [Annotation],
    draft: Annotation?,
    interactive: Bool,
    cropDraft: CGRect? = nil,
    selectedID: String? = nil
) -> CGImage? {
    guard let picture else { return nil }
    let layout = composition(picture: picture, crop: crop, style: style)
    let width = Int(ceil(layout.size.width))
    let height = Int(ceil(layout.size.height))
    guard let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    let painter = Painter(context: context, height: CGFloat(height))
    painter.drawBackground(style.background, CGSize(width: width, height: height))
    let cropRect = activeCrop(picture: picture, crop: crop) ?? .zero
    let radius = style.radius
    let card = style.frame == .none ? NSColor.white : NSColor(srgbRed: 0.956, green: 0.956, blue: 0.956, alpha: 1)

    context.saveGState()
    if style.shadow > 0 { painter.applyShadow(style.shadow) }
    painter.fillRound(layout.window, radius: radius, color: card)
    context.restoreGState()

    if style.frame == .browser {
        painter.drawBrowserChrome(layout.window, radius: radius, name: picture.name)
    } else if style.frame == .desktop {
        painter.drawDesktopChrome(layout.window, radius: radius, name: picture.name)
    }

    context.saveGState()
    painter.clipRound(layout.window, radius: radius)
    context.clip(to: painter.cg(layout.image))
    painter.drawImage(picture.image, crop: cropRect, dest: layout.image)
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
    context.restoreGState()

    context.saveGState()
    context.setStrokeColor(NSColor.black.withAlphaComponent(0.12).cgColor)
    context.setLineWidth(1)
    painter.strokeRound(layout.window.insetBy(dx: 0.5, dy: 0.5), radius: max(0, radius - 0.5))
    context.restoreGState()
    return context.makeImage()
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
        switch background {
        case .color(let hex):
            if hex == "transparent" {
                drawChecker(size)
                return
            }
            context.setFillColor(paint(hex))
            context.fill(CGRect(origin: .zero, size: size))
        case .gradient(let from, let to, let angle):
            let radians = (angle - 90) * .pi / 180
            let length = abs(size.width * cos(radians)) + abs(size.height * sin(radians))
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let delta = CGPoint(x: cos(radians) * length / 2, y: sin(radians) * length / 2)
            let colors = [paint(from), paint(to)] as CFArray
            let locations: [CGFloat] = [0, 1]
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations) else { return }
            context.drawLinearGradient(gradient, start: cg(CGPoint(x: center.x - delta.x, y: center.y - delta.y)), end: cg(CGPoint(x: center.x + delta.x, y: center.y + delta.y)), options: [])
        case .wallpaper(let id):
            drawWallpaper(id, size)
        }
    }

    func drawChecker(_ size: CGSize) {
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        context.setFillColor(NSColor(srgbRed: 0.925, green: 0.925, blue: 0.925, alpha: 1).cgColor)
        let step: CGFloat = 12
        var y: CGFloat = 0
        var row = 0
        while y < size.height {
            var x: CGFloat = row.isMultiple(of: 2) ? 0 : step
            while x < size.width {
                context.fill(cg(CGRect(x: x, y: y, width: step, height: step)))
                x += step * 2
            }
            y += step
            row += 1
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
        }
    }

    func applyShadow(_ intensity: CGFloat) {
        let amount = intensity / 100
        let color = NSColor(srgbRed: 0.08, green: 0.08, blue: 0.08, alpha: 0.05 + amount * 0.4).cgColor
        context.setShadow(offset: CGSize(width: 0, height: -(2 + amount * 26)), blur: 8 + amount * 72, color: color)
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

private func displayName(_ filename: String) -> String {
    let ns = filename as NSString
    let base = ns.deletingPathExtension
    return base.isEmpty ? filename : base
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
