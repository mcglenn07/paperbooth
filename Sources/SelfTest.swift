import AppKit
import ImageIO
import SwiftUI

enum SelfTest {
    @MainActor static func run() throws {
        let args = CommandLine.arguments
        let output = args.count > 2 ? URL(fileURLWithPath: args[2], isDirectory: true) : URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Paperbooth-tests")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        func require(_ condition: Bool, _ message: String) throws {
            if !condition { throw BoothError.message(message) }
        }
        func solid(_ color: NSColor, size: NSSize = NSSize(width: 1600, height: 1000)) -> NSImage {
            let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
                                       bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                       colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            color.setFill()
            NSRect(origin: .zero, size: size).fill()
            NSGraphicsContext.restoreGraphicsState()
            let image = NSImage(size: size)
            image.addRepresentation(rep)
            return image
        }
        let colors: [NSColor] = [.systemRed, .systemGreen, .systemBlue]
        let photos = colors.map { solid($0) }
        let imports = output.appendingPathComponent("import-photos")
        try FileManager.default.createDirectory(at: imports, withIntermediateDirectories: true)
        for (index, photo) in photos.enumerated() {
            try SheetRenderer.jpeg(photo).write(to: imports.appendingPathComponent("photo-\(index + 1).jpg"))
        }
        let sheet = SheetRenderer.render(photos: photos, style: SheetStyle())
        let data = try SheetRenderer.jpeg(sheet)
        let source = CGImageSourceCreateWithData(data as CFData, nil)!
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)! as NSDictionary
        try require(properties[kCGImagePropertyPixelWidth] as? Int == 1800, "Incorrect sheet width")
        try require(properties[kCGImagePropertyPixelHeight] as? Int == 1200, "Incorrect sheet height")
        try require(properties[kCGImagePropertyDPIWidth] as? Int == 300, "Incorrect horizontal DPI")
        try require(properties[kCGImagePropertyDPIHeight] as? Int == 300, "Incorrect vertical DPI")
        let rep = sheet.representations[0] as! NSBitmapImageRep
        for (index, point) in [(200, 200), (1050, 200), (200, 750)].enumerated() {
            let color = rep.colorAt(x: point.0, y: point.1)!.usingColorSpace(.sRGB)!
            let expected = colors[index].usingColorSpace(.sRGB)!
            try require(abs(color.redComponent - expected.redComponent) < 0.025 &&
                        abs(color.greenComponent - expected.greenComponent) < 0.025 &&
                        abs(color.blueComponent - expected.blueComponent) < 0.025, "Photo order or orientation failed at cell \(index + 1)")
        }
        let custom = SheetRenderer.render(photos: photos, style: SheetStyle(titleArtwork: solid(.magenta)))
        let titlePixel = (custom.representations[0] as! NSBitmapImageRep).colorAt(x: 1100, y: 800)!.usingColorSpace(.sRGB)!
        try require(titlePixel.redComponent > 0.9 && titlePixel.blueComponent > 0.9, "Title artwork did not replace title cell")
        let overlay = SheetRenderer.render(photos: photos, style: SheetStyle(overlay: solid(.yellow)))
        let overlayPixel = (overlay.representations[0] as! NSBitmapImageRep).colorAt(x: 200, y: 200)!.usingColorSpace(.sRGB)!
        try require(overlayPixel.redComponent > 0.9 && overlayPixel.greenComponent > 0.9, "Overlay was not drawn last")
        let cropImage = NSImage(size: NSSize(width: 2400, height: 1000), flipped: true) { rect in
            NSColor.red.setFill(); rect.fill()
            NSColor.green.setFill(); NSRect(x: 400, y: 0, width: 1600, height: 1000).fill()
            NSColor.blue.setFill(); NSRect(x: 2000, y: 0, width: 400, height: 1000).fill()
            return true
        }
        let cropSheet = SheetRenderer.render(photos: [cropImage], style: SheetStyle())
        let cropRep = cropSheet.representations[0] as! NSBitmapImageRep
        for x in [90, 400, 870] {
            let pixel = cropRep.colorAt(x: x, y: 300)!.usingColorSpace(.sRGB)!
            try require(pixel.greenComponent > 0.9 && pixel.redComponent < 0.1, "Aspect-fill cropping failed")
        }
        let preview = SheetRenderer.render(photos: [], style: SheetStyle())
        try (preview.representations[0] as! NSBitmapImageRep).representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("Midnight-layout.png"))
        let warm = SheetRenderer.render(photos: [], style: SheetStyle(title: "GOOD TIMES\nTOGETHER", subtitle: "YOUR EVENT • YOUR DATE", theme: "Warm paper"))
        try (warm.representations[0] as! NSBitmapImageRep).representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("Warm-paper-layout.png"))
        try data.write(to: output.appendingPathComponent("test-sheet.jpg"))
        let long = SheetRenderer.render(photos: [], style: SheetStyle(title: String(repeating: "A wonderful celebration ", count: 5)))
        try (long.representations[0] as! NSBitmapImageRep).representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("test-long-title.png"))
        let preferenceSuite = "local.paperbooth.tests.\(UUID().uuidString)"
        let testPreferences = UserDefaults(suiteName: preferenceSuite)!
        defer { testPreferences.removePersistentDomain(forName: preferenceSuite) }
        let model = BoothModel(defaults: testPreferences)
        try require(!model.manualMode, "Default mode should remain automatic")
        model.manualMode = true
        try require(BoothModel(defaults: UserDefaults(suiteName: preferenceSuite)!).manualMode, "Manual mode did not persist")
        model.manualMode = false
        try require(model.mirrored, "First launch must retain the existing mirrored default")
        model.mirrored = false
        try require(!BoothModel(defaults: UserDefaults(suiteName: preferenceSuite)!).mirrored,
                    "Mirror OFF did not survive model recreation")
        model.mirrored = true
        try require(BoothModel(defaults: UserDefaults(suiteName: preferenceSuite)!).mirrored,
                    "Mirror ON did not survive model recreation")
        func sheets(in folder: URL) throws -> [URL] {
            try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
                .filter { $0.lastPathComponent.hasPrefix("sheet-6x4") && $0.pathExtension == "jpg" }
        }
        model.outputFolder = output.appendingPathComponent("session-tests")
        model.photos = photos
        model.updateProof()
        model.save()
        try require(!model.needsSave && model.savedFolder != nil, "Session save state failed")
        let firstFolder = model.savedFolder!
        for name in ["photo-1.jpg", "photo-2.jpg", "photo-3.jpg"] {
            try require(FileManager.default.fileExists(atPath: firstFolder.appendingPathComponent(name).path), "Missing export: \(name)")
        }
        let firstSheets = try sheets(in: firstFolder)
        try require(firstSheets.count == 1, "Expected one finished sheet")
        let firstName = firstSheets[0].lastPathComponent
        let defaultCollection = model.mergedOutputFolder!
        try require(try sheets(in: defaultCollection).map(\.lastPathComponent) == [firstName], "Default collection is missing the finished sheet")
        try require(try Data(contentsOf: defaultCollection.appendingPathComponent(firstName)) == Data(contentsOf: firstSheets[0]),
                    "Collected image differs from the session sheet")
        try require(firstName.range(of: #"^sheet-6x4_\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}_[A-F0-9]{6}\.jpg$"#,
                                    options: .regularExpression) != nil, "Sheet lacks a timestamp and unique suffix")
        model.updateProof()
        model.save()
        try require(try sheets(in: firstFolder).map(\.lastPathComponent) == [firstName], "Saving again created duplicate finished sheets")
        try require(try sheets(in: defaultCollection).count == 1, "Re-saving duplicated a collected sheet")
        model.reset()
        try require(model.photos.isEmpty && !model.needsSave && model.savedFolder == nil, "Reset did not clear session state")
        model.photos = [photos[0]]
        model.updateProof()
        model.save()
        try require(model.savedFolder != nil && model.savedFolder != firstFolder, "Session folders were reused")
        try require(try sheets(in: model.savedFolder!).isEmpty, "Incomplete session exported a sheet")
        try require(try sheets(in: defaultCollection).count == 1, "Partial session appeared in the finished collection")
        let partialFolder = model.savedFolder!
        model.photos = photos
        model.updateProof()
        model.save()
        let secondSheets = try sheets(in: model.savedFolder!)
        try require(model.savedFolder == partialFolder && secondSheets.count == 1 && secondSheets[0].lastPathComponent != firstName,
                    "Different sessions must have different sheet filenames, including a resumed partial session")
        try require(try sheets(in: defaultCollection).count == 2, "Completed sessions did not collect in one folder")

        let customCollection = output.appendingPathComponent("facebook-ready")
        model.finishedSheetsFolder = customCollection
        try require(model.needsSave && model.savedFolder == nil, "Changing destination should allow the current sheet to be saved there")
        try require(BoothModel(defaults: UserDefaults(suiteName: preferenceSuite)!).finishedSheetsFolder?.path == customCollection.path,
                    "Finished sheets folder did not persist")
        model.save()
        let secondName = secondSheets[0].lastPathComponent
        try require(!model.needsSave && model.error == nil && (try sheets(in: customCollection).map(\.lastPathComponent)) == [secondName],
                    "Changing destination did not save the current sheet with its stable filename")
        let blockedFolder = output.appendingPathComponent("not-a-directory")
        try Data("test blocker".utf8).write(to: blockedFolder)
        model.finishedSheetsFolder = blockedFolder
        model.save()
        try require(model.needsSave && model.savedFolder == nil && model.error != nil, "Failed collection write incorrectly marked session saved")
        try require(FileManager.default.fileExists(atPath: partialFolder.appendingPathComponent(secondName).path),
                    "Collection failure lost the session backup")
        model.finishedSheetsFolder = customCollection
        model.save()
        try require(!model.needsSave && model.error == nil && (try sheets(in: customCollection).count) == 1, "Retry failed or duplicated sheet")
        model.reset()
        model.outputFolder = nil
        model.photos = photos
        model.updateProof()
        model.save()
        let collectedFiles = try FileManager.default.contentsOfDirectory(at: customCollection, includingPropertiesForKeys: nil)
        try require(!model.needsSave && model.savedFolder == customCollection && collectedFiles.count == 2 && collectedFiles.allSatisfy { $0.pathExtension == "jpg" },
                    "Choosing only a finished sheets folder must save without backup folders or original photos in that collection")
        print("PASS: flat finished-sheet collection, persistent folder selection, custom/default destinations, sheets-only saving, duplicate-free retries and failure recovery.")
        print("PASS: mirror ON/OFF persistence, unique sheet filenames across sessions, stable filenames on re-save, and partial-session completion.")
        // Render the guest screen with a synthetic camera frame; no camera access required.
        let guestModel = BoothModel(defaults: testPreferences)
        guestModel.title = "Primary Trick or Treat"
        guestModel.camera.ready = true
        guestModel.camera.guestPreviewAvailable = true
        guestModel.camera.guestFrame = photos[0]
        for size in [NSSize(width: 1280, height: 800), NSSize(width: 800, height: 1280)] {
            let renderer = ImageRenderer(content: GuestView(model: guestModel, camera: guestModel.camera)
                .frame(width: size.width, height: size.height))
            guard let image = renderer.cgImage else { throw BoothError.message("Guest screen did not render") }
            try require(image.width == Int(size.width) && image.height == Int(size.height), "Guest screen dimensions incorrect")
            let bitmap = NSBitmapImageRep(cgImage: image)
            let center = bitmap.colorAt(x: image.width / 2, y: image.height / 2)!.usingColorSpace(.sRGB)!
            try require(center.redComponent > 0.8 && center.greenComponent < 0.4, "Guest camera frame is missing or obscured")
            try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("guest-view-\(Int(size.width)).png"))
        }
        guestModel.countdown = 3
        let countdownRenderer = ImageRenderer(content: GuestView(model: guestModel, camera: guestModel.camera).frame(width: 1280, height: 800))
        guard let countdownImage = countdownRenderer.cgImage else { throw BoothError.message("Guest countdown did not render") }
        try NSBitmapImageRep(cgImage: countdownImage).representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("guest-countdown.png"))
        guestModel.countdown = nil
        let splitFrame = solid(.red)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: splitFrame.representations[0] as! NSBitmapImageRep)
        NSColor.blue.setFill(); NSRect(x: 800, y: 0, width: 800, height: 1000).fill()
        NSGraphicsContext.restoreGraphicsState()
        guestModel.camera.guestFrame = splitFrame
        for mirrored in [false, true] {
            guestModel.mirrored = mirrored
            let renderer = ImageRenderer(content: GuestView(model: guestModel, camera: guestModel.camera).frame(width: 1280, height: 800))
            guard let image = renderer.cgImage else { throw BoothError.message("Mirrored guest view did not render") }
            let pixel = NSBitmapImageRep(cgImage: image).colorAt(x: 300, y: 400)!.usingColorSpace(.sRGB)!
            try require(mirrored ? pixel.blueComponent > 0.9 : pixel.redComponent > 0.9, "Guest mirror setting does not match the operator setting")
        }
        guestModel.camera.ready = false
        let disconnected = ImageRenderer(content: GuestView(model: guestModel, camera: guestModel.camera).frame(width: 1280, height: 800))
        guard let disconnectedImage = disconnected.cgImage else { throw BoothError.message("Disconnected guest view did not render") }
        let disconnectedPixel = NSBitmapImageRep(cgImage: disconnectedImage).colorAt(x: 300, y: 400)!.usingColorSpace(.sRGB)!
        try require(disconnectedPixel.redComponent < 0.1 && disconnectedPixel.blueComponent < 0.1, "Disconnected guest view still shows an old camera frame")
        print("PASS: guest view renders the camera frame in landscape and portrait display sizes, plus countdown preview.")
        guestModel.photos = photos
        guestModel.updateProof()
        try require(guestModel.showingFinishedSheet && guestModel.viewerAspectRatio == 1.5, "Completed session did not switch to the full sheet")
        func renderedGuest() throws -> Data {
            let renderer = ImageRenderer(content: GuestView(model: guestModel, camera: guestModel.camera).frame(width: 1280, height: 800))
            guard let image = renderer.cgImage else { throw BoothError.message("Completed guest sheet did not render") }
            return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
        }
        let completedGuest = try renderedGuest()
        try completedGuest.write(to: output.appendingPathComponent("guest-finished-sheet.png"))
        guestModel.camera.ready = true
        guestModel.camera.guestFrame = photos[1]
        guestModel.mirrored.toggle()
        guestModel.error = "Simulated save failure"
        try require(try renderedGuest() == completedGuest, "Finished sheet changed with live camera, mirror preference or save failure")
        let completedRenderer = ImageRenderer(content: FinishedSheetView(image: guestModel.proof).frame(width: 900, height: 600))
        guard let completedImage = completedRenderer.cgImage else { throw BoothError.message("Shared finished-sheet viewer did not render") }
        let completedRep = NSBitmapImageRep(cgImage: completedImage)
        for (index, point) in [(100, 100), (525, 100), (100, 375)].enumerated() {
            let actual = completedRep.colorAt(x: point.0, y: point.1)!.usingColorSpace(.sRGB)!
            let channels = [actual.redComponent, actual.greenComponent, actual.blueComponent]
            try require(channels[index] > 0.6 && channels[index] > channels[(index + 1) % 3] + 0.2 && channels[index] > channels[(index + 2) % 3] + 0.2,
                        "Finished-sheet viewer cropped or mirrored photo \(index + 1)")
        }
        guestModel.reset()
        try require(!guestModel.showingFinishedSheet && (try renderedGuest()) != completedGuest, "Next guests did not return the viewer to the camera")
        guestModel.photos = [photos[0], photos[1]]
        guestModel.updateProof()
        try require(!guestModel.showingFinishedSheet, "Incomplete session incorrectly shows a finished sheet")
        print("PASS: completed sheet stays on both viewers, remains unmirrored, survives camera/save changes and resets for next guests.")
        var gate = SpacePressGate()
        try require(gate.press(isRepeat: false), "Initial Space did not trigger")
        try require(!gate.press(isRepeat: true) && !gate.press(isRepeat: false), "Held or duplicate Space retriggered")
        gate.release()
        try require(!gate.press(isRepeat: true), "Auto-repeat after focus change triggered capture")
        gate.release()
        try require(gate.press(isRepeat: false), "Fresh Space press failed")
        let captureModel = BoothModel(defaults: testPreferences)
        captureModel.manualMode = true
        captureModel.camera.ready = true
        captureModel.finishedSheetsFolder = output.appendingPathComponent("manual-mode-sheets")
        var captured = 0
        var countdownTicks = 0
        let fakeCapture: (Bool) async throws -> NSImage = { _ in captured += 1; return photos[(captured - 1) % 3] }
        let fakeSleep: (UInt64) async throws -> Void = { duration in
            try Task.checkCancellation()
            if duration == 1_000_000_000 { countdownTicks += 1 }
            await Task.yield()
        }
        func finishCapture() throws {
            let deadline = Date().addingTimeInterval(5)
            while captureModel.takingPhotos && Date() < deadline {
                RunLoop.current.run(until: Date().addingTimeInterval(0.01))
            }
            try require(!captureModel.takingPhotos, "Capture sequence failed to finish")
        }
        for expected in 1...3 {
            captureModel.runCapture(capture: fakeCapture, sleep: fakeSleep)
            // Multiple presses while busy must neither capture nor queue shots.
            for _ in 0..<5 { captureModel.runCapture(capture: fakeCapture, sleep: fakeSleep) }
            try finishCapture()
            try require(captured == expected && captureModel.photos.count == expected, "Manual trigger captured more than one photo")
        }
        try require(countdownTicks == captureModel.countdownSeconds * 3 && !captureModel.needsSave && captureModel.savedFolder != nil,
                    "Manual photos need separate countdowns and a saved sheet after photo three")
        captureModel.runCapture(capture: fakeCapture, sleep: fakeSleep)
        try require(captured == 3 && !captureModel.takingPhotos && captureModel.showingFinishedSheet, "Capture action should not add a fourth photo")
        captureModel.updateProof()
        captureModel.triggerManualAction()
        try require(captureModel.showingFinishedSheet && captureModel.discardAction == "reset", "Space discarded an unsaved sheet without the existing save prompt")
        captureModel.discardAction = nil
        captureModel.save()
        var reviewGate = SpacePressGate()
        if reviewGate.press(isRepeat: false) { captureModel.triggerManualAction() }
        try require(captureModel.photos.isEmpty && !captureModel.showingFinishedSheet && !captureModel.takingPhotos && captureModel.countdown == nil && captured == 3,
                    "Review Space should only prepare the next group, not start capturing")
        try require(!reviewGate.press(isRepeat: true) && !reviewGate.press(isRepeat: false), "Held review key can trigger the next capture")
        reviewGate.release()
        try require(reviewGate.press(isRepeat: false), "Next group needs a fresh key press")
        captureModel.runCapture(capture: fakeCapture, sleep: fakeSleep)
        captureModel.cancel()
        try finishCapture()
        try require(captureModel.photos.isEmpty, "Cancelled countdown still captured a photo")
        captureModel.runCapture(capture: { _ in throw BoothError.message("Test camera failure") }, sleep: fakeSleep)
        try finishCapture()
        try require(captureModel.photos.isEmpty && captureModel.error != nil, "Failed shot consumed a photo slot")
        captureModel.error = nil
        captureModel.manualMode = false
        captureModel.runCapture(capture: fakeCapture, sleep: fakeSleep)
        try finishCapture()
        try require(captureModel.photos.count == 3 && captured == 6, "Automatic mode no longer captures three photos")
        captureModel.reset()
        captureModel.camera.ready = false
        captureModel.runCapture(capture: fakeCapture, sleep: fakeSleep)
        try require(!captureModel.takingPhotos && captured == 6, "Disconnected camera accepted a trigger")
        print("PASS: Space advances saved review to ready without capturing, preserves unsaved sheets and requires a fresh press for the next shot.")
        print("PASS: manual one-shot countdowns, busy/held key protection, cancellation, errors, completed-sheet hold, persistence and automatic mode.")
        if args.count > 3 {
            let templateURL = URL(fileURLWithPath: args[3])
            guard let layout = try TemplateLayout.load(for: templateURL), let template = NSImage(contentsOf: templateURL) else {
                throw BoothError.message("Missing template or placement file")
            }
            let templateStyle = SheetStyle(background: try layout.background(nextTo: templateURL), overlay: template,
                                           photoRects: layout.photos.map(\.rect))
            let fitted = SheetRenderer.render(photos: photos, style: templateStyle)
            let fittedRep = fitted.representations[0] as! NSBitmapImageRep
            for (index, cell) in layout.photos.enumerated() {
                let actual = fittedRep.colorAt(x: Int(cell.x + cell.width / 2), y: Int(cell.y + cell.height / 2))!.usingColorSpace(.sRGB)!
                let expected = colors[index].usingColorSpace(.sRGB)!
                try require(abs(actual.redComponent - expected.redComponent) < 0.03 &&
                            abs(actual.greenComponent - expected.greenComponent) < 0.03 &&
                            abs(actual.blueComponent - expected.blueComponent) < 0.03, "Template window \(index + 1) is not transparent or aligned")
            }
            try fittedRep.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("template-alignment-check.png"))
            let blank = SheetRenderer.render(photos: [], style: templateStyle)
            try (blank.representations[0] as! NSBitmapImageRep).representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("template-preview.png"))
            try SheetRenderer.jpeg(fitted).write(to: output.appendingPathComponent("template-print-check.jpg"))
            let badURL = output.appendingPathComponent("invalid-overlay.png")
            let badData = Data("{\"canvasWidth\":1800,\"canvasHeight\":1200,\"photos\":[]}".utf8)
            try badData.write(to: badURL.deletingPathExtension().appendingPathExtension("layout.json"))
            var rejected = false
            do { _ = try TemplateLayout.load(for: badURL) } catch { rejected = true }
            try require(rejected, "Invalid layout was not rejected")
            print("PASS: custom template alignment, transparent windows, original event panel, preview/export and invalid-layout handling.")
        }
        print("PASS: dimensions, 300 dpi, photo order/orientation, crop, title art, overlay, styles, full/partial session saving, unique session folders, and reset.")
    }
}
