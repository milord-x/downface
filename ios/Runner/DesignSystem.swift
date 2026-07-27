import SwiftUI

enum DFColor {
    static let background = Color.black
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.6)
    static let textTertiary = Color.white.opacity(0.38)
    static let divider = Color.white.opacity(0.12)
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
