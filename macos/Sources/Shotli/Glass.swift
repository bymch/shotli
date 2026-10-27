import AppKit
import SwiftUI

/// Shared material for Shotli's editor chrome. The screenshot and the exported
/// image never use these views.
enum ShotliGlass {
    enum Role {
        /// Large surfaces that hold text and controls. More opaque.
        case panel
        /// Compact bars and transient controls over a varied backdrop.
        case compact
    }

    static let accent = Color(nsColor: NSColor(srgbRed: 18.0 / 255.0, green: 120.0 / 255.0, blue: 180.0 / 255.0, alpha: 1))
    static let ink = Color(nsColor: NSColor(srgbRed: 28.0 / 255.0, green: 30.0 / 255.0, blue: 36.0 / 255.0, alpha: 1))
    static let line = Color.black.opacity(0.12)

    static let workspaceTop = NSColor(srgbRed: 0.905, green: 0.918, blue: 0.945, alpha: 1)
    static let workspaceBottom = NSColor(srgbRed: 0.855, green: 0.872, blue: 0.910, alpha: 1)

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

    static func fallback(_ role: Role) -> Color {
        switch role {
        case .panel:
            return Color(nsColor: NSColor(srgbRed: 0.945, green: 0.948, blue: 0.962, alpha: 1))
        case .compact:
            return Color(nsColor: NSColor(srgbRed: 0.955, green: 0.958, blue: 0.970, alpha: 1))
        }
    }
}

struct ShotliWorkspaceWash: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(nsColor: ShotliGlass.workspaceTop),
                Color(nsColor: ShotliGlass.workspaceBottom),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
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
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let scrim = ShotliGlass.scrim(role)
        ZStack {
            if reduceTransparency {
                shape.fill(ShotliGlass.fallback(role))
            } else {
                ShotliVisualEffect(material: ShotliGlass.material(role), radius: radius)
                shape.fill(
                    LinearGradient(
                        colors: [Color.white.opacity(scrim.top), Color.white.opacity(scrim.bottom)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            shape.strokeBorder(
                reduceTransparency ? Color.black.opacity(0.12) : Color.white.opacity(0.78),
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

    func body(content: Content) -> some View {
        let shadow = ShotliGlass.shadow(role)
        content
            .background(ShotliGlassPlate(role: role, radius: radius))
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(
                color: Color.black.opacity(castsShadow ? shadow.opacity : 0),
                radius: castsShadow ? shadow.radius : 0,
                y: castsShadow ? shadow.y : 0
            )
    }
}

extension View {
    func shotliGlass(_ role: ShotliGlass.Role, radius: CGFloat, shadow: Bool = true) -> some View {
        modifier(ShotliGlassModifier(role: role, radius: radius, castsShadow: shadow))
    }

    func shotliCapsuleChip() -> some View {
        background(
            Capsule()
                .fill(Color.white.opacity(ShotliGlass.chipFill))
                .overlay(Capsule().strokeBorder(Color.white.opacity(ShotliGlass.chipHighlight), lineWidth: 0.8))
                .overlay(Capsule().strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5))
        )
    }

    func shotliRoundedChip(radius: CGFloat = ShotliGlass.radiusChip) -> some View {
        background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Color.white.opacity(ShotliGlass.chipFill))
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(Color.white.opacity(ShotliGlass.chipHighlight), lineWidth: 0.8)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5)
                )
        )
    }
}
