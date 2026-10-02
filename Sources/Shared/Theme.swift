import SwiftUI

enum Theme: String, CaseIterable, Identifiable {
    case graphite, clay, moss, inkBlue, forest, plum

    static let storageKey = "selectedTheme"
    var id: String { rawValue }

    var title: String {
        switch self {
        case .clay: "Clay"
        case .moss: "Moss"
        case .inkBlue: "Ink Blue"
        case .forest: "Forest"
        case .graphite: "Graphite"
        case .plum: "Plum"
        }
    }

    var accent: Color {
        switch self {
        case .clay: Self.color(light: 0xAD5030, dark: 0xE7A080)
        case .moss: Self.color(light: 0x596E53, dark: 0xB8C8AA)
        case .inkBlue: Self.color(light: 0x324E76, dark: 0xA9BFDF)
        case .forest: Self.color(light: 0x2C6254, dark: 0xA9CFBF)
        case .graphite: Self.color(light: 0x56534F, dark: 0xCAC5BE)
        case .plum: Self.color(light: 0x695677, dark: 0xC9B3DC)
        }
    }

    var onAccent: Color {
        switch self {
        case .clay: Self.color(light: 0xFFF9EF, dark: 0x241D17)
        case .graphite: Self.color(light: 0xFFFFFF, dark: 0x1D1C1B)
        default: background
        }
    }

    var background: Color {
        switch self {
        case .clay: Self.color(light: 0xEEE9E0, dark: 0x241D17)
        case .moss: Self.color(light: 0xF6F7F1, dark: 0x191F18)
        case .inkBlue: Self.color(light: 0xF4F5F4, dark: 0x141B24)
        case .forest: Self.color(light: 0xF5F6F1, dark: 0x151E1A)
        case .graphite: Self.color(light: 0xF6F5F3, dark: 0x1D1C1B)
        case .plum: Self.color(light: 0xF4F1F7, dark: 0x1D1722)
        }
    }

    var paper: Color {
        switch self {
        case .clay: Self.color(light: 0xFAF6EB, dark: 0x31271F)
        case .moss: Self.color(light: 0xFFFFFF, dark: 0x252D22)
        case .inkBlue: Self.color(light: 0xFFFFFF, dark: 0x202731)
        case .forest: Self.color(light: 0xFFFFFF, dark: 0x202923)
        case .graphite: Self.color(light: 0xFEFDFC, dark: 0x2A2927)
        case .plum: Self.color(light: 0xFFFFFF, dark: 0x292330)
        }
    }

    var ink: Color {
        switch self {
        case .clay: Self.color(light: 0x293B29, dark: 0xF2ECDF)
        case .moss: Self.color(light: 0x30382F, dark: 0xECF1E7)
        case .inkBlue: Self.color(light: 0x1F2B3D, dark: 0xEDF1F6)
        case .forest: Self.color(light: 0x22382F, dark: 0xEDF3EE)
        case .graphite: Self.color(light: 0x383735, dark: 0xF4F2EE)
        case .plum: Self.color(light: 0x352D3D, dark: 0xF3EDF7)
        }
    }

    var secondaryInk: Color {
        switch self {
        case .clay: Self.color(light: 0x5E6553, dark: 0xC6BEAB)
        case .moss: Self.color(light: 0x66705F, dark: 0xB4BEAC)
        case .inkBlue: Self.color(light: 0x606D7D, dark: 0xB2BECD)
        case .forest: Self.color(light: 0x647369, dark: 0xADBEAF)
        case .graphite: Self.color(light: 0x6D6963, dark: 0xC1BCB4)
        case .plum: Self.color(light: 0x74697C, dark: 0xBFB2CB)
        }
    }

    private static func color(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

extension EnvironmentValues {
    @Entry var theme = Theme.graphite
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.theme) private var theme
    @Environment(\.localization) private var l10n
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(JournalTypography.font(size: 17, relativeTo: .body, language: l10n.language))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(isEnabled ? theme.onAccent : theme.secondaryInk)
            .background(
                isEnabled ? theme.accent : theme.ink.opacity(0.08),
                in: Capsule()
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}
