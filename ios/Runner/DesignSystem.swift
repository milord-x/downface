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
/// trait — no manual view subscriptions needed.
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

    /// Fill used for content cards (never glass, per Apple HIG — glass is
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
