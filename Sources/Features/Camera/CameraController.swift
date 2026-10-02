@preconcurrency import AVFoundation
import Combine
import UIKit

final class CameraController: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    @Published private(set) var image: UIImage?
    @Published private(set) var isReady = false
    @Published private(set) var isCapturing = false
    @Published private(set) var isFront = false
    @Published private(set) var permissionDenied = false
    @Published private(set) var message: String?

    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "app.timetrace.camera")
    private let output = AVCapturePhotoOutput()
    private var input: AVCaptureDeviceInput?
    private var wantsRunning = false

    override init() {
        super.init()
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(interrupted), name: .AVCaptureSessionWasInterrupted, object: session)
        center.addObserver(self, selector: #selector(interruptionEnded), name: .AVCaptureSessionInterruptionEnded, object: session)
        center.addObserver(self, selector: #selector(runtimeError), name: .AVCaptureSessionRuntimeError, object: session)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        let session = session
        queue.async { if session.isRunning { session.stopRunning() } }
    }

    func start() {
        queue.async { [self] in
            wantsRunning = true
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized: configureAndStart()
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                    guard let self else { return }
                    self.queue.async {
                        guard self.wantsRunning else { return }
                        if granted { self.configureAndStart() }
                        else { self.showPermissionDenied() }
                    }
                }
            default: showPermissionDenied()
            }
        }
    }

    func stop() {
        queue.async { [self] in
            wantsRunning = false
            if session.isRunning { session.stopRunning() }
            DispatchQueue.main.async { self.isReady = false }
        }
    }

    func capture() {
        guard isReady, !isCapturing else { return }
        isCapturing = true
        message = nil
        queue.async { [self] in
            guard wantsRunning, session.isRunning else {
                fail(AppLocalization.current.text("camera.notReady"))
                return
            }
            if let connection = output.connection(with: .video) {
                Self.configure(connection, mirrored: input?.device.position == .front)
            }
            let settings = AVCapturePhotoSettings()
            settings.flashMode = .off
            output.capturePhoto(with: settings, delegate: self)
        }
    }

    func retake() {
        image = nil
        message = nil
        start()
    }

    func switchCamera() {
        guard isReady, !isCapturing else { return }
        isReady = false
        queue.async { [self] in
            let position: AVCaptureDevice.Position = input?.device.position == .front ? .back : .front
            do {
                let replacement = try makeInput(position: position)
                session.beginConfiguration()
                let previous = input
                if let previous { session.removeInput(previous) }
                if session.canAddInput(replacement) {
                    session.addInput(replacement)
                    input = replacement
                } else if let previous {
                    session.addInput(previous)
                }
                session.commitConfiguration()
                publishReady()
            } catch {
                publishReady()
                DispatchQueue.main.async {
                    self.message = (error as? CameraError)?.errorDescription
                        ?? AppLocalization.current.text("camera.switchFailed")
                }
            }
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil, let data = photo.fileDataRepresentation(), let captured = UIImage(data: data) else {
            fail(AppLocalization.current.text("camera.captureFailed"))
            return
        }
        stop()
        DispatchQueue.main.async {
            self.image = captured
            self.isCapturing = false
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        if error != nil { fail(AppLocalization.current.text("camera.captureFailed")) }
    }

    static func configure(_ connection: AVCaptureConnection, mirrored: Bool) {
        if connection.isVideoRotationAngleSupported(90) { connection.videoRotationAngle = 90 }
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = mirrored
        }
    }

    private func configureAndStart() {
        guard wantsRunning else { return }
        do {
            if input == nil {
                let camera = try makeInput(position: .back)
                session.beginConfiguration()
                session.sessionPreset = .photo
                guard session.canAddInput(camera), session.canAddOutput(output) else {
                    session.commitConfiguration()
                    throw CameraError.unavailable
                }
                session.addInput(camera)
                session.addOutput(output)
                input = camera
                session.commitConfiguration()
            }
            if !session.isRunning { session.startRunning() }
            publishReady()
        } catch {
            fail((error as? CameraError)?.errorDescription ?? AppLocalization.current.text("camera.setupFailed"))
        }
    }

    private func makeInput(position: AVCaptureDevice.Position) throws -> AVCaptureDeviceInput {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
            throw CameraError.unavailable
        }
        return try AVCaptureDeviceInput(device: device)
    }

    private func publishReady() {
        let running = session.isRunning && wantsRunning
        let front = input?.device.position == .front
        DispatchQueue.main.async {
            self.permissionDenied = false
            self.message = nil
            self.isFront = front
            self.isReady = running
        }
    }

    private func showPermissionDenied() {
        DispatchQueue.main.async {
            self.permissionDenied = true
            self.isReady = false
            self.message = AppLocalization.current.text("camera.permissionDenied")
        }
    }

    private func fail(_ description: String) {
        DispatchQueue.main.async {
            self.isCapturing = false
            self.message = description
        }
    }

    @objc private func interrupted() {
        queue.async { [self] in
            if session.isRunning { session.stopRunning() }
            DispatchQueue.main.async {
                self.isReady = false
                self.isCapturing = false
                self.message = AppLocalization.current.text("camera.interrupted")
            }
        }
    }

    @objc private func interruptionEnded() {
        queue.async { [self] in if wantsRunning { configureAndStart() } }
    }

    @objc private func runtimeError() {
        DispatchQueue.main.async {
            self.isReady = false
            self.isCapturing = false
            self.message = AppLocalization.current.text("camera.stopped")
        }
    }

    private enum CameraError: LocalizedError {
        case unavailable
        var errorDescription: String? {
            let l10n = AppLocalization.current
            return l10n.text("camera.unavailable", l10n.brandName)
        }
    }
}
