import AppKit
import ImageIO

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
        let model = BoothModel()
        model.outputFolder = output.appendingPathComponent("session-tests")
        model.photos = photos
        model.updateProof()
        model.save()
        try require(!model.needsSave && model.savedFolder != nil, "Session save state failed")
        let firstFolder = model.savedFolder!
        for name in ["photo-1.jpg", "photo-2.jpg", "photo-3.jpg", "sheet-6x4.jpg"] {
            try require(FileManager.default.fileExists(atPath: firstFolder.appendingPathComponent(name).path), "Missing export: \(name)")
        }
        model.reset()
        try require(model.photos.isEmpty && !model.needsSave && model.savedFolder == nil, "Reset did not clear session state")
        model.photos = [photos[0]]
        model.updateProof()
        model.save()
        try require(model.savedFolder != nil && model.savedFolder != firstFolder, "Session folders were reused")
        try require(!FileManager.default.fileExists(atPath: model.savedFolder!.appendingPathComponent("sheet-6x4.jpg").path), "Incomplete session exported a sheet")
        print("PASS: dimensions, 300 dpi, photo order/orientation, crop, title art, overlay, styles, full/partial session saving, unique session folders, and reset.")
    }
}
