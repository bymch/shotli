import AppKit
import Foundation
import ImageIO

enum ToolsVerify {
    static func run() -> Int {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("shotli-tools-verify-\(UUID().uuidString)", isDirectory: true)
        ShotliProjects.rootOverride = root.appendingPathComponent("Projects", isDirectory: true)
        defer {
            ShotliProjects.rootOverride = nil
            try? FileManager.default.removeItem(at: root)
        }
        do {
            try FileManager.default.createDirectory(at: ShotliProjects.root, withIntermediateDirectories: true)
            try checkPatterns()
            try checkRecognition()
            try checkWebP()
            try checkExportSizes()
            try checkStyles()
            try checkBatch(in: root)
            try checkGIF(in: root)
            print("tools verified")
            return 0
        } catch {
            fputs("tools verify failed: \(error)\n", stderr)
            return 1
        }
    }

    private static func checkPatterns() throws {
        let cases: [(String, SensitiveKind?)] = [
            ("write to jane.doe+x@example.co.uk today", .email),
            ("key sk_live_51Hab2Cd3Ef4Gh5Ij6Kl", .secret),
            ("sk-ant-api03-abcdefghijklmnopqrstuvwx", .secret),
            ("ghp_abcdefghijklmnopqrstuvwxyz0123", .secret),
            ("AKIAIOSFODNN7EXAMPLE", .secret),
            ("password: hunter2", .secret),
            ("API_KEY=abcd1234", .secret),
            ("Authorization: Bearer abc.def-ghi123", .secret),
            ("eyJhbGciOiJI.eyJzdWIiOiIx.SflKxwRJSM", .secret),
            ("aB3dE5gH7jK9mN1pQ3sT5vX7zA9cE1gI3k", .secret),
            ("card 4242 4242 4242 4242 exp", .card),
            ("4111-1111-1111-1112", .card),
            ("378282246310005", .card),
            ("call +1 415 555 2671 now", .phone),
            ("Quarterly plan for the team", nil),
            ("Forgot your password? Reset it", nil),
            ("Released 2026-11-04", nil),
            ("commit 8d9ad91 turned frames off", nil),
            ("invoice 1234567890123456", nil),
        ]
        for (text, expected) in cases {
            let found = SensitiveText.matches(in: text).map(\.kind)
            if let expected {
                guard found == [expected] else { throw Failure("\(text): got \(found), wanted \(expected)") }
            } else {
                guard found.isEmpty else { throw Failure("\(text): false positive \(found)") }
            }
        }
        guard SensitiveText.isLuhnValid("4242424242424242"), !SensitiveText.isLuhnValid("4242424242424243") else {
            throw Failure("luhn")
        }
    }

    /// Real Vision on a drawn picture, so rect placement and the bottom-left flip are both exercised.
    private static func checkRecognition() throws {
        let email = "jane.doe@example.com"
        let image = try drawn(width: 1400, height: 700, lines: [
            (60, 60, "Quarterly plan"),
            (60, 300, "Contact \(email) for access"),
            (60, 560, "Launch checklist"),
        ])
        let lines = TextScan.lines(in: image)
        let findings = SensitiveText.findings(in: lines, bounds: CGSize(width: 1400, height: 700), covered: [])
        guard findings.count == 1, findings[0].kind == .email, let finding = findings.first else {
            throw Failure("recognition found \(findings) in \(lines.map(\.text))")
        }
        guard finding.rect.minY > 260, finding.rect.maxY < 400 else {
            throw Failure("the email box is in the wrong place: \(finding.rect)")
        }
        guard finding.rect.minX > 60 else { throw Failure("the box covers the word before the email: \(finding.rect)") }
        guard !finding.preview.contains("example") else { throw Failure("the preview shows the address") }

        let all = TextScan.visibleText(lines, visible: nil, hidden: [])
        let order = ["Quarterly", "Contact", "Launch"].compactMap { all.range(of: $0)?.lowerBound }
        guard order.count == 3, order == order.sorted(), all.contains(email) else { throw Failure("reading order: \(all)") }
        let redacted = TextScan.visibleText(lines, visible: nil, hidden: [finding.rect])
        guard !redacted.contains(email), redacted.contains("Contact") else { throw Failure("copy kept a redaction: \(redacted)") }
        let cropped = TextScan.visibleText(lines, visible: CGRect(x: 0, y: 0, width: 1400, height: 200), hidden: [])
        guard cropped.contains("Quarterly"), !cropped.contains("Launch") else { throw Failure("copy kept cropped text: \(cropped)") }

        let picture = LoadedPicture(image: image, name: "Scan.png", scaled: false)
        let mark = Annotation.shape(ShapeMark(
            id: "m", kind: .pixelate, color: "#000000", strokeWidth: 1,
            x: finding.rect.minX, y: finding.rect.minY, w: finding.rect.width, h: finding.rect.height,
            amount: max(14, finding.rect.height)
        ))
        var bare = Presets.all[0].style
        bare.hideMockup = true
        guard let output = renderShot(picture: picture, crop: nil, style: bare, annotations: [mark], layers: [], draft: nil, interactive: false) else {
            throw Failure("redacted render")
        }
        let after = TextScan.visibleText(TextScan.lines(in: output), visible: nil, hidden: [])
        guard !after.contains("example"), after.contains("Quarterly") else { throw Failure("the address is still readable: \(after)") }
        let rescan = SensitiveText.findings(in: lines, bounds: CGSize(width: 1400, height: 700), covered: [finding.rect])
        guard rescan.isEmpty else { throw Failure("a covered item was listed again") }
    }

    private static func checkWebP() throws {
        let cases: [(String, Int, Int, (Int, Int) -> (UInt8, UInt8, UInt8, UInt8))] = [
            ("one pixel", 1, 1, { _, _ in (10, 20, 30, 255) }),
            ("flat", 64, 64, { _, _ in (200, 200, 200, 255) }),
            ("two colours", 40, 9, { x, _ in x % 2 == 0 ? (0, 0, 0, 255) : (255, 255, 255, 255) }),
            ("gradient", 300, 200, { x, y in (UInt8(x % 256), UInt8(y % 256), UInt8((x + y) % 256), 255) }),
            ("noise", 257, 131, { x, y in
                let seed = (x &* 73856093) ^ (y &* 19349663)
                return (UInt8(seed & 255), UInt8((seed >> 8) & 255), UInt8((seed >> 16) & 255), 255)
            }),
            ("transparency", 120, 80, { x, y in x < 60 ? (255, 0, 0, 255) : (y < 40 ? (0, 0, 0, 0) : (0, 0, 255, 255)) }),
        ]
        for (name, width, height, pixel) in cases {
            let image = try makeImage(width: width, height: height, pixel)
            guard let data = WebPEncoder.encode(image) else { throw Failure("webp encode \(name)") }
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let decoded = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                throw Failure("ImageIO can't read the \(name) WebP")
            }
            guard decoded.width == width, decoded.height == height else { throw Failure("webp size \(name)") }
            let got = try samples(decoded)
            for y in 0..<height {
                for x in 0..<width {
                    let wanted = pixel(x, y)
                    let at = (y * width + x) * 4
                    let found = (got[at], got[at + 1], got[at + 2], got[at + 3])
                    guard found == wanted else {
                        throw Failure("webp \(name) at \(x),\(y): \(found) vs \(wanted)")
                    }
                }
            }
        }
        let screen = try drawn(width: 1400, height: 700, lines: [(60, 60, "Quarterly plan")])
        guard let small = WebPEncoder.encode(screen), small.count < 60_000 else {
            throw Failure("a flat screenshot should compress well")
        }
    }

    private static func checkExportSizes() throws {
        let picture = LoadedPicture(image: sampleScreenshot(), name: "Sample.png", scaled: false)
        var style = Presets.all[0].style
        style.background = .color("transparent")
        for size in ExportSize.social + ExportSize.appStore {
            guard let image = ExportRender.render(picture: picture, crop: nil, style: style, annotations: [], layers: [], size: size, format: .png) else {
                throw Failure("render \(size.id)")
            }
            guard image.width == Int(size.width), image.height == Int(size.height) else {
                throw Failure("\(size.id) came out \(image.width)×\(image.height)")
            }
            guard size.opaque == [.none, .noneSkipLast, .noneSkipFirst].contains(image.alphaInfo) else {
                throw Failure("\(size.id) alpha is \(image.alphaInfo.rawValue)")
            }
        }
        guard let original = ExportRender.render(picture: picture, crop: nil, style: style, annotations: [], layers: [], size: .original, format: .png),
              let plain = renderShot(picture: picture, crop: nil, style: style, annotations: [], layers: [], draft: nil, interactive: false),
              original.width == plain.width, original.height == plain.height else {
            throw Failure("original size changed the render")
        }
        guard let flat = ExportRender.render(picture: picture, crop: nil, style: style, annotations: [], layers: [], size: .original, format: .jpeg),
              let jpeg = ExportRender.encode(flat, format: .jpeg),
              let source = CGImageSourceCreateWithData(jpeg as CFData, nil),
              let decoded = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw Failure("jpeg")
        }
        for size in [ExportSize.original, ExportSize.named("x")] {
            guard let clear = ExportRender.render(picture: picture, crop: nil, style: style, annotations: [], layers: [], size: size, format: .png) else {
                throw Failure("clear render")
            }
            guard try samples(clear)[3] == 0 else { throw Failure("\(size.id) kept the editor's checkerboard") }
        }
        let corner = try samples(decoded)
        guard corner[0] > 250, corner[1] > 250, corner[2] > 250 else { throw Failure("JPEG transparency isn't white: \(corner[0])") }

        // The screenshot must keep its shape on a canvas of a very different shape.
        let fitted = ExportRender.fittedStyle(style, picture: picture, crop: nil, layerCount: 0, target: CGSize(width: 1320, height: 2868))
        let layout = composition(picture: picture, crop: nil, style: fitted)
        guard abs(layout.image.width / layout.image.height - picture.width / picture.height) < 0.001 else { throw Failure("the picture stretched") }
        guard abs(layout.size.width / layout.size.height - 1320.0 / 2868.0) < 0.002 else { throw Failure("wrong canvas shape \(layout.size)") }
    }

    private static func checkStyles() throws {
        let store = StyleStore.shared
        store.reload()
        guard store.styles.isEmpty else { throw Failure("styles leaked in from outside the verify folder") }
        var style = Presets.tilted()
        style.background = .gradient(from: "#112233", mid: nil, to: "#445566", angle: 45)
        style.card = .glassDark
        let saved = store.add(name: "Launch", style: style)
        store.setDefault(saved.id)
        store.reload()
        guard store.styles.first?.name == "Launch", store.defaultStyle == style else { throw Failure("style round trip") }

        let model = EditorModel.shared
        model.useSample()
        guard model.style == style else { throw Failure("a new screenshot ignored the default style") }

        store.rename(saved.id, to: "Launch 2")
        store.reload()
        guard store.styles.first?.name == "Launch 2" else { throw Failure("rename") }
        store.delete(saved.id)
        store.reload()
        guard store.styles.isEmpty, store.defaultID == nil else { throw Failure("delete left the default set") }
    }

    private static func checkBatch(in root: URL) throws {
        let folder = ShotliProjects.root.appendingPathComponent("Batch", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let now = ProjectStore.stamp(Date())
        try ProjectStore.write(
            ProjectFile(version: 1, id: "batch", name: "Batch", created: now, modified: now, compositions: [], assets: []),
            to: folder
        )
        // Wider than a thumbnail, so a thumbnail-sized decode would put the crop on the wrong pixels.
        let big = try drawn(width: 3000, height: 1000, lines: [(100, 100, "Big screenshot")])
        guard let bigPNG = ExportRender.encode(big, format: .png) else { throw Failure("png") }
        let crop = CGRect(x: 2000, y: 0, width: 1000, height: 1000)
        let mark = Annotation.shape(ShapeMark(id: "keep", kind: .rect, color: "#FF0000", strokeWidth: 4, x: 2100, y: 100, w: 300, h: 300, amount: 0))
        let first = try ProjectStore.saveComposition(CompositionDraft(
            id: nil, name: "One.png", sourceData: bigPNG, sourceFileName: "One.png", sourceSHA256: nil, reuseRelative: nil,
            crop: crop, style: Presets.all[0].style, annotations: [mark], thumbnail: big
        ), in: folder)
        guard let other = ExportRender.encode(sampleScreenshot(), format: .png) else { throw Failure("png") }
        try ProjectStore.saveComposition(CompositionDraft(
            id: nil, name: "One.png", sourceData: other, sourceFileName: "Two.png", sourceSHA256: nil, reuseRelative: nil,
            crop: nil, style: Presets.all[1].style, annotations: [], thumbnail: nil
        ), in: folder)

        var style = Presets.tilted()
        style.background = .wallpaper(.bloom)
        style.tiltX = 0
        style.tiltY = 0
        let count = try ProjectStore.applyStyle(style, to: folder)
        let file = try ProjectStore.read(folder)
        guard count == 2, file.compositions.allSatisfy({ $0.style.style.background == .wallpaper(.bloom) }) else { throw Failure("apply style") }
        guard let one = file.compositions.first(where: { $0.id == first.compositionID }),
              one.crop?.rect == crop, one.annotations.compactMap(\.annotation) == [mark] else {
            throw Failure("apply style lost a crop or a mark")
        }
        guard let thumb = one.thumbnail, let thumbURL = try? ProjectStore.resolve(thumb, in: folder),
              let thumbImage = NSImage(contentsOf: thumbURL)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw Failure("no redrawn thumbnail")
        }
        let padded = composition(picture: LoadedPicture(image: big, name: "b", scaled: false), crop: crop, style: style).size
        guard thumbImage.width == Int(ceil(padded.width)) else { throw Failure("thumbnail wasn't drawn at the crop: \(thumbImage.width) vs \(padded.width)") }

        let destination = root.appendingPathComponent("Out", isDirectory: true)
        let size = ExportSize.named("og")
        let result = try ProjectStore.exportAll(in: folder, to: destination, format: .webp, size: size)
        guard result.saved == 2, result.failed == 0 else { throw Failure("export all \(result)") }
        var names = try FileManager.default.contentsOfDirectory(atPath: destination.path).sorted()
        guard names == ["One-2.webp", "One.webp"] else { throw Failure("export names \(names)") }
        let written = destination.appendingPathComponent("One.webp")
        guard let source = CGImageSourceCreateWithURL(written as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              props[kCGImagePropertyPixelWidth] as? Int == 1200, props[kCGImagePropertyPixelHeight] as? Int == 630 else {
            throw Failure("exported size")
        }
        let before = try Data(contentsOf: written)
        _ = try ProjectStore.exportAll(in: folder, to: destination, format: .webp, size: size)
        names = try FileManager.default.contentsOfDirectory(atPath: destination.path)
        guard names.count == 4, try Data(contentsOf: written) == before else { throw Failure("a second export replaced a file") }

        var broken = try ProjectStore.read(folder)
        broken.compositions[1].source = "Screenshots/missing.png"
        try ProjectStore.write(broken, to: folder)
        let partial = try ProjectStore.exportAll(in: folder, to: root.appendingPathComponent("Out2"), format: .png, size: .original)
        guard partial.saved == 1, partial.failed == 1 else { throw Failure("a missing screenshot wasn't reported: \(partial)") }
    }

    private static func checkGIF(in root: URL) throws {
        let picture = LoadedPicture(image: sampleScreenshot(), name: "Sample.png", scaled: false)
        var settings = MotionSettings()
        settings.duration = 2
        settings.loops = true
        let url = root.appendingPathComponent("loop.gif")
        var last = 0.0
        try MotionExport.writeGIF(picture: picture, crop: nil, style: Presets.all[3].style, annotations: [], settings: settings, to: url) { last = $0 }
        guard last == 1, let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { throw Failure("gif progress") }
        let frames = CGImageSourceGetCount(source)
        guard frames == Int((settings.outputDuration * 20).rounded()) else { throw Failure("gif frames \(frames)") }
        let container = (CGImageSourceCopyProperties(source, nil) as? [CFString: Any])?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        let frameProps = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let frameGIF = frameProps?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        let delay = (frameGIF?[kCGImagePropertyGIFUnclampedDelayTime] ?? frameGIF?[kCGImagePropertyGIFDelayTime]) as? Double
        guard container?[kCGImagePropertyGIFLoopCount] as? Int == 0 else { throw Failure("gif loop: \(String(describing: container))") }
        guard let delay, abs(delay - 0.05) < 0.001 else { throw Failure("gif delay: \(String(describing: frameGIF))") }
        guard frameProps?[kCGImagePropertyPixelWidth] as? Int == 800 else { throw Failure("gif width") }
    }

    private static func drawn(width: Int, height: Int, lines: [(CGFloat, CGFloat, String)]) throws -> CGImage {
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw Failure("context") }
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let previous = NSGraphicsContext.current
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        defer { NSGraphicsContext.current = previous }
        for (x, top, text) in lines {
            (text as NSString).draw(at: CGPoint(x: x, y: CGFloat(height) - top - 60), withAttributes: [
                .font: NSFont.systemFont(ofSize: 48),
                .foregroundColor: NSColor.black,
            ])
        }
        guard let image = context.makeImage() else { throw Failure("image") }
        return image
    }

    private static func makeImage(width: Int, height: Int, _ pixel: (Int, Int) -> (UInt8, UInt8, UInt8, UInt8)) throws -> CGImage {
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let value = pixel(x, y)
                let at = (y * width + x) * 4
                bytes[at] = value.0
                bytes[at + 1] = value.1
                bytes[at + 2] = value.2
                bytes[at + 3] = value.3
            }
        }
        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let image = CGImage(
                width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
              ) else { throw Failure("image") }
        return image
    }

    private static func samples(_ image: CGImage) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let drawn: Bool = bytes.withUnsafeMutableBytes { raw in
            guard let context = CGContext(
                data: raw.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        guard drawn else { throw Failure("samples") }
        return bytes
    }

    private struct Failure: LocalizedError {
        var message: String
        init(_ message: String) { self.message = message }
        var errorDescription: String? { message }
    }
}
