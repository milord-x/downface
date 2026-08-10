import SwiftUI

/// User-selectable app theme, independent of the system appearance.
enum AppTheme: String, CaseIterable {
    case dark
    case light

    var colorScheme: ColorScheme {
        self == .dark ? .dark : .light
    }

    var userInterfaceStyle: UIUserInterfaceStyle {
        self == .dark ? .dark : .light
    }
}

@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    private static let key = "app_theme"

    @Published var theme: AppTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: Self.key) }
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: Self.key)
        theme = saved.flatMap(AppTheme.init(rawValue:)) ?? .dark
    }
}

/// Pure black/white theme colors. Each is a dynamic `UIColor` that resolves
/// against the trait collection, so it automatically flips when
/// `.preferredColorScheme()` (driven by ThemeManager) changes the active
/// trait – no manual view subscriptions needed.
enum DFColor {
    static let background = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? .black : .white
    })

    static let textPrimary = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? .white : .black
    })

    static let textSecondary = Color(UIColor { traits in
        (traits.userInterfaceStyle == .dark ? UIColor.white : .black).withAlphaComponent(0.6)
    })

    static let textTertiary = Color(UIColor { traits in
        (traits.userInterfaceStyle == .dark ? UIColor.white : .black).withAlphaComponent(0.38)
    })

    static let divider = Color(UIColor { traits in
        (traits.userInterfaceStyle == .dark ? UIColor.white : .black).withAlphaComponent(0.12)
    })

    /// Fill used for content cards (never glass, per Apple HIG – glass is
    /// reserved for the floating navigation/control layer).
    static let cardFill = Color(UIColor { traits in
        (traits.userInterfaceStyle == .dark ? UIColor.white : .black).withAlphaComponent(0.06)
    })

    static let cardFillStrong = Color(UIColor { traits in
        (traits.userInterfaceStyle == .dark ? UIColor.white : .black).withAlphaComponent(0.08)
    })

    static let scrim = Color(UIColor { traits in
        (traits.userInterfaceStyle == .dark ? UIColor.white : .black).withAlphaComponent(0.1)
    })
}

enum DFType {
    static let display = Font.system(size: 34, weight: .bold, design: .rounded)
    static let title = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let body = Font.system(size: 16, weight: .medium, design: .rounded)
    static let caption = Font.system(size: 13, weight: .medium, design: .rounded)
    static let number = Font.system(size: 64, weight: .heavy, design: .rounded)
}

enum DFSpacing {
    static let screenPadding: CGFloat = 20
    static let cardPadding: CGFloat = 20
    static let stackGap: CGFloat = 16
}

/// Liquid Glass (`.glassEffect`, `.buttonStyle(.glass...)`,
/// `GlassEffectContainer`) only exists from iOS 26 – calling it on 17/18
/// crashes at runtime, not just looks wrong. Every card and button in the
/// app goes through these two modifiers instead of calling glass APIs
/// directly, so the iOS-26-or-not branch lives in exactly one place rather
/// than being copy-pasted at each of the ~46 call sites across the view
/// files. On 17/18 they fall back to the flat `cardFill`/`cardFillStrong`
/// backgrounds the app used before Liquid Glass existed.
extension View {
    /// Standard content card surface (activity/stats cards, metric tiles,
    /// grouped settings sections).
    @ViewBuilder
    func dfCardSurface(cornerRadius: CGFloat, prominent: Bool = false) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            self.background(
                prominent ? DFColor.cardFillStrong : DFColor.cardFill,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        }
    }

    /// Primary filled action button (white pill, black label) – "begin
    /// set", "done", "start workout".
    @ViewBuilder
    func dfPrimaryButtonStyle() -> some View {
        if #available(iOS 26, *) {
            self.buttonStyle(.glassProminent).tint(.white).foregroundStyle(.black)
        } else {
            self.buttonStyle(.plain)
                .background(Color.white, in: Capsule())
                .foregroundStyle(.black)
        }
    }

    /// Secondary outline-style button ("finish workout", "cancel").
    @ViewBuilder
    func dfSecondaryButtonStyle() -> some View {
        if #available(iOS 26, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.plain)
                .background(DFColor.cardFillStrong, in: Capsule())
                .foregroundStyle(DFColor.textPrimary)
        }
    }

    /// Small round icon button (close, back, light-boost toggle).
    @ViewBuilder
    func dfCircleButtonStyle(prominent: Bool = false) -> some View {
        if #available(iOS 26, *) {
            if prominent {
                self.buttonStyle(.glassProminent).tint(.white).buttonBorderShape(.circle)
            } else {
                self.buttonStyle(.glass).buttonBorderShape(.circle)
            }
        } else {
            self.buttonStyle(.plain)
                .background(prominent ? Color.white : DFColor.cardFillStrong, in: Circle())
        }
    }

    /// `glassEffectID(_:in:)` itself only exists on iOS 26 – calling it
    /// unconditionally doesn't just look wrong on 17/18, it fails to
    /// compile once the deployment target drops below 26. On 17/18 there's
    /// no glass to morph between buttons for, so this is a no-op there.
    @ViewBuilder
    func dfGlassID(_ id: String, in namespace: Namespace.ID) -> some View {
        if #available(iOS 26, *) {
            self.glassEffectID(id, in: namespace)
        } else {
            self
        }
    }
}

/// Groups glass buttons that morph into each other on iOS 26
/// (`GlassEffectContainer` + `glassEffectID`). On 17/18 there's no glass
/// morphing to opt into, so this is a plain container – the buttons inside
/// it render normally without a shared namespace or transition.
struct DFButtonGroup<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: () -> Content

    init(spacing: CGFloat = 16, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        // Callers always wrap their own HStack/VStack inside this – the
        // container itself never dictates layout direction, only whether
        // glass morphing is active, so the 17/18 branch is a plain
        // passthrough rather than guessing a direction.
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: spacing) { content() }
        } else {
            content()
        }
    }
}
