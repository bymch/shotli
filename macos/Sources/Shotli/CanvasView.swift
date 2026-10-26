import AppKit
import SwiftUI

struct CanvasView: NSViewRepresentable {
    @ObservedObject var model: EditorModel
    var viewport: CGSize

    func makeNSView(context: Context) -> EditorCanvas {
        let view = EditorCanvas()
        view.model = model
        view.viewport = viewport
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return view
    }

    func updateNSView(_ view: EditorCanvas, context: Context) {
        view.model = model
        if view.viewport != viewport {
            view.viewport = viewport
            view.needsDisplay = true
        }
        if view.seenFit != model.fitRequest {
            view.seenFit = model.fitRequest
            view.fitToScreen()
        }
        if view.seenActual != model.actualRequest {
            view.seenActual = model.actualRequest
            if model.actualRequest > 0 { view.actualSize() }
        }
        if view.seenZoomIn != model.zoomInRequest {
            view.seenZoomIn = model.zoomInRequest
            if model.zoomInRequest > 0 { view.zoomBy(1.1) }
        }
        if view.seenZoomOut != model.zoomOutRequest {
            view.seenZoomOut = model.zoomOutRequest
            if model.zoomOutRequest > 0 { view.zoomBy(1 / 1.1) }
        }
        view.needsDisplay = true
    }
}

final class EditorCanvas: NSView {
    var model: EditorModel!
    var viewport: CGSize = .zero
    private var zoom: CGFloat = 1
    private var pan = CGPoint.zero
    var seenFit = 0
    var seenActual = 0
    var seenZoomIn = 0
    var seenZoomOut = 0
    private var draft: Annotation?
    private var cropDraft: CGRect?
    private var spaceDown = false

    private enum Drag {
        case none
        case create(CGPoint, Annotation)
        case move(Annotation, CGPoint)
        case resize(Annotation, Handle, CGPoint)
        case crop(CGPoint)
        case pan(CGPoint, CGPoint)
    }

    private var drag: Drag = .none

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        focusRingType = .none
        wantsLayer = true
        layer?.masksToBounds = true
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) { nil }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }

    override func layout() {
        super.layout()
        publishZoom()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        drawStage()
        guard model.picture != nil else { return }
        guard let image = renderComposition(
            picture: model.picture,
            crop: model.crop,
            style: model.style,
            annotations: model.annotations,
            draft: draft,
            interactive: true,
            cropDraft: cropDraft,
            selectedID: model.selectedID
        ) else { return }
        let layout = composition(picture: model.picture, crop: model.crop, style: model.style)
        let place = placement(for: layout.size)
        let dest = CGRect(x: place.origin.x, y: place.origin.y, width: layout.size.width * place.scale, height: layout.size.height * place.scale)
        NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height)).draw(in: dest)
    }

    private func drawStage() {
        NSColor(srgbRed: 0.945, green: 0.945, blue: 0.945, alpha: 1).setFill()
        bounds.fill()
        NSColor(white: 0.82, alpha: 1).setFill()
        let step: CGFloat = 16
        var y: CGFloat = 8
        while y < bounds.height {
            var x: CGFloat = 8
            while x < bounds.width {
                NSBezierPath(ovalIn: CGRect(x: x, y: y, width: 1.4, height: 1.4)).fill()
                x += step
            }
            y += step
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let viewPoint = convert(event.locationInWindow, from: nil)
        if spaceDown || event.buttonNumber == 2 {
            drag = .pan(viewPoint, pan)
            return
        }
        guard let imagePoint = imagePoint(from: viewPoint) else {
            model.selectedID = nil
            return
        }
        let shift = event.modifierFlags.contains(.shift)
        let slop = 8 / max(placement(for: composition(picture: model.picture, crop: model.crop, style: model.style).size).scale, 0.05)
        switch model.tool {
        case .select:
            if let selected = model.selected, let handle = hitHandle(selected, imagePoint, slop: slop) {
                model.beginGesture()
                drag = .resize(selected, handle, imagePoint)
            } else if let hit = hitAnnotation(model.annotations, imagePoint, slop: slop) {
                model.selectedID = hit.id
                model.beginGesture()
                drag = .move(hit, imagePoint)
            } else {
                model.selectedID = nil
            }
        case .crop:
            model.beginGesture()
            drag = .crop(imagePoint)
            cropDraft = CGRect(origin: imagePoint, size: .zero)
        case .text:
            placeInstant(at: imagePoint, shift: shift)
        case .marker:
            placeInstant(at: imagePoint, shift: shift)
        default:
            let created = makeAnnotation(at: imagePoint)
            model.beginGesture()
            draft = created
            drag = .create(imagePoint, created)
        }
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let viewPoint = convert(event.locationInWindow, from: nil)
        let shift = event.modifierFlags.contains(.shift)
        switch drag {
        case .pan(let start, let origin):
            pan = CGPoint(x: origin.x + viewPoint.x - start.x, y: origin.y + viewPoint.y - start.y)
            settle()
        case .move(let origin, let start):
            guard let point = imagePoint(from: viewPoint) else { return }
            replace(translated(origin, dx: point.x - start.x, dy: point.y - start.y))
        case .resize(let origin, let handle, let start):
            guard let point = imagePoint(from: viewPoint) else { return }
            replace(resized(origin, handle: handle, dx: point.x - start.x, dy: point.y - start.y))
        case .crop(let start):
            guard let point = imagePoint(from: viewPoint), let picture = model.picture else { return }
            let end = constrainLine(from: start, to: point, shift: shift)
            let size = constrainBox(width: end.x - start.x, height: end.y - start.y, shift: shift)
            cropDraft = CGRect(x: start.x, y: start.y, width: size.width, height: size.height)
            _ = picture
        case .create(let start, let seed):
            guard let point = imagePoint(from: viewPoint) else { return }
            draft = updated(seed, from: start, to: point, shift: shift)
        default:
            break
        }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        switch drag {
        case .create:
            if let draft, isBigEnough(draft) {
                model.annotations.append(finalized(draft))
                model.selectedID = draft.id
                model.tool = .select
            }
            self.draft = nil
            model.endGesture()
        case .crop:
            if let cropDraft, let picture = model.picture {
                let bounds = CGRect(x: 0, y: 0, width: picture.width, height: picture.height)
                let next = clamp(normalized(cropDraft), to: bounds)
                if next.width >= 8 && next.height >= 8 { model.crop = next }
            }
            self.cropDraft = nil
            model.endGesture()
            model.tool = .select
        case .move, .resize:
            model.endGesture()
        case .pan, .none:
            break
        }
        drag = .none
        needsDisplay = true
    }

    override func scrollWheel(with event: NSEvent) {
        let anchor = convert(event.locationInWindow, from: nil)
        if event.modifierFlags.contains(.command) || event.modifierFlags.contains(.control) {
            zoomAt(1 + event.scrollingDeltaY * 0.012, anchor: anchor)
        } else {
            pan.x += event.scrollingDeltaX
            pan.y += event.scrollingDeltaY
            settle()
            needsDisplay = true
        }
    }

    override func magnify(with event: NSEvent) {
        let anchor = convert(event.locationInWindow, from: nil)
        zoomAt(1 + event.magnification, anchor: anchor)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 49 {
            spaceDown = true
            return
        }
        if window?.firstResponder is NSTextView { return }
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
        if event.modifierFlags.contains(.command) { return }
        let tools: [String: Tool] = ["v": .select, "k": .crop, "r": .rect, "f": .rectFill, "c": .circle, "l": .line, "a": .arrow, "d": .draw, "t": .text, "n": .marker, "p": .pixelate, "b": .blur]
        if let tool = tools[key] {
            model.tool = tool
            return
        }
        if event.keyCode == 51 || event.keyCode == 117 {
            model.deleteSelected()
            return
        }
        super.keyDown(with: event)
    }

    override func keyUp(with event: NSEvent) {
        if event.keyCode == 49 {
            spaceDown = false
            return
        }
        super.keyUp(with: event)
    }

    override func otherMouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let viewPoint = convert(event.locationInWindow, from: nil)
        drag = .pan(viewPoint, pan)
    }

    override func otherMouseDragged(with event: NSEvent) {
        let viewPoint = convert(event.locationInWindow, from: nil)
        if case .pan(let start, let origin) = drag {
            pan = CGPoint(x: origin.x + viewPoint.x - start.x, y: origin.y + viewPoint.y - start.y)
            settle()
            needsDisplay = true
        }
    }

    override func otherMouseUp(with event: NSEvent) {
        if case .pan = drag { drag = .none }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], let url = urls.first else { return false }
        model.load(url: url)
        return true
    }

    func fitToScreen() {
        zoom = 1
        pan = .zero
        publishZoom()
        needsDisplay = true
    }

    func actualSize() {
        guard model.picture != nil else { return }
        let layout = composition(picture: model.picture, crop: model.crop, style: model.style)
        let fit = fitScale(layout.size)
        zoom = clampZoom(fit > 0 ? 1 / fit : 1)
        pan = .zero
        settle()
        publishZoom()
        needsDisplay = true
    }

    func zoomBy(_ factor: CGFloat) {
        let box = stageBox()
        zoomAt(factor, anchor: CGPoint(x: box.midX, y: box.midY))
    }

    private func placeInstant(at point: CGPoint, shift: Bool) {
        _ = shift
        let annotation = makeAnnotation(at: point)
        model.beginGesture()
        model.annotations.append(annotation)
        model.selectedID = annotation.id
        model.endGesture()
        model.tool = .select
    }

    private func makeAnnotation(at point: CGPoint) -> Annotation {
        let id = UUID().uuidString
        let brush = model.brush
        switch model.tool {
        case .rect:
            return .shape(ShapeMark(id: id, kind: .rect, color: brush.color, strokeWidth: brush.strokeWidth, x: point.x, y: point.y, w: 0, h: 0, amount: 0))
        case .rectFill:
            return .shape(ShapeMark(id: id, kind: .rectFill, color: brush.color, strokeWidth: brush.strokeWidth, x: point.x, y: point.y, w: 0, h: 0, amount: 0))
        case .circle:
            return .shape(ShapeMark(id: id, kind: .circle, color: brush.color, strokeWidth: brush.strokeWidth, x: point.x, y: point.y, w: 0, h: 0, amount: 0))
        case .pixelate:
            return .shape(ShapeMark(id: id, kind: .pixelate, color: brush.color, strokeWidth: brush.strokeWidth, x: point.x, y: point.y, w: 0, h: 0, amount: brush.pixelSize))
        case .blur:
            return .shape(ShapeMark(id: id, kind: .blur, color: brush.color, strokeWidth: brush.strokeWidth, x: point.x, y: point.y, w: 0, h: 0, amount: brush.blur))
        case .line:
            return .line(LineMark(id: id, arrow: false, color: brush.color, strokeWidth: brush.strokeWidth, x: point.x, y: point.y, x2: point.x, y2: point.y))
        case .arrow:
            return .line(LineMark(id: id, arrow: true, color: brush.color, strokeWidth: brush.strokeWidth, x: point.x, y: point.y, x2: point.x, y2: point.y))
        case .draw:
            return .draw(DrawMark(id: id, color: brush.color, strokeWidth: brush.strokeWidth, points: [point]))
        case .text:
            return .text(TextMark(id: id, color: brush.color, x: point.x, y: point.y, text: "Text", fontSize: brush.fontSize))
        case .marker:
            return .marker(MarkerMark(id: id, color: brush.color, x: point.x, y: point.y, n: model.nextMarkerNumber()))
        case .select, .crop:
            return .marker(MarkerMark(id: id, color: brush.color, x: point.x, y: point.y, n: 1))
        }
    }

    private func updated(_ seed: Annotation, from start: CGPoint, to point: CGPoint, shift: Bool) -> Annotation {
        let end = constrainLine(from: start, to: point, shift: shift)
        let size = constrainBox(width: end.x - start.x, height: end.y - start.y, shift: shift)
        switch seed {
        case .shape(var mark):
            mark.w = size.width
            mark.h = size.height
            return .shape(mark)
        case .line(var mark):
            mark.x2 = end.x
            mark.y2 = end.y
            return .line(mark)
        case .draw(var mark):
            mark.points.append(point)
            return .draw(mark)
        default:
            return seed
        }
    }

    private func replace(_ annotation: Annotation) {
        guard let index = model.annotations.firstIndex(where: { $0.id == annotation.id }) else { return }
        model.annotations[index] = annotation
        model.selectedID = annotation.id
    }

    /// The rectangle the picture is fitted into. Prefer the SwiftUI stage size so a
    /// view that has grown past the window cannot scale the shot until it is cropped.
    private func stageBox() -> CGRect {
        let width = viewport.width > 80 ? viewport.width : bounds.width
        let height = viewport.height > 80 ? viewport.height : bounds.height
        let boxW = bounds.width > 80 ? min(bounds.width, width) : width
        let boxH = bounds.height > 80 ? min(bounds.height, height) : height
        return CGRect(x: 0, y: 0, width: max(1, boxW), height: max(1, boxH))
    }

    private func fitScale(_ size: CGSize) -> CGFloat {
        let box = stageBox()
        guard size.width > 1, size.height > 1, box.width > 80, box.height > 80 else { return 1 }
        let availW = box.width - 72
        let availH = box.height - 160
        guard availW > 40, availH > 40 else { return 1 }
        return max(0.02, min(availW / size.width, availH / size.height))
    }

    private func currentScale() -> CGFloat {
        guard model?.picture != nil else { return 1 }
        let layout = composition(picture: model.picture, crop: model.crop, style: model.style)
        return fitScale(layout.size) * zoom
    }

    private func clampZoom(_ value: CGFloat) -> CGFloat {
        min(40, max(0.2, value))
    }

    private func settle() {
        guard model?.picture != nil else { return }
        let layout = composition(picture: model.picture, crop: model.crop, style: model.style)
        guard layout.size.width > 1, layout.size.height > 1 else { return }
        let box = stageBox()
        let scale = fitScale(layout.size) * zoom
        let limitX = max(0, layout.size.width * scale - box.width) / 2
        let limitY = max(0, layout.size.height * scale - box.height) / 2
        pan.x = min(max(pan.x, -limitX), limitX)
        pan.y = min(max(pan.y, -limitY), limitY)
    }

    private func zoomAt(_ factor: CGFloat, anchor: CGPoint) {
        guard model?.picture != nil, factor > 0, factor.isFinite else { return }
        let layout = composition(picture: model.picture, crop: model.crop, style: model.style)
        let old = max(currentScale(), 0.05)
        let fit = max(fitScale(layout.size), 0.02)
        let nextZoom = clampZoom(zoom * factor)
        let next = fit * nextZoom
        let place = placement(for: layout.size)
        let canvasX = (anchor.x - place.origin.x) / old
        let canvasY = (anchor.y - place.origin.y) / old
        zoom = nextZoom
        let centered = CGPoint(x: (stageBox().width - layout.size.width * next) / 2, y: (stageBox().height - layout.size.height * next) / 2)
        let origin = CGPoint(x: anchor.x - canvasX * next, y: anchor.y - canvasY * next)
        pan = CGPoint(x: origin.x - centered.x, y: origin.y - centered.y)
        settle()
        publishZoom()
        needsDisplay = true
    }

    private func publishZoom() {
        let percent = Int((currentScale() * 100).rounded())
        guard model?.zoomPercent != percent else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.model?.zoomPercent != percent else { return }
            self.model?.zoomPercent = percent
        }
    }

    private func placement(for size: CGSize) -> (scale: CGFloat, origin: CGPoint) {
        let box = stageBox()
        guard size.width > 1, size.height > 1, box.width > 80, box.height > 80 else { return (1, .zero) }
        let scale = fitScale(size) * zoom
        let limitX = max(0, size.width * scale - box.width) / 2
        let limitY = max(0, size.height * scale - box.height) / 2
        let held = CGPoint(x: min(max(pan.x, -limitX), limitX), y: min(max(pan.y, -limitY), limitY))
        let origin = CGPoint(
            x: (box.width - size.width * scale) / 2 + held.x,
            y: (box.height - size.height * scale) / 2 + held.y
        )
        return (scale, origin)
    }

    private func imagePoint(from viewPoint: CGPoint) -> CGPoint? {
        guard model.picture != nil else { return nil }
        let layout = composition(picture: model.picture, crop: model.crop, style: model.style)
        let place = placement(for: layout.size)
        guard place.scale > 0 else { return nil }
        let comp = CGPoint(x: (viewPoint.x - place.origin.x) / place.scale, y: (viewPoint.y - place.origin.y) / place.scale)
        let crop = activeCrop(picture: model.picture, crop: model.crop) ?? .zero
        return CGPoint(x: comp.x - layout.image.minX + crop.minX, y: comp.y - layout.image.minY + crop.minY)
    }
}
