import SwiftUI

struct LibraryView: View {
    let store: TimelineStore
    @Environment(\.theme) private var theme
    @Environment(\.localization) private var l10n
    @State private var creating = false
    @State private var settings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    LibraryHeader(
                        showsCreate: store.loadError == nil && !store.topics.isEmpty,
                        create: { creating = true },
                        openSettings: { settings = true }
                    )
                    if store.loadError != nil {
                        ContentUnavailableView {
                            Label(l10n.text("library.loadError.title"), systemImage: "externaldrive.badge.exclamationmark")
                        } description: {
                            Text(l10n.text("library.loadError.description"))
                        }
                    } else if store.topics.isEmpty {
                        EmptyLibraryView(create: { creating = true })
                    } else {
                        LazyVStack(spacing: 20) {
                            ForEach(store.topics) { topic in
                                TopicCard(topic: topic, store: store, rotation: topic.id == store.topics.first?.id ? 2.5 : 0)
                            }
                        }
                    }
                }
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background { PaperBackground().ignoresSafeArea() }
            .foregroundStyle(theme.ink)
            .navigationTitle(l10n.brandName)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $creating) { TopicEditor(store: store) }
            .sheet(isPresented: $settings) { SettingsView() }
        }
    }
}

private struct LibraryHeader: View {
    let showsCreate: Bool
    let create: () -> Void
    let openSettings: () -> Void
    @Environment(\.theme) private var theme
    @Environment(\.localization) private var l10n
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(l10n.brandName)
                        .font(JournalTypography.font(
                            size: isChinese ? 46 : 36,
                            relativeTo: .largeTitle,
                            language: isChinese ? l10n.language : .english,
                            emphasized: true
                        ))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("brandTitle")
                    if isChinese {
                        Text("Timetrace")
                            .font(.custom("Baskerville", size: 10, relativeTo: .caption2))
                            .tracking(4)
                            .foregroundStyle(theme.secondaryInk)
                            .accessibilityHidden(true)
                    }
                    tagline
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 10) {
                    Button(action: openSettings) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 19, weight: .medium))
                            .frame(width: 44, height: 44)
                            .background(theme.ink.opacity(0.07), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(l10n.text("common.settings"))
                    .accessibilityIdentifier("settings")
                    if showsCreate && !dynamicTypeSize.isAccessibilitySize {
                        createButton
                    }
                }
                .padding(.top, 4)
            }
            if showsCreate && dynamicTypeSize.isAccessibilitySize {
                createButton
            }
        }
    }

    private var isChinese: Bool {
        l10n.language == .simplifiedChinese || l10n.language == .traditionalChinese
    }

    private var tagline: some View {
        Text(l10n.text("library.tagline"))
            .font(JournalTypography.font(size: 14, relativeTo: .subheadline, language: l10n.language))
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(theme.secondaryInk)
    }

    private var createButton: some View {
        Button(action: create) {
            Label(l10n.text("library.newStory"), systemImage: "plus")
                .font(JournalTypography.font(size: 18, relativeTo: .body, language: l10n.language))
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .frame(minHeight: 44)
                .foregroundStyle(theme.onAccent)
                .background(theme.accent, in: Capsule())
                .shadow(color: theme.accent.opacity(0.18), radius: 5, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("newStory")
    }
}

private struct EmptyLibraryView: View {
    let create: () -> Void
    @Environment(\.theme) private var theme
    @Environment(\.localization) private var l10n
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 32) {
            ZStack {
                blankPrint
                    .rotationEffect(.degrees(8))
                    .offset(x: 30, y: 12)
                blankPrint
                    .overlay(alignment: .center) {
                        Image(systemName: "photo")
                            .font(.system(size: 40, weight: .ultraLight))
                            .foregroundStyle(theme.accent.opacity(0.7))
                            .padding(.bottom, 18)
                    }
                    .rotationEffect(.degrees(-8))
                    .offset(x: -12, y: -6)
            }
            .frame(width: 210, height: 210)
            .accessibilityHidden(true)

            Text(l10n.text("library.empty.description"))
                .font(JournalTypography.font(size: 16, relativeTo: .body, language: l10n.language))
                .lineSpacing(4)
                .foregroundStyle(theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
            Button(l10n.text("library.empty.action"), action: create)
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("startStory")
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: 340)
        .frame(maxWidth: .infinity)
        .padding(.top, dynamicTypeSize.isAccessibilitySize ? 16 : 48)
    }

    private var blankPrint: some View {
        Rectangle()
            .fill(theme.accent.opacity(0.07))
            .frame(width: 116, height: 142)
            .padding(10)
            .padding(.bottom, 20)
            .background { PaperBackground(isPhotoPaper: true) }
            .shadow(color: .black.opacity(0.08), radius: 10, y: 6)
    }
}
