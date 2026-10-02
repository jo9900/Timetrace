import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @Environment(\.localization) private var l10n
    @AppStorage(Theme.storageKey) private var selectedTheme = Theme.graphite
    @AppStorage(AppLanguage.storageKey) private var selectedLanguage = AppLanguage.system

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(l10n.brandName)
                            .font(JournalTypography.font(size: 28, relativeTo: .title, language: l10n.language, emphasized: true))
                        Text(l10n.text("settings.tagline")).foregroundStyle(theme.secondaryInk)
                        Text(l10n.text("settings.version", "1.0.0")).font(.caption).foregroundStyle(theme.secondaryInk)
                    }.padding(.vertical, 12)
                }
                .listRowBackground(theme.paper)
                Section(l10n.text("settings.theme")) {
                    ForEach(Theme.allCases) { option in
                        Button { selectedTheme = option } label: {
                            HStack(spacing: 12) {
                                Circle().fill(option.accent).frame(width: 24, height: 24)
                                    .accessibilityHidden(true)
                                Text(l10n.text("theme.\(option.rawValue)"))
                                Spacer()
                                if selectedTheme == option {
                                    Image(systemName: "checkmark")
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(theme.accent)
                                        .accessibilityHidden(true)
                                }
                            }
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(l10n.text("theme.\(option.rawValue)"))
                        .accessibilityValue(l10n.text(selectedTheme == option ? "common.selected" : "common.notSelected"))
                        .accessibilityAddTraits(selectedTheme == option ? .isSelected : [])
                        .accessibilityIdentifier("theme.\(option.rawValue)")
                    }
                }
                .listRowBackground(theme.paper)
                Section(l10n.text("settings.language")) {
                    ForEach(AppLanguage.allCases) { option in
                        Button { selectedLanguage = option } label: {
                            HStack {
                                Text(languageName(option))
                                Spacer()
                                if selectedLanguage == option {
                                    Image(systemName: "checkmark")
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(theme.accent)
                                        .accessibilityHidden(true)
                                }
                            }
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(languageName(option))
                        .accessibilityValue(l10n.text(selectedLanguage == option ? "common.selected" : "common.notSelected"))
                        .accessibilityAddTraits(selectedLanguage == option ? .isSelected : [])
                        .accessibilityIdentifier("language.\(option.rawValue)")
                    }
                }
                .listRowBackground(theme.paper)
                Section(l10n.text("settings.share.title")) {
                    Text(l10n.text("settings.share.instructions"))
                }
                .listRowBackground(theme.paper)
            }
            .foregroundStyle(theme.ink)
            .scrollContentBackground(.hidden)
            .background { PaperBackground().ignoresSafeArea() }
            .navigationTitle(l10n.text("common.settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(l10n.text("common.done")) { dismiss() }
                        .accessibilityIdentifier("settingsDone")
                }
            }
        }
    }

    private func languageName(_ language: AppLanguage) -> String {
        language == .system ? l10n.text("settings.followSystem") : language.nativeName
    }
}
