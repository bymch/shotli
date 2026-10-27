import AppKit
import Carbon
import SwiftUI

enum CaptureAction: String, CaseIterable {
    case full
    case window
    case area

    var menuTitle: String {
        switch self {
        case .full: return "Capture Full Screen"
        case .window: return "Capture Window"
        case .area: return "Capture Area"
        }
    }

    var hotkeyID: UInt32 {
        switch self {
        case .full: return 1
        case .window: return 2
        case .area: return 3
        }
    }

    static func matching(menuTitle: String) -> CaptureAction? {
        allCases.first { $0.menuTitle == menuTitle }
    }

    static func matching(hotkeyID: UInt32) -> CaptureAction? {
        allCases.first { $0.hotkeyID == hotkeyID }
    }
}

struct ShotShortcut: Equatable, Codable {
    var keyCode: UInt32
    var carbonModifiers: UInt32

    static func preset(_ action: CaptureAction) -> ShotShortcut {
        let modifiers = CarbonModifier.control | CarbonModifier.option | CarbonModifier.command
        switch action {
        case .full: return ShotShortcut(keyCode: 18, carbonModifiers: modifiers)
        case .window: return ShotShortcut(keyCode: 19, carbonModifiers: modifiers)
        case .area: return ShotShortcut(keyCode: 20, carbonModifiers: modifiers)
        }
    }

    var label: String {
        var text = ""
        if carbonModifiers & CarbonModifier.control != 0 { text += "⌃" }
        if carbonModifiers & CarbonModifier.option != 0 { text += "⌥" }
        if carbonModifiers & CarbonModifier.shift != 0 { text += "⇧" }
        if carbonModifiers & CarbonModifier.command != 0 { text += "⌘" }
        text += Self.keyName(keyCode)
        return text
    }

    var modifierMask: NSEvent.ModifierFlags {
        var mask: NSEvent.ModifierFlags = []
        if carbonModifiers & CarbonModifier.control != 0 { mask.insert(.control) }
        if carbonModifiers & CarbonModifier.option != 0 { mask.insert(.option) }
        if carbonModifiers & CarbonModifier.shift != 0 { mask.insert(.shift) }
        if carbonModifiers & CarbonModifier.command != 0 { mask.insert(.command) }
        return mask
    }

    var keyEquivalent: String {
        switch keyCode {
        case 36: return "\r"
        case 48: return "\t"
        case 49: return " "
        case 123: return Self.glyph(NSLeftArrowFunctionKey)
        case 124: return Self.glyph(NSRightArrowFunctionKey)
        case 125: return Self.glyph(NSDownArrowFunctionKey)
        case 126: return Self.glyph(NSUpArrowFunctionKey)
        case 122: return Self.glyph(NSF1FunctionKey)
        case 120: return Self.glyph(NSF2FunctionKey)
        case 99: return Self.glyph(NSF3FunctionKey)
        case 118: return Self.glyph(NSF4FunctionKey)
        case 96: return Self.glyph(NSF5FunctionKey)
        case 97: return Self.glyph(NSF6FunctionKey)
        case 98: return Self.glyph(NSF7FunctionKey)
        case 100: return Self.glyph(NSF8FunctionKey)
        case 101: return Self.glyph(NSF9FunctionKey)
        case 109: return Self.glyph(NSF10FunctionKey)
        case 103: return Self.glyph(NSF11FunctionKey)
        case 111: return Self.glyph(NSF12FunctionKey)
        default:
            let name = Self.keyName(keyCode)
            return name.count == 1 ? name.lowercased() : ""
        }
    }

    static func from(event: NSEvent) -> ShotShortcut? {
        let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
        let primary = mods.contains(.command) || mods.contains(.option) || mods.contains(.control)
        guard primary || isFunctionKey(event.keyCode) else { return nil }
        return ShotShortcut(keyCode: UInt32(event.keyCode), carbonModifiers: carbon(from: mods))
    }

    static func isFunctionKey(_ keyCode: UInt16) -> Bool {
        [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111].contains(keyCode)
    }

    static func carbon(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var value: UInt32 = 0
        if flags.contains(.command) { value |= CarbonModifier.command }
        if flags.contains(.shift) { value |= CarbonModifier.shift }
        if flags.contains(.option) { value |= CarbonModifier.option }
        if flags.contains(.control) { value |= CarbonModifier.control }
        return value
    }

    private static func glyph<T: BinaryInteger>(_ key: T) -> String {
        String(UnicodeScalar(UInt32(key))!)
    }

    private static func keyName(_ keyCode: UInt32) -> String {
        let names: [UInt32: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
            38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
            45: "N", 46: "M", 47: ".", 49: "Space", 50: "`",
            36: "Return", 48: "Tab", 51: "Delete", 53: "Escape",
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
            98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
            123: "Left", 124: "Right", 125: "Down", 126: "Up",
        ]
        return names[keyCode] ?? "Key \(keyCode)"
    }
}

private enum CarbonModifier {
    static let command: UInt32 = 256
    static let shift: UInt32 = 512
    static let option: UInt32 = 2048
    static let control: UInt32 = 4096
}

private struct ShortcutBox: Codable {
    var shortcut: ShotShortcut?
}

private enum StoredShortcut {
    case missing
    case value(ShotShortcut?)
}

private func shotliHotKeyHandler(_ next: EventHandlerCallRef?, _ event: EventRef?, _ user: UnsafeMutableRawPointer?) -> OSStatus {
    guard let event else { return noErr }
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    if status != noErr { return status }
    let id = hotKeyID.id
    DispatchQueue.main.async {
        ShotShortcuts.shared.perform(id: id)
    }
    return noErr
}

final class ShotShortcuts: ObservableObject {
    static let shared = ShotShortcuts()

    @Published private(set) var full: ShotShortcut?
    @Published private(set) var window: ShotShortcut?
    @Published private(set) var area: ShotShortcut?
    @Published var note: String?

    private let defaults = UserDefaults.standard
    private var paused = false
    private var installed = false
    private var refs: [UInt32: EventHotKeyRef] = [:]
    private let signature: OSType = 0x53484F54

    private init() {
        full = ShotShortcut.preset(.full)
        window = ShotShortcut.preset(.window)
        area = ShotShortcut.preset(.area)
        if case let .value(shortcut) = Self.stored(.full) { full = shortcut }
        if case let .value(shortcut) = Self.stored(.window) { window = shortcut }
        if case let .value(shortcut) = Self.stored(.area) { area = shortcut }
    }

    func install() {
        guard !installed else { return }
        installed = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), shotliHotKeyHandler, 1, &spec, nil, nil)
        _ = reregister()
        let refresh = NotificationCenter.default
        refresh.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.announce()
        }
        refresh.addObserver(forName: NSMenu.didBeginTrackingNotification, object: nil, queue: .main) { [weak self] note in
            guard let menu = note.object as? NSMenu else { return }
            self?.apply(to: menu)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.announce()
        }
    }

    func keys(for action: CaptureAction) -> ShotShortcut? {
        switch action {
        case .full: return full
        case .window: return window
        case .area: return area
        }
    }

    func label(for action: CaptureAction) -> String {
        keys(for: action)?.label ?? "None"
    }

    var isDefault: Bool {
        full == ShotShortcut.preset(.full)
            && window == ShotShortcut.preset(.window)
            && area == ShotShortcut.preset(.area)
    }

    var statusTip: String {
        if let area {
            return "Shotli. Area capture is \(area.label)."
        }
        return "Shotli"
    }

    func setPaused(_ paused: Bool) {
        guard self.paused != paused else { return }
        self.paused = paused
        _ = reregister()
    }

    func set(_ shortcut: ShotShortcut?, for action: CaptureAction) {
        if let shortcut, let other = conflict(shortcut, ignoring: action) {
            note = "\(shortcut.label) is already used for \(other.menuTitle)."
            return
        }
        let previous = keys(for: action)
        assign(shortcut, to: action)
        unregisterAll()
        if let shortcut, !probe(shortcut) {
            assign(previous, to: action)
            _ = reregister()
            note = "macOS is already using that shortcut."
            return
        }
        persist(action)
        guard reregister() else {
            assign(previous, to: action)
            persist(action)
            _ = reregister()
            note = "macOS is already using that shortcut."
            announce()
            return
        }
        note = nil
        announce()
    }

    func restoreDefaults() {
        let previous = (full, window, area)
        full = ShotShortcut.preset(.full)
        window = ShotShortcut.preset(.window)
        area = ShotShortcut.preset(.area)
        guard reregister() else {
            (full, window, area) = previous
            _ = reregister()
            note = "macOS is already using one of those shortcuts."
            return
        }
        for action in CaptureAction.allCases { persist(action) }
        note = nil
        announce()
    }

    func perform(id: UInt32) {
        guard let action = CaptureAction.matching(hotkeyID: id) else { return }
        switch action {
        case .full: ScreenCapture.shared.capture(.full)
        case .window: ScreenCapture.shared.capture(.window)
        case .area: ScreenCapture.shared.capture(.area)
        }
    }

    func apply(to menu: NSMenu) {
        for item in menu.items {
            if let action = CaptureAction.matching(menuTitle: item.title) {
                let shortcut = keys(for: action)
                item.keyEquivalent = shortcut?.keyEquivalent ?? ""
                item.keyEquivalentModifierMask = shortcut?.modifierMask ?? []
            }
            if let submenu = item.submenu {
                apply(to: submenu)
            }
        }
    }

    private func conflict(_ shortcut: ShotShortcut, ignoring action: CaptureAction) -> CaptureAction? {
        CaptureAction.allCases.first { other in
            other != action && keys(for: other) == shortcut
        }
    }

    private func assign(_ shortcut: ShotShortcut?, to action: CaptureAction) {
        switch action {
        case .full: full = shortcut
        case .window: window = shortcut
        case .area: area = shortcut
        }
    }

    @discardableResult
    private func reregister() -> Bool {
        unregisterAll()
        var registered: [UInt32: EventHotKeyRef] = [:]
        for action in CaptureAction.allCases {
            guard let shortcut = keys(for: action) else { continue }
            guard let ref = register(shortcut, id: action.hotkeyID) else {
                for existing in registered.values { UnregisterEventHotKey(existing) }
                return false
            }
            registered[action.hotkeyID] = ref
        }
        if paused {
            for existing in registered.values { UnregisterEventHotKey(existing) }
            return true
        }
        refs = registered
        return true
    }

    private func probe(_ shortcut: ShotShortcut) -> Bool {
        guard let ref = register(shortcut, id: 99) else { return false }
        UnregisterEventHotKey(ref)
        return true
    }

    private func register(_ shortcut: ShotShortcut, id: UInt32) -> EventHotKeyRef? {
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            EventHotKeyID(signature: signature, id: id),
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr else { return nil }
        return ref
    }

    private func unregisterAll() {
        for ref in refs.values {
            UnregisterEventHotKey(ref)
        }
        refs.removeAll()
    }

    private func announce() {
        (NSApp.delegate as? AppDelegate)?.refreshCaptureShortcuts()
    }

    private func persist(_ action: CaptureAction) {
        let box = ShortcutBox(shortcut: keys(for: action))
        if let data = try? JSONEncoder().encode(box) {
            defaults.set(data, forKey: Self.key(action))
        }
    }

    private static func stored(_ action: CaptureAction) -> StoredShortcut {
        guard UserDefaults.standard.object(forKey: key(action)) != nil else { return .missing }
        guard let data = UserDefaults.standard.data(forKey: key(action)),
              let box = try? JSONDecoder().decode(ShortcutBox.self, from: data) else {
            return .missing
        }
        return .value(box.shortcut)
    }

    private static func key(_ action: CaptureAction) -> String {
        "shotli.shortcut.\(action.rawValue)"
    }
}

struct ShortcutWell: NSViewRepresentable {
    let action: CaptureAction

    func makeNSView(context: Context) -> ShortcutWellView {
        let view = ShortcutWellView()
        view.action = action
        return view
    }

    func updateNSView(_ view: ShortcutWellView, context: Context) {
        view.action = action
        view.shortcut = ShotShortcuts.shared.keys(for: action)
        view.needsDisplay = true
    }
}

final class ShortcutWellView: NSView {
    var action: CaptureAction = .area
    var shortcut: ShotShortcut?
    var onFinished: (() -> Void)?
    private var recording = false
    private var keyMonitor: Any?
    private var mouseMonitor: Any?

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func mouseDown(with event: NSEvent) {
        if recording {
            stop()
        } else {
            start()
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
        ShotliGlass.controlFill.setFill()
        path.fill()
        let ink = ShotliGlass.inkColor
        (recording ? ink : ShotliGlass.hairlineColor).setStroke()
        path.lineWidth = recording ? 1.5 : 1
        path.stroke()
        let title = recording ? "Press keys" : (shortcut?.label ?? "None")
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineBreakMode = .byTruncatingTail
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: recording ? ink : NSColor.secondaryLabelColor,
            .paragraphStyle: style,
        ]
        let size = title.size(withAttributes: attrs)
        let textRect = NSRect(
            x: 8,
            y: (bounds.height - size.height) / 2,
            width: max(0, bounds.width - 16),
            height: size.height
        )
        (title as NSString).draw(in: textRect, withAttributes: attrs)
    }

    private func start() {
        recording = true
        needsDisplay = true
        toolTip = "Press a shortcut. Escape cancels. Delete clears it."
        ShotShortcuts.shared.setPaused(true)
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.recording, !event.isARepeat else { return event }
            self.handle(event)
            return nil
        }
        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, self.recording else { return event }
            let point = self.convert(event.locationInWindow, from: nil)
            if event.window !== self.window || !self.bounds.contains(point) {
                DispatchQueue.main.async { [weak self] in self?.stop() }
            }
            return event
        }
    }

    private func handle(_ event: NSEvent) {
        if event.keyCode == 53 {
            DispatchQueue.main.async { [weak self] in self?.stop() }
            return
        }
        if event.keyCode == 51 || event.keyCode == 117 {
            let action = self.action
            DispatchQueue.main.async {
                ShotShortcuts.shared.set(nil, for: action)
                self.stop()
            }
            return
        }
        guard let shortcut = ShotShortcut.from(event: event) else { return }
        let action = self.action
        DispatchQueue.main.async {
            ShotShortcuts.shared.set(shortcut, for: action)
            self.stop()
        }
    }

    private func stop() {
        guard recording else { return }
        recording = false
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
        keyMonitor = nil
        mouseMonitor = nil
        toolTip = "Click, then press a shortcut. Delete clears it."
        ShotShortcuts.shared.setPaused(false)
        shortcut = ShotShortcuts.shared.keys(for: action)
        needsDisplay = true
    }

    deinit {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
        if recording {
            ShotShortcuts.shared.setPaused(false)
        }
    }
}
