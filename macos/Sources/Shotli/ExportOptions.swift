import AppKit
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

enum ExportFormat: String, CaseIterable, Identifiable {
    case png, jpeg, webp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .png: return "PNG"
        case .jpeg: return "JPEG"
        case .webp: return "WebP"
        }
    }

    var fileExtension: String {
        switch self {
        case .png: return "png"
        case .jpeg: return "jpg"
        case .webp: return "webp"
        }
    }

    var contentType: UTType {
        switch self {
        case .png: return .png
        case .jpeg: return .jpeg
        case .webp: return .webP
        }
    }
}

struct ExportSize: Identifiable, Equatable {
    var id: String
    var name: String
    var short: String
    var width: CGFloat = 0
    var height: CGFloat = 0
    /// App Store Connect rejects images with an alpha channel.
    var opaque = false

    var isOriginal: Bool { width <= 0 || height <= 0 }
    var target: CGSize { CGSize(width: width, height: height) }

    var label: String {
        isOriginal ? name : "\(name), \(Int(width)) × \(Int(height))"
    }

    static let original = ExportSize(id: "original", name: "Original size", short: "1×")

    static let social = [
        ExportSize(id: "x", name: "X post", short: "X", width: 1600, height: 900),
        ExportSize(id: "linkedin", name: "LinkedIn post", short: "LinkedIn", width: 1200, height: 627),
        ExportSize(id: "og", name: "Open Graph", short: "OG", width: 1200, height: 630),
        ExportSize(id: "square", name: "Instagram square", short: "Square", width: 1080, height: 1080),
    ]

    static let appStore = [
        ExportSize(id: "iphone", name: "iPhone 6.9\"", short: "iPhone", width: 1320, height: 2868, opaque: true),
        ExportSize(id: "ipad", name: "iPad 13\"", short: "iPad", width: 2064, height: 2752, opaque: true),
        ExportSize(id: "mac", name: "Mac App Store", short: "Mac", width: 2880, height: 1800, opaque: true),
    ]

    static let all = [original] + social + appStore

    static func named(_ id: String?) -> ExportSize {
        all.first { $0.id == id } ?? original
    }
}

final class ExportSettings: ObservableObject {
    static let shared = ExportSettings()

    @Published var format: ExportFormat {
        didSet { UserDefaults.standard.set(format.rawValue, forKey: "exportFormat") }
    }
    @Published var sizeID: String {
        didSet { UserDefaults.standard.set(sizeID, forKey: "exportSize") }
    }

    private init() {
        format = ExportFormat(rawValue: UserDefaults.standard.string(forKey: "exportFormat") ?? "") ?? .png
        sizeID = ExportSize.named(UserDefaults.standard.string(forKey: "exportSize")).id
    }

    var size: ExportSize { ExportSize.named(sizeID) }
    var summary: String { "\(size.short) \(format.title)" }
}

enum ExportRender {
    /// Grows the canvas to the target's shape, so the background fills the space instead of the picture stretching.
    static func fittedStyle(_ style: ShotliStyle, picture: LoadedPicture?, crop: CGRect?, layerCount: Int, target: CGSize) -> ShotliStyle {
        var next = style
        next.canvas = .auto
        next.canvasWidth = 0
        next.canvasHeight = 0
        let content = composition(picture: picture, crop: crop, style: next, layerCount: layerCount).size
        // At most 2× enlargement. A smaller picture sits on more background rather than going soft.
        let scale = max(0.5, max(content.width / target.width, content.height / target.height))
        next.canvasWidth = ceil(target.width * scale)
        next.canvasHeight = ceil(target.height * scale)
        return next
    }

    static func render(
        picture: LoadedPicture?,
        crop: CGRect?,
        style: ShotliStyle,
        annotations: [Annotation],
        layers: [ShotLayer],
        size: ExportSize,
        format: ExportFormat
    ) -> CGImage? {
        let flatten = format == .jpeg || size.opaque
        let used = size.isOriginal
            ? style
            : fittedStyle(style, picture: picture, crop: crop, layerCount: layers.count, target: size.target)
        // The transparent swatch paints a checkerboard for the editor. A file should have real transparency.
        let clear = style.background == .color("transparent")
        guard let image = renderShot(
            picture: picture, crop: crop, style: used, annotations: annotations, layers: layers, draft: nil, interactive: false, omitBackground: clear
        ) else { return nil }
        let target = size.isOriginal ? CGSize(width: image.width, height: image.height) : size.target
        if size.isOriginal && !flatten { return image }
        return place(image, on: target, background: style.background, flatten: flatten)
    }

    private static func place(_ image: CGImage, on target: CGSize, background: Background, flatten: Bool) -> CGImage? {
        guard let context = CGContext(
            data: nil, width: Int(target.width), height: Int(target.height), bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: flatten ? CGImageAlphaInfo.noneSkipLast.rawValue : CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        let bounds = CGRect(origin: .zero, size: target)
        context.interpolationQuality = .high
        if flatten {
            context.setFillColor(NSColor.white.cgColor)
            context.fill(bounds)
        }
        let source = CGFloat(image.width) / CGFloat(image.height)
        let wanted = target.width / target.height
        if abs(source - wanted) < 0.01 {
            context.draw(image, in: bounds)
        } else {
            // Device frames keep their own canvas, so they sit on the background at the target shape.
            if background != .color("transparent"), let backdrop = renderBackdrop(background, size: target) {
                context.draw(backdrop, in: bounds)
            }
            let scale = min(target.width / CGFloat(image.width), target.height / CGFloat(image.height))
            let width = CGFloat(image.width) * scale
            let height = CGFloat(image.height) * scale
            context.draw(image, in: CGRect(x: (target.width - width) / 2, y: (target.height - height) / 2, width: width, height: height))
        }
        return context.makeImage()
    }

    static func encode(_ image: CGImage, format: ExportFormat) -> Data? {
        if format == .webp { return WebPEncoder.encode(image) }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, format.contentType.identifier as CFString, 1, nil) else { return nil }
        let options: [CFString: Any] = format == .jpeg ? [kCGImageDestinationLossyCompressionQuality: 0.92] : [:]
        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}

struct ExportOptionsForm: View {
    @ObservedObject var settings = ExportSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Format", selection: $settings.format) {
                ForEach(ExportFormat.allCases) { format in
                    Text(format.title).tag(format)
                }
            }
            Picker("Size", selection: $settings.sizeID) {
                Text(ExportSize.original.label).tag(ExportSize.original.id)
                Section("Social") {
                    ForEach(ExportSize.social) { size in
                        Text(size.label).tag(size.id)
                    }
                }
                Section("App Store") {
                    ForEach(ExportSize.appStore) { size in
                        Text(size.label).tag(size.id)
                    }
                }
            }
        }
        .padding(14)
        .frame(width: 320)
    }
}

/// A lossless VP8L writer. ImageIO reads WebP but does not write it.
enum WebPEncoder {
    private struct BitWriter {
        var bytes: [UInt8] = []
        private var buffer: UInt64 = 0
        private var count = 0

        mutating func write(_ value: Int, _ bits: Int) {
            buffer |= UInt64(value) << UInt64(count)
            count += bits
            while count >= 8 {
                bytes.append(UInt8(buffer & 0xFF))
                buffer >>= 8
                count -= 8
            }
        }

        mutating func finish() {
            if count > 0 {
                bytes.append(UInt8(buffer & 0xFF))
                buffer = 0
                count = 0
            }
        }
    }

    private struct Code {
        var lengths: [Int]
        var codes: [Int]
    }

    private enum Token {
        case literal(UInt32)
        case copy(length: Int, distanceCode: Int)
    }

    private static let maxCopy = 4096

    static func encode(_ image: CGImage) -> Data? {
        let width = image.width
        let height = image.height
        guard (1...16384).contains(width), (1...16384).contains(height) else { return nil }
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        let drawn: Bool = rgba.withUnsafeMutableBytes { raw in
            guard let context = CGContext(
                data: raw.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }

        var pixels = [UInt32](repeating: 0, count: width * height)
        var hasAlpha = false
        for index in 0..<pixels.count {
            let at = index * 4
            let alpha = Int(rgba[at + 3])
            var red = Int(rgba[at])
            var green = Int(rgba[at + 1])
            var blue = Int(rgba[at + 2])
            if alpha == 0 {
                red = 0
                green = 0
                blue = 0
            } else if alpha < 255 {
                red = min(255, (red * 255 + alpha / 2) / alpha)
                green = min(255, (green * 255 + alpha / 2) / alpha)
                blue = min(255, (blue * 255 + alpha / 2) / alpha)
            }
            if alpha < 255 { hasAlpha = true }
            // The subtract-green transform leaves grays and flat colours mostly as zeros.
            let packedRed = UInt32((red - green) & 0xFF)
            let packedBlue = UInt32((blue - green) & 0xFF)
            pixels[index] = UInt32(alpha) << 24 | packedRed << 16 | UInt32(green) << 8 | packedBlue
        }

        let tokens = tokenize(pixels, width: width)
        var green = [Int](repeating: 0, count: 256 + 24)
        var red = [Int](repeating: 0, count: 256)
        var blue = [Int](repeating: 0, count: 256)
        var alpha = [Int](repeating: 0, count: 256)
        var distance = [Int](repeating: 0, count: 40)
        for token in tokens {
            switch token {
            case .literal(let pixel):
                green[Int(pixel >> 8 & 0xFF)] += 1
                red[Int(pixel >> 16 & 0xFF)] += 1
                blue[Int(pixel & 0xFF)] += 1
                alpha[Int(pixel >> 24)] += 1
            case .copy(let length, let distanceCode):
                green[256 + prefix(length).symbol] += 1
                distance[prefix(distanceCode).symbol] += 1
            }
        }

        var writer = BitWriter()
        writer.write(0x2F, 8)
        writer.write(width - 1, 14)
        writer.write(height - 1, 14)
        writer.write(hasAlpha ? 1 : 0, 1)
        writer.write(0, 3)
        writer.write(1, 1)
        writer.write(2, 2)
        writer.write(0, 1)
        writer.write(0, 1)
        writer.write(0, 1)
        let greenCode = writeCode(green, to: &writer)
        let redCode = writeCode(red, to: &writer)
        let blueCode = writeCode(blue, to: &writer)
        let alphaCode = writeCode(alpha, to: &writer)
        let distanceCode = writeCode(distance, to: &writer)

        func put(_ code: Code, _ symbol: Int) {
            writer.write(code.codes[symbol], code.lengths[symbol])
        }
        for token in tokens {
            switch token {
            case .literal(let pixel):
                put(greenCode, Int(pixel >> 8 & 0xFF))
                put(redCode, Int(pixel >> 16 & 0xFF))
                put(blueCode, Int(pixel & 0xFF))
                put(alphaCode, Int(pixel >> 24))
            case .copy(let length, let distanceValue):
                let lengthPrefix = prefix(length)
                put(greenCode, 256 + lengthPrefix.symbol)
                writer.write(lengthPrefix.extraValue, lengthPrefix.extraBits)
                let distancePrefix = prefix(distanceValue)
                put(distanceCode, distancePrefix.symbol)
                writer.write(distancePrefix.extraValue, distancePrefix.extraBits)
            }
        }
        writer.finish()
        return container(writer.bytes)
    }

    /// Copies from the pixel to the left (distance code 2) or the one above (code 1). Screenshots are mostly both.
    private static func tokenize(_ pixels: [UInt32], width: Int) -> [Token] {
        var tokens: [Token] = []
        var index = 0
        while index < pixels.count {
            func run(_ back: Int) -> Int {
                guard index >= back else { return 0 }
                var length = 0
                while length < maxCopy, index + length < pixels.count, pixels[index + length] == pixels[index + length - back] {
                    length += 1
                }
                return length
            }
            let left = run(1)
            let above = run(width)
            if max(left, above) >= 3 {
                let useAbove = above > left
                let length = useAbove ? above : left
                tokens.append(.copy(length: length, distanceCode: useAbove ? 1 : 2))
                index += length
            } else {
                tokens.append(.literal(pixels[index]))
                index += 1
            }
        }
        return tokens
    }

    private static func prefix(_ value: Int) -> (symbol: Int, extraBits: Int, extraValue: Int) {
        if value <= 4 { return (value - 1, 0, 0) }
        let shifted = value - 1
        let highest = Int.bitWidth - 1 - shifted.leadingZeroBitCount
        let second = (shifted >> (highest - 1)) & 1
        let extraBits = highest - 1
        return (2 * highest + second, extraBits, shifted & ((1 << extraBits) - 1))
    }

    private static func writeCode(_ histogram: [Int], to writer: inout BitWriter) -> Code {
        var counts = histogram
        let used = counts.indices.filter { counts[$0] > 0 }
        if used.count <= 2, used.allSatisfy({ $0 < 256 }) {
            let symbols = used.isEmpty ? [0] : used
            writer.write(1, 1)
            writer.write(symbols.count - 1, 1)
            if symbols[0] < 2 {
                writer.write(0, 1)
                writer.write(symbols[0], 1)
            } else {
                writer.write(1, 1)
                writer.write(symbols[0], 8)
            }
            if symbols.count == 2 { writer.write(symbols[1], 8) }
            var lengths = [Int](repeating: 0, count: counts.count)
            var codes = lengths
            if symbols.count == 2 {
                lengths[symbols[0]] = 1
                lengths[symbols[1]] = 1
                codes[symbols[1]] = 1
            }
            return Code(lengths: lengths, codes: codes)
        }
        if used.count < 2 {
            counts[used.first == 0 ? 1 : 0] = 1
        }
        let lengths = huffmanLengths(counts, limit: 15)
        writer.write(0, 1)
        writeLengths(lengths, to: &writer)
        return Code(lengths: lengths, codes: canonicalCodes(lengths))
    }

    private static func writeLengths(_ lengths: [Int], to writer: inout BitWriter) {
        var symbols: [(symbol: Int, extra: Int, bits: Int)] = []
        var index = 0
        while index < lengths.count {
            if lengths[index] != 0 {
                symbols.append((lengths[index], 0, 0))
                index += 1
                continue
            }
            var run = 0
            while index + run < lengths.count, lengths[index + run] == 0, run < 138 { run += 1 }
            if run >= 11 {
                symbols.append((18, run - 11, 7))
            } else if run >= 3 {
                symbols.append((17, run - 3, 3))
            } else {
                symbols.append(contentsOf: Array(repeating: (0, 0, 0), count: run))
            }
            index += run
        }
        var histogram = [Int](repeating: 0, count: 19)
        for item in symbols { histogram[item.symbol] += 1 }
        if histogram.filter({ $0 > 0 }).count < 2 {
            histogram[histogram[0] > 0 ? 1 : 0] = 1
        }
        let codeLengths = huffmanLengths(histogram, limit: 7)
        let codes = canonicalCodes(codeLengths)
        let order = [17, 18, 0, 1, 2, 3, 4, 5, 16, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
        let last = order.lastIndex { codeLengths[$0] > 0 } ?? 0
        let stored = max(4, last + 1)
        writer.write(stored - 4, 4)
        for position in 0..<stored { writer.write(codeLengths[order[position]], 3) }
        writer.write(0, 1)
        for item in symbols {
            writer.write(codes[item.symbol], codeLengths[item.symbol])
            writer.write(item.extra, item.bits)
        }
    }

    private static func huffmanLengths(_ histogram: [Int], limit: Int) -> [Int] {
        var counts = histogram
        while true {
            let lengths = treeLengths(counts)
            if (lengths.max() ?? 0) <= limit { return lengths }
            // Flattening the counts shortens the deepest branches and keeps the code complete.
            counts = counts.map { $0 == 0 ? 0 : max(1, $0 / 2) }
        }
    }

    private static func treeLengths(_ counts: [Int]) -> [Int] {
        var lengths = [Int](repeating: 0, count: counts.count)
        var nodes = counts.indices.filter { counts[$0] > 0 }.map { (weight: counts[$0], symbols: [$0]) }
        guard nodes.count >= 2 else { return lengths }
        while nodes.count > 1 {
            nodes.sort { $0.weight > $1.weight }
            let first = nodes.removeLast()
            let second = nodes.removeLast()
            let symbols = first.symbols + second.symbols
            for symbol in symbols { lengths[symbol] += 1 }
            nodes.append((first.weight + second.weight, symbols))
        }
        return lengths
    }

    /// Canonical codes with their bits reversed, because VP8L reads each code from its top bit.
    private static func canonicalCodes(_ lengths: [Int]) -> [Int] {
        var codes = [Int](repeating: 0, count: lengths.count)
        var next = 0
        for length in 1...15 {
            for symbol in lengths.indices where lengths[symbol] == length {
                var reversed = 0
                for bit in 0..<length where next >> bit & 1 == 1 {
                    reversed |= 1 << (length - 1 - bit)
                }
                codes[symbol] = reversed
                next += 1
            }
            next <<= 1
        }
        return codes
    }

    private static func container(_ payload: [UInt8]) -> Data {
        func little(_ value: Int) -> [UInt8] {
            (0..<4).map { UInt8((value >> ($0 * 8)) & 0xFF) }
        }
        let padded = payload.count + (payload.count % 2)
        var data = Data()
        data.append(contentsOf: Array("RIFF".utf8))
        data.append(contentsOf: little(4 + 8 + padded))
        data.append(contentsOf: Array("WEBP".utf8))
        data.append(contentsOf: Array("VP8L".utf8))
        data.append(contentsOf: little(payload.count))
        data.append(contentsOf: payload)
        if payload.count % 2 == 1 { data.append(0) }
        return data
    }
}
