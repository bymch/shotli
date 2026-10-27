import AppKit
import CoreGraphics

enum MotionCompose {
    struct Plate {
        var card: CGImage
        var baseTiltX: CGFloat
        var baseTiltY: CGFloat
        var style: ShotliStyle
    }

    static func plate(picture: LoadedPicture, crop: CGRect?, style: ShotliStyle, annotations: [Annotation]) -> Plate? {
        var flat = style
        flat.padding = max(8, min(style.padding, 36))
        flat.tiltX = 0
        flat.tiltY = 0
        flat.shadowKind = .none
        flat.shadow = 0
        flat.shiftX = 0
        flat.shiftY = 0
        flat.canvas = .auto
        flat.canvasWidth = 0
        flat.canvasHeight = 0
        guard let rendered = renderComposition(
            picture: picture,
            crop: crop,
            style: flat,
            annotations: annotations,
            draft: nil,
            interactive: false,
            omitBackground: true
        ) else { return nil }
        return Plate(
            card: fitted(rendered, maxEdge: 1600),
            baseTiltX: style.tiltX,
            baseTiltY: style.tiltY,
            style: style
        )
    }

    static func frame(
        plate: Plate,
        background: Background,
        pose: MotionPose,
        output: CGSize,
        backdrop: CGImage?
    ) -> (image: CGImage, backdrop: CGImage)? {
        let size = evenSize(output)
        let bleed = MotionFormat.bleed
        let backdropSize = CGSize(width: size.width + bleed * 2, height: size.height + bleed * 2)
        let backdropImage: CGImage
        if let backdrop, backdrop.width == Int(backdropSize.width), backdrop.height == Int(backdropSize.height) {
            backdropImage = backdrop
        } else if let rendered = renderBackdrop(background, size: backdropSize) {
            backdropImage = rendered
        } else {
            return nil
        }
        guard let context = bitmap(size) else { return nil }
        let parallaxX = min(bleed, max(-bleed, pose.parallaxX * size.width))
        let parallaxY = min(bleed, max(-bleed, pose.parallaxY * size.height))
        context.draw(
            backdropImage,
            in: CGRect(
                x: -bleed + parallaxX,
                y: -bleed + parallaxY,
                width: backdropSize.width,
                height: backdropSize.height
            )
        )

        let tiltX = clampDegrees(plate.baseTiltX + pose.tiltX)
        let tiltY = clampDegrees(plate.baseTiltY + pose.tiltY)
        let card = warpMotionCard(plate.card, tiltX: tiltX, tiltY: tiltY)
        let rect = cardRect(card: card, output: size, pose: pose)
        context.saveGState()
        context.translateBy(x: rect.midX, y: rect.midY)
        context.rotate(by: pose.rotation * .pi / 180)
        if let shadow = shadow(style: plate.style, gain: pose.shadowGain) {
            context.setShadow(offset: shadow.offset, blur: shadow.blur, color: shadow.color.cgColor)
        }
        context.draw(
            card,
            in: CGRect(x: -rect.width / 2, y: -rect.height / 2, width: rect.width, height: rect.height)
        )
        context.restoreGState()
        guard let image = context.makeImage() else { return nil }
        return (image, backdropImage)
    }

    private static func cardRect(card: CGImage, output: CGSize, pose: MotionPose) -> CGRect {
        let slack: CGFloat = 0.11
        let box = CGSize(width: output.width * (1 - slack * 2), height: output.height * (1 - slack * 2))
        let cardSize = CGSize(width: CGFloat(card.width), height: CGFloat(card.height))
        let fit = min(box.width / max(cardSize.width, 1), box.height / max(cardSize.height, 1))
        let maxScale: CGFloat = 1.09
        let scale = fit / maxScale * max(0.84, pose.scale)
        let width = cardSize.width * scale
        let height = cardSize.height * scale
        let center = CGPoint(
            x: output.width * (0.5 + pose.shiftX),
            y: output.height * (0.5 + pose.shiftY)
        )
        return CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height)
    }

    private static func shadow(style: ShotliStyle, gain: CGFloat) -> (offset: CGSize, blur: CGFloat, color: NSColor)? {
        guard style.shadowKind != .none, style.shadow > 0.5, style.shadowOpacity > 0.5 else { return nil }
        let depth = style.shadow / 100 * max(0.35, gain)
        let alpha = min(0.82, (0.06 + depth * 0.38) * (style.shadowOpacity / 40))
        switch style.shadowKind {
        case .none:
            return nil
        case .hug:
            return (
                CGSize(width: 0, height: -(1 + depth * 4)),
                2 + depth * 12,
                NSColor(srgbRed: 0.05, green: 0.05, blue: 0.06, alpha: min(0.9, alpha * 1.1))
            )
        case .adaptive, .spread:
            return (
                CGSize(width: 0, height: -(6 + depth * 28)),
                12 + depth * 48,
                NSColor(srgbRed: 0.07, green: 0.08, blue: 0.1, alpha: alpha)
            )
        }
    }

    private static func clampDegrees(_ value: CGFloat) -> CGFloat {
        min(12, max(-12, value))
    }

    static func evenSize(_ size: CGSize) -> CGSize {
        CGSize(width: CGFloat(even(size.width)), height: CGFloat(even(size.height)))
    }

    private static func even(_ value: CGFloat) -> Int {
        let rounded = max(2, Int(value.rounded()))
        return rounded.isMultiple(of: 2) ? rounded : rounded - 1
    }

    private static func fitted(_ image: CGImage, maxEdge: CGFloat) -> CGImage {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        let edge = max(width, height)
        guard edge > maxEdge, edge > 1 else { return image }
        let scale = maxEdge / edge
        let size = CGSize(width: floor(width * scale), height: floor(height * scale))
        guard let context = bitmap(size) else { return image }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(origin: .zero, size: size))
        return context.makeImage() ?? image
    }

    private static func bitmap(_ size: CGSize) -> CGContext? {
        let width = Int(size.width.rounded())
        let height = Int(size.height.rounded())
        guard width > 1, height > 1 else { return nil }
        return CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    }
}
