import CoreText
import UIKit
import XCTest
@testable import Timetrace

final class TypographyTests: XCTestCase {
    func testBundledSerifsAreRegisteredAndContainBrandGlyphs() throws {
        let samples = [
            "SC": "\u{6E10}\u{89C1}\u{7167}\u{7247}\u{8BB0}\u{5F55}",
            "TC": "\u{6F38}\u{898B}\u{7167}\u{7247}\u{8A18}\u{9304}"
        ]
        for (region, sample) in samples {
            for weight in ["Regular", "Black"] {
                let name = "NotoSerif\(region)-\(weight)"
                XCTAssertNotNil(Bundle.main.url(forResource: name, withExtension: "otf"))
                let font = try XCTUnwrap(UIFont(name: name, size: 32), "Missing registration: \(name)")
                XCTAssertEqual(font.fontName, name)
                let coreFont = CTFontCreateWithName(font.fontName as CFString, 32, nil)
                let characters = Array(sample.utf16)
                var glyphs = [CGGlyph](repeating: 0, count: characters.count)
                XCTAssertTrue(CTFontGetGlyphsForCharacters(coreFont, characters, &glyphs, characters.count), name)
                XCTAssertTrue(glyphs.allSatisfy { $0 != 0 }, name)
            }
        }
        XCTAssertNotNil(Bundle.main.url(forResource: "NotoSerif-LICENSE", withExtension: "txt"))
    }
}
