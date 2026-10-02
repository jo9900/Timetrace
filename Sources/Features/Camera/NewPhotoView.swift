import SwiftUI

struct NewPhotoView: View {
    let topic: Topic
    let store: TimelineStore

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @Environment(\.localization) private var l10n
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var camera = CameraController()
    @State private var reference: UIImage?
    @State private var showsReference = true
    @State private var opacity = 0.35
    @State private var note = ""
    @State private var saveError: String?
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text(l10n.text(camera.image == nil ? "camera.alignTitle" : "camera.capturedTitle"))
                        .font(.title2.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    viewfinder
                    if camera.image != nil { reviewControls }
                    else { captureControls }
                }
                .padding()
            }
            .background { PaperBackground().ignoresSafeArea() }
            .navigationTitle(topic.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l10n.text("common.cancel")) { camera.stop(); dismiss() }
                        .disabled(isSaving)
                        .accessibilityIdentifier("cameraCancel")
                }
            }
            .alert(l10n.text("camera.notSaved"), isPresented: Binding(
                get: { saveError != nil }, set: { if !$0 { saveError = nil } }
            )) {
                Button(l10n.text("common.ok"), role: .cancel) { saveError = nil }
            } message: { Text(saveError ?? "") }
            .onAppear {
                if let lastPhoto = topic.orderedPhotos.last { reference = store.fullImage(for: lastPhoto) }
                camera.start()
            }
            .onDisappear { camera.stop() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active, camera.image == nil { camera.start() }
                else { camera.stop() }
            }
        }
        .tint(theme.accent)
    }

    private var viewfinder: some View {
        ZStack {
            Color.black
            if let captured = camera.image {
                Image(uiImage: captured)
                    .resizable()
                    .scaledToFill()
                    .accessibilityLabel(l10n.text("camera.capturedPhoto"))
            } else {
                CameraPreview(session: camera.session, mirrored: camera.isFront)
                    .accessibilityHidden(true)
                if camera.isReady, showsReference, let reference {
                    Image(uiImage: reference)
                        .resizable()
                        .scaledToFill()
                        .opacity(opacity)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                if !camera.isReady {
                    VStack(spacing: 12) {
                        Image(systemName: camera.permissionDenied ? "camera.badge.ellipsis" : "camera")
                            .font(.largeTitle)
                        if let message = camera.message {
                            Text(message).multilineTextAlignment(.center)
                            if camera.permissionDenied {
                                Button(l10n.text("common.openSettings")) {
                                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                                }
                                .buttonStyle(.borderedProminent)
                                .foregroundStyle(theme.background)
                            } else {
                                Button(l10n.text("common.tryAgain")) { camera.start() }.buttonStyle(.borderedProminent)
                                    .foregroundStyle(theme.background)
                                    .accessibilityIdentifier("cameraRetry")
                            }
                        } else {
                            ProgressView().tint(.white)
                            Text(l10n.text("camera.preparing"))
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(24)
                }
            }
        }
        .aspectRatio(3 / 4, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private var captureControls: some View {
        VStack(spacing: 20) {
            if reference != nil {
                Toggle(l10n.text("camera.alignPrevious"), isOn: $showsReference)
                if showsReference {
                    HStack {
                        Image(systemName: "square.on.square")
                        Slider(value: $opacity, in: 0.1...0.7)
                            .accessibilityLabel(l10n.text("camera.referenceOpacity"))
                    }
                }
            }
            if camera.isReady, let message = camera.message {
                Text(message).font(.footnote).foregroundStyle(.secondary)
            }
            HStack {
                Text(l10n.text("camera.today")).font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Button { camera.capture() } label: {
                    ZStack {
                        Circle().strokeBorder(theme.accent, lineWidth: 3).frame(width: 76, height: 76)
                        Circle().fill(theme.accent).frame(width: 62, height: 62)
                        if camera.isCapturing { ProgressView().tint(theme.background) }
                    }
                }
                .accessibilityLabel(l10n.text("camera.takePhoto"))
                .accessibilityIdentifier("takePhoto")
                .disabled(!camera.isReady || camera.isCapturing)
                .opacity(camera.isReady ? 1 : 0.4)
                Button { camera.switchCamera() } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .font(.title2)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .accessibilityLabel(l10n.text("camera.switchCamera"))
                .disabled(!camera.isReady || camera.isCapturing)
            }
        }
    }

    private var reviewControls: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField(l10n.text("camera.notePlaceholder"), text: $note, axis: .vertical)
                .lineLimit(2...4)
                .padding(16)
                .background(.background, in: RoundedRectangle(cornerRadius: 16))
                .accessibilityLabel(l10n.text("camera.photoNote"))
                .onChange(of: note) { _, value in
                    if value.count > 2_000 { note = String(value.prefix(2_000)) }
                }
            Button(l10n.text(isSaving ? "camera.saving" : "camera.saveToTimeline")) { save() }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isSaving)
            Button(l10n.text("camera.retake")) { camera.retake() }
                .frame(maxWidth: .infinity, minHeight: 44)
                .disabled(isSaving)
        }
    }

    private func save() {
        guard let image = camera.image, !isSaving else { return }
        isSaving = true
        do {
            try store.addPhoto(topicID: topic.id, image: image, note: note.trimmingCharacters(in: .whitespacesAndNewlines))
            dismiss()
        } catch let error as TimelineStore.StoreError {
            saveError = error.localizedDescription
            isSaving = false
        } catch {
            saveError = l10n.text("camera.saveFailed")
            isSaving = false
        }
    }
}
