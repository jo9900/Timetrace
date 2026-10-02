import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case japanese = "ja"
    case english = "en"

    static let storageKey = "selectedLanguage"
    var id: String { rawValue }

    var nativeName: String {
        switch self {
        case .system: "System"
        case .simplifiedChinese: "\u{7B80}\u{4F53}\u{4E2D}\u{6587}"
        case .traditionalChinese: "\u{7E41}\u{9AD4}\u{4E2D}\u{6587}"
        case .japanese: "\u{65E5}\u{672C}\u{8A9E}"
        case .english: "English"
        }
    }

    func resolved(preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        guard self == .system else { return self }
        for identifier in preferredLanguages {
            let parts = identifier.replacingOccurrences(of: "_", with: "-").lowercased().split(separator: "-")
            switch parts.first {
            case "en": return .english
            case "ja": return .japanese
            case "zh":
                if parts.contains("hant") { return .traditionalChinese }
                if parts.contains("hans") { return .simplifiedChinese }
                return parts.contains(where: { $0 == "tw" || $0 == "hk" || $0 == "mo" })
                    ? .traditionalChinese : .simplifiedChinese
            default: continue
            }
        }
        return .simplifiedChinese
    }
}

struct AppLocalization: Equatable, Sendable {
    let language: AppLanguage

    init(language: AppLanguage) {
        self.language = language.resolved()
    }

    static var current: AppLocalization {
        let selection = UserDefaults.standard.string(forKey: AppLanguage.storageKey)
            .flatMap(AppLanguage.init(rawValue:)) ?? .system
        return AppLocalization(language: selection)
    }

    var locale: Locale { Locale(identifier: language.rawValue) }
    var brandName: String { text("brand.name") }

    private var bundle: Bundle {
        guard let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return .main }
        return bundle
    }

    func text(_ key: String, _ arguments: CVarArg...) -> String {
        let format = bundle.localizedString(forKey: key, value: nil, table: "Localizable")
        return arguments.isEmpty ? format : String(format: format, locale: locale, arguments: arguments)
    }

    func frames(_ count: Int) -> String {
        text(count == 1 ? "frames.one" : "frames.other", count)
    }

    func date(_ date: Date, time: Bool = false) -> String {
        date.formatted(Date.FormatStyle(date: .abbreviated, time: time ? .shortened : .omitted).locale(locale))
    }

    func error(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? text("common.error")
    }
}

extension EnvironmentValues {
    @Entry var localization = AppLocalization(language: .simplifiedChinese)
}
