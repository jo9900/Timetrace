import SwiftUI

@main
struct TimetraceApp: App {
    @State private var store = makeStore()
    @AppStorage(Theme.storageKey) private var selectedTheme = Theme.graphite
    @AppStorage(AppLanguage.storageKey) private var selectedLanguage = AppLanguage.system
    @Environment(\.scenePhase) private var scenePhase
    @State private var preferredLanguages = Locale.preferredLanguages

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing"),
           ProcessInfo.processInfo.arguments.contains("--reset-theme") {
            UserDefaults.standard.removeObject(forKey: Theme.storageKey)
        }
        if ProcessInfo.processInfo.arguments.contains("--ui-testing"),
           ProcessInfo.processInfo.arguments.contains("--reset-language") {
            UserDefaults.standard.removeObject(forKey: AppLanguage.storageKey)
        }
        #endif
    }

    private static func makeStore() -> TimelineStore {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("TimetraceUITests")
            try? FileManager.default.removeItem(at: directory)
            return TimelineStore(directory: directory)
        }
        #endif
        return TimelineStore()
    }

    var body: some Scene {
        WindowGroup {
            let localization = AppLocalization(language: selectedLanguage.resolved(preferredLanguages: preferredLanguages))
            LibraryView(store: store)
                .environment(\.theme, selectedTheme)
                .environment(\.localization, localization)
                .environment(\.locale, localization.locale)
                .tint(selectedTheme.accent)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { preferredLanguages = Locale.preferredLanguages }
                }
        }
    }
}
