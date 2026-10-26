import AppKit

struct Composition {
    var image: CGRect
    var window: CGRect
    var size: CGSize
}

func composition(picture: LoadedPicture?, crop: CGRect?, style: ShotliStyle) -> Composition {
    let cropRect = activeCrop(picture: picture, crop: crop)
    let width = cropRect?.width ?? 0
    let height = cropRect?.height ?? 0
    let pad = stagePad(style, span: max(width, height))
    let chrome: CGFloat = style.hideMockup || style.frame == .none ? 0 : chromeHeight
    let rim = cardRim(style)
    let contentW = max(1, width + pad * 2 + rim * 2)
    let contentH = max(1, height + chrome + pad * 2 + rim * 2)
    var compW = contentW
    var compH = contentH
    if style.canvasWidth > 0, style.canvasHeight > 0 {
        compW = max(contentW, style.canvasWidth)
        compH = max(contentH, style.canvasHeight)
    } else if let ratio = style.canvas.ratio, compH > 0 {
        let current = compW / compH
        if current > ratio {
            compH = compW / ratio
        } else if current < ratio {
            compW = compH * ratio
        }
    }
    let extraX = max(0, compW - contentW)
    let extraY = max(0, compH - contentH)
    let nx = min(1, max(0, 0.5 + style.shiftX * 0.42))
    let ny = min(1, max(0, 0.5 + style.shiftY * 0.42))
    let originX = pad + extraX * nx
    let originY = pad + extraY * ny
    return Composition(
        image: CGRect(x: originX + rim, y: originY + chrome + rim, width: width, height: height),
        window: CGRect(x: originX, y: originY, width: width + rim * 2, height: height + chrome + rim * 2),
        size: CGSize(width: compW, height: compH)
    )
}

func tiltMargin(_ span: CGFloat) -> CGFloat {
    max(96, span * 0.12)
}

func stagePad(_ style: ShotliStyle, span: CGFloat) -> CGFloat {
    if style.hideMockup { return 0 }
    let tilt = abs(style.tiltX) + abs(style.tiltY)
    if tilt < 0.5 { return style.padding }
    return style.padding + min(140, span * 0.05)
}

func contentSize(picture: LoadedPicture?, crop: CGRect?, style: ShotliStyle) -> CGSize {
    let cropRect = activeCrop(picture: picture, crop: crop)
    let width = cropRect?.width ?? 0
    let height = cropRect?.height ?? 0
    let chrome: CGFloat = style.hideMockup || style.frame == .none ? 0 : chromeHeight
    let pad = stagePad(style, span: max(width, height))
    let rim = cardRim(style)
    return CGSize(width: max(1, width + pad * 2 + rim * 2), height: max(1, height + chrome + pad * 2 + rim * 2))
}

func cardRim(_ style: ShotliStyle) -> CGFloat {
    if style.hideMockup { return 0 }
    switch style.card {
    case .glassLight, .glassDark, .liquid: return 22
    case .insetLight, .insetDark: return 18
    case .border: return 14
    case .retro: return 10
    default: return 0
    }
}

func activeCrop(picture: LoadedPicture?, crop: CGRect?) -> CGRect? {
    guard let picture else { return nil }
    return crop ?? CGRect(x: 0, y: 0, width: picture.width, height: picture.height)
}

func normalized(_ rect: CGRect) -> CGRect {
    CGRect(
        x: rect.width < 0 ? rect.minX + rect.width : rect.minX,
        y: rect.height < 0 ? rect.minY + rect.height : rect.minY,
        width: abs(rect.width),
        height: abs(rect.height)
    )
}

func clamp(_ value: CGFloat, _ minValue: CGFloat, _ maxValue: CGFloat) -> CGFloat {
    min(maxValue, max(minValue, value))
}

func clamp(_ rect: CGRect, to bounds: CGRect) -> CGRect {
    let n = normalized(rect)
    let x1 = clamp(n.minX, bounds.minX, bounds.maxX)
    let y1 = clamp(n.minY, bounds.minY, bounds.maxY)
    let x2 = clamp(n.maxX, bounds.minX, bounds.maxX)
    let y2 = clamp(n.maxY, bounds.minY, bounds.maxY)
    return CGRect(x: x1, y: y1, width: max(0, x2 - x1), height: max(0, y2 - y1))
}

func textSize(_ text: String, fontSize: CGFloat) -> CGSize {
    let lines = text.isEmpty ? [""] : text.components(separatedBy: "\n")
    let font = NSFont.systemFont(ofSize: fontSize)
    var width: CGFloat = 24
    for line in lines {
        width = max(width, (line as NSString).size(withAttributes: [.font: font]).width)
    }
    return CGSize(width: width, height: CGFloat(max(1, lines.count)) * fontSize * 1.25)
}

func bounds(of annotation: Annotation) -> CGRect {
    switch annotation {
    case .shape(let mark):
        return normalized(CGRect(x: mark.x, y: mark.y, width: mark.w, height: mark.h))
    case .line(let mark):
        let x = min(mark.x, mark.x2)
        let y = min(mark.y, mark.y2)
        return CGRect(x: x, y: y, width: abs(mark.x2 - mark.x), height: abs(mark.y2 - mark.y))
    case .draw(let mark):
        guard let first = mark.points.first else { return .zero }
        var minX = first.x, minY = first.y, maxX = first.x, maxY = first.y
        for point in mark.points {
            minX = min(minX, point.x); minY = min(minY, point.y)
            maxX = max(maxX, point.x); maxY = max(maxY, point.y)
        }
        return CGRect(x: minX, y: minY, width: max(1, maxX - minX), height: max(1, maxY - minY))
    case .text(let mark):
        let size = textSize(mark.text, fontSize: mark.fontSize)
        return CGRect(x: mark.x, y: mark.y, width: size.width, height: size.height)
    case .marker(let mark):
        return CGRect(x: mark.x - 16, y: mark.y - 16, width: 32, height: 32)
    }
}

enum Handle: String { case nw, n, ne, e, se, s, sw, w, start, end }

func handles(of annotation: Annotation) -> [(Handle, CGPoint)] {
    switch annotation {
    case .line(let mark):
        return [(.start, CGPoint(x: mark.x, y: mark.y)), (.end, CGPoint(x: mark.x2, y: mark.y2))]
    case .shape(let mark):
        let rect = normalized(CGRect(x: mark.x, y: mark.y, width: mark.w, height: mark.h))
        let midX = rect.midX
        let midY = rect.midY
        return [
            (.nw, CGPoint(x: rect.minX, y: rect.minY)),
            (.n, CGPoint(x: midX, y: rect.minY)),
            (.ne, CGPoint(x: rect.maxX, y: rect.minY)),
            (.e, CGPoint(x: rect.maxX, y: midY)),
            (.se, CGPoint(x: rect.maxX, y: rect.maxY)),
            (.s, CGPoint(x: midX, y: rect.maxY)),
            (.sw, CGPoint(x: rect.minX, y: rect.maxY)),
            (.w, CGPoint(x: rect.minX, y: midY)),
        ]
    default:
        return []
    }
}

func hitHandle(_ annotation: Annotation, _ point: CGPoint, slop: CGFloat) -> Handle? {
    for item in handles(of: annotation).reversed() {
        if abs(item.1.x - point.x) <= slop && abs(item.1.y - point.y) <= slop { return item.0 }
    }
    return nil
}

private func distanceToSegment(_ point: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
    let dx = b.x - a.x
    let dy = b.y - a.y
    let len2 = dx * dx + dy * dy
    let t = len2 == 0 ? 0 : clamp(((point.x - a.x) * dx + (point.y - a.y) * dy) / len2, 0, 1)
    return hypot(point.x - (a.x + t * dx), point.y - (a.y + t * dy))
}

func hit(_ annotation: Annotation, _ point: CGPoint, slop: CGFloat) -> Bool {
    switch annotation {
    case .line(let mark):
        return distanceToSegment(point, CGPoint(x: mark.x, y: mark.y), CGPoint(x: mark.x2, y: mark.y2)) <= max(slop, mark.strokeWidth / 2 + 4)
    case .draw(let mark):
        let box = bounds(of: annotation).insetBy(dx: -(slop + 8), dy: -(slop + 8))
        guard box.contains(point) else { return false }
        if mark.points.count == 1 {
            return hypot(mark.points[0].x - point.x, mark.points[0].y - point.y) <= slop + 4
        }
        for index in 1..<mark.points.count {
            if distanceToSegment(point, mark.points[index - 1], mark.points[index]) <= max(slop, mark.strokeWidth / 2 + 4) {
                return true
            }
        }
        return false
    case .marker(let mark):
        return hypot(mark.x - point.x, mark.y - point.y) <= 16 + slop
    default:
        return bounds(of: annotation).insetBy(dx: -slop, dy: -slop).contains(point)
    }
}

func hitAnnotation(_ annotations: [Annotation], _ point: CGPoint, slop: CGFloat) -> Annotation? {
    for annotation in annotations.reversed() where hit(annotation, point, slop: slop) {
        return annotation
    }
    return nil
}

func isBigEnough(_ annotation: Annotation) -> Bool {
    switch annotation {
    case .line(let mark):
        return hypot(mark.x2 - mark.x, mark.y2 - mark.y) >= 4
    case .draw(let mark):
        return mark.points.count > 1
    case .text, .marker:
        return true
    case .shape(let mark):
        let rect = normalized(CGRect(x: mark.x, y: mark.y, width: mark.w, height: mark.h))
        return rect.width >= 4 && rect.height >= 4
    }
}

func translated(_ annotation: Annotation, dx: CGFloat, dy: CGFloat) -> Annotation {
    switch annotation {
    case .line(var mark):
        mark.x += dx; mark.y += dy; mark.x2 += dx; mark.y2 += dy
        return .line(mark)
    case .draw(var mark):
        mark.points = mark.points.map { CGPoint(x: $0.x + dx, y: $0.y + dy) }
        return .draw(mark)
    case .shape(var mark):
        mark.x += dx; mark.y += dy
        return .shape(mark)
    case .text(var mark):
        mark.x += dx; mark.y += dy
        return .text(mark)
    case .marker(var mark):
        mark.x += dx; mark.y += dy
        return .marker(mark)
    }
}

func resized(_ annotation: Annotation, handle: Handle, dx: CGFloat, dy: CGFloat) -> Annotation {
    switch annotation {
    case .line(var mark):
        if handle == .start { mark.x += dx; mark.y += dy }
        if handle == .end { mark.x2 += dx; mark.y2 += dy }
        return .line(mark)
    case .shape(var mark):
        let rect = normalized(CGRect(x: mark.x, y: mark.y, width: mark.w, height: mark.h))
        var x1 = rect.minX, y1 = rect.minY, x2 = rect.maxX, y2 = rect.maxY
        if handle == .nw || handle == .w || handle == .sw { x1 += dx }
        if handle == .ne || handle == .e || handle == .se { x2 += dx }
        if handle == .nw || handle == .n || handle == .ne { y1 += dy }
        if handle == .sw || handle == .s || handle == .se { y2 += dy }
        mark.x = x1; mark.y = y1; mark.w = x2 - x1; mark.h = y2 - y1
        return .shape(mark)
    default:
        return annotation
    }
}

func finalized(_ annotation: Annotation) -> Annotation {
    if case .shape(var mark) = annotation {
        let rect = normalized(CGRect(x: mark.x, y: mark.y, width: mark.w, height: mark.h))
        mark.x = rect.minX; mark.y = rect.minY; mark.w = rect.width; mark.h = rect.height
        return .shape(mark)
    }
    return annotation
}

func constrainLine(from start: CGPoint, to end: CGPoint, shift: Bool) -> CGPoint {
    guard shift else { return end }
    let dx = end.x - start.x
    let dy = end.y - start.y
    let snapped = (atan2(dy, dx) / (.pi / 4)).rounded() * (.pi / 4)
    let length = hypot(dx, dy)
    return CGPoint(x: start.x + cos(snapped) * length, y: start.y + sin(snapped) * length)
}

func constrainBox(width: CGFloat, height: CGFloat, shift: Bool) -> CGSize {
    guard shift else { return CGSize(width: width, height: height) }
    let size = max(abs(width), abs(height))
    let sx: CGFloat = width < 0 ? -1 : 1
    let sy: CGFloat = height < 0 ? -1 : 1
    return CGSize(width: sx * size, height: sy * size)
}
