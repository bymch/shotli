import AppKit
import SwiftUI

struct CanvasView: NSViewRepresentable {
    @ObservedObject var model: EditorModel

    func makeNSView(context: Context) -> EditorCanvas {
        let view = EditorCanvas()
        view.model = model
        return view
    }

    func updateNSView(_ view: EditorCanvas, context: Context) {
        view.model = model
        if view.seenFit != model.fitRequest {
            view.seenFit = model.fitRequest
            view.resetView()
        } else {
            view.needsDisplay = true
        }
    }
}

final class EditorCanvas: NSView {
    var model: EditorModel!
    private var zoom: CGFloat = 1
    private var pan = CGPoint.zero
    var seenFit = 0
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
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        NSColor(srgbRed: 0.945, green: 0.945, blue: 0.945, alpha: 1).setFill()
        dirtyRect.fill()
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
        if event.modifierFlags.contains(.command) {
            let factor = 1 + event.scrollingDeltaY * 0.012
            zoom = min(8, max(0.2, zoom * factor))
        } else {
            pan.x += event.scrollingDeltaX
            pan.y += event.scrollingDeltaY
        }
        needsDisplay = true
    }

    override func magnify(with event: NSEvent) {
        zoom = min(8, max(0.2, zoom * (1 + event.magnification)))
        needsDisplay = true
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

    func resetView() {
        zoom = 1
        pan = .zero
        needsDisplay = true
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

    private func placement(for size: CGSize) -> (scale: CGFloat, origin: CGPoint) {
        guard size.width > 1, size.height > 1, bounds.width > 80, bounds.height > 80 else { return (1, .zero) }
        let fit = min((bounds.width - 64) / size.width, (bounds.height - 64) / size.height)
        let scale = max(0.02, fit) * zoom
        let origin = CGPoint(x: (bounds.width - size.width * scale) / 2 + pan.x, y: (bounds.height - size.height * scale) / 2 + pan.y)
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
