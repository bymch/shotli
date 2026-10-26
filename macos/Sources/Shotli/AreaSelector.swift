import AppKit
import CoreGraphics
import ImageIO
import ScreenCaptureKit
import UniformTypeIdentifiers

final class AreaSelector {
    static let shared = AreaSelector()
    private(set) var isActive = false
    private var windows: [NSWindow] = []
    private var host: NSScreen?
    private var rect: CGRect = .zero
    private var adjusting = false
    private var monitor: Any?

    func begin() {
        guard !isActive else { return }
        isActive = true
        adjusting = false
        rect = .zero
        host = nil
        windows = NSScreen.screens.map { screen in
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.hidesOnDeactivate = false
            window.sharingType = .none
            window.isReleasedWhenClosed = false
            let view = AreaOverlay(selector: self, screen: screen)
            window.contentView = view
            window.makeKeyAndOrderFront(nil)
            return window
        }
        NSApp.activate(ignoringOtherApps: true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isActive else { return event }
            return self.key(event)
        }
        NSCursor.crosshair.set()
    }

    func selection(on screen: NSScreen) -> CGRect? {
        guard host === screen, rect.width > 1, rect.height > 1 else { return nil }
        return rect
    }

    func isAdjusting(on screen: NSScreen) -> Bool {
        adjusting && host == screen
    }

    func mouseDown(on screen: NSScreen, at point: CGPoint) {
        host = screen
        adjusting = false
        rect = CGRect(origin: point, size: .zero)
        refresh()
    }

    func mouseDragged(to point: CGPoint, anchor: CGPoint) {
        rect = CGRect(
            x: min(anchor.x, point.x),
            y: min(anchor.y, point.y),
            width: abs(point.x - anchor.x),
            height: abs(point.y - anchor.y)
        )
        refresh()
    }

    func mouseMoved(to point: CGPoint, bounds: CGRect) {
        guard adjusting, host != nil else {
            NSCursor.crosshair.set()
            return
        }
        cursor(for: point, in: rect).set()
    }

    func mouseUp(at point: CGPoint, anchor: CGPoint, bounds: CGRect) {
        rect = CGRect(
            x: min(anchor.x, point.x),
            y: min(anchor.y, point.y),
            width: abs(point.x - anchor.x),
            height: abs(point.y - anchor.y)
        ).intersection(bounds)
        guard rect.width >= 4, rect.height >= 4 else {
            rect = .zero
            adjusting = false
            refresh()
            return
        }
        adjusting = true
        refresh()
    }

    func move(_ start: CGRect, by delta: CGPoint, bounds: CGRect) {
        var next = start
        next.origin.x = min(max(0, start.minX + delta.x), max(0, bounds.width - start.width))
        next.origin.y = min(max(0, start.minY + delta.y), max(0, bounds.height - start.height))
        rect = next
        refresh()
    }

    func resize(_ start: CGRect, handle: AreaHandle, to point: CGPoint, bounds: CGRect) {
        var next = start
        switch handle {
        case .west, .northWest, .southWest:
            next.origin.x = min(point.x, start.maxX - 4)
            next.size.width = start.maxX - next.origin.x
        case .east, .northEast, .southEast:
            next.size.width = max(4, point.x - start.minX)
        default:
            break
        }
        switch handle {
        case .north, .northWest, .northEast:
            next.origin.y = min(point.y, start.maxY - 4)
            next.size.height = start.maxY - next.origin.y
        case .south, .southWest, .southEast:
            next.size.height = max(4, point.y - start.minY)
        default:
            break
        }
        rect = next.intersection(bounds)
        if rect.width < 4 || rect.height < 4 { rect = start }
        refresh()
    }

    func commit() {
        guard isActive, let screen = host, rect.width >= 4, rect.height >= 4 else { return }
        let local = rect
        let scale = screen.backingScaleFactor
        let displayID = screen.displayID
        let appKit = CGRect(
            x: screen.frame.minX + local.minX,
            y: screen.frame.maxY - local.maxY,
            width: local.width,
            height: local.height
        )
        tearDown()
        Task {
            let image = await AreaGrab.image(displayID: displayID, points: local, scale: scale, appKit: appKit)
            DispatchQueue.main.async {
                guard let image, let url = AreaGrab.write(image) else {
                    EditorModel.shared.notice = "Couldn't capture that area."
                    ScreenCapture.shared.revealEditor()
                    return
                }
                ScreenCapture.shared.adopt(url)
            }
        }
    }

    func cancel() {
        tearDown()
        ScreenCapture.shared.revealEditor()
    }

    private func key(_ event: NSEvent) -> NSEvent? {
        switch event.keyCode {
        case 53:
            cancel()
            return nil
        case 36, 76:
            if adjusting { commit() }
            return nil
        case 123, 124, 125, 126:
            guard adjusting, let screen = host else { return nil }
            let step: CGFloat = event.modifierFlags.contains(.shift) ? 10 : 1
            var delta = CGPoint.zero
            if event.keyCode == 123 { delta.x = -step }
            if event.keyCode == 124 { delta.x = step }
            if event.keyCode == 125 { delta.y = step }
            if event.keyCode == 126 { delta.y = -step }
            move(rect, by: delta, bounds: CGRect(origin: .zero, size: screen.frame.size))
            return nil
        default:
            return event
        }
    }

    private func refresh() {
        for window in windows {
            window.contentView?.needsDisplay = true
        }
    }

    private func tearDown() {
        isActive = false
        adjusting = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        for window in windows {
            window.orderOut(nil)
            window.close()
        }
        windows = []
        NSCursor.arrow.set()
    }

    private func cursor(for point: CGPoint, in rect: CGRect) -> NSCursor {
        switch AreaHandle.hit(point, in: rect) {
        case .move: return .openHand
        case .none: return .crosshair
        default: return .crosshair
        }
    }

}

enum AreaHandle {
    case none, move
    case north, south, east, west
    case northEast, northWest, southEast, southWest

    static func hit(_ point: CGPoint, in rect: CGRect) -> AreaHandle {
        guard rect.width > 1 else { return .none }
        let slop: CGFloat = 10
        let nearLeft = abs(point.x - rect.minX) <= slop
        let nearRight = abs(point.x - rect.maxX) <= slop
        let nearTop = abs(point.y - rect.minY) <= slop
        let nearBottom = abs(point.y - rect.maxY) <= slop
        let insideX = point.x >= rect.minX - slop && point.x <= rect.maxX + slop
        let insideY = point.y >= rect.minY - slop && point.y <= rect.maxY + slop
        if nearTop && nearLeft { return .northWest }
        if nearTop && nearRight { return .northEast }
        if nearBottom && nearLeft { return .southWest }
        if nearBottom && nearRight { return .southEast }
        if nearTop && insideX { return .north }
        if nearBottom && insideX { return .south }
        if nearLeft && insideY { return .west }
        if nearRight && insideY { return .east }
        if rect.contains(point) { return .move }
        return .none
    }
}

private final class AreaOverlay: NSView {
    let screen: NSScreen
    private let selector: AreaSelector
    private var anchor = CGPoint.zero
    private var dragStart = CGRect.zero
    private var handle: AreaHandle = .none

    init(selector: AreaSelector, screen: NSScreen) {
        self.selector = selector
        self.screen = screen
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { nil }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
        window?.acceptsMouseMovedEvents = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let hole = selector.selection(on: screen)
        let shade = NSBezierPath(rect: bounds)
        if let hole {
            shade.append(NSBezierPath(rect: hole))
        }
        shade.windingRule = .evenOdd
        NSColor.black.withAlphaComponent(0.42).setFill()
        shade.fill()
        guard let hole else { return }
        NSColor.white.setStroke()
        let border = NSBezierPath(rect: hole.insetBy(dx: 0.5, dy: 0.5))
        border.lineWidth = 1.5
        border.stroke()
        if selector.isAdjusting(on: screen) {
            for point in handlePoints(hole) {
                let mark = NSBezierPath(ovalIn: CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8))
                NSColor.white.setFill()
                mark.fill()
                NSColor.black.withAlphaComponent(0.45).setStroke()
                mark.lineWidth = 1
                mark.stroke()
            }
        }
        drawReadout(hole)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if event.clickCount == 2, selector.isAdjusting(on: screen) {
            selector.commit()
            return
        }
        if let hole = selector.selection(on: screen), selector.isAdjusting(on: screen) {
            let hit = AreaHandle.hit(point, in: hole)
            if hit != .none {
                handle = hit
                anchor = point
                dragStart = hole
                return
            }
        }
        handle = .none
        anchor = point
        selector.mouseDown(on: screen, at: point)
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        switch handle {
        case .none:
            selector.mouseDragged(to: point, anchor: anchor)
        case .move:
            selector.move(dragStart, by: CGPoint(x: point.x - anchor.x, y: point.y - anchor.y), bounds: bounds)
        default:
            selector.resize(dragStart, handle: handle, to: point, bounds: bounds)
        }
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        selector.mouseMoved(to: point, bounds: bounds)
    }

    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if handle == .none {
            selector.mouseUp(at: point, anchor: anchor, bounds: bounds)
        }
        handle = .none
    }

    private func handlePoints(_ rect: CGRect) -> [CGPoint] {
        [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.midX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.minX, y: rect.midY),
            CGPoint(x: rect.maxX, y: rect.midY),
            CGPoint(x: rect.minX, y: rect.maxY),
            CGPoint(x: rect.midX, y: rect.midY),
            CGPoint(x: rect.maxX, y: rect.maxY),
        ]
    }

    private func drawReadout(_ hole: CGRect) {
        let scale = screen.backingScaleFactor
        let width = Int((hole.width * scale).rounded())
        let height = Int((hole.height * scale).rounded())
        let text = selector.isAdjusting(on: screen) ? "\(width) × \(height)   Return to capture · Esc to cancel" : "\(width) × \(height)"
        let font = NSFont.systemFont(ofSize: 12, weight: .medium)
        let size = (text as NSString).size(withAttributes: [.font: font])
        var origin = CGPoint(x: hole.minX, y: hole.maxY + 8)
        if origin.y + size.height + 10 > bounds.height {
            origin.y = max(8, hole.minY - size.height - 16)
        }
        origin.x = min(max(8, origin.x), max(8, bounds.width - size.width - 20))
        let background = CGRect(x: origin.x - 8, y: origin.y - 5, width: size.width + 16, height: size.height + 10)
        NSColor.black.withAlphaComponent(0.78).setFill()
        NSBezierPath(roundedRect: background, xRadius: 7, yRadius: 7).fill()
        (text as NSString).draw(at: origin, withAttributes: [
            .font: font,
            .foregroundColor: NSColor.white,
        ])
    }
}

private enum AreaGrab {
    static func image(displayID: CGDirectDisplayID, points: CGRect, scale: CGFloat, appKit: CGRect) async -> CGImage? {
        if #available(macOS 14.0, *) {
            if let image = await modern(displayID: displayID, points: points, scale: scale) {
                return image
            }
        }
        return legacy(appKit)
    }

    @available(macOS 14.0, *)
    private static func modern(displayID: CGDirectDisplayID, points: CGRect, scale: CGFloat) async -> CGImage? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first(where: { $0.displayID == displayID }) else { return nil }
            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            config.sourceRect = points
            config.width = max(1, Int((points.width * scale).rounded()))
            config.height = max(1, Int((points.height * scale).rounded()))
            config.showsCursor = false
            config.capturesAudio = false
            return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        } catch {
            return nil
        }
    }

    private static func legacy(_ rect: CGRect) -> CGImage? {
        let primary = NSScreen.screens.first { $0.frame.origin == .zero } ?? NSScreen.main
        let height = primary?.frame.height ?? 0
        let global = CGRect(x: rect.minX, y: height - rect.maxY, width: rect.width, height: rect.height)
        return CGWindowListCreateImage(global, .optionOnScreenOnly, kCGNullWindowID, [.bestResolution])
    }

    static func write(_ image: CGImage) -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("shotli-capture-\(UUID().uuidString).png")
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return url
    }
}

private extension NSScreen {
    var displayID: CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        guard let number = deviceDescription[key] as? NSNumber else { return 0 }
        return CGDirectDisplayID(number.uint32Value)
    }
}
