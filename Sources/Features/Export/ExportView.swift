import AVKit
import Photos
import SwiftUI

struct ExportView: View {
    let topic: Topic
    let store: TimelineStore

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @Environment(\.localization) private var l10n
    @Environment(\.openURL) private var openURL
    @State private var secondsPerPhoto = 1.0
    @State private var progress = 0.0
    @State private var exportTask: Task<Void, Never>?
    @State private var videoURL: URL?
    @State private var player: AVPlayer?
    @State private var isSharing = false
    @State private var isSaving = false
    @State private var hasDisappeared = false
    @State private var message: String?
    @State private var needsPhotoSettings = false
    @State private var saved = false

    var body: some View {
        NavigationStack {
            Form {
                if let player {
                    Section {
                        VideoPlayer(player: player)
                            .frame(height: 330)
                            .accessibilityLabel(l10n.text("export.preview"))
                    }
                }
                Section(l10n.text("export.yourVideo")) {
                    LabeledContent(l10n.text("export.timeline"), value: topic.title)
                    LabeledContent(l10n.text("export.photos"), value: topic.photos.count.formatted(.number.locale(l10n.locale)))
                    LabeledContent(l10n.text("export.format"), value: l10n.text("export.formatValue"))
                    Picker(l10n.text("export.timePerPhoto"), selection: $secondsPerPhoto) {
                        Text(l10n.text("export.halfSecond")).tag(0.5)
                        Text(l10n.text("export.oneSecond")).tag(1.0)
                        Text(l10n.text("export.twoSeconds")).tag(2.0)
                    }
                    .disabled(exportTask != nil || isSaving)
                }
                Section {
                    if exportTask != nil {
                        ProgressView(l10n.text("export.creating"), value: progress)
                        Button(l10n.text("export.cancel"), role: .cancel) { exportTask?.cancel() }
                    } else {
                        Button(l10n.text(videoURL == nil ? "export.create" : "export.recreate")) { startExport() }
                            .disabled(topic.photos.count < 2 || isSaving)
                    }
                } footer: {
                    Text(topic.photos.count < 2
                         ? l10n.text("export.insufficientPhotos")
                         : l10n.text("export.brandingNotice", l10n.brandName))
                }
                if videoURL != nil {
                    Section {
                        Button {
                            player?.pause()
                            isSharing = true
                        } label: {
                            Label(l10n.text("export.share"), systemImage: "square.and.arrow.up")
                        }
                        Button { saveVideo() } label: {
                            Label(l10n.text(isSaving ? "export.saving" : saved ? "export.saved" : "export.saveToPhotos"), systemImage: "square.and.arrow.down")
                        }
                        .disabled(isSaving || saved)
                    } footer: {
                        Text(l10n.text("export.sharingHelp"))
                    }
                    .disabled(exportTask != nil || isSaving)
                }
            }
            .scrollContentBackground(.hidden)
            .background { PaperBackground().ignoresSafeArea() }
            .navigationTitle(l10n.text("export.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(l10n.text("common.done")) { dismiss() }.disabled(isSaving)
                }
            }
            .interactiveDismissDisabled(isSaving)
            .sheet(isPresented: $isSharing, onDismiss: {
                if hasDisappeared { cleanUp() }
            }) {
                if let videoURL { VideoShareSheet(url: videoURL) }
            }
            .alert(l10n.text("export.alertTitle"), isPresented: Binding(
                get: { message != nil }, set: { if !$0 { message = nil } }
            )) {
                if needsPhotoSettings {
                    Button(l10n.text("common.openSettings")) {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                }
                Button(l10n.text("common.ok"), role: .cancel) { message = nil }
            } message: {
                Text(message ?? "")
            }
            .onAppear { hasDisappeared = false }
            .onDisappear {
                player?.pause()
                hasDisappeared = true
                if !isSharing { cleanUp() }
            }
        }
    }

    private func startExport() {
        cleanUp()
        progress = 0
        saved = false
        needsPhotoSettings = false
        let localization = l10n
        let frames = topic.orderedPhotos.map {
            VideoExporter.Frame(
                imageURL: store.photoURL(for: $0),
                dateLabel: localization.date($0.capturedAt),
                dayNumber: topic.dayNumber(for: $0.capturedAt)
            )
        }
        let title = topic.title
        let brandName = localization.brandName
        let duration = secondsPerPhoto
        exportTask = Task { @MainActor in
            do {
                let url = try await VideoExporter().export(
                    frames: frames, title: title, brandName: brandName, secondsPerPhoto: duration, localization: localization
                ) { value in
                    await MainActor.run { progress = value }
                }
                if Task.isCancelled {
                    try? FileManager.default.removeItem(at: url)
                } else {
                    videoURL = url
                    player = AVPlayer(url: url)
                }
            } catch is CancellationError {
                // Cancellation leaves the original photos untouched.
            } catch {
                message = (error as? VideoExporter.ExportError)?.errorDescription ?? l10n.text("export.encodingFailed")
            }
            exportTask = nil
        }
    }

    private func saveVideo() {
        guard let videoURL else { return }
        isSaving = true
        needsPhotoSettings = false
        Task { @MainActor in
            defer { isSaving = false }
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard status == .authorized || status == .limited else {
                needsPhotoSettings = status == .denied
                message = l10n.text("export.photoAccessDenied")
                return
            }
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
                }
                saved = true
            } catch {
                message = l10n.text("export.saveFailed")
            }
        }
    }

    private func cleanUp() {
        exportTask?.cancel()
        player?.pause()
        player = nil
        if let videoURL { try? FileManager.default.removeItem(at: videoURL) }
        videoURL = nil
    }
}

private struct VideoShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
