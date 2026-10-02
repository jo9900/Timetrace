import Foundation
import XCTest
@testable import Timetrace

final class LocalizationTests: XCTestCase {
    func testSystemLanguageResolutionAndExplicitSelection() {
        let cases: [([String], AppLanguage)] = [
            (["zh-HK"], .traditionalChinese), (["zh-TW"], .traditionalChinese),
            (["zh-MO"], .traditionalChinese), (["zh-Hant-CN"], .traditionalChinese),
            (["zh-Hans-HK"], .simplifiedChinese), (["zh-CN"], .simplifiedChinese),
            (["zh_SG"], .simplifiedChinese), (["ja-JP"], .japanese),
            (["en-GB"], .english), (["fr-FR", "ja-JP", "en-US"], .japanese),
            (["en-US", "zh-TW"], .english), (["fr-FR", "de-DE"], .simplifiedChinese),
            ([], .simplifiedChinese)
        ]
        for (preferences, expected) in cases {
            XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: preferences), expected, "\(preferences)")
            for selection in AppLanguage.allCases where selection != .system {
                XCTAssertEqual(selection.resolved(preferredLanguages: preferences), selection)
            }
        }
    }

    func testLocalizedResourcesHaveMatchingKeysAndFormatArguments() throws {
        let formats = try NSRegularExpression(pattern: #"%(?:\d+\$)?(?:ld|lld|d|@|(?:\.\d+)?f)"#)
        var reference: [String: String]?
        for language in AppLanguage.allCases where language != .system {
            let directory = try XCTUnwrap(Bundle.main.url(forResource: language.rawValue, withExtension: "lproj"))
            let data = try Data(contentsOf: directory.appendingPathComponent("Localizable.strings"))
            let strings = try XCTUnwrap(try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String])
            XCTAssertFalse(strings.isEmpty)
            if let reference {
                XCTAssertEqual(Set(strings.keys), Set(reference.keys), language.rawValue)
                for (key, value) in strings {
                    let expected = try XCTUnwrap(reference[key])
                    let arguments = [expected, value].map { text in
                        formats.matches(in: text, range: NSRange(text.startIndex..., in: text)).map {
                            (text as NSString).substring(with: $0.range)
                        }
                    }
                    XCTAssertEqual(arguments[0], arguments[1], "\(language.rawValue): \(key)")
                }
            } else {
                reference = strings
            }
            let l10n = AppLocalization(language: language)
            for (key, value) in strings {
                XCTAssertFalse(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, key)
                XCTAssertNotEqual(l10n.text(key), key, "\(language.rawValue): \(key)")
            }
        }
    }

    func testLocalizedCountsBrandAndVideoCaption() {
        let english = AppLocalization(language: .english)
        XCTAssertEqual(english.frames(1), "1 frame")
        XCTAssertEqual(english.frames(2), "2 frames")
        XCTAssertEqual(english.brandName, "Timetrace")
        XCTAssertEqual(english.text("settings.language"), "Language")
        XCTAssertEqual(english.text("export.frameCaption", 3, "Sep 1"), "Day 3  ·  Sep 1")
        let simplified = AppLocalization(language: .simplifiedChinese)
        let traditional = AppLocalization(language: .traditionalChinese)
        XCTAssertEqual(simplified.brandName, "\u{6E10}\u{89C1}")
        XCTAssertEqual(traditional.brandName, "\u{6F38}\u{898B}")
        let japanese = AppLocalization(language: .japanese)
        XCTAssertEqual(japanese.brandName, "Timetrace")
        XCTAssertEqual(japanese.text("export.frameCaption", 3, "2026"), "3\u{65E5}\u{76EE}  ·  2026")
        let date = Date(timeIntervalSince1970: 1_788_264_000)
        XCTAssertNotEqual(english.date(date), japanese.date(date))
        XCTAssertFalse(japanese.date(date, time: true).isEmpty)
    }
}
