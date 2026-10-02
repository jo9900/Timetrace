import SwiftUI
import UIKit
import XCTest
@testable import Timetrace

@MainActor
final class ThemeTests: XCTestCase {
    func testEveryPaletteHasReadableTextAndPrimaryButtons() {
        for theme in Theme.allCases {
            for style in [UIUserInterfaceStyle.light, .dark] {
                let traits = UITraitCollection(userInterfaceStyle: style)
                let pairs: [(String, Color, Color)] = [
                    ("body", theme.ink, theme.background),
                    ("secondary", theme.secondaryInk, theme.background),
                    ("paper body", theme.ink, theme.paper),
                    ("paper secondary", theme.secondaryInk, theme.paper),
                    ("primary button", theme.onAccent, theme.accent)
                ]
                for (name, foreground, background) in pairs {
                    let values = [luminance(foreground, traits), luminance(background, traits)].sorted()
                    let contrast = (values[1] + 0.05) / (values[0] + 0.05)
                    XCTAssertGreaterThanOrEqual(contrast, 4.5, "\(theme.rawValue), \(style), \(name)")
                }
            }
        }
    }

    private func luminance(_ color: Color, _ traits: UITraitCollection) -> Double {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        let resolved = UIColor(color).resolvedColor(with: traits)
        XCTAssertTrue(resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
        XCTAssertEqual(alpha, 1)
        let components = [red, green, blue].map { value -> Double in
            let value = Double(value)
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return components[0] * 0.2126 + components[1] * 0.7152 + components[2] * 0.0722
    }
}
