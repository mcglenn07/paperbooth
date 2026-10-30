import AppKit
import SwiftUI

@MainActor
final class GuestDisplayController: NSObject, ObservableObject, NSWindowDelegate {
    struct Display: Identifiable { let id: UInt32; let name: String }
    @Published private(set) var displays: [Display] = []
    @Published var selectedID: UInt32 = 0
    @Published private(set) var isOpen = false
    @Published private(set) var message = "Connect a second display and use Extended display in macOS Displays settings."
    private var guestWindow: NSWindow?
    private weak var camera: CameraController?
    private var observer: NSObjectProtocol?
    private var activeDisplayID: UInt32?
    private var operatorDisplayID: UInt32?

    static func displayID(_ screen: NSScreen) -> UInt32 {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }

    func refresh() {
        let screens = NSScreen.screens
        if let window = NSApp.mainWindow, window !== guestWindow, let screen = window.screen {
            operatorDisplayID = Self.displayID(screen)
        }
        displays = screens.map { Display(id: Self.displayID($0), name: $0.localizedName) }
        if !displays.contains(where: { $0.id == selectedID }) || selectedID == 0 {
            let remembered = UInt32(clamping: UserDefaults.standard.integer(forKey: "guestDisplayID"))
            selectedID = displays.first(where: { $0.id == remembered && $0.id != operatorDisplayID })?.id
                ?? displays.first(where: { $0.id != operatorDisplayID && CGDisplayIsBuiltin($0.id) == 0 })?.id
                ?? displays.first(where: { $0.id != operatorDisplayID })?.id ?? displays.first?.id ?? 0
        }
        if observer == nil {
            observer = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                                               object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.screensChanged() }
            }
        }
    }

    func show(model: BoothModel, previewOnly: Bool = false) {
        refresh()
        if !previewOnly {
            guard displays.count > 1, selectedID != operatorDisplayID,
                  CGDisplayIsInMirrorSet(selectedID) == 0,
                  let screen = NSScreen.screens.first(where: { Self.displayID($0) == selectedID }) else {
                message = "Choose a second display. Set it to Extended display in macOS so your controls stay on this screen."
                return
            }
            close()
            createWindow(model: model, frame: screen.frame, borderless: true)
            activeDisplayID = selectedID
            UserDefaults.standard.set(Int(selectedID), forKey: "guestDisplayID")
            message = "Guest View is showing on \(screen.localizedName)."
        } else {
            close()
            createWindow(model: model, frame: NSRect(x: 0, y: 0, width: 960, height: 640), borderless: false)
            guestWindow?.center()
            message = "Guest View is open in a preview window."
        }
        guestWindow?.orderFront(nil)
        camera = model.camera
        model.camera.setGuestPreviewActive(true)
        isOpen = true
    }

    private func createWindow(model: BoothModel, frame: NSRect, borderless: Bool) {
        let window = GuestWindow(contentRect: frame, styleMask: borderless ? [.borderless] : [.titled, .closable, .resizable],
                                 backing: .buffered, defer: false)
        window.title = "Paperbooth — Guest View"
        window.isReleasedWhenClosed = false
        window.backgroundColor = .black
        if borderless {
            window.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 1)
            window.setFrame(frame, display: false)
        }
        window.delegate = self
        window.collectionBehavior = [.fullScreenAuxiliary]
        window.contentView = NSHostingView(rootView: GuestView(model: model, camera: model.camera))
        window.onEscape = { [weak self] in self?.close() }
        guestWindow = window
    }

    func close() {
        guestWindow?.close()
        guestWindow = nil
        activeDisplayID = nil
        camera?.setGuestPreviewActive(false)
        isOpen = false
    }

    func windowWillClose(_ notification: Notification) {
        camera?.setGuestPreviewActive(false)
        isOpen = false
        activeDisplayID = nil
    }

    private func screensChanged() {
        refresh()
        guard let activeDisplayID else { return }
        guard let screen = NSScreen.screens.first(where: { Self.displayID($0) == activeDisplayID }), displays.count > 1 else {
            close()
            message = "Guest display disconnected. Reconnect it, then open Guest View again."
            return
        }
        guestWindow?.setFrame(screen.frame, display: true)
    }

    deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }
}

final class GuestWindow: NSWindow {
    var onEscape: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { onEscape?() }
}

struct GuestView: View {
    @ObservedObject var model: BoothModel
    @ObservedObject var camera: CameraController

    var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width / 1280, geometry.size.height / 800)
            VStack(spacing: 16 * scale) {
                Text(model.title.isEmpty ? "WELCOME TO THE PHOTOBOOTH" : model.title)
                    .font(.system(size: max(16, 28 * scale), weight: .semibold, design: .rounded))
                    .lineLimit(2).minimumScaleFactor(0.5).multilineTextAlignment(.center)
                ZStack {
                    Color.black
                    if camera.ready, let frame = camera.guestFrame {
                        GeometryReader { area in
                            Image(nsImage: frame).resizable().scaledToFill()
                                .frame(width: area.size.width, height: area.size.height).clipped()
                                .scaleEffect(x: model.mirrored ? -1 : 1, y: 1)
                        }
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "camera.fill").font(.system(size: 48 * scale))
                            Text(camera.ready ? (camera.guestPreviewAvailable ? "Getting the camera view ready…" : "Camera preview unavailable. Please ask the booth operator.") : "Getting ready. Please wait for your host.")
                                .font(.system(size: max(16, 26 * scale))).multilineTextAlignment(.center)
                        }.padding(30)
                    }
                    if let countdown = model.countdown {
                        Text("\(countdown)").font(.system(size: max(80, 190 * scale), weight: .heavy, design: .rounded))
                            .shadow(color: .black.opacity(0.8), radius: 12)
                    }
                    if model.flash { Color.white }
                }
                .aspectRatio(model.captureAspectRatio, contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                Text(prompt).font(.system(size: max(18, 32 * scale), weight: .semibold, design: .rounded))
                    .lineLimit(2).minimumScaleFactor(0.5).multilineTextAlignment(.center)
            }.padding(24 * scale).frame(width: geometry.size.width, height: geometry.size.height)
        }.background(Color.black).foregroundStyle(.white)
    }

    private var prompt: String {
        if model.flash { return "Lovely!" }
        if model.photos.count == 3 { return "All done! Thank you for the smiles." }
        if !camera.ready { return "Your photo moment is coming up." }
        if model.countdown != nil { return "Photo \(model.photos.count + 1) of 3 — look at the camera!" }
        if model.takingPhotos { return model.photos.isEmpty ? "Get ready!" : "Great! Try a new pose." }
        return model.photos.isEmpty ? "Find your pose. Your host will start shortly." : "Hold on — your host will continue shortly."
    }
}
