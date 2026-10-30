import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class BoothModel: ObservableObject {
    private let preferences: UserDefaults
    let camera = CameraController()
    @Published var showSettings = false
    @Published var discardAction: String?
    @Published var title: String { didSet { updateProof(); preferences.set(title, forKey: "eventTitle") } }
    @Published var subtitle: String { didSet { updateProof(); preferences.set(subtitle, forKey: "eventSubtitle") } }
    @Published var theme: String { didSet { updateProof(); preferences.set(theme, forKey: "theme") } }
    @Published var countdownSeconds: Int { didSet { preferences.set(countdownSeconds, forKey: "countdown") } }
    @Published var mirrored: Bool { didSet { preferences.set(mirrored, forKey: "mirrorPhotos") } }
    @Published var background: NSImage?
    @Published var titleArtwork: NSImage?
    @Published var overlay: NSImage?
    @Published var overlayPhotoRects: [NSRect]?
    private var templateBackground: NSImage?
    @Published var backgroundName = "Original geometric design"
    @Published var titleArtworkName = "Editable event title"
    @Published var overlayName = "No overlay"
    @Published var photos: [NSImage] = []
    @Published var proof: NSImage
    @Published var countdown: Int?
    @Published var takingPhotos = false
    @Published var flash = false
    @Published var status = "Three photos. One keepsake."
    @Published var error: String?
    @Published var outputFolder: URL?
    @Published var finishedSheetsFolder: URL? {
        didSet {
            if let folder = finishedSheetsFolder { preferences.set(folder.path, forKey: "finishedSheetsFolder") }
            else { preferences.removeObject(forKey: "finishedSheetsFolder") }
            if photos.count == 3 {
                needsSave = true; savedFolder = nil
                status = "Finished sheets folder changed. Save to put this sheet there."
            }
        }
    }
    @Published var savedFolder: URL?
    @Published var needsSave = false
    private var task: Task<Void, Never>?
    private var sessionFolder: URL?
    private var sessionID: String?

    var mergedOutputFolder: URL? {
        finishedSheetsFolder ?? outputFolder?.appendingPathComponent("Finished Sheets", isDirectory: true)
    }

    var style: SheetStyle { SheetStyle(title: title, subtitle: subtitle, theme: theme,
                                       background: templateBackground ?? background, titleArtwork: titleArtwork,
                                       overlay: overlay, photoRects: overlayPhotoRects) }
    var captureAspectRatio: CGFloat {
        let rect = overlayPhotoRects?[min(photos.count, 2)] ?? SheetRenderer.cells[0]
        return rect.width / rect.height
    }

    init(defaults: UserDefaults = .standard) {
        preferences = defaults
        mirrored = defaults.object(forKey: "mirrorPhotos") == nil ? true : defaults.bool(forKey: "mirrorPhotos")
        title = defaults.string(forKey: "eventTitle") ?? "A NIGHT TO\nREMEMBER"
        subtitle = defaults.string(forKey: "eventSubtitle") ?? "GOOD PEOPLE. GREAT MEMORIES."
        theme = defaults.string(forKey: "theme") ?? "Midnight"
        countdownSeconds = max(2, min(10, defaults.integer(forKey: "countdown") == 0 ? 3 : defaults.integer(forKey: "countdown")))
        proof = SheetRenderer.render(photos: [], style: SheetStyle())
        for kind in ["background", "titleArtwork", "overlay"] {
            if let path = defaults.string(forKey: "asset.\(kind)"), let image = NSImage(contentsOfFile: path) {
                let name = URL(fileURLWithPath: path).lastPathComponent
                switch kind {
                case "background": background = image; backgroundName = name
                case "titleArtwork": titleArtwork = image; titleArtworkName = name
                default:
                    do {
                        try loadOverlayLayout(URL(fileURLWithPath: path))
                        overlay = image; overlayName = name
                    } catch { self.error = error.localizedDescription }
                }
            }
        }
        if let path = defaults.string(forKey: "outputFolder") {
            outputFolder = URL(fileURLWithPath: path, isDirectory: true)
        }
        if let path = defaults.string(forKey: "finishedSheetsFolder") {
            finishedSheetsFolder = URL(fileURLWithPath: path, isDirectory: true)
        }
        updateProof()
    }

    func updateProof() {
        proof = SheetRenderer.render(photos: photos, style: style)
        if !photos.isEmpty {
            needsSave = true; savedFolder = nil
            if !takingPhotos { status = "Sheet updated. Save to keep these changes." }
        }
    }

    private func loadOverlayLayout(_ url: URL) throws {
        let layout = try TemplateLayout.load(for: url)
        let base = try layout?.background(nextTo: url)
        overlayPhotoRects = layout?.photos.map(\.rect)
        templateBackground = base
    }

    func start() {
        guard !takingPhotos, camera.ready, photos.count < 3 else { return }
        takingPhotos = true
        task = Task {
            do {
                while photos.count < 3 {
                    status = "Get ready for photo \(photos.count + 1) of 3"
                    for tick in stride(from: countdownSeconds, through: 1, by: -1) {
                        try Task.checkCancellation()
                        countdown = tick
                        try await Task.sleep(nanoseconds: 1_000_000_000)
                    }
                    countdown = nil
                    status = "Hold that pose…"
                    let photo = try await camera.capture(mirrored: mirrored)
                    try Task.checkCancellation()
                    photos.append(photo)
                    updateProof()
                    flash = true
                    try await Task.sleep(nanoseconds: 160_000_000)
                    flash = false
                    if photos.count < 3 {
                        status = "Nice! Change your pose."
                        try await Task.sleep(nanoseconds: 1_200_000_000)
                    }
                }
                status = "Your keepsake is ready."
                if mergedOutputFolder != nil { save() }
            } catch is CancellationError {
                status = photos.isEmpty ? "Session cancelled." : "Paused. Your captured photos are kept."
            } catch {
                self.error = error.localizedDescription
                status = "Your captured photos are kept. Reconnect and continue."
            }
            countdown = nil
            flash = false
            takingPhotos = false
            task = nil
        }
    }

    func cancel() { task?.cancel(); camera.cancelCapture() }

    func reset() {
        guard !takingPhotos else { return }
        photos = []
        sessionFolder = nil
        sessionID = nil
        savedFolder = nil
        needsSave = false
        updateProof()
        status = "Ready for the next guests."
    }

    func importPhotos() {
        let panel = NSOpenPanel()
        panel.title = "Choose exactly three photos"
        panel.message = "Photos are placed in filename order: top left, top right, then bottom left."
        panel.allowedContentTypes = [.jpeg, .png, .heic, .tiff]
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        guard panel.urls.count == 3 else { error = "Choose exactly three photos for this layout."; return }
        let urls = panel.urls.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        let images = urls.compactMap { NSImage(contentsOf: $0) }
        guard images.count == 3 else { error = "One of these photos could not be opened. Please choose different files."; return }
        reset()
        photos = images
        updateProof()
        status = "Three photos imported. Your keepsake is ready."
        if mergedOutputFolder != nil { save() }
    }

    func chooseArtwork(_ kind: String) {
        let panel = NSOpenPanel()
        panel.title = kind == "titleArtwork" ? "Choose title-cell artwork" : kind == "overlay" ? "Choose a transparent overlay" : "Choose a sheet background"
        panel.message = kind == "titleArtwork" ? "Use an 8:5 image. It replaces the title cell, including its text." : kind == "overlay" ? "Use an 1800 × 1200 transparent PNG. It is drawn over the entire finished sheet." : "Use an 1800 × 1200 image. Other sizes are cropped to fill."
        panel.allowedContentTypes = kind == "overlay" ? [.png] : [.png, .jpeg, .heic, .tiff]
        guard panel.runModal() == .OK, let url = panel.url, let image = NSImage(contentsOf: url) else { return }
        switch kind {
        case "background": background = image; backgroundName = url.lastPathComponent
        case "titleArtwork": titleArtwork = image; titleArtworkName = url.lastPathComponent
        default:
            do { try loadOverlayLayout(url) }
            catch { self.error = error.localizedDescription; return }
            overlay = image; overlayName = url.lastPathComponent
        }
        preferences.set(url.path, forKey: "asset.\(kind)")
        updateProof()
    }

    func clearArtwork(_ kind: String) {
        switch kind {
        case "background": background = nil; backgroundName = "Original geometric design"
        case "titleArtwork": titleArtwork = nil; titleArtworkName = "Editable event title"
        default:
            overlay = nil; overlayName = "No overlay"
            overlayPhotoRects = nil; templateBackground = nil
        }
        preferences.removeObject(forKey: "asset.\(kind)")
        updateProof()
    }

    @discardableResult func chooseOutputFolder() -> Bool {
        let panel = NSOpenPanel()
        panel.title = "Choose where to save booth sessions"
        panel.message = "Each session gets its own folder with the finished sheet and three original photos. Future completed sessions save here automatically."
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        outputFolder = url
        sessionFolder = nil
        preferences.set(url.path, forKey: "outputFolder")
        if !photos.isEmpty { needsSave = true; savedFolder = nil }
        return true
    }

    func chooseFinishedSheetsFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose a folder for all finished sheets"
        panel.message = "Every completed 6 × 4 image goes directly into this one folder, ready to select for Facebook uploads."
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = mergedOutputFolder
        guard panel.runModal() == .OK, let url = panel.url else { return }
        finishedSheetsFolder = url
    }

    func openFinishedSheetsFolder() {
        guard let folder = mergedOutputFolder else { return }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            if !NSWorkspace.shared.open(folder) { throw BoothError.message("Finder could not open this folder.") }
        } catch { self.error = "Could not open \(folder.path): \(error.localizedDescription)" }
    }

    func save() {
        guard !photos.isEmpty else { return }
        // Partial sessions need a backup folder for their individual photos.
        if (photos.count < 3 && outputFolder == nil) || mergedOutputFolder == nil {
            guard chooseOutputFolder() else { return }
        }
        needsSave = true
        savedFolder = nil
        error = nil
        do {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let identifier = sessionID ?? "\(formatter.string(from: Date()))_\(UUID().uuidString.prefix(6))"
            sessionID = identifier
            var backupFolder: URL?
            if let outputFolder {
                let folder = sessionFolder ?? outputFolder.appendingPathComponent("Booth_\(identifier)")
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                sessionFolder = folder
                backupFolder = folder
                // Save originals first so a sheet-export error never discards the captures.
                for (index, image) in photos.enumerated() {
                    try SheetRenderer.jpeg(image).write(to: folder.appendingPathComponent("photo-\(index + 1).jpg"), options: .atomic)
                }
            }
            if photos.count == 3 {
                let sheetName = "sheet-6x4_\(identifier).jpg"
                let jpeg = try SheetRenderer.jpeg(proof)
                if let backupFolder {
                    try jpeg.write(to: backupFolder.appendingPathComponent(sheetName), options: .atomic)
                }
                guard let folder = mergedOutputFolder else { throw BoothError.message("Choose a finished sheets folder in Setup.") }
                do {
                    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                    try jpeg.write(to: folder.appendingPathComponent(sheetName), options: .atomic)
                } catch {
                    throw BoothError.message("Could not save the finished sheet to \(folder.path). Choose an available folder in Setup and save again. \(error.localizedDescription)")
                }
            }
            savedFolder = backupFolder ?? mergedOutputFolder
            needsSave = false
            status = photos.count == 3 ? "Saved — ready to print or start the next session." : "Captured photos saved. Continue to finish the sheet."
        } catch {
            self.error = "Could not save this session: \(error.localizedDescription)"
            status = "Save incomplete. Your photos are kept; check the folder and save again."
        }
    }

    func printSheet() {
        guard photos.count == 3 else { return }
        let view = SheetPrintView(image: proof)
        let info = NSPrintInfo.shared.copy() as! NSPrintInfo
        info.orientation = .landscape
        info.paperSize = NSSize(width: 432, height: 288)
        info.topMargin = 0; info.bottomMargin = 0; info.leftMargin = 0; info.rightMargin = 0
        info.horizontalPagination = .fit; info.verticalPagination = .fit
        info.isHorizontallyCentered = true; info.isVerticallyCentered = true
        let operation = NSPrintOperation(view: view, printInfo: info)
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
        operation.run()
    }
}

final class SheetPrintView: NSView {
    let image: NSImage
    init(image: NSImage) { self.image = image; super.init(frame: NSRect(x: 0, y: 0, width: 432, height: 288)) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        image.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true,
                   hints: [.interpolation: NSImageInterpolation.high])
    }
}
