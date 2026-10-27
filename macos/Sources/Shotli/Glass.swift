import AppKit
import SwiftUI

/// Shared material for Shotli's editor chrome. The screenshot and the exported
/// image never use these views. Tokens follow the window appearance.
enum ShotliGlass {
    enum Role {
        /// Large surfaces that hold text and controls. More opaque.
        case panel
        /// Compact bars and transient controls over a varied backdrop.
        case compact
    }

    static let accent = Color(nsColor: srgb(18.0 / 255.0, 120.0 / 255.0, 180.0 / 255.0))
    static func ink(_ scheme: ColorScheme) -> Color {
        tone(scheme, light: srgb(28.0 / 255.0, 30.0 / 255.0, 36.0 / 255.0), dark: srgb(0.94, 0.95, 0.97))
    }
    static func line(_ scheme: ColorScheme) -> Color {
        tone(scheme, light: NSColor.black.withAlphaComponent(0.12), dark: NSColor.white.withAlphaComponent(0.16))
    }
    static func hairline(_ scheme: ColorScheme) -> Color {
        tone(scheme, light: NSColor.black.withAlphaComponent(0.06), dark: NSColor.white.withAlphaComponent(0.12))
    }

    static let workspaceTop = dynamic(light: srgb(0.905, 0.918, 0.945), dark: srgb(0.10, 0.12, 0.17))
    static let workspaceBottom = dynamic(light: srgb(0.855, 0.872, 0.910), dark: srgb(0.06, 0.07, 0.11))
    static let stageColor = dynamic(light: srgb(0.945, 0.945, 0.945), dark: srgb(0.055, 0.065, 0.10))
    static let controlFill = dynamic(light: srgb(0.945, 0.945, 0.945), dark: srgb(0.16, 0.18, 0.25))
    static let inkColor = dynamic(light: srgb(28.0 / 255.0, 30.0 / 255.0, 36.0 / 255.0), dark: srgb(0.94, 0.95, 0.97))
    static let hairlineColor = dynamic(light: NSColor.black.withAlphaComponent(0.08), dark: NSColor.white.withAlphaComponent(0.16))

    static func page(_ scheme: ColorScheme) -> Color {
        tone(scheme, light: srgb(0.945, 0.945, 0.945), dark: srgb(0.07, 0.08, 0.12))
    }
    static func sidebar(_ scheme: ColorScheme) -> Color {
        tone(scheme, light: srgb(0.965, 0.968, 0.978), dark: srgb(0.065, 0.075, 0.11))
    }
    static func surface(_ scheme: ColorScheme) -> Color {
        tone(scheme, light: .white, dark: srgb(0.145, 0.165, 0.22))
    }
    static func surfaceSecondary(_ scheme: ColorScheme) -> Color {
        tone(scheme, light: srgb(0.945, 0.948, 0.962), dark: srgb(0.11, 0.125, 0.175))
    }
    static func elevated(_ scheme: ColorScheme) -> Color {
        tone(scheme, light: .white, dark: srgb(0.18, 0.20, 0.27))
    }
    static func search(_ scheme: ColorScheme) -> Color {
        tone(scheme, light: srgb(0.955, 0.958, 0.970), dark: srgb(0.12, 0.14, 0.19))
    }
    static func hover(_ scheme: ColorScheme) -> Color {
        tone(scheme, light: NSColor.white.withAlphaComponent(0.45), dark: NSColor.white.withAlphaComponent(0.08))
    }
    static func pressed(_ scheme: ColorScheme) -> Color {
        tone(scheme, light: NSColor.black.withAlphaComponent(0.06), dark: NSColor.white.withAlphaComponent(0.12))
    }
    static func rowHover(_ scheme: ColorScheme) -> Color {
        tone(scheme, light: srgb(18.0 / 255.0, 120.0 / 255.0, 180.0 / 255.0, 0.08), dark: NSColor.white.withAlphaComponent(0.08))
    }
    static func rowPressed(_ scheme: ColorScheme) -> Color {
        tone(scheme, light: srgb(18.0 / 255.0, 120.0 / 255.0, 180.0 / 255.0, 0.16), dark: NSColor.white.withAlphaComponent(0.14))
    }
    static func quiet(_ scheme: ColorScheme) -> Color {
        tone(scheme, light: NSColor.black.withAlphaComponent(0.05), dark: NSColor.white.withAlphaComponent(0.08))
    }
    static func selectedNav(_ scheme: ColorScheme) -> Color {
        tone(
            scheme,
            light: srgb(18.0 / 255.0, 120.0 / 255.0, 180.0 / 255.0, 0.14),
            dark: srgb(18.0 / 255.0, 120.0 / 255.0, 180.0 / 255.0, 0.32)
        )
    }
    static func selectedCard(_ scheme: ColorScheme) -> Color {
        tone(
            scheme,
            light: srgb(18.0 / 255.0, 120.0 / 255.0, 180.0 / 255.0, 0.08),
            dark: srgb(18.0 / 255.0, 120.0 / 255.0, 180.0 / 255.0, 0.22)
        )
    }
    static func segment(_ scheme: ColorScheme) -> Color {
        tone(scheme, light: NSColor.white.withAlphaComponent(0.78), dark: NSColor.white.withAlphaComponent(0.14))
    }
    static func segmentSolid(_ scheme: ColorScheme) -> Color {
        tone(scheme, light: .white, dark: srgb(0.26, 0.30, 0.40))
    }
    static func segmentEdge(_ scheme: ColorScheme) -> Color {
        tone(scheme, light: NSColor.white.withAlphaComponent(0.8), dark: NSColor.white.withAlphaComponent(0.22))
    }
    static func focusRing(_ scheme: ColorScheme) -> Color {
        tone(scheme, light: NSColor.white.withAlphaComponent(0.92), dark: NSColor.white.withAlphaComponent(0.38))
    }
    static func emphasis(_ scheme: ColorScheme) -> Color {
        tone(scheme, light: NSColor.black.withAlphaComponent(0.82), dark: NSColor.white.withAlphaComponent(0.88))
    }
    static func capsule(_ scheme: ColorScheme) -> Color {
        tone(scheme, light: NSColor.white.withAlphaComponent(0.72), dark: NSColor.white.withAlphaComponent(0.10))
    }
    static func selectedControl(_ scheme: ColorScheme) -> Color {
        tone(scheme, light: .black, dark: srgb(0.93, 0.94, 0.97))
    }
    static func selectedControlInk(_ scheme: ColorScheme) -> Color {
        tone(scheme, light: .white, dark: srgb(0.08, 0.09, 0.12))
    }
    static func emptyIcon(_ scheme: ColorScheme) -> Color {
        tone(
            scheme,
            light: srgb(28.0 / 255.0, 30.0 / 255.0, 36.0 / 255.0, 0.34),
            dark: srgb(0.93, 0.94, 0.97, 0.62)
        )
    }
    static func error(_ scheme: ColorScheme) -> Color {
        tone(scheme, light: srgb(193.0 / 255.0, 54.0 / 255.0, 54.0 / 255.0), dark: srgb(1.0, 0.48, 0.45))
    }
    static func success(_ scheme: ColorScheme) -> Color {
        tone(scheme, light: srgb(0.12, 0.54, 0.30), dark: srgb(0.45, 0.82, 0.58))
    }
    static func warning(_ scheme: ColorScheme) -> Color {
        tone(scheme, light: srgb(0.72, 0.48, 0.08), dark: srgb(0.93, 0.72, 0.38))
    }

    static func tone(_ scheme: ColorScheme, light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: scheme == .dark ? dark : light)
    }

    static let duration: Double = 0.16
    static let pressedOpacity: Double = 0.82
    static let chipFill: Double = 0.66
    static let chipHighlight: Double = 0.82

    static let radiusPanel: CGFloat = 22
    static let radiusBar: CGFloat = 20
    static let radiusOverlay: CGFloat = 26
    static let radiusChip: CGFloat = 10
    static let pageInset: CGFloat = 12
    static let controlHeight: CGFloat = 32

    static func material(_ role: Role) -> NSVisualEffectView.Material {
        switch role {
        case .panel: return .sheet
        case .compact: return .underWindowBackground
        }
    }

    static func scrim(_ role: Role) -> (top: Double, bottom: Double) {
        switch role {
        case .panel: return (0.58, 0.40)
        case .compact: return (0.40, 0.20)
        }
    }

    static func shadow(_ role: Role) -> (opacity: Double, radius: CGFloat, y: CGFloat) {
        switch role {
        case .panel: return (0.10, 18, 8)
        case .compact: return (0.12, 14, 6)
        }
    }

    static func plateScrim(_ role: Role, dark: Bool) -> (Color, Color) {
        if dark {
            switch role {
            case .panel:
                return (
                    Color(nsColor: srgb(0.24, 0.32, 0.48, 0.28)),
                    Color(nsColor: srgb(0.07, 0.08, 0.13, 0.78))
                )
            case .compact:
                return (
                    Color(nsColor: srgb(1, 1, 1, 0.07)),
                    Color(nsColor: srgb(0.05, 0.06, 0.10, 0.62))
                )
            }
        }
        let amount = scrim(role)
        return (Color.white.opacity(amount.top), Color.white.opacity(amount.bottom))
    }

    static func plateEdge(dark: Bool, reduceTransparency: Bool) -> Color {
        if reduceTransparency {
            return dark ? Color.white.opacity(0.16) : Color.black.opacity(0.12)
        }
        return dark ? Color.white.opacity(0.16) : Color.white.opacity(0.78)
    }

    static func fallback(_ role: Role, dark: Bool) -> Color {
        if dark {
            switch role {
            case .panel: return Color(nsColor: srgb(0.13, 0.15, 0.21))
            case .compact: return Color(nsColor: srgb(0.16, 0.18, 0.25))
            }
        }
        switch role {
        case .panel: return Color(nsColor: srgb(0.945, 0.948, 0.962))
        case .compact: return Color(nsColor: srgb(0.955, 0.958, 0.970))
        }
    }

    static func chipFill(dark: Bool, opaque: Bool) -> Color {
        if dark {
            return Color(nsColor: srgb(0.18, 0.20, 0.28, opaque ? 1 : 0.72))
        }
        return Color.white.opacity(chipFill)
    }

    static func chipHighlight(dark: Bool) -> Color {
        dark ? Color.white.opacity(0.18) : Color.white.opacity(chipHighlight)
    }

    static func chipLine(dark: Bool) -> Color {
        dark ? Color.white.opacity(0.10) : Color.black.opacity(0.08)
    }

    static func srgb(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }

    static func dynamic(light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }

}

struct ShotliWorkspaceWash: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [top, bottom],
                startPoint: .top,
                endPoint: .bottom
            )
            if scheme == .dark && !reduceTransparency {
                RadialGradient(
                    colors: [
                        Color(nsColor: ShotliGlass.srgb(0.20, 0.32, 0.55, 0.36)),
                        Color.clear,
                    ],
                    center: .topTrailing,
                    startRadius: 12,
                    endRadius: 560
                )
                RadialGradient(
                    colors: [
                        Color(nsColor: ShotliGlass.srgb(0.28, 0.18, 0.46, 0.26)),
                        Color.clear,
                    ],
                    center: .bottomLeading,
                    startRadius: 8,
                    endRadius: 480
                )
            }
        }
    }

    private var top: Color {
        scheme == .dark
            ? Color(nsColor: ShotliGlass.srgb(0.10, 0.12, 0.17))
            : Color(nsColor: ShotliGlass.srgb(0.905, 0.918, 0.945))
    }

    private var bottom: Color {
        scheme == .dark
            ? Color(nsColor: ShotliGlass.srgb(0.06, 0.07, 0.11))
            : Color(nsColor: ShotliGlass.srgb(0.855, 0.872, 0.910))
    }
}

private struct ShotliVisualEffect: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var radius: CGFloat

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .withinWindow
        view.state = .active
        view.isEmphasized = false
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = .withinWindow
        view.state = .active
        view.isEmphasized = false
        guard let layer = view.layer else { return }
        layer.cornerRadius = radius
        layer.cornerCurve = .continuous
        layer.masksToBounds = true
    }
}

private struct ShotliGlassPlate: View {
    var role: ShotliGlass.Role
    var radius: CGFloat
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let scrim = ShotliGlass.plateScrim(role, dark: scheme == .dark)
        ZStack {
            if reduceTransparency {
                shape.fill(ShotliGlass.fallback(role, dark: scheme == .dark))
            } else {
                ShotliVisualEffect(material: ShotliGlass.material(role), radius: radius)
                shape.fill(
                    LinearGradient(
                        colors: [scrim.0, scrim.1],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            shape.strokeBorder(
                ShotliGlass.plateEdge(dark: scheme == .dark, reduceTransparency: reduceTransparency),
                lineWidth: reduceTransparency ? 1 : 0.8
            )
        }
        .allowsHitTesting(false)
    }
}

private struct ShotliGlassModifier: ViewModifier {
    var role: ShotliGlass.Role
    var radius: CGFloat
    var castsShadow: Bool
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let shadow = ShotliGlass.shadow(role)
        let opacity = scheme == .dark ? min(0.45, shadow.opacity + 0.22) : shadow.opacity
        content
            .background(ShotliGlassPlate(role: role, radius: radius))
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(
                color: Color.black.opacity(castsShadow ? opacity : 0),
                radius: castsShadow ? shadow.radius : 0,
                y: castsShadow ? shadow.y : 0
            )
    }
}

private struct ShotliChipPlate: View {
    var capsule: Bool
    var radius: CGFloat
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        let dark = scheme == .dark
        let fill = ShotliGlass.chipFill(dark: dark, opaque: reduceTransparency)
        let highlight = ShotliGlass.chipHighlight(dark: dark)
        let edge = ShotliGlass.chipLine(dark: dark)
        if capsule {
            Capsule()
                .fill(fill)
                .overlay(Capsule().strokeBorder(highlight, lineWidth: 0.8))
                .overlay(Capsule().strokeBorder(edge, lineWidth: 0.5))
        } else {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(fill)
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(highlight, lineWidth: 0.8)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(edge, lineWidth: 0.5)
                )
        }
    }
}

extension View {
    func shotliGlass(_ role: ShotliGlass.Role, radius: CGFloat, shadow: Bool = true) -> some View {
        modifier(ShotliGlassModifier(role: role, radius: radius, castsShadow: shadow))
    }

    func shotliCapsuleChip() -> some View {
        background(ShotliChipPlate(capsule: true, radius: ShotliGlass.radiusChip))
    }

    func shotliRoundedChip(radius: CGFloat = ShotliGlass.radiusChip) -> some View {
        background(ShotliChipPlate(capsule: false, radius: radius))
    }

    func shotliAppearance() -> some View {
        modifier(ShotliAppearanceModifier())
    }
}

private struct ShotliAppearanceModifier: ViewModifier {
    @ObservedObject private var settings = ShotliSettings.shared

    func body(content: Content) -> some View {
        content.preferredColorScheme(settings.appearance.colorScheme)
    }
}
