import AppKit

struct MagicColor: Identifiable, Equatable {
    var hex: String
    var name: String
    var wash: Background
    var id: String { hex }
}

struct MagicBackground: Identifiable, Equatable {
    var id: String
    var name: String
    var background: Background
}

struct MagicReading {
    var colors: [MagicColor]
    var backgrounds: [MagicBackground]
}

enum MagicPalette {
    static func read(_ image: CGImage) -> MagicReading {
        let pixels = sample(image)
        guard !pixels.isEmpty else { return fallback }
        let accents = accentColors(in: pixels)
        if accents.isEmpty {
            return neutralReading(pixels)
        }
        return coloredReading(accents)
    }

    static func wash(for hex: String) -> Background {
        let color = NSColor(hex: hex) ?? NSColor(srgbRed: 0.2, green: 0.4, blue: 0.8, alpha: 1)
        return .color(self.hex(shift(color, saturation: 0.14, brightness: 0.97)))
    }

    private static var fallback: MagicReading {
        let paper = "#F6F4F1"
        let ink = "#1A1B1F"
        return MagicReading(
            colors: [MagicColor(hex: paper, name: "Paper", wash: .color(paper))],
            backgrounds: [
                MagicBackground(id: "paper", name: "Paper", background: .color(paper)),
                MagicBackground(id: "mist", name: "Mist", background: .gradient(from: "#F7F5F2", mid: "#E4EAF1", to: "#D5DDE8", angle: 160)),
                MagicBackground(id: "ink", name: "Ink", background: .color(ink)),
            ]
        )
    }

    private static func coloredReading(_ accents: [NSColor]) -> MagicReading {
        let primary = accents[0]
        let secondary = accents.count > 1 ? accents[1] : nil
        var colors: [MagicColor] = []
        var backgrounds: [MagicBackground] = []

        for (index, accent) in accents.prefix(4).enumerated() {
            let name = hueName(accent)
            let wash = self.hex(shift(accent, saturation: 0.14, brightness: 0.97))
            colors.append(MagicColor(hex: self.hex(accent), name: name, wash: .color(wash)))
            if index == 0 {
                backgrounds.append(MagicBackground(id: "wash", name: "\(name) wash", background: .color(wash)))
                backgrounds.append(MagicBackground(
                    id: "soft",
                    name: "Soft \(name.lowercased())",
                    background: .color(self.hex(shift(accent, saturation: 0.26, brightness: 0.93)))
                ))
                backgrounds.append(MagicBackground(
                    id: "field",
                    name: "\(name) field",
                    background: .gradient(
                        from: self.hex(shift(accent, saturation: 0.12, brightness: 0.98)),
                        mid: self.hex(shift(accent, saturation: 0.22, brightness: 0.90)),
                        to: self.hex(shift(accent, saturation: 0.38, brightness: 0.78)),
                        angle: 155
                    )
                ))
                backgrounds.append(MagicBackground(
                    id: "deep",
                    name: "Deep \(name.lowercased())",
                    background: .color(self.hex(shift(accent, saturation: 0.46, brightness: 0.20)))
                ))
                let opposite = rotate(accent, degrees: 180)
                let oppositeName = hueName(opposite)
                backgrounds.append(MagicBackground(
                    id: "complement",
                    name: "\(oppositeName) wash",
                    background: .color(self.hex(shift(opposite, saturation: 0.16, brightness: 0.96)))
                ))
                backgrounds.append(MagicBackground(
                    id: "complement-deep",
                    name: "Deep \(oppositeName.lowercased())",
                    background: .color(self.hex(shift(opposite, saturation: 0.40, brightness: 0.22)))
                ))
            }
        }

        if let secondary {
            let from = shift(primary, saturation: 0.16, brightness: 0.96)
            let to = shift(secondary, saturation: 0.20, brightness: 0.90)
            backgrounds.append(MagicBackground(
                id: "duo",
                name: "\(hueName(primary)) and \(hueName(secondary).lowercased())",
                background: .gradient(from: self.hex(from), mid: nil, to: self.hex(to), angle: 135)
            ))
        }

        return MagicReading(colors: colors, backgrounds: unique(backgrounds))
    }

    private static func neutralReading(_ pixels: [NSColor]) -> MagicReading {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        for pixel in pixels {
            var pr: CGFloat = 0, pg: CGFloat = 0, pb: CGFloat = 0, pa: CGFloat = 0
            pixel.getRed(&pr, green: &pg, blue: &pb, alpha: &pa)
            r += pr
            g += pg
            b += pb
        }
        let count = CGFloat(pixels.count)
        let average = NSColor(srgbRed: r / count, green: g / count, blue: b / count, alpha: 1)
        let paper = shift(average, saturation: 0.06, brightness: 0.97)
        let soft = shift(average, saturation: 0.10, brightness: 0.92)
        let ink = shift(average, saturation: 0.12, brightness: 0.14)
        let paperHex = self.hex(paper)
        return MagicReading(
            colors: [MagicColor(hex: self.hex(average), name: "Paper", wash: .color(paperHex))],
            backgrounds: [
                MagicBackground(id: "paper", name: "Paper", background: .color(paperHex)),
                MagicBackground(id: "soft-paper", name: "Soft paper", background: .color(self.hex(soft))),
                MagicBackground(
                    id: "field",
                    name: "Field",
                    background: .gradient(from: paperHex, mid: self.hex(soft), to: self.hex(shift(average, saturation: 0.14, brightness: 0.84)), angle: 160)
                ),
                MagicBackground(id: "ink", name: "Ink", background: .color(self.hex(ink))),
            ]
        )
    }

    private static func unique(_ items: [MagicBackground]) -> [MagicBackground] {
        var seen: [Background] = []
        return items.filter { item in
            guard !seen.contains(item.background) else { return false }
            seen.append(item.background)
            return true
        }
    }

    private static func accentColors(in pixels: [NSColor]) -> [NSColor] {
        struct Bin {
            var weight: CGFloat = 0
            var r: CGFloat = 0
            var g: CGFloat = 0
            var b: CGFloat = 0
        }
        var bins = Array(repeating: Bin(), count: 24)
        for pixel in pixels {
            var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
            pixel.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
            guard saturation >= 0.14, brightness > 0.08, brightness < 0.98 else { continue }
            let index = min(23, Int(hue * 24))
            let weight = saturation * saturation * (0.45 + 0.55 * brightness)
            bins[index].weight += weight
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
            pixel.getRed(&r, green: &g, blue: &b, alpha: &alpha)
            bins[index].r += r * weight
            bins[index].g += g * weight
            bins[index].b += b * weight
        }

        var picked: [NSColor] = []
        var blocked = Set<Int>()
        for _ in 0..<4 {
            var best = -1
            var bestWeight: CGFloat = 1.2
            for index in bins.indices where !blocked.contains(index) && bins[index].weight > bestWeight {
                best = index
                bestWeight = bins[index].weight
            }
            guard best >= 0 else { break }
            let bin = bins[best]
            picked.append(NSColor(srgbRed: bin.r / bin.weight, green: bin.g / bin.weight, blue: bin.b / bin.weight, alpha: 1))
            for index in bins.indices where hueDistance(index, best) <= 2 {
                blocked.insert(index)
            }
        }
        return picked
    }

    private static func hueDistance(_ a: Int, _ b: Int) -> Int {
        let delta = abs(a - b)
        return min(delta, 24 - delta)
    }

    private static func sample(_ image: CGImage) -> [NSColor] {
        let side = 120
        var bytes = [UInt8](repeating: 0, count: side * side * 4)
        let drew = bytes.withUnsafeMutableBytes { raw -> Bool in
            guard let context = CGContext(
                data: raw.baseAddress,
                width: side,
                height: side,
                bitsPerComponent: 8,
                bytesPerRow: side * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard drew else { return [] }
        var pixels: [NSColor] = []
        pixels.reserveCapacity(side * side)
        for index in stride(from: 0, to: bytes.count, by: 4) {
            let alpha = CGFloat(bytes[index + 3]) / 255
            guard alpha > 0.2 else { continue }
            let red = min(1, CGFloat(bytes[index]) / 255 / alpha)
            let green = min(1, CGFloat(bytes[index + 1]) / 255 / alpha)
            let blue = min(1, CGFloat(bytes[index + 2]) / 255 / alpha)
            pixels.append(NSColor(srgbRed: red, green: green, blue: blue, alpha: 1))
        }
        return pixels
    }

    private static func shift(_ color: NSColor, saturation: CGFloat, brightness: CGFloat) -> NSColor {
        var hue: CGFloat = 0, currentSaturation: CGFloat = 0, currentBrightness: CGFloat = 0, alpha: CGFloat = 0
        color.usingColorSpace(.sRGB)?.getHue(&hue, saturation: &currentSaturation, brightness: &currentBrightness, alpha: &alpha)
        let keptHue = currentSaturation < 0.04 ? 0 : hue
        return NSColor(hue: keptHue, saturation: saturation, brightness: brightness, alpha: 1)
    }

    private static func rotate(_ color: NSColor, degrees: CGFloat) -> NSColor {
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        color.usingColorSpace(.sRGB)?.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        let turned = (hue + degrees / 360).truncatingRemainder(dividingBy: 1)
        return NSColor(hue: turned < 0 ? turned + 1 : turned, saturation: max(saturation, 0.4), brightness: max(brightness, 0.45), alpha: 1)
    }

    private static func hueName(_ color: NSColor) -> String {
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        color.usingColorSpace(.sRGB)?.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        if saturation < 0.08 { return brightness < 0.4 ? "Ink" : "Paper" }
        switch hue {
        case ..<0.04, 0.96...: return "Red"
        case ..<0.08: return "Orange"
        case ..<0.12: return "Amber"
        case ..<0.18: return "Gold"
        case ..<0.25: return "Olive"
        case ..<0.42: return "Green"
        case ..<0.50: return "Teal"
        case ..<0.58: return "Cyan"
        case ..<0.72: return "Blue"
        case ..<0.80: return "Indigo"
        case ..<0.90: return "Purple"
        default: return "Pink"
        }
    }

    private static func hex(_ color: NSColor) -> String {
        guard let rgb = color.usingColorSpace(.sRGB) else { return "#F4F1EC" }
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        rgb.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(format: "#%02X%02X%02X", byte(red), byte(green), byte(blue))
    }

    private static func byte(_ channel: CGFloat) -> Int {
        Int((min(1, max(0, channel)) * 255).rounded())
    }
}
