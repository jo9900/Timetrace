import SwiftUI

struct CompareView: View {
    let topic: Topic
    let store: TimelineStore

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @Environment(\.localization) private var l10n
    @State private var beforeID: UUID?
    @State private var afterID: UUID?
    @State private var reveal = 0.5
    @State private var beforeImage: UIImage?
    @State private var afterImage: UIImage?

    init(topic: Topic, store: TimelineStore) {
        self.topic = topic
        self.store = store
        // Each presentation starts with the full timeline's first and last photos.
        _beforeID = State(initialValue: topic.orderedPhotos.first?.id)
        _afterID = State(initialValue: topic.orderedPhotos.last?.id)
    }

    private var photos: [PhotoRecord] { topic.orderedPhotos }
    private var beforeIndex: Int { photos.firstIndex { $0.id == beforeID } ?? 0 }
    private var afterIndex: Int { photos.firstIndex { $0.id == afterID } ?? max(0, photos.count - 1) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if photos.count < 2 {
                        ContentUnavailableView(l10n.text("compare.emptyTitle"), systemImage: "rectangle.on.rectangle", description: Text(l10n.text("compare.emptyBody")))
                    } else {
                        Text(l10n.text("compare.headline"))
                            .font(.title2.weight(.semibold))
                        photoPickers
                        if let beforeImage, let afterImage {
                            ComparisonCanvas(before: beforeImage, after: afterImage, reveal: reveal)
                                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .accessibilityHidden(true)
                            VStack(spacing: 10) {
                                Slider(value: $reveal, in: 0...1) {
                                    Text(l10n.text("compare.photoComparison"))
                                } minimumValueLabel: {
                                    Text(l10n.text("compare.after")).font(.caption)
                                } maximumValueLabel: {
                                    Text(l10n.text("compare.before")).font(.caption)
                                }
                                .accessibilityValue(l10n.text("compare.revealValue", Int((reveal * 100).rounded())))
                                .accessibilityHint(l10n.text("compare.revealHint"))
                                Text(l10n.text("compare.sliderInstruction"))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            ContentUnavailableView(l10n.text("compare.unavailableTitle"), systemImage: "photo.badge.exclamationmark", description: Text(l10n.text("compare.unavailableBody")))
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background { PaperBackground().ignoresSafeArea() }
            .tint(theme.accent)
            .navigationTitle(l10n.text("compare.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(l10n.text("common.done")) { dismiss() }
                }
            }
            .onChange(of: beforeID, initial: true) {
                beforeImage = photos.first { $0.id == beforeID }.flatMap { store.fullImage(for: $0) }
            }
            .onChange(of: afterID, initial: true) {
                afterImage = photos.first { $0.id == afterID }.flatMap { store.fullImage(for: $0) }
            }
        }
    }

    private var photoPickers: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(l10n.text("compare.before")).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Picker(l10n.text("compare.beforePhoto"), selection: $beforeID) {
                    ForEach(Array(photos.prefix(afterIndex))) { photo in
                        Text(label(for: photo)).tag(Optional(photo.id))
                    }
                }
                .labelsHidden()
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(l10n.text("compare.after")).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Picker(l10n.text("compare.afterPhoto"), selection: $afterID) {
                    ForEach(Array(photos.dropFirst(beforeIndex + 1))) { photo in
                        Text(label(for: photo)).tag(Optional(photo.id))
                    }
                }
                .labelsHidden()
            }
        }
        .pickerStyle(.menu)
    }

    private func label(for photo: PhotoRecord) -> String {
        l10n.text("compare.moment", topic.dayNumber(for: photo.capturedAt), l10n.date(photo.capturedAt, time: true))
    }
}

private struct ComparisonCanvas: View {
    let before: UIImage
    let after: UIImage
    let reveal: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                fitted(after, size: geometry.size)
                fitted(before, size: geometry.size)
                    .mask(alignment: .leading) {
                        Rectangle().frame(width: geometry.size.width * reveal)
                    }
                Rectangle()
                    .fill(.white)
                    .frame(width: 2)
                    .offset(x: max(0, min(geometry.size.width - 2, geometry.size.width * reveal - 1)))
            }
        }
    }

    private func fitted(_ image: UIImage, size: CGSize) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(width: size.width, height: size.height)
            .background(.black)
    }
}
