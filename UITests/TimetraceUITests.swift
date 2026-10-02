import XCTest

final class TimetraceUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCreateStoryAndCameraAvailability() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-theme", "--reset-language", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.buttons["startStory"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["newStory"].exists)
        app.buttons["startStory"].tap()
        let field = app.textFields["topicTitle"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Monstera diary")
        app.buttons["createTopic"].tap()
        let story = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "openStory-")).firstMatch
        XCTAssertTrue(story.waitForExistence(timeout: 5))
        XCTAssertTrue(story.label.contains("Monstera diary"))
        XCTAssertTrue(app.buttons["newStory"].exists)
        XCTAssertFalse(app.buttons["startStory"].exists)
        let library = XCTAttachment(screenshot: app.screenshot())
        library.name = "Graphite library"
        library.lifetime = .keepAlways
        add(library)
        story.tap()
        XCTAssertTrue(app.buttons["captureMoment"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["comparePhotos"].isEnabled)
        XCTAssertFalse(app.buttons["makeVideo"].isEnabled)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Empty story"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.navigationBars.buttons.firstMatch.tap()
        let capture = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "captureStory-")).firstMatch
        XCTAssertTrue(capture.waitForExistence(timeout: 5))
        capture.tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let permission = springboard.alerts.buttons.matching(
            NSPredicate(format: "label IN %@", ["Allow", "OK", "\u{5141}\u{8bb8}"])
        ).firstMatch
        if permission.waitForExistence(timeout: 2) { permission.tap() }
        let retryExists = app.buttons["cameraRetry"].waitForExistence(timeout: 8)
        if !retryExists {
            print(app.debugDescription)
            let camera = XCTAttachment(screenshot: app.screenshot())
            camera.name = "Camera fallback"
            camera.lifetime = .keepAlways
            add(camera)
        }
        XCTAssertTrue(retryExists)
        XCTAssertFalse(app.buttons["takePhoto"].isEnabled)
        app.buttons["cameraCancel"].tap()
        XCTAssertTrue(story.waitForExistence(timeout: 5))
        story.tap()
        XCTAssertTrue(app.buttons["captureMoment"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSystemLanguagesAndUnsupportedFallback() {
        let app = XCUIApplication()
        let simplifiedBrand = "\u{6E10}\u{89C1}"
        let simplifiedAction = "\u{5F00}\u{59CB}\u{7B2C}\u{4E00}\u{6BB5}\u{8BB0}\u{5F55}"
        let variants = [
            ("zh-Hans", "zh_CN", simplifiedBrand, simplifiedAction),
            ("zh-Hant", "zh_TW", "\u{6F38}\u{898B}", "\u{958B}\u{59CB}\u{7B2C}\u{4E00}\u{6BB5}\u{8A18}\u{9304}"),
            ("ja", "ja_JP", "Timetrace", "\u{6700}\u{521D}\u{306E}\u{8A18}\u{9332}\u{3092}\u{59CB}\u{3081}\u{308B}"),
            ("en", "en_US", "Timetrace", "Start your first story"),
            ("fr", "fr_FR", simplifiedBrand, simplifiedAction)
        ]

        for (language, locale, brand, action) in variants {
            app.launchArguments = [
                "--ui-testing", "--reset-theme", "--reset-language",
                "-AppleLanguages", "(\(language))", "-AppleLocale", locale
            ]
            app.launch()
            assertHome(in: app, brand: brand, action: action)
            if brand != "Timetrace" {
                XCTAssertFalse(app.staticTexts["Timetrace"].exists)
            }
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "System language \(language)"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            app.terminate()
        }
    }

    @MainActor
    func testLanguageSelectionPersistsAndReturnsToSystem() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-theme", "--reset-language", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        assertHome(in: app, brand: "Timetrace", action: "Start your first story")
        openSettings(in: app)
        let plum = app.buttons["theme.plum"]
        revealOption(plum, in: app)
        plum.tap()
        XCTAssertTrue(plum.isSelected)

        chooseLanguage("ja", in: app)
        let japaneseAction = "\u{6700}\u{521D}\u{306E}\u{8A18}\u{9332}\u{3092}\u{59CB}\u{3081}\u{308B}"
        assertHome(in: app, brand: "Timetrace", action: japaneseAction)
        app.terminate()
        app.launchArguments.removeAll { ["--reset-theme", "--reset-language"].contains($0) }
        app.launch()
        assertHome(in: app, brand: "Timetrace", action: japaneseAction)

        openSettings(in: app)
        revealOption(plum, in: app)
        XCTAssertTrue(plum.isSelected)
        chooseLanguage("zh-Hant", in: app)
        assertHome(in: app, brand: "\u{6F38}\u{898B}", action: "\u{958B}\u{59CB}\u{7B2C}\u{4E00}\u{6BB5}\u{8A18}\u{9304}")
        XCTAssertFalse(app.staticTexts["Timetrace"].exists)

        openSettings(in: app)
        chooseLanguage("system", in: app)
        assertHome(in: app, brand: "Timetrace", action: "Start your first story")
        openSettings(in: app)
        revealOption(plum, in: app)
        XCTAssertTrue(plum.isSelected)
        app.buttons["settingsDone"].tap()
    }

    @MainActor
    func testThemeSelectionPersistsAcrossLaunches() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-theme", "--reset-language", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.buttons["settings"].waitForExistence(timeout: 10))
        let empty = XCTAttachment(screenshot: app.screenshot())
        empty.name = "Graphite empty library"
        empty.lifetime = .keepAlways
        add(empty)
        app.buttons["settings"].tap()
        let graphite = app.buttons["theme.graphite"]
        revealOption(graphite, in: app)
        XCTAssertTrue(graphite.isSelected)

        for theme in ["clay", "moss", "inkBlue", "forest", "plum"] {
            let option = app.buttons["theme.\(theme)"]
            revealOption(option, in: app)
            option.tap()
            XCTAssertEqual(option.value as? String, "Selected")
            XCTAssertFalse(graphite.isSelected)
        }
        let settings = XCTAttachment(screenshot: app.screenshot())
        settings.name = "Theme settings"
        settings.lifetime = .keepAlways
        add(settings)
        app.buttons["settingsDone"].tap()
        XCTAssertTrue(app.buttons["startStory"].waitForExistence(timeout: 5))
        app.terminate()

        app.launchArguments.removeAll { $0 == "--reset-theme" }
        app.launch()
        XCTAssertTrue(app.buttons["settings"].waitForExistence(timeout: 10))
        app.buttons["settings"].tap()
        let plum = app.buttons["theme.plum"]
        revealOption(plum, in: app)
        XCTAssertEqual(plum.value as? String, "Selected")
        revealOption(graphite, in: app)
        graphite.tap()
        XCTAssertTrue(graphite.isSelected)
    }

    @MainActor
    func testEmptyHomeAtAccessibilityTextSize() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing", "--reset-theme", "--reset-language",
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        app.launch()
        assertHome(in: app, brand: "Timetrace", action: "Start your first story")
        let startStory = app.buttons["startStory"]
        revealOption(startStory, in: app)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Graphite empty home at accessibility text size"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        startStory.tap()
        XCTAssertTrue(app.textFields["topicTitle"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func assertHome(in app: XCUIApplication, brand: String, action: String) {
        let title = app.staticTexts["brandTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertEqual(title.label, brand)
        let startStory = app.buttons["startStory"]
        XCTAssertTrue(startStory.waitForExistence(timeout: 5))
        XCTAssertEqual(startStory.label, action)
        XCTAssertFalse(app.buttons["newStory"].exists)
    }

    @MainActor
    private func openSettings(in app: XCUIApplication) {
        XCTAssertTrue(app.buttons["settings"].waitForExistence(timeout: 5))
        app.buttons["settings"].tap()
        XCTAssertTrue(app.buttons["settingsDone"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func chooseLanguage(_ language: String, in app: XCUIApplication) {
        let option = app.buttons["language.\(language)"]
        revealOption(option, in: app)
        option.tap()
        XCTAssertTrue(option.isSelected)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Selected language \(language)"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["settingsDone"].tap()
    }

    @MainActor
    private func revealOption(_ option: XCUIElement, in app: XCUIApplication) {
        let visibleBounds = app.frame.insetBy(dx: 0, dy: 64)
        for _ in 0..<6 {
            if option.exists && option.isHittable && visibleBounds.contains(option.frame) { break }
            if option.exists && option.frame.minY < visibleBounds.minY {
                app.swipeDown()
            } else {
                app.swipeUp()
            }
        }
        XCTAssertTrue(option.isHittable, "Option \(option.identifier) should be reachable")
        XCTAssertTrue(visibleBounds.contains(option.frame), "Option \(option.identifier) should be fully visible")
    }
}
