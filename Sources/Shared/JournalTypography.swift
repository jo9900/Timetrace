import SwiftUI

enum JournalTypography {
    static func font(
        size: CGFloat, relativeTo style: Font.TextStyle,
        language: AppLanguage, emphasized: Bool = false
    ) -> Font {
        let name: String
        switch language.resolved() {
        case .system, .simplifiedChinese:
            name = emphasized ? "NotoSerifSC-Black" : "NotoSerifSC-Regular"
        case .traditionalChinese:
            name = emphasized ? "NotoSerifTC-Black" : "NotoSerifTC-Regular"
        case .japanese:
            name = emphasized ? "HiraMinProN-W6" : "HiraMinProN-W3"
        case .english:
            name = emphasized ? "Baskerville-SemiBold" : "Baskerville"
        }
        return .custom(name, size: size, relativeTo: style)
    }
}
