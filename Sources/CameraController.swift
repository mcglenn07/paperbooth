import AppKit
import AVFoundation
import SwiftUI

// Capture state lives on queue; observable UI state is only changed on the main thread.
final class CameraController: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "app.paperbooth.camera")
    private let output = AVCapturePhotoOutput()
    private var pending: CheckedContinuation<NSImage, Error>?
    private var captureID: Int64?
    private var observers: [NSObjectProtocol] = []
    @Published var devices: [AVCaptureDevice] = []
    @Published var selectedID = ""
    @Published var ready = false
    @Published var busy = false
    @Published var message = "Connect your iPhone, then enable the camera."
    @Published var permissionDenied = false

    override init() {
        super.init()
        let center = NotificationCenter.default
        for name in [AVCaptureDevice.wasConnectedNotification, AVCaptureDevice.wasDisconnectedNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                guard let self else { return }
                self.refresh()
                if name == AVCaptureDevice.wasDisconnectedNotification,
                   let device = notification.object as? AVCaptureDevice, device.uniqueID == self.selectedID {
                    self.ready = false
                    self.message = "Camera disconnected. Reconnect it and choose Enable camera."
                    self.queue.async { self.failPending("The camera disconnected. Reconnect it and try again.") }
                }
            })
        }
        observers.append(center.addObserver(forName: AVCaptureSession.runtimeErrorNotification, object: session, queue: .main) { [weak self] notification in
            guard let self else { return }
            let error = notification.userInfo?[AVCaptureSessionErrorKey] as? Error
            self.ready = false
            self.message = error?.localizedDescription ?? "The camera stopped. Enable it again to reconnect."
            self.queue.async { self.failPending("The camera stopped. Please reconnect and retry.") }
        })
        observers.append(center.addObserver(forName: AVCaptureSession.wasInterruptedNotification, object: session, queue: .main) { [weak self] _ in
            self?.ready = false
            self?.message = "Camera paused. Check your iPhone, then enable the camera again."
            self?.queue.async { self?.failPending("The camera was interrupted. Check your iPhone and retry.") }
        })
    }

    func refresh() {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else { return }
        devices = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera],
                                                   mediaType: .video, position: .unspecified).devices
    }

    func enable() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            refresh()
            if let device = devices.first(where: { $0.uniqueID == selectedID })
                ?? devices.first(where: { $0.isContinuityCamera }) ?? AVCaptureDevice.systemPreferredCamera ?? devices.first {
                select(device.uniqueID)
            } else {
                message = "No camera found. Mount and lock your iPhone, or connect it with USB, then retry."
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] _ in DispatchQueue.main.async { self?.enable() } }
        default:
            permissionDenied = true
            message = "Allow Paperbooth in System Settings → Privacy & Security → Camera, then reopen it."
        }
    }

    func select(_ id: String) {
        guard !busy, let device = devices.first(where: { $0.uniqueID == id }) else { return }
        selectedID = id
        ready = false
        busy = true
        message = "Connecting to \(device.localizedName)…"
        queue.async {
            do {
                self.session.stopRunning()
                self.session.beginConfiguration()
                self.session.inputs.forEach { self.session.removeInput($0) }
                self.session.outputs.forEach { self.session.removeOutput($0) }
                do {
                    let input = try AVCaptureDeviceInput(device: device)
                    guard self.session.canAddInput(input) else { throw BoothError.message("This camera could not be connected.") }
                    self.session.addInput(input)
                    if self.session.canSetSessionPreset(.photo) { self.session.sessionPreset = .photo }
                    else if self.session.canSetSessionPreset(.high) { self.session.sessionPreset = .high }
                    guard self.session.canAddOutput(self.output) else { throw BoothError.message("This camera does not support photo capture.") }
                    self.session.addOutput(self.output)
                    self.session.commitConfiguration()
                } catch {
                    self.session.commitConfiguration()
                    throw error
                }
                self.session.startRunning()
                let active = self.session.isRunning
                DispatchQueue.main.async {
                    self.busy = false
                    self.ready = active
                    self.message = active ? device.localizedName : "Camera unavailable. Close other camera apps and retry."
                }
            } catch {
                DispatchQueue.main.async {
                    self.busy = false
                    self.ready = false
                    self.message = error.localizedDescription
                }
            }
        }
    }

    func capture(mirrored: Bool) async throws -> NSImage {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                guard self.session.isRunning, self.pending == nil else {
                    continuation.resume(throwing: BoothError.message("The camera is not ready. Enable it and try again."))
                    return
                }
                self.pending = continuation
                let settings: AVCapturePhotoSettings
                if self.output.availablePhotoCodecTypes.contains(.jpeg) {
                    settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
                } else { settings = AVCapturePhotoSettings() }
                if let connection = self.output.connection(with: .video), connection.isVideoMirroringSupported {
                    connection.automaticallyAdjustsVideoMirroring = false
                    connection.isVideoMirrored = mirrored
                }
                self.captureID = settings.uniqueID
                self.output.capturePhoto(with: settings, delegate: self)
                let id = settings.uniqueID
                self.queue.asyncAfter(deadline: .now() + 15) {
                    if self.captureID == id { self.failPending("The camera took too long to respond. Check your iPhone and try again.") }
                }
            }
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        queue.async {
            guard self.captureID == photo.resolvedSettings.uniqueID else { return }
            if let error { self.failPending(error.localizedDescription); return }
            guard let data = photo.fileDataRepresentation(), let image = NSImage(data: data) else {
                self.failPending("The camera returned an unreadable photo. Please try again.")
                return
            }
            let continuation = self.pending
            self.pending = nil
            self.captureID = nil
            continuation?.resume(returning: image)
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        guard let error else { return }
        queue.async {
            if self.captureID == resolvedSettings.uniqueID { self.failPending(error.localizedDescription) }
        }
    }

    private func failPending(_ message: String) {
        let continuation = pending
        pending = nil
        captureID = nil
        continuation?.resume(throwing: BoothError.message(message))
    }

    func cancelCapture() {
        queue.async {
            let continuation = self.pending
            self.pending = nil
            self.captureID = nil
            continuation?.resume(throwing: CancellationError())
        }
    }

    deinit { observers.forEach(NotificationCenter.default.removeObserver) }
}

final class PreviewView: NSView {
    let preview = AVCaptureVideoPreviewLayer()
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        preview.videoGravity = .resizeAspectFill
        layer?.addSublayer(preview)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layout() { super.layout(); preview.frame = bounds }
}

struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession
    let mirrored: Bool
    func makeNSView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.preview.session = session
        return view
    }
    func updateNSView(_ view: PreviewView, context: Context) {
        if let connection = view.preview.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = mirrored
        }
    }
}
