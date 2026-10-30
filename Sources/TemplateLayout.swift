import AppKit
import CryptoKit

struct TemplateLayout: Decodable {
    struct Photo: Decodable {
        let x: Double
        let y: Double
        let width: Double
        let height: Double
        var rect: NSRect { NSRect(x: x, y: y, width: width, height: height) }
    }
    let canvasWidth: Double
    let canvasHeight: Double
    let baseImage: String?
    let photos: [Photo]

    static func load(for overlayURL: URL) throws -> TemplateLayout? {
        let url = overlayURL.deletingPathExtension().appendingPathExtension("layout.json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            // Recognize this exact, unmodified artwork even when selected from Downloads
            // without its companion layout. Other overlays keep their own placement.
            let digest = SHA256.hash(data: try Data(contentsOf: overlayURL))
                .map { String(format: "%02x", $0) }.joined()
            guard digest == "e2bc1a78251325654f58fce2a5804db738a317edccd781653bf4c3e0e4669188" else { return nil }
            return TemplateLayout(canvasWidth: 1800, canvasHeight: 1200, baseImage: nil, photos: [
                Photo(x: 121.875, y: 101.953125, width: 764.0625, height: 440.625),
                Photo(x: 921.09375, y: 101.953125, width: 721.875, height: 440.625),
                // Bottom-left opening: x 104...756, y 500...864 at 1536 × 1024.
                Photo(x: 121.875, y: 585.9375, width: 764.0625, height: 426.5625)
            ])
        }
        let layout = try JSONDecoder().decode(TemplateLayout.self, from: Data(contentsOf: url))
        guard layout.canvasWidth == 1800, layout.canvasHeight == 1200, layout.photos.count == 3,
              layout.photos.allSatisfy({ p in
                  [p.x, p.y, p.width, p.height].allSatisfy(\.isFinite) &&
                  p.x >= 0 && p.y >= 0 && p.width >= 20 && p.height >= 20 &&
                  p.x + p.width <= 1800 && p.y + p.height <= 1200
              }) else { throw BoothError.message("This template's photo placement file is invalid.") }
        if let name = layout.baseImage, name != URL(fileURLWithPath: name).lastPathComponent {
            throw BoothError.message("The template background must be in the same folder as its overlay.")
        }
        return layout
    }

    func background(nextTo overlayURL: URL) throws -> NSImage? {
        guard let name = baseImage else { return nil }
        guard let image = NSImage(contentsOf: overlayURL.deletingLastPathComponent().appendingPathComponent(name)) else {
            throw BoothError.message("The template background is missing. Keep all template files together.")
        }
        return image
    }
}
