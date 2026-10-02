import SwiftUI

struct PhotoDetailView: View {
    let topicID: UUID
    let photoID: UUID
    let store: TimelineStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @Environment(\.localization) private var l10n
    @State private var note = ""
    @State private var loaded = false
    @State private var deleting = false
    @State private var error: String?
    private var photo: PhotoRecord? { store.topics.first { $0.id == topicID }?.photos.first { $0.id == photoID } }

    var body: some View {
        ScrollView {
            if let photo {
                VStack(alignment: .leading, spacing: 20) {
                    if let image = store.fullImage(for: photo) {
                        Image(uiImage: image).resizable().scaledToFit()
                            .accessibilityLabel(l10n.text("photo.captured", l10n.date(photo.capturedAt, time: true)))
                    } else {
                        ContentUnavailableView(l10n.text("photo.unavailable"), systemImage: "photo.badge.exclamationmark")
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text(l10n.date(photo.capturedAt, time: true))
                            .font(.subheadline).foregroundStyle(.secondary)
                        TextField(l10n.text("photo.notePlaceholder"), text: $note, axis: .vertical)
                            .lineLimit(3...8)
                            .onChange(of: note) { note = String(note.prefix(2000)) }
                        Button(l10n.text("photo.saveNote")) {
                            do { try store.updateNote(topicID: topicID, photoID: photoID, note: note) }
                            catch { self.error = l10n.error(error) }
                        }
                        .buttonStyle(.bordered)
                        .disabled(note == photo.note)
                    }.padding(.horizontal, 24)
                }
                .onAppear { if !loaded { note = photo.note; loaded = true } }
            }
        }
        .background { PaperBackground().ignoresSafeArea() }
        .navigationTitle(l10n.text("photo.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button(l10n.text("photo.delete"), systemImage: "trash", role: .destructive) { deleting = true }
                .labelStyle(.iconOnly)
        }
        .confirmationDialog(l10n.text("photo.deletePrompt"), isPresented: $deleting, titleVisibility: .visible) {
            Button(l10n.text("photo.delete"), role: .destructive) {
                do { try store.deletePhoto(topicID: topicID, photoID: photoID); dismiss() }
                catch { self.error = l10n.error(error) }
            }
            Button(l10n.text("common.cancel"), role: .cancel) { }
        } message: { Text(l10n.text("photo.deleteWarning")) }
        .alert(l10n.text("photo.saveFailed"), isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button(l10n.text("common.ok")) { error = nil }
        } message: { Text(error ?? "") }
    }
}
