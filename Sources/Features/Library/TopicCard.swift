import SwiftUI

struct TopicCard: View {
    let topic: Topic
    let store: TimelineStore
    var rotation: Double = 0
    @Environment(\.theme) private var theme
    @Environment(\.localization) private var l10n
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var takingPhoto = false

    var body: some View {
        let photos = topic.orderedPhotos
        let showsEarlierPrint = photos.count > 1 && !dynamicTypeSize.isAccessibilitySize

        VStack(alignment: .leading, spacing: 16) {
            ZStack(alignment: .topTrailing) {
                if showsEarlierPrint, let first = photos.first {
                    PhotoView(photo: first, store: store)
                        .frame(width: 92, height: 112)
                        .clipped()
                        .padding(7)
                        .padding(.bottom, 14)
                        .background { PaperBackground(isPhotoPaper: true) }
                        .rotationEffect(.degrees(9))
                        .shadow(color: .black.opacity(0.09), radius: 5, y: 4)
                        .offset(y: 42)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                photoPrint(latest: photos.last)
                    .rotationEffect(.degrees(dynamicTypeSize.isAccessibilitySize ? 0 : rotation))
                    .padding(.trailing, showsEarlierPrint ? 45 : 0)
            }
            .padding(.top, 8)

            if !photos.isEmpty {
                TopicThumbnailStrip(topicID: topic.id, photos: Array(photos.suffix(7)), store: store)
            }
        }
        .fullScreenCover(isPresented: $takingPhoto) {
            NewPhotoView(topic: topic, store: store)
        }
    }

    private func photoPrint(latest: PhotoRecord?) -> some View {
        ZStack(alignment: .bottomTrailing) {
            NavigationLink {
                TimelineView(topicID: topic.id, store: store)
                    .toolbar(.visible, for: .navigationBar)
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    Rectangle()
                        .fill(theme.accent.opacity(0.06))
                        .aspectRatio(dynamicTypeSize.isAccessibilitySize && latest == nil ? 0.8 : 1.6, contentMode: .fit)
                        .overlay {
                            if let latest {
                                PhotoView(photo: latest, store: store)
                            } else {
                                VStack(spacing: 12) {
                                    Image(systemName: topic.symbol)
                                        .font(.largeTitle.weight(.light))
                                    Text(l10n.text("library.firstFrame"))
                                        .font(JournalTypography.font(size: 15, relativeTo: .subheadline, language: l10n.language))
                                        .multilineTextAlignment(.center)
                                }
                                .foregroundStyle(theme.accent)
                                .padding()
                            }
                        }
                        .clipped()
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(topic.title)
                            .font(JournalTypography.font(size: 20, relativeTo: .title3, language: l10n.language))
                            .foregroundStyle(theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(l10n.frames(topic.photos.count))
                            .font(JournalTypography.font(size: 13, relativeTo: .footnote, language: l10n.language))
                            .foregroundStyle(theme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                    .padding(.trailing, 52)
                    .padding(.horizontal, 2)
                    .padding(.bottom, 2)
                }
                .padding(9)
                .background { PaperBackground(isPhotoPaper: true) }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(l10n.text("library.story.accessibilityLabel", topic.title, l10n.frames(topic.photos.count)))
            .accessibilityHint(l10n.text("library.story.openHint"))
            .accessibilityIdentifier("openStory-\(topic.id.uuidString)")

            Button { takingPhoto = true } label: {
                Image(systemName: "camera")
                    .font(.system(size: 20))
                    .foregroundStyle(theme.onAccent)
                    .frame(width: 44, height: 44)
                    .background(theme.accent, in: Circle())
                    .shadow(color: theme.accent.opacity(0.18), radius: 4, y: 3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(l10n.text(topic.photos.isEmpty ? "library.story.captureFirst" : "library.story.captureNext", topic.title))
            .accessibilityIdentifier("captureStory-\(topic.id.uuidString)")
            .padding(12)
        }
        .overlay(alignment: .top) {
            if rotation != 0 && !dynamicTypeSize.isAccessibilitySize {
                Rectangle()
                    .fill(Color(red: 0.66, green: 0.56, blue: 0.37).opacity(0.3))
                    .frame(width: 28, height: 20)
                    .rotationEffect(.degrees(6))
                    .offset(y: -7)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .shadow(color: .black.opacity(0.09), radius: 7, y: 5)
    }
}

private struct TopicThumbnailStrip: View {
    let topicID: UUID
    let photos: [PhotoRecord]
    let store: TimelineStore
    @Environment(\.theme) private var theme
    @Environment(\.localization) private var l10n

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                ForEach(photos) { photo in
                    NavigationLink {
                        PhotoDetailView(topicID: topicID, photoID: photo.id, store: store)
                            .toolbar(.visible, for: .navigationBar)
                    } label: {
                        PhotoView(photo: photo, store: store)
                            .frame(width: 40, height: 40)
                            .clipped()
                            .clipShape(.rect(cornerRadius: 3))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(l10n.text("library.photo.from", l10n.date(photo.capturedAt)))
                    .accessibilityIdentifier("storyThumbnail-\(photo.id.uuidString)")
                }
                NavigationLink {
                    TimelineView(topicID: topicID, store: store)
                        .toolbar(.visible, for: .navigationBar)
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(theme.secondaryInk)
                        .frame(width: 40, height: 40)
                        .background(theme.accent.opacity(0.07), in: .rect(cornerRadius: 3))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(l10n.text("library.viewAllFrames"))
            }
        }
        .scrollIndicators(.hidden)
    }
}
