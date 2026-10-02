import SwiftUI

struct TimelineView: View {
    let topicID: UUID
    let store: TimelineStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @Environment(\.localization) private var l10n
    @State private var takingPhoto = false
    @State private var comparing = false
    @State private var exporting = false
    @State private var deleting = false
    @State private var renaming = false
    @State private var title = ""
    @State private var error: String?
    private var topic: Topic? { store.topics.first { $0.id == topicID } }

    var body: some View {
        Group {
            if let topic {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        summary(topic)
                        if topic.photos.isEmpty {
                            ContentUnavailableView {
                                Label(l10n.text("timeline.emptyTitle"), systemImage: topic.symbol)
                            } description: {
                                Text(l10n.text("timeline.emptyDescription"))
                            }
                            .padding(.vertical, 40)
                        } else {
                            LazyVStack(spacing: 28) {
                                ForEach(topic.orderedPhotos.reversed()) { photo in
                                    NavigationLink {
                                        PhotoDetailView(topicID: topic.id, photoID: photo.id, store: store)
                                    } label: {
                                        TimelineFrame(photo: photo, day: topic.dayNumber(for: photo.capturedAt), store: store)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }.padding(24)
                }
                .background { PaperBackground().ignoresSafeArea() }
                .safeAreaInset(edge: .bottom) {
                    Button { takingPhoto = true } label: { Label(l10n.text("timeline.capture"), systemImage: "camera") }
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(.horizontal, 24).padding(.vertical, 12)
                        .background(.regularMaterial)
                        .accessibilityIdentifier("captureMoment")
                }
                .navigationTitle(topic.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    Menu {
                        Button(l10n.text("timeline.rename"), systemImage: "pencil") { title = topic.title; renaming = true }
                        Button(l10n.text("timeline.delete"), systemImage: "trash", role: .destructive) { deleting = true }
                    } label: { Image(systemName: "ellipsis").frame(minWidth: 44, minHeight: 44) }
                    .accessibilityLabel(l10n.text("timeline.options"))
                }
                .sheet(isPresented: $comparing) { CompareView(topic: topic, store: store) }
                .sheet(isPresented: $exporting) { ExportView(topic: topic, store: store) }
                .fullScreenCover(isPresented: $takingPhoto) { NewPhotoView(topic: topic, store: store) }
                .confirmationDialog(l10n.text("timeline.deletePrompt"), isPresented: $deleting, titleVisibility: .visible) {
                    Button(l10n.text("timeline.delete"), role: .destructive) {
                        do { try store.deleteTopic(id: topic.id); dismiss() }
                        catch { self.error = l10n.error(error) }
                    }
                    Button(l10n.text("common.cancel"), role: .cancel) { }
                } message: { Text(l10n.text("timeline.deleteWarning")) }
                .alert(l10n.text("timeline.rename"), isPresented: $renaming) {
                    TextField(l10n.text("timeline.storyName"), text: $title)
                    Button(l10n.text("common.cancel"), role: .cancel) { }
                    Button(l10n.text("common.save")) {
                        do { try store.renameTopic(id: topic.id, title: title) }
                        catch { self.error = l10n.error(error) }
                    }
                }
            } else {
                ContentUnavailableView(l10n.text("timeline.unavailable"), systemImage: "photo.on.rectangle")
            }
        }
        .alert(l10n.text("common.errorTitle"), isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button(l10n.text("common.ok")) { error = nil }
        } message: { Text(error ?? "") }
    }

    private func summary(_ topic: Topic) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(topic.photos.count)").font(.largeTitle.weight(.medium))
                Text(topic.photos.count == 1 ? l10n.text("timeline.momentOne") : l10n.text("timeline.momentOther")).foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Button { comparing = true } label: { Label(l10n.text("timeline.compare"), systemImage: "rectangle.lefthalf.inset.filled").frame(maxWidth: .infinity, minHeight: 36) }
                    .accessibilityIdentifier("comparePhotos")
                Button { exporting = true } label: { Label(l10n.text("timeline.makeVideo"), systemImage: "play.rectangle").frame(maxWidth: .infinity, minHeight: 36) }
                    .accessibilityIdentifier("makeVideo")
            }
            .buttonStyle(.bordered)
            .disabled(topic.photos.count < 2)
            if topic.photos.count < 2 {
                Text(l10n.text("timeline.needsTwoPhotos")).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}

private struct TimelineFrame: View {
    @Environment(\.theme) private var theme
    @Environment(\.localization) private var l10n
    let photo: PhotoRecord
    let day: Int
    let store: TimelineStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(l10n.text("timeline.day", day)).font(.caption.weight(.semibold)).tracking(1).foregroundStyle(theme.accent)
                Spacer()
                Text(l10n.date(photo.capturedAt))
                    .font(.caption).foregroundStyle(.secondary)
            }
            GeometryReader { proxy in
                PhotoView(photo: photo, store: store)
                    .frame(width: proxy.size.width, height: proxy.size.height).clipped()
            }
            .aspectRatio(3 / 4, contentMode: .fit)
            .clipShape(.rect(cornerRadius: 14))
            if !photo.note.isEmpty { Text(photo.note).font(.body).foregroundStyle(.primary).lineLimit(3) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(l10n.text("timeline.photoHint"))
    }
}
