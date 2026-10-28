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

    static func device(_ id: String?) -> DeviceSpec? {
        guard let id else { return nil }
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
        if matching("folio", category: nil).contains(where: { $0.category != .laptop }) { return "folio search left laptops" }
        if !matching("folio", category: .phone).isEmpty { return "phone filter kept a laptop" }
        if !matching("zzzz-no-device", category: nil).isEmpty { return "empty search returned devices" }
        if matching("", category: .watch).count != all.filter({ $0.category == .watch }).count { return "watch filter" }
        guard let pocket = device("pocket") else { return "missing pocket" }
        if pocket.finishes.count < 4 { return "pocket finishes" }
        if pocket.finish("missing").id != pocket.finishes[0].id { return "unknown finish" }
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
        guard let graphite = paintPocket("graphite"), let silver = paintPocket("silver") else { return "device sample" }
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
        style.deviceFinish = "graphite"
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
        if matching("pulse", category: nil).count != 3 { return "pulse search" }
        return nil
    }

    private static func styleRoundTrip() -> String? {
        var style = Presets.style(48, 12, 20, .none, .color("#123456"))
        style.deviceID = "folio-14"
        style.deviceFinish = "space"
        style.deviceFit = .fill
        style.deviceScale = 0.82
        let kept = style.background
        style.deviceFinish = "silver"
        if style.background != kept || style.deviceID != "folio-14" { return "finish reset the composition" }
        style.deviceFinish = "space"
        do {
            let encoded = try JSONEncoder().encode(StyleFile(style))
            let decoded = try JSONDecoder().decode(StyleFile.self, from: encoded).style
            if decoded.deviceID != "folio-14" || decoded.deviceFinish != "space" || decoded.deviceFit != .fill || abs(decoded.deviceScale - 0.82) > 0.001 {
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
    case .handset, .slate:
        fillRound(body, radius: body.width * (device.shell == .slate ? 0.08 : 0.14), color: bodyColor, context: context, height: canvasHeight)
    case .laptop:
        let deck = CGRect(x: body.minX, y: body.maxY - body.height * 0.34, width: body.width, height: body.height * 0.34)
        let lid = CGRect(x: body.minX + body.width * 0.04, y: body.minY, width: body.width * 0.92, height: body.height * 0.70)
        fillRound(deck, radius: 10, color: bodyColor, context: context, height: canvasHeight)
        fillRound(lid, radius: 14, color: bezel, context: context, height: canvasHeight)
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
        let strap = CGRect(x: body.midX - body.width * 0.22, y: body.minY + body.height * 0.04, width: body.width * 0.44, height: body.height * 0.92)
        fillRound(strap, radius: 16, color: accent, context: context, height: canvasHeight)
        let caseRect = screen.insetBy(dx: -screen.width * 0.1, dy: -screen.height * 0.1)
        fillRound(caseRect, radius: caseRect.width * 0.24, color: bodyColor, context: context, height: canvasHeight)
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

    context.saveGState()
    context.setStrokeColor(bezel.withAlphaComponent(0.9).cgColor)
    context.setLineWidth(max(2, screen.width * 0.012))
    let lip = screen.insetBy(dx: 1, dy: 1)
    context.addPath(roundPath(lip, radius: screenRadius(device, screen: lip), height: canvasHeight))
    context.strokePath()
    context.restoreGState()

    drawCutout(device, screen: screen, color: bezel, accent: accent, context: context, height: canvasHeight)
    drawHardware(device, body: body, color: accent, context: context, height: canvasHeight)
}

private func drawCutout(_ device: DeviceSpec, screen: CGRect, color: NSColor, accent: NSColor, context: CGContext, height: CGFloat) {
    switch device.cutout {
    case .none:
        return
    case .island:
        let pill = CGRect(x: screen.midX - screen.width * 0.16, y: screen.minY + screen.height * 0.028, width: screen.width * 0.32, height: screen.height * 0.045)
        fillRound(pill, radius: pill.height / 2, color: color, context: context, height: height)
        let lens = CGRect(x: pill.maxX - pill.height * 0.85, y: pill.midY - pill.height * 0.28, width: pill.height * 0.5, height: pill.height * 0.5)
        context.setFillColor(accent.cgColor)
        context.fillEllipse(in: flip(lens, height: height))
    case .notch:
        let bite = CGRect(x: screen.midX - screen.width * 0.22, y: screen.minY - 2, width: screen.width * 0.44, height: screen.height * 0.07)
        fillRound(bite, radius: 10, color: color, context: context, height: height)
    case .hole:
        let dot = CGRect(x: screen.midX - screen.width * 0.015, y: screen.minY + screen.height * 0.03, width: screen.width * 0.03, height: screen.width * 0.03)
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: flip(dot, height: height))
    }
}

private func drawHardware(_ device: DeviceSpec, body: CGRect, color: NSColor, context: CGContext, height: CGFloat) {
    context.setFillColor(color.cgColor)
    switch device.shell {
    case .handset:
        let button = CGRect(x: body.maxX - 2, y: body.minY + body.height * 0.28, width: 3, height: body.height * 0.1)
        fillRound(button, radius: 1.5, color: color, context: context, height: height)
    case .slate:
        let button = CGRect(x: body.maxX - 2, y: body.minY + body.height * 0.2, width: 3, height: body.height * 0.06)
        fillRound(button, radius: 1.5, color: color, context: context, height: height)
    case .laptop:
        let deck = CGRect(x: body.minX, y: body.maxY - body.height * 0.34, width: body.width, height: body.height * 0.34)
        let keys = CGRect(x: deck.minX + deck.width * 0.12, y: deck.minY + deck.height * 0.22, width: deck.width * 0.76, height: deck.height * 0.38)
        context.setStrokeColor(color.withAlphaComponent(0.45).cgColor)
        context.setLineWidth(1)
        context.stroke(flip(keys, height: height))
        let pad = CGRect(x: deck.midX - deck.width * 0.1, y: deck.minY + deck.height * 0.64, width: deck.width * 0.2, height: deck.height * 0.2)
        context.strokeEllipse(in: flip(pad, height: height))
    case .watch:
        let crown = CGRect(x: body.maxX - body.width * 0.16, y: body.midY - 5, width: body.width * 0.06, height: 10)
        fillRound(crown, radius: 2, color: color, context: context, height: height)
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
        let pill = CGRect(x: screen.midX - screen.width * 0.16, y: screen.minY + screen.height * 0.028, width: screen.width * 0.32, height: max(4, screen.height * 0.045))
        path.addPath(roundPath(pill, radius: pill.height / 2, height: height))
    case .notch:
        let bite = CGRect(x: screen.midX - screen.width * 0.22, y: screen.minY - 2, width: screen.width * 0.44, height: screen.height * 0.07)
        path.addPath(roundPath(bite, radius: 10, height: height))
    case .hole:
        let dot = CGRect(x: screen.midX - screen.width * 0.015, y: screen.minY + screen.height * 0.03, width: screen.width * 0.03, height: screen.width * 0.03)
        path.addEllipse(in: flip(dot, height: height))
    }
    return path
}

private func screenRadius(_ device: DeviceSpec, screen: CGRect) -> CGFloat {
    device.screenRadius * min(screen.width, screen.height)
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
    static var phones: [DeviceSpec] {
        [
            handset("pocket", "Pocket", "1170 × 2532", 0.462, CGRect(x: 0.055, y: 0.03, width: 0.89, height: 0.94), 0.16, .island, 4),
            handset("pocket-air", "Pocket Air", "1206 × 2622", 0.448, CGRect(x: 0.032, y: 0.016, width: 0.936, height: 0.968), 0.18, .island, 4),
            handset("pocket-pro", "Pocket Pro", "1206 × 2622", 0.46, CGRect(x: 0.04, y: 0.02, width: 0.92, height: 0.96), 0.15, .island, 4),
            handset("pocket-pro-max", "Pocket Pro Max", "1320 × 2868", 0.45, CGRect(x: 0.036, y: 0.018, width: 0.928, height: 0.964), 0.14, .island, 4),
            handset("compact", "Compact", "750 × 1334", 0.56, CGRect(x: 0.07, y: 0.1, width: 0.86, height: 0.8), 0.08, .notch, 3),
        ]
    }

    static var tablets: [DeviceSpec] {
        [
            slate("slate", "Slate", "1620 × 2160", 0.75, 3),
            slate("slate-air", "Slate Air", "1640 × 2360", 0.69, 4),
            slate("slate-pro-11", "Slate Pro 11", "1668 × 2420", 0.69, 3),
            slate("slate-pro-13", "Slate Pro 13", "2064 × 2752", 0.75, 4),
        ]
    }

    static var laptops: [DeviceSpec] {
        [
            laptop("folio-13", "Folio 13", "2560 × 1664", 1.42),
            laptop("folio-14", "Folio 14", "3024 × 1964", 1.46),
            laptop("studio-14", "Studio 14", "3024 × 1964", 1.5),
            laptop("studio-16", "Studio 16", "3456 × 2234", 1.55),
        ]
    }

    static var desktops: [DeviceSpec] {
        [
            desktop("halo-24", "Halo 24", "4480 × 2520", 1.15, .allInOne),
            desktop("panel-27", "Panel 27", "5120 × 2880", 1.55, .monitor),
            desktop("panel-32", "Panel 32", "6016 × 3384", 1.62, .monitor),
        ]
    }

    static var watches: [DeviceSpec] {
        [
            watch("pulse-41", "Pulse 41", "352 × 430"),
            watch("pulse-45", "Pulse 45", "396 × 484"),
            watch("pulse-ultra", "Pulse Ultra", "410 × 502"),
        ]
    }

    static func handset(_ id: String, _ name: String, _ resolution: String, _ aspect: CGFloat, _ screen: CGRect, _ radius: CGFloat, _ cutout: DeviceCutout, _ finishCount: Int) -> DeviceSpec {
        DeviceSpec(id: id, name: name, maker: "Shotli", category: .phone, resolution: resolution, bodyAspect: aspect, screen: screen, screenRadius: radius, cutout: cutout, shell: .handset, finishes: phoneFinishes(finishCount), licence: licence)
    }

    static func slate(_ id: String, _ name: String, _ resolution: String, _ aspect: CGFloat, _ finishCount: Int) -> DeviceSpec {
        DeviceSpec(
            id: id, name: name, maker: "Shotli", category: .tablet, resolution: resolution, bodyAspect: aspect,
            screen: CGRect(x: 0.035, y: 0.028, width: 0.93, height: 0.944), screenRadius: 0.06, cutout: .hole, shell: .slate,
            finishes: metalFinishes(finishCount), licence: licence
        )
    }

    static func laptop(_ id: String, _ name: String, _ resolution: String, _ aspect: CGFloat) -> DeviceSpec {
        DeviceSpec(
            id: id, name: name, maker: "Shotli", category: .laptop, resolution: resolution, bodyAspect: aspect,
            screen: CGRect(x: 0.09, y: 0.035, width: 0.82, height: 0.6), screenRadius: 0.03, cutout: .none, shell: .laptop,
            finishes: metalFinishes(3), licence: licence
        )
    }

    static func desktop(_ id: String, _ name: String, _ resolution: String, _ aspect: CGFloat, _ shell: DeviceShell) -> DeviceSpec {
        let screen = shell == .allInOne
            ? CGRect(x: 0.045, y: 0.04, width: 0.91, height: 0.72)
            : CGRect(x: 0.025, y: 0.03, width: 0.95, height: 0.82)
        return DeviceSpec(
            id: id, name: name, maker: "Shotli", category: .desktop, resolution: resolution, bodyAspect: aspect,
            screen: screen, screenRadius: 0.02, cutout: .none, shell: shell, finishes: metalFinishes(3), licence: licence
        )
    }

    static func watch(_ id: String, _ name: String, _ resolution: String) -> DeviceSpec {
        DeviceSpec(
            id: id, name: name, maker: "Shotli", category: .watch, resolution: resolution, bodyAspect: 0.58,
            screen: CGRect(x: 0.2, y: 0.34, width: 0.6, height: 0.32), screenRadius: 0.24, cutout: .none, shell: .watch,
            finishes: [
                DeviceFinish(id: "silver", name: "Silver", body: "#D5D8DE", bezel: "#8E949E", accent: "#6E7580"),
                DeviceFinish(id: "ink", name: "Ink", body: "#2A2E36", bezel: "#101216", accent: "#4A4038"),
                DeviceFinish(id: "sand", name: "Sand", body: "#E4D2BC", bezel: "#B89A78", accent: "#8C6239"),
            ],
            licence: licence
        )
    }

    static func phoneFinishes(_ count: Int) -> [DeviceFinish] {
        Array(phonePalette.prefix(count))
    }

    static func metalFinishes(_ count: Int) -> [DeviceFinish] {
        Array(metalPalette.prefix(count))
    }

    static let phonePalette: [DeviceFinish] = [
        DeviceFinish(id: "silver", name: "Silver", body: "#E6E8EE", bezel: "#C5C9D1", accent: "#9AA1AB"),
        DeviceFinish(id: "graphite", name: "Graphite", body: "#3A3E46", bezel: "#1A1C20", accent: "#6A707A"),
        DeviceFinish(id: "blue", name: "Blue", body: "#C5D4E4", bezel: "#8FA4BA", accent: "#5E7894"),
        DeviceFinish(id: "sand", name: "Sand", body: "#E7D7C4", bezel: "#C4B09A", accent: "#A68662"),
        DeviceFinish(id: "green", name: "Green", body: "#D5E2D4", bezel: "#9BB39A", accent: "#6E8B6C"),
    ]

    static let metalPalette: [DeviceFinish] = [
        DeviceFinish(id: "silver", name: "Silver", body: "#E4E7EE", bezel: "#B7BDC8", accent: "#8E96A3"),
        DeviceFinish(id: "space", name: "Space", body: "#4A4E57", bezel: "#22252B", accent: "#6D7380"),
        DeviceFinish(id: "starlight", name: "Starlight", body: "#F3EDE4", bezel: "#D9D0C4", accent: "#B7AA9A"),
        DeviceFinish(id: "blue", name: "Blue", body: "#D5E0EA", bezel: "#A9BCCE", accent: "#7E97B0"),
    ]
}
