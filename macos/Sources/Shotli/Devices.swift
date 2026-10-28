import AppKit

enum DeviceCategory: String, CaseIterable, Identifiable {
    case phone, tablet, laptop, desktop, watch
    var id: String { rawValue }
    var label: String {
        switch self {
        case .phone: return "Phone"
        case .tablet: return "Tablet"
        case .laptop: return "Laptop"
        case .desktop: return "Desktop"
        case .watch: return "Watch"
        }
    }
    var symbol: String {
        switch self {
        case .phone: return "iphone"
        case .tablet: return "ipad"
        case .laptop: return "laptopcomputer"
        case .desktop: return "desktopcomputer"
        case .watch: return "applewatch"
        }
    }
}

enum DeviceFit: String, Equatable, Hashable {
    case fit, fill
}

enum DeviceCutout: String, Equatable {
    case none, island, notch, hole
}

enum DeviceShell: String, Equatable {
    case handset, slate, laptop, allInOne, monitor, watch
}

struct DeviceFinish: Identifiable, Equatable {
    var id: String
    var name: String
    var body: String
    var bezel: String
    var accent: String
}

struct DeviceSpec: Identifiable, Equatable {
    var id: String
    var name: String
    var maker: String
    var category: DeviceCategory
    var resolution: String
    var bodyAspect: CGFloat
    var screen: CGRect
    var screenRadius: CGFloat
    var cutout: DeviceCutout
    var shell: DeviceShell
    var finishes: [DeviceFinish]
    var licence: String
    var isNew: Bool = false

    func finish(_ id: String?) -> DeviceFinish {
        if let id, let match = finishes.first(where: { $0.id == id }) { return match }
        return finishes[0]
    }
}

struct DeviceFrameLayout: Equatable {
    var canvas: CGSize
    var body: CGRect
    var screen: CGRect
    var image: CGRect
}

enum DeviceLibrary {
    static let licence = "Original Shotli vector frame, drawn for this app. No third-party product artwork."

    static let all: [DeviceSpec] = phones + tablets + laptops + desktops + watches

    /// Previous Shotli names. Saved projects keep their mockup and resolve to the current model.
    static let legacyIDs: [String: String] = [
        "pocket": "iphone-17",
        "pocket-air": "iphone-air",
        "pocket-pro": "iphone-18-pro",
        "pocket-pro-max": "iphone-18-pro-max",
        "compact": "iphone-17e",
        "slate": "ipad-air-11",
        "slate-air": "ipad-air-11",
        "slate-pro-11": "ipad-pro-11",
        "slate-pro-13": "ipad-pro-13",
        "folio-13": "macbook-air-13",
        "folio-14": "macbook-pro-14",
        "studio-14": "macbook-pro-14",
        "studio-16": "macbook-pro-16",
        "halo-24": "imac-24",
        "panel-27": "imac-24",
        "panel-32": "imac-24",
        "pulse-41": "watch-series-12-42",
        "pulse-45": "watch-series-12-46",
        "pulse-ultra": "watch-ultra-4",
    ]

    static func device(_ id: String?) -> DeviceSpec? {
        guard var id else { return nil }
        if let mapped = legacyIDs[id] { id = mapped }
        return all.first { $0.id == id }
    }

    static func active(_ style: ShotliStyle) -> DeviceSpec? {
        guard style.frame == .none, !style.hideMockup else { return nil }
        return device(style.deviceID)
    }

    static func matching(_ query: String, category: DeviceCategory?) -> [DeviceSpec] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return all.filter { device in
            if let category, device.category != category { return false }
            guard !needle.isEmpty else { return true }
            let haystack = "\(device.name) \(device.maker) \(device.category.label) \(device.resolution)".lowercased()
            return haystack.contains(needle)
        }
    }

    static func frameLayout(device: DeviceSpec, shot: CGSize, padding: CGFloat, scale: CGFloat, fit: DeviceFit) -> DeviceFrameLayout {
        let shotW = max(1, shot.width)
        let shotH = max(1, shot.height)
        let screenAspect = device.bodyAspect * device.screen.width / max(device.screen.height, 0.01)
        let shotAspect = shotW / shotH
        let screenW: CGFloat
        let screenH: CGFloat
        if fit == .fill {
            if shotAspect > screenAspect {
                screenH = shotH
                screenW = screenH * screenAspect
            } else {
                screenW = shotW
                screenH = screenW / screenAspect
            }
        } else if shotAspect > screenAspect {
            screenW = shotW
            screenH = screenW / screenAspect
        } else {
            screenH = shotH
            screenW = screenH * screenAspect
        }
        let bodyW = screenW / max(device.screen.width, 0.01)
        let bodyH = screenH / max(device.screen.height, 0.01)
        let clamped = min(1, max(0.45, scale))
        let pad = max(0, padding)
        let canvas = CGSize(width: bodyW + pad * 2, height: bodyH + pad * 2)
        let body = CGRect(
            x: pad + (bodyW - bodyW * clamped) / 2,
            y: pad + (bodyH - bodyH * clamped) / 2,
            width: bodyW * clamped,
            height: bodyH * clamped
        )
        let placed = screenPlacement(device: device, body: body, shot: CGSize(width: shotW, height: shotH), fit: fit)
        return DeviceFrameLayout(canvas: canvas, body: body, screen: placed.screen, image: placed.image)
    }

    static func screenPlacement(device: DeviceSpec, body: CGRect, shot: CGSize, fit: DeviceFit) -> (screen: CGRect, image: CGRect) {
        let screen = CGRect(
            x: body.minX + device.screen.minX * body.width,
            y: body.minY + device.screen.minY * body.height,
            width: device.screen.width * body.width,
            height: device.screen.height * body.height
        )
        return (screen, placedShot(shot, in: screen, fit: fit))
    }

    static func body(in slot: CGRect, device: DeviceSpec) -> CGRect {
        placedShot(CGSize(width: device.bodyAspect, height: 1), in: slot, fit: .fit)
    }

    static func preview(device: DeviceSpec, finishID: String?, shot: CGImage?, size: CGSize) -> NSImage {
        let key = "\(device.id)|\(finishID ?? "")|\(Int(size.width))x\(Int(size.height))|\(shot.map { UInt(bitPattern: Unmanaged.passUnretained($0).toOpaque()) } ?? 0)" as NSString
        if let cached = previewCache.object(forKey: key) { return cached }
        let image = NSImage(size: size)
        image.lockFocus()
        if let context = NSGraphicsContext.current?.cgContext {
            let body = CGRect(x: 8, y: 8, width: size.width - 16, height: size.height - 16)
            let fitted = aspectFit(CGSize(width: device.bodyAspect, height: 1), in: body)
            let shotSize = shot.map { CGSize(width: $0.width, height: $0.height) } ?? CGSize(width: 9, height: 16)
            let placed = screenPlacement(device: device, body: fitted, shot: shotSize, fit: .fill)
            drawDevice(
                device,
                finish: device.finish(finishID),
                body: fitted,
                screen: placed.screen,
                image: placed.image,
                shot: shot,
                shadow: 10,
                in: context,
                canvasHeight: size.height
            )
        }
        image.unlockFocus()
        previewCache.setObject(image, forKey: key)
        return image
    }

    static func check() -> String? {
        if all.count < 16 { return "device catalogue is thin" }
        for category in DeviceCategory.allCases {
            if all.filter({ $0.category == category }).isEmpty { return "\(category.label) has no devices" }
        }
        if matching("macbook", category: nil).contains(where: { $0.category != .laptop }) { return "macbook search left laptops" }
        if !matching("macbook", category: .phone).isEmpty { return "phone filter kept a laptop" }
        if !matching("zzzz-no-device", category: nil).isEmpty { return "empty search returned devices" }
        if matching("", category: .watch).count != all.filter({ $0.category == .watch }).count { return "watch filter" }
        if all.contains(where: { $0.name.localizedCaseInsensitiveContains("17 air") || $0.name.hasPrefix("Pocket") }) {
            return "unofficial product name"
        }
        guard let air = device("iphone-air"), air.name == "iPhone Air", air.isNew else { return "air name" }
        guard let pro = device("iphone-18-pro"), pro.isNew, pro.cutout == .island else { return "pro badge" }
        guard let phone = device("iphone-17"), !phone.isNew, phone.finishes.count >= 4 else { return "iphone 17" }
        if device("iphone-17e")?.cutout != DeviceCutout.none { return "17e invented an island" }
        if air.screen.height <= pro.screen.height { return "air bezel" }
        guard let saved = device("pocket"), saved.id == "iphone-17" else { return "old project device" }
        if phone.finish("missing").id != phone.finishes[0].id { return "unknown finish" }
        for device in all {
            if device.finishes.count < 2 { return "\(device.name) needs finishes" }
            if device.screen.minX < 0 || device.screen.minY < 0 || device.screen.maxX > 1.001 || device.screen.maxY > 1.001 {
                return "\(device.name) screen leaves the body"
            }
            if device.screen.width < 0.4 || device.screen.height < 0.2 { return "\(device.name) screen collapsed" }
            let shot = CGSize(width: 400, height: 800)
            let fitted = frameLayout(device: device, shot: shot, padding: 20, scale: 1, fit: .fit)
            if !fitted.body.contains(fitted.screen.insetBy(dx: 0.5, dy: 0.5)) { return "\(device.name) screen left the body" }
            if !fitted.screen.insetBy(dx: -0.5, dy: -0.5).contains(fitted.image) { return "\(device.name) picture left the screen" }
            let filled = frameLayout(device: device, shot: shot, padding: 0, scale: 1, fit: .fill)
            if filled.image.width + 0.5 < filled.screen.width || filled.image.height + 0.5 < filled.screen.height {
                return "\(device.name) fill did not cover the screen"
            }
        }
        if let issue = samplePocket() { return issue }
        if let issue = renderPocket() { return issue }
        if let issue = styleRoundTrip() { return issue }
        return nil
    }

    private static func samplePocket() -> String? {
        guard let graphite = paintPocket("black"), let silver = paintPocket("white") else { return "device sample" }
        if graphite.red < 400 { return "screenshot missed the screen" }
        if graphite.dark < 80 { return "screenshot covered the bezel" }
        if graphite.clear < 20 { return "device filled the canvas" }
        if silver.light <= graphite.light { return "finish did not change the body" }
        if silver.red < 400 { return "finish cleared the screenshot" }
        return nil
    }

    private static func paintPocket(_ finish: String) -> (red: Int, dark: Int, light: Int, clear: Int)? {
        guard let pocket = device("pocket") else { return nil }
        let width = 120
        let height = 220
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let shot = solidImage(width: 30, height: 60, red: 0.85, green: 0.15, blue: 0.12) else { return nil }
        let body = CGRect(x: 10, y: 8, width: 100, height: 204)
        let placed = screenPlacement(device: pocket, body: body, shot: CGSize(width: 30, height: 60), fit: .fill)
        drawDevice(
            pocket, finish: pocket.finish(finish), body: body, screen: placed.screen, image: placed.image,
            shot: shot, shadow: 0, in: context, canvasHeight: CGFloat(height)
        )
        return tally(context, width: width, height: height)
    }

    private static func tally(_ context: CGContext, width: Int, height: Int) -> (red: Int, dark: Int, light: Int, clear: Int) {
        guard let data = context.data else { return (0, 0, 0, 0) }
        let bytes = context.bytesPerRow
        let pointer = data.bindMemory(to: UInt8.self, capacity: bytes * height)
        var red = 0, dark = 0, light = 0, clear = 0
        for row in 0..<height {
            for x in 0..<width {
                let offset = row * bytes + x * 4
                let r = pointer[offset]
                let g = pointer[offset + 1]
                let b = pointer[offset + 2]
                let a = pointer[offset + 3]
                if a < 20 { clear += 1 }
                else if r > 180 && g < 90 && b < 90 { red += 1 }
                else if r < 90 && g < 110 && b < 120 { dark += 1 }
                else if r > 210 && g > 210 && b > 210 { light += 1 }
            }
        }
        return (red, dark, light, clear)
    }

    private static func renderPocket() -> String? {
        guard let pocket = device("pocket"),
              let shot = solidImage(width: 90, height: 180, red: 0.85, green: 0.12, blue: 0.1) else { return "device shot" }
        var style = Presets.style(40, 8, 0, .none, .color("#FFFFFF"))
        style.deviceID = pocket.id
        style.deviceFinish = "black"
        style.deviceFit = .fit
        style.deviceScale = 1
        style.shadow = 0
        let picture = LoadedPicture(image: shot, name: "Sample", scaled: false)
        guard let rendered = renderComposition(
            picture: picture, crop: nil, style: style, annotations: [], draft: nil, interactive: false
        ) else { return "device export" }
        let layout = frameLayout(device: pocket, shot: CGSize(width: 90, height: 180), padding: 40, scale: 1, fit: .fit)
        if rendered.width != Int(ceil(layout.canvas.width)) || rendered.height != Int(ceil(layout.canvas.height)) {
            return "device canvas"
        }
        var browser = style
        browser.frame = .browser
        if active(browser) != nil { return "frame kept the device" }
        var missing = style
        missing.deviceID = "not-a-device"
        if active(missing) != nil { return "unknown device" }
        guard let blue = solidImage(width: 80, height: 140, red: 0.15, green: 0.35, blue: 0.8) else { return "second shot" }
        let layers = [
            ShotLayer(id: "a", image: shot, name: "red", x: 0.04, y: 0.12, width: 0.44, height: 0.76, radius: 16, shadow: 12, order: 0, sourceRelative: nil, sourceSHA: nil, sourceData: nil, sourceFileName: nil),
            ShotLayer(id: "b", image: blue, name: "blue", x: 0.52, y: 0.12, width: 0.44, height: 0.76, radius: 16, shadow: 12, order: 1, sourceRelative: nil, sourceSHA: nil, sourceData: nil, sourceFileName: nil),
        ]
        if renderShot(picture: picture, crop: nil, style: style, annotations: [], layers: layers, draft: nil, interactive: false) == nil {
            return "two devices"
        }
        if matching("series 12", category: nil).count != 2 { return "series search" }
        return nil
    }

    private static func styleRoundTrip() -> String? {
        var style = Presets.style(48, 12, 20, .none, .color("#123456"))
        style.deviceID = "macbook-pro-14"
        style.deviceFinish = "space-black"
        style.deviceFit = .fill
        style.deviceScale = 0.82
        let kept = style.background
        style.deviceFinish = "silver"
        if style.background != kept || style.deviceID != "macbook-pro-14" { return "finish reset the composition" }
        style.deviceFinish = "space-black"
        do {
            let encoded = try JSONEncoder().encode(StyleFile(style))
            let decoded = try JSONDecoder().decode(StyleFile.self, from: encoded).style
            if decoded.deviceID != "macbook-pro-14" || decoded.deviceFinish != "space-black" || decoded.deviceFit != .fill || abs(decoded.deviceScale - 0.82) > 0.001 {
                return "device style round trip"
            }
            var plain = Presets.style(48, 12, 20, .none, .color("#123456"))
            plain.deviceID = nil
            let legacy = try JSONEncoder().encode(StyleFile(plain))
            if String(data: legacy, encoding: .utf8)?.contains("\"device\"") == true { return "empty device was written" }
            let restored = try JSONDecoder().decode(StyleFile.self, from: legacy).style
            if restored.deviceID != nil || restored.deviceFit != .fit { return "legacy style invented a device" }
        } catch {
            return "device style could not be saved"
        }
        return nil
    }

    private static func solidImage(width: Int, height: Int, red: CGFloat, green: CGFloat, blue: CGFloat) -> CGImage? {
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.setFillColor(NSColor(srgbRed: red, green: green, blue: blue, alpha: 1).cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    private static let previewCache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 80
        return cache
    }()
}

func drawDevice(
    _ device: DeviceSpec,
    finish: DeviceFinish,
    body: CGRect,
    screen: CGRect,
    image: CGRect,
    shot: CGImage?,
    shadow: CGFloat,
    in context: CGContext,
    canvasHeight: CGFloat
) {
    let bodyColor = NSColor(hex: finish.body) ?? .darkGray
    let bezel = NSColor(hex: finish.bezel) ?? .black
    let accent = NSColor(hex: finish.accent) ?? .gray
    context.saveGState()
    if shadow > 0.5 {
        context.setShadow(offset: CGSize(width: 0, height: -max(8, shadow * 0.28)), blur: max(12, shadow * 0.55), color: NSColor.black.withAlphaComponent(0.28).cgColor)
    }
    switch device.shell {
    case .handset:
        drawPhoneButtons(body: body, metal: bodyColor, context: context, height: canvasHeight)
        let rim: CGFloat = device.id == "iphone-air" ? 0.008 : (device.id == "iphone-17e" ? 0.018 : 0.014)
        let corner: CGFloat = device.id == "iphone-air" ? 0.20 : (device.id == "iphone-17e" ? 0.13 : 0.16)
        drawHandsetChassis(body: body, metal: bodyColor, context: context, height: canvasHeight, rim: rim, corner: corner)
    case .slate:
        fillRound(body, radius: body.width * 0.08, color: bodyColor, context: context, height: canvasHeight)
    case .laptop:
        let parts = laptopMetrics(device, body: body)
        fillRound(parts.deck, radius: 10, color: bodyColor, context: context, height: canvasHeight)
        fillRound(parts.lid, radius: 14, color: bezel, context: context, height: canvasHeight)
    case .allInOne:
        let panel = CGRect(x: body.minX, y: body.minY, width: body.width, height: body.height * 0.82)
        fillRound(panel, radius: 16, color: bezel, context: context, height: canvasHeight)
        let neck = CGRect(x: body.midX - body.width * 0.035, y: panel.maxY, width: body.width * 0.07, height: body.height * 0.08)
        fillRound(neck, radius: 3, color: accent, context: context, height: canvasHeight)
        let foot = CGRect(x: body.midX - body.width * 0.22, y: body.maxY - body.height * 0.045, width: body.width * 0.44, height: body.height * 0.04)
        fillRound(foot, radius: 6, color: accent, context: context, height: canvasHeight)
    case .monitor:
        let panel = CGRect(x: body.minX, y: body.minY, width: body.width, height: body.height * 0.9)
        fillRound(panel, radius: 12, color: bezel, context: context, height: canvasHeight)
        let foot = CGRect(x: body.midX - body.width * 0.16, y: body.maxY - body.height * 0.05, width: body.width * 0.32, height: body.height * 0.045)
        fillRound(foot, radius: 4, color: accent, context: context, height: canvasHeight)
    case .watch:
        let ultra = device.id == "watch-ultra-4"
        let strap = CGRect(x: body.midX - body.width * 0.22, y: body.minY + body.height * 0.04, width: body.width * 0.44, height: body.height * 0.92)
        fillRound(strap, radius: 16, color: accent, context: context, height: canvasHeight)
        let caseRect = screen.insetBy(dx: -screen.width * (ultra ? 0.08 : 0.1), dy: -screen.height * (ultra ? 0.08 : 0.1))
        fillRound(caseRect, radius: caseRect.width * (ultra ? 0.16 : 0.28), color: bodyColor, context: context, height: canvasHeight)
    }
    context.restoreGState()

    context.saveGState()
    context.addPath(screenClip(device, screen: screen, height: canvasHeight))
    context.clip(using: device.cutout == .none ? .winding : .evenOdd)
    if let shot {
        context.interpolationQuality = .high
        context.draw(shot, in: flip(image, height: canvasHeight))
    } else {
        context.setFillColor(NSColor(srgbRed: 0.75, green: 0.8, blue: 0.86, alpha: 1).cgColor)
        context.fill(flip(screen, height: canvasHeight))
    }
    context.restoreGState()

    if device.shell == .handset {
        drawScreenGlass(screen, context: context, height: canvasHeight)
    } else {
        context.saveGState()
        context.setStrokeColor(bezel.withAlphaComponent(0.9).cgColor)
        context.setLineWidth(max(2, screen.width * 0.012))
        let lip = screen.insetBy(dx: 1, dy: 1)
        context.addPath(roundPath(lip, radius: screenRadius(device, screen: lip), height: canvasHeight))
        context.strokePath()
        context.restoreGState()
    }

    drawCutout(device, screen: screen, color: bezel, accent: accent, context: context, height: canvasHeight)
    if device.shell == .handset {
        drawAntennaGaps(body: body, metal: bodyColor, context: context, height: canvasHeight)
    } else {
        drawHardware(device, body: body, color: accent, context: context, height: canvasHeight)
    }
}

private func drawCutout(_ device: DeviceSpec, screen: CGRect, color: NSColor, accent: NSColor, context: CGContext, height: CGFloat) {
    switch device.cutout {
    case .none:
        return
    case .island:
        let pill = islandRect(screen)
        fillRound(pill, radius: pill.height / 2, color: NSColor(srgbRed: 0.02, green: 0.02, blue: 0.025, alpha: 1), context: context, height: height)
        let lens = pill.height * 0.62
        let glass = CGRect(x: pill.maxX - pill.height * 0.82, y: pill.midY - lens / 2, width: lens, height: lens)
        context.setFillColor(NSColor(srgbRed: 0.05, green: 0.1, blue: 0.16, alpha: 1).cgColor)
        context.fillEllipse(in: flip(glass, height: height))
        context.setStrokeColor(accent.withAlphaComponent(0.85).cgColor)
        context.setLineWidth(max(0.6, glass.width * 0.08))
        context.strokeEllipse(in: flip(glass.insetBy(dx: 0.3, dy: 0.3), height: height))
        let spec = CGRect(x: glass.minX + glass.width * 0.18, y: glass.minY + glass.height * 0.16, width: glass.width * 0.34, height: glass.height * 0.34)
        context.setFillColor(NSColor.white.withAlphaComponent(0.72).cgColor)
        context.fillEllipse(in: flip(spec, height: height))
        let sensor = CGRect(x: glass.minX - pill.height * 0.42, y: pill.midY - pill.height * 0.12, width: pill.height * 0.22, height: pill.height * 0.22)
        context.setFillColor(NSColor(srgbRed: 0.1, green: 0.1, blue: 0.12, alpha: 1).cgColor)
        context.fillEllipse(in: flip(sensor, height: height))
    case .notch:
        let bite = notchRect(screen)
        fillRound(bite, radius: bite.height * 0.45, color: NSColor(srgbRed: 0.02, green: 0.02, blue: 0.025, alpha: 1), context: context, height: height)
        let slot = CGRect(x: bite.midX - bite.width * 0.12, y: bite.midY - bite.height * 0.08, width: bite.width * 0.24, height: max(2, bite.height * 0.14))
        fillRound(slot, radius: slot.height / 2, color: NSColor(white: 0.25, alpha: 1), context: context, height: height)
    case .hole:
        let dot = holeRect(device, screen: screen)
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: flip(dot, height: height))
    }
}

private func drawHardware(_ device: DeviceSpec, body: CGRect, color: NSColor, context: CGContext, height: CGFloat) {
    context.setFillColor(color.cgColor)
    switch device.shell {
    case .handset:
        break
    case .slate:
        let button = CGRect(x: body.maxX - 2, y: body.minY + body.height * 0.2, width: 3, height: body.height * 0.06)
        fillRound(button, radius: 1.5, color: color, context: context, height: height)
    case .laptop:
        let deck = laptopMetrics(device, body: body).deck
        let keys = CGRect(x: deck.minX + deck.width * 0.12, y: deck.minY + deck.height * 0.22, width: deck.width * 0.76, height: deck.height * 0.38)
        context.setStrokeColor(color.withAlphaComponent(0.45).cgColor)
        context.setLineWidth(1)
        context.stroke(flip(keys, height: height))
        let pad = CGRect(x: deck.midX - deck.width * 0.1, y: deck.minY + deck.height * 0.64, width: deck.width * 0.2, height: deck.height * 0.2)
        context.strokeEllipse(in: flip(pad, height: height))
    case .watch:
        let crown = CGRect(x: body.maxX - body.width * 0.16, y: body.midY - 5, width: body.width * 0.06, height: 10)
        fillRound(crown, radius: 2, color: color, context: context, height: height)
        if device.id == "watch-ultra-4" {
            let action = CGRect(x: body.minX + body.width * 0.1, y: body.midY - 8, width: body.width * 0.055, height: 16)
            fillRound(action, radius: 3, color: color, context: context, height: height)
        }
    case .allInOne, .monitor:
        break
    }
}

private func screenClip(_ device: DeviceSpec, screen: CGRect, height: CGFloat) -> CGPath {
    let path = CGMutablePath()
    path.addPath(roundPath(screen, radius: screenRadius(device, screen: screen), height: height))
    switch device.cutout {
    case .none:
        break
    case .island:
        let pill = islandRect(screen)
        path.addPath(roundPath(pill, radius: pill.height / 2, height: height))
    case .notch:
        let bite = notchRect(screen)
        path.addPath(roundPath(bite, radius: bite.height * 0.45, height: height))
    case .hole:
        path.addEllipse(in: flip(holeRect(device, screen: screen), height: height))
    }
    return path
}

private func screenRadius(_ device: DeviceSpec, screen: CGRect) -> CGFloat {
    device.screenRadius * min(screen.width, screen.height)
}

private func laptopMetrics(_ device: DeviceSpec, body: CGRect) -> (deck: CGRect, lid: CGRect) {
    let lidFrac = min(0.94, device.screen.maxY + 0.055)
    let deckFrac = min(0.20, max(0.08, 1 - lidFrac + 0.015))
    let deck = CGRect(x: body.minX, y: body.maxY - body.height * deckFrac, width: body.width, height: body.height * deckFrac)
    let lid = CGRect(x: body.minX + body.width * 0.025, y: body.minY, width: body.width * 0.95, height: body.height * lidFrac)
    return (deck, lid)
}

private func holeRect(_ device: DeviceSpec, screen: CGRect) -> CGRect {
    let size = max(4, screen.width * (device.shell == .laptop || device.shell == .allInOne ? 0.018 : 0.028))
    let x = device.id.hasPrefix("ipad-pro") ? screen.maxX - screen.width * 0.08 : screen.midX - size / 2
    return CGRect(x: x, y: screen.minY + screen.height * 0.028, width: size, height: size)
}

private func drawHandsetChassis(body: CGRect, metal: NSColor, context: CGContext, height: CGFloat, rim: CGFloat, corner: CGFloat) {
    let radius = body.width * corner
    let light = shade(metal, 0.07)
    let dark = shade(metal, -0.05)
    fillRoundGradient(body, radius: radius, colors: [light, metal, dark], context: context, height: height)
    context.saveGState()
    context.setStrokeColor(shade(metal, 0.22).withAlphaComponent(0.9).cgColor)
    context.setLineWidth(max(1, body.width * 0.01))
    context.addPath(roundPath(body.insetBy(dx: body.width * 0.008, dy: body.width * 0.008), radius: radius * 0.94, height: height))
    context.strokePath()
    context.setStrokeColor(NSColor.black.withAlphaComponent(0.28).cgColor)
    context.setLineWidth(max(1, body.width * 0.008))
    context.addPath(roundPath(body.insetBy(dx: 0.8, dy: 0.8), radius: radius, height: height))
    context.strokePath()
    context.restoreGState()
    let lipInset = body.width * rim
    let lip = body.insetBy(dx: lipInset, dy: lipInset)
    fillRound(lip, radius: max(4, radius - lipInset), color: NSColor(srgbRed: 0.015, green: 0.015, blue: 0.02, alpha: 1), context: context, height: height)
}

private func drawPhoneButtons(body: CGRect, metal: NSColor, context: CGContext, height: CGFloat) {
    let reach = max(2, body.width * 0.018)
    let left = body.minX - reach * 0.72
    let right = body.maxX - reach * 0.28
    let buttons = [
        CGRect(x: left, y: body.minY + body.height * 0.15, width: reach, height: body.height * 0.045),
        CGRect(x: left, y: body.minY + body.height * 0.22, width: reach, height: body.height * 0.07),
        CGRect(x: left, y: body.minY + body.height * 0.305, width: reach, height: body.height * 0.07),
        CGRect(x: right, y: body.minY + body.height * 0.24, width: reach, height: body.height * 0.11),
    ]
    for button in buttons {
        fillRoundGradient(button, radius: button.width / 2, colors: [shade(metal, 0.12), metal, shade(metal, -0.12)], context: context, height: height)
    }
}

private func drawAntennaGaps(body: CGRect, metal: NSColor, context: CGContext, height: CGFloat) {
    let ink = shade(metal, -0.28)
    let thickness = max(1.5, body.height * 0.008)
    let depth = body.width * 0.016
    let marks: [(CGFloat, Bool)] = [(0.1, true), (0.74, true), (0.18, false), (0.68, false)]
    for mark in marks {
        let x = mark.1 ? body.minX : body.maxX - depth
        let rect = CGRect(x: x, y: body.minY + body.height * mark.0, width: depth, height: thickness)
        fillRound(rect, radius: thickness / 2, color: ink, context: context, height: height)
    }
}

private func drawScreenGlass(_ screen: CGRect, context: CGContext, height: CGFloat) {
    context.saveGState()
    context.addPath(roundPath(screen, radius: screen.width * 0.12, height: height))
    context.clip()
    let band = CGRect(x: screen.minX, y: screen.minY, width: screen.width, height: screen.height * 0.22)
    let flipped = flip(band, height: height)
    let colors = [NSColor.white.withAlphaComponent(0.16).cgColor, NSColor.white.withAlphaComponent(0).cgColor] as CFArray
    if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: nil) {
        context.drawLinearGradient(gradient, start: CGPoint(x: flipped.midX, y: flipped.maxY), end: CGPoint(x: flipped.midX, y: flipped.minY), options: [])
    }
    context.restoreGState()
}

private func islandRect(_ screen: CGRect) -> CGRect {
    let width = screen.width * 0.28
    let pill = max(6, screen.width * 0.074)
    return CGRect(x: screen.midX - width / 2, y: screen.minY + screen.height * 0.016, width: width, height: pill)
}

private func notchRect(_ screen: CGRect) -> CGRect {
    CGRect(x: screen.midX - screen.width * 0.18, y: screen.minY - screen.height * 0.01, width: screen.width * 0.36, height: max(8, screen.height * 0.052))
}

private func shade(_ color: NSColor, _ amount: CGFloat) -> NSColor {
    guard let rgb = color.usingColorSpace(.sRGB) else { return color }
    func channel(_ value: CGFloat) -> CGFloat { min(1, max(0, value + amount)) }
    return NSColor(srgbRed: channel(rgb.redComponent), green: channel(rgb.greenComponent), blue: channel(rgb.blueComponent), alpha: rgb.alphaComponent)
}

private func fillRoundGradient(_ rect: CGRect, radius: CGFloat, colors: [NSColor], context: CGContext, height: CGFloat) {
    context.saveGState()
    context.addPath(roundPath(rect, radius: radius, height: height))
    context.clip()
    let flipped = flip(rect, height: height)
    let cgColors = colors.map { $0.cgColor } as CFArray
    if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cgColors, locations: nil) {
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: flipped.minX, y: flipped.maxY),
            end: CGPoint(x: flipped.maxX, y: flipped.minY),
            options: []
        )
    }
    context.restoreGState()
}

private func fillRound(_ rect: CGRect, radius: CGFloat, color: NSColor, context: CGContext, height: CGFloat) {
    context.setFillColor(color.cgColor)
    context.addPath(roundPath(rect, radius: radius, height: height))
    context.fillPath()
}

private func roundPath(_ rect: CGRect, radius: CGFloat, height: CGFloat) -> CGPath {
    let flipped = flip(rect, height: height)
    let curve = min(radius, abs(flipped.width) / 2, abs(flipped.height) / 2)
    return CGPath(roundedRect: flipped, cornerWidth: curve, cornerHeight: curve, transform: nil)
}

private func flip(_ rect: CGRect, height: CGFloat) -> CGRect {
    CGRect(x: rect.minX, y: height - rect.maxY, width: rect.width, height: rect.height)
}

private func placedShot(_ shot: CGSize, in screen: CGRect, fit: DeviceFit) -> CGRect {
    guard shot.width > 0, shot.height > 0, screen.width > 0, screen.height > 0 else { return screen }
    let shotAspect = shot.width / shot.height
    let boxAspect = screen.width / screen.height
    var size = screen.size
    let wide = shotAspect > boxAspect
    if fit == .fit {
        if wide { size.height = screen.width / shotAspect } else { size.width = screen.height * shotAspect }
    } else if wide {
        size.width = screen.height * shotAspect
    } else {
        size.height = screen.width / shotAspect
    }
    return CGRect(x: screen.midX - size.width / 2, y: screen.midY - size.height / 2, width: size.width, height: size.height)
}

private func aspectFit(_ aspect: CGSize, in rect: CGRect) -> CGRect {
    placedShot(aspect, in: rect, fit: .fit)
}

private extension DeviceLibrary {
    // Names, diagonals, pixel resolutions, case sizes, and finishes are Apple's,
    // checked 28 October 2026. Pixel counts are physical pixels, not points.
    // Frames are original vectors. Finish colours approximate the published names.
    // iPhone Duo is omitted: a single rectangle would misrepresent the folding display.

    static var phones: [DeviceSpec] {
        [
            handset(
                "iphone-18-pro", "iPhone 18 Pro", "6.3-inch, 2622 × 1206 px",
                width: 71.9, height: 150.0, pixels: (2622, 1206), bezel: 0.034,
                radius: 0.12, cutout: .island, finishes: proFinishes, fresh: true,
                page: "https://www.apple.com/iphone-18-pro/specs/"
            ),
            handset(
                "iphone-18-pro-max", "iPhone 18 Pro Max", "6.9-inch, 2868 × 1320 px",
                width: 78.0, height: 163.4, pixels: (2868, 1320), bezel: 0.032,
                radius: 0.12, cutout: .island, finishes: proFinishes, fresh: true,
                page: "https://www.apple.com/iphone-18-pro/specs/"
            ),
            handset(
                "iphone-air", "iPhone Air", "6.5-inch, 2736 × 1260 px",
                width: 74.7, height: 156.2, pixels: (2736, 1260), bezel: 0.018,
                radius: 0.14, cutout: .island, finishes: airFinishes, fresh: true,
                page: "https://www.apple.com/iphone-air/specs/"
            ),
            handset(
                "iphone-17", "iPhone 17", "6.3-inch, 2622 × 1206 px",
                width: 71.5, height: 149.6, pixels: (2622, 1206), bezel: 0.036,
                radius: 0.12, cutout: .island, finishes: phone17Finishes, fresh: false,
                page: "https://www.apple.com/iphone-17/specs/"
            ),
            handset(
                "iphone-17e", "iPhone 17e", "6.1-inch, 2532 × 1170 px",
                width: 71.5, height: 146.7, pixels: (2532, 1170), bezel: 0.042,
                radius: 0.10, cutout: .none, finishes: phone17eFinishes, fresh: false,
                page: "https://www.apple.com/iphone-17e/specs/"
            ),
        ]
    }

    static var tablets: [DeviceSpec] {
        [
            slate(
                "ipad-pro-11", "iPad Pro 11-inch", "2420 × 1668 px",
                width: 177.5, height: 249.7, pixels: (2420, 1668), bezel: 0.028,
                finishes: proTabletFinishes, fresh: false,
                page: "https://www.apple.com/ipad-pro/specs/"
            ),
            slate(
                "ipad-pro-13", "iPad Pro 13-inch", "2752 × 2064 px",
                width: 215.5, height: 281.6, pixels: (2752, 2064), bezel: 0.024,
                finishes: proTabletFinishes, fresh: false,
                page: "https://www.apple.com/ipad-pro/specs/"
            ),
            slate(
                "ipad-air-11", "iPad Air 11-inch", "2360 × 1640 px",
                width: 178.5, height: 247.6, pixels: (2360, 1640), bezel: 0.030,
                finishes: airTabletFinishes, fresh: false,
                page: "https://www.apple.com/ipad-air/specs/"
            ),
            slate(
                "ipad-air-13", "iPad Air 13-inch", "2732 × 2048 px",
                width: 214.9, height: 280.6, pixels: (2732, 2048), bezel: 0.026,
                finishes: airTabletFinishes, fresh: false,
                page: "https://www.apple.com/ipad-air/specs/"
            ),
            slate(
                "ipad-mini", "iPad mini", "8.5-inch, 2316 × 1512 px",
                width: 132.6, height: 195.3, pixels: (2316, 1512), bezel: 0.026,
                finishes: miniFinishes, fresh: true,
                page: "https://www.apple.com/ipad-mini/specs/"
            ),
        ]
    }

    static var laptops: [DeviceSpec] {
        [
            laptop(
                "macbook-air-13", "MacBook Air (13-inch)", "13.6-inch, 2560 × 1664 px",
                width: 30.41, depth: 21.5, deck: 0.06, pixels: (2560, 1664), glass: 0.88,
                finishes: airLaptopFinishes, page: "https://www.apple.com/macbook-air/specs/"
            ),
            laptop(
                "macbook-air-15", "MacBook Air (15-inch)", "15.3-inch, 2880 × 1864 px",
                width: 34.04, depth: 23.76, deck: 0.055, pixels: (2880, 1864), glass: 0.88,
                finishes: airLaptopFinishes, page: "https://www.apple.com/macbook-air/specs/"
            ),
            laptop(
                "macbook-pro-14", "MacBook Pro (14-inch)", "14.2-inch, 3024 × 1964 px",
                width: 31.26, depth: 22.12, deck: 0.09, pixels: (3024, 1964), glass: 0.84,
                finishes: proLaptopFinishes, page: "https://www.apple.com/macbook-pro/specs/"
            ),
            laptop(
                "macbook-pro-16", "MacBook Pro (16-inch)", "16.2-inch, 3456 × 2234 px",
                width: 35.57, depth: 24.81, deck: 0.09, pixels: (3456, 2234), glass: 0.84,
                finishes: proLaptopFinishes, page: "https://www.apple.com/macbook-pro/specs/"
            ),
        ]
    }

    static var desktops: [DeviceSpec] {
        [
            desktop(
                "imac-24", "iMac (24-inch)", "4480 × 2520 px",
                width: 21.5, height: 18.1, pixels: (4480, 2520),
                page: "https://www.apple.com/imac/specs/"
            ),
        ]
    }

    static var watches: [DeviceSpec] {
        [
            watch(
                "watch-series-12-42", "Apple Watch Series 12 (42mm)", "374 × 446 px",
                caseW: 37, caseH: 42, band: 0.85, pixels: (374, 446), radius: 0.22,
                finishes: seriesFinishes, page: "https://www.apple.com/apple-watch-series-12/specs/"
            ),
            watch(
                "watch-series-12-46", "Apple Watch Series 12 (46mm)", "416 × 496 px",
                caseW: 40, caseH: 46, band: 0.85, pixels: (416, 496), radius: 0.22,
                finishes: seriesFinishes, page: "https://www.apple.com/apple-watch-series-12/specs/"
            ),
            watch(
                "watch-ultra-4", "Apple Watch Ultra 4", "422 × 514 px",
                caseW: 44, caseH: 49, band: 0.70, pixels: (422, 514), radius: 0.14,
                finishes: ultraFinishes, page: "https://www.apple.com/apple-watch-ultra-4/specs/"
            ),
        ]
    }

    static func handset(
        _ id: String, _ name: String, _ resolution: String,
        width: CGFloat, height: CGFloat, pixels: (CGFloat, CGFloat), bezel: CGFloat,
        radius: CGFloat, cutout: DeviceCutout, finishes: [DeviceFinish], fresh: Bool, page: String
    ) -> DeviceSpec {
        let aspect = width / height
        let pixelAspect = pixels.1 / pixels.0
        return DeviceSpec(
            id: id, name: name, maker: "Apple", category: .phone, resolution: resolution,
            bodyAspect: aspect, screen: screenRect(bodyAspect: aspect, pixelAspect: pixelAspect, bezel: bezel),
            screenRadius: radius, cutout: cutout, shell: .handset, finishes: finishes,
            licence: cite(page), isNew: fresh
        )
    }

    static func slate(
        _ id: String, _ name: String, _ resolution: String,
        width: CGFloat, height: CGFloat, pixels: (CGFloat, CGFloat), bezel: CGFloat,
        finishes: [DeviceFinish], fresh: Bool, page: String
    ) -> DeviceSpec {
        let aspect = width / height
        let pixelAspect = pixels.1 / pixels.0
        return DeviceSpec(
            id: id, name: name, maker: "Apple", category: .tablet, resolution: resolution,
            bodyAspect: aspect, screen: screenRect(bodyAspect: aspect, pixelAspect: pixelAspect, bezel: bezel),
            screenRadius: 0.045, cutout: .hole, shell: .slate, finishes: finishes,
            licence: cite(page), isNew: fresh
        )
    }

    static func laptop(
        _ id: String, _ name: String, _ resolution: String,
        width: CGFloat, depth: CGFloat, deck: CGFloat, pixels: (CGFloat, CGFloat), glass: CGFloat,
        finishes: [DeviceFinish], page: String
    ) -> DeviceSpec {
        let total = depth + width * deck
        let aspect = width / total
        let pixelAspect = pixels.0 / pixels.1
        let screenH = glass * aspect / pixelAspect
        let lid = depth / total
        let screen = CGRect(x: (1 - glass) / 2, y: max(0.02, (lid - screenH) / 2), width: glass, height: screenH)
        return DeviceSpec(
            id: id, name: name, maker: "Apple", category: .laptop, resolution: resolution,
            bodyAspect: aspect, screen: screen, screenRadius: 0.028, cutout: .hole, shell: .laptop,
            finishes: finishes, licence: cite(page) + " Open lid is an original drawing sized from the published width and depth."
        )
    }

    static func desktop(
        _ id: String, _ name: String, _ resolution: String,
        width: CGFloat, height: CGFloat, pixels: (CGFloat, CGFloat), page: String
    ) -> DeviceSpec {
        let aspect = width / height
        let pixelAspect = pixels.0 / pixels.1
        let glass: CGFloat = 0.90
        let screenH = glass * aspect / pixelAspect
        let screen = CGRect(x: (1 - glass) / 2, y: 0.05, width: glass, height: screenH)
        return DeviceSpec(
            id: id, name: name, maker: "Apple", category: .desktop, resolution: resolution,
            bodyAspect: aspect, screen: screen, screenRadius: 0.02, cutout: .hole, shell: .allInOne,
            finishes: imacFinishes, licence: cite(page) + " Actual diagonal on the specs page is 23.5 inches."
        )
    }

    static func watch(
        _ id: String, _ name: String, _ resolution: String,
        caseW: CGFloat, caseH: CGFloat, band: CGFloat, pixels: (CGFloat, CGFloat), radius: CGFloat,
        finishes: [DeviceFinish], page: String
    ) -> DeviceSpec {
        let total = caseH * (1 + band * 2)
        let aspect = caseW / total
        let screenH = (caseH / total) * 0.86
        let pixelAspect = pixels.0 / pixels.1
        let screenW = screenH * pixelAspect / aspect
        let screen = CGRect(x: (1 - screenW) / 2, y: (1 - screenH) / 2, width: screenW, height: screenH)
        return DeviceSpec(
            id: id, name: name, maker: "Apple", category: .watch, resolution: resolution,
            bodyAspect: aspect, screen: screen, screenRadius: radius, cutout: .none, shell: .watch,
            finishes: finishes, licence: cite(page) + " Band length is an original drawing around the published case."
        )
    }

    static func screenRect(bodyAspect: CGFloat, pixelAspect: CGFloat, bezel: CGFloat) -> CGRect {
        var height = min(0.96, 1 - bezel * 2)
        var width = height * pixelAspect / max(bodyAspect, 0.01)
        if width > 0.96 {
            width = 0.96
            height = width * bodyAspect / max(pixelAspect, 0.01)
        }
        return CGRect(x: (1 - width) / 2, y: (1 - height) / 2, width: width, height: height)
    }

    static func cite(_ page: String) -> String {
        "\(licence) Specs checked 28 October 2026 at \(page). Finish colours approximate the published finish names."
    }

    static func swatch(_ id: String, _ name: String, _ body: String, _ bezel: String, _ accent: String) -> DeviceFinish {
        DeviceFinish(id: id, name: name, body: body, bezel: bezel, accent: accent)
    }

    static let proFinishes: [DeviceFinish] = [
        swatch("black", "Black", "#1C1E22", "#0E1014", "#3A3E46"),
        swatch("silver", "Silver", "#F3F4F7", "#D5D8DE", "#A8AEB8"),
        swatch("glacier", "Glacier", "#C5D4DC", "#8FA6B2", "#5E7A88"),
        swatch("burgundy", "Burgundy", "#6E2E38", "#3E161C", "#A85A66"),
    ]

    static let airFinishes: [DeviceFinish] = [
        swatch("space-black", "Space Black", "#1A1B1E", "#0C0D10", "#3A3C42"),
        swatch("cloud-white", "Cloud White", "#F7F5F2", "#E4E0DA", "#C8C2B8"),
        swatch("light-gold", "Light Gold", "#E6D3B0", "#CDB892", "#A89068"),
        swatch("sky-blue", "Sky Blue", "#B9D4E6", "#8FB4CC", "#6A94B0"),
    ]

    static let phone17Finishes: [DeviceFinish] = [
        swatch("black", "Black", "#1C1E22", "#0E1014", "#3A3E46"),
        swatch("white", "White", "#F7F7F5", "#E6E6E2", "#C8C8C2"),
        swatch("mist-blue", "Mist Blue", "#C9D6E2", "#A9BCCE", "#7E97B0"),
        swatch("sage", "Sage", "#C5D1C4", "#9AAD98", "#6E866C"),
        swatch("lavender", "Lavender", "#D5D0E2", "#B7B0C8", "#8E86A4"),
    ]

    static let phone17eFinishes: [DeviceFinish] = [
        swatch("black", "Black", "#1C1E22", "#0E1014", "#3A3E46"),
        swatch("white", "White", "#F7F7F5", "#E6E6E2", "#C8C8C2"),
        swatch("soft-pink", "Soft Pink", "#F0D5D2", "#E0B8B4", "#C48E8A"),
    ]

    static let proTabletFinishes: [DeviceFinish] = [
        swatch("silver", "Silver", "#E6E8EE", "#C5C9D2", "#9AA0AA"),
        swatch("space-black", "Space Black", "#2A2C31", "#121316", "#4A4E56"),
    ]

    static let airTabletFinishes: [DeviceFinish] = [
        swatch("starlight", "Starlight", "#F3EDE4", "#D9D0C4", "#B7AA9A"),
        swatch("space-gray", "Space Gray", "#8E9198", "#5C6068", "#3E424A"),
    ]

    static let miniFinishes: [DeviceFinish] = [
        swatch("midnight", "Midnight", "#2C3140", "#161820", "#4A5164"),
        swatch("starlight", "Starlight", "#F3EDE4", "#D9D0C4", "#B7AA9A"),
    ]

    static let airLaptopFinishes: [DeviceFinish] = [
        swatch("sky-blue", "Sky Blue", "#B9D4E6", "#8FB4CC", "#6A94B0"),
        swatch("silver", "Silver", "#E6E8EE", "#C5C9D2", "#9AA0AA"),
        swatch("starlight", "Starlight", "#F3EDE4", "#D9D0C4", "#B7AA9A"),
        swatch("midnight", "Midnight", "#2C3140", "#161820", "#4A5164"),
    ]

    static let proLaptopFinishes: [DeviceFinish] = [
        swatch("space-black", "Space Black", "#2A2C31", "#121316", "#4A4E56"),
        swatch("silver", "Silver", "#E6E8EE", "#C5C9D2", "#9AA0AA"),
    ]

    static let imacFinishes: [DeviceFinish] = [
        swatch("blue", "Blue", "#6E9EC4", "#3E6E96", "#2A5070"),
        swatch("purple", "Purple", "#8E7EB8", "#5E4E86", "#3E345C"),
        swatch("pink", "Pink", "#E7B4C4", "#C8889C", "#A86880"),
        swatch("orange", "Orange", "#E8A05A", "#C47830", "#9A5A20"),
        swatch("yellow", "Yellow", "#F0D56A", "#D4B040", "#A88820"),
        swatch("green", "Green", "#7EAE78", "#4E7E48", "#345E30"),
        swatch("silver", "Silver", "#E6E8EE", "#C5C9D2", "#9AA0AA"),
    ]

    static let seriesFinishes: [DeviceFinish] = [
        swatch("dark-bronze", "Dark Bronze", "#6E5848", "#3E3028", "#8A7260"),
        swatch("light-gold", "Light Gold", "#E6D3B0", "#CDB892", "#A89068"),
        swatch("black", "Black", "#1C1E22", "#0E1014", "#3A3E46"),
        swatch("space-gray", "Space Gray", "#8E9198", "#5C6068", "#3E424A"),
    ]

    static let ultraFinishes: [DeviceFinish] = [
        swatch("natural", "Natural", "#C8C2B4", "#8E8878", "#6A6458"),
        swatch("black", "Black", "#1C1E22", "#0E1014", "#3A3E46"),
    ]
}
