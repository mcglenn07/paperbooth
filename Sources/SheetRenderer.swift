import AppKit
import ImageIO
import UniformTypeIdentifiers

struct SheetStyle {
    var title = "A NIGHT TO\nREMEMBER"
    var subtitle = "GOOD PEOPLE. GREAT MEMORIES."
    var theme = "Midnight"
    var background: NSImage?
    var titleArtwork: NSImage?
    var overlay: NSImage?
    var photoRects: [NSRect]?
}

enum SheetRenderer {
    static let size = NSSize(width: 1800, height: 1200)
    // Coordinates are measured from the top left, as in most design tools.
    static let cells = [
        NSRect(x: 80, y: 80, width: 800, height: 500),
        NSRect(x: 920, y: 80, width: 800, height: 500),
        NSRect(x: 80, y: 620, width: 800, height: 500),
        NSRect(x: 920, y: 620, width: 800, height: 500)
    ]

    static func render(photos: [NSImage], style: SheetStyle) -> NSImage {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1800, pixelsHigh: 1200,
                                      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                      isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        bitmap.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let context = NSGraphicsContext.current!.cgContext
        context.translateBy(x: 0, y: 1200)
        context.scaleBy(x: 1, y: -1)
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        draw(photos: photos, style: style)
        NSGraphicsContext.restoreGraphicsState()
        let result = NSImage(size: size)
        result.addRepresentation(bitmap)
        return result
    }

    private static func draw(photos: [NSImage], style: SheetStyle) {
        let warm = style.theme == "Warm paper"
        let base = warm ? NSColor(hex: 0xEDE5D5) : NSColor(hex: 0x142D32)
        let ink = NSColor(hex: 0x183137)
        let accent = warm ? NSColor(hex: 0xBD6241) : NSColor(hex: 0xD7EDAB)
        base.setFill()
        NSRect(origin: .zero, size: size).fill()
        if let background = style.background {
            fill(background, in: NSRect(origin: .zero, size: size))
        } else {
            // Original, quiet geometric artwork; no template assets are copied.
            accent.withAlphaComponent(0.18).setStroke()
            for i in 0..<6 {
                let inset = CGFloat(i * 30)
                let ring = NSBezierPath(ovalIn: NSRect(x: -240 + inset, y: 800 + inset,
                                                      width: 620 - inset * 2, height: 620 - inset * 2))
                ring.lineWidth = 2
                ring.stroke()
                let upper = NSBezierPath(ovalIn: NSRect(x: 1490 + inset, y: -250 + inset,
                                                       width: 580 - inset * 2, height: 580 - inset * 2))
                upper.lineWidth = 2
                upper.stroke()
            }
            for x in stride(from: 100, through: 1700, by: 80) {
                accent.withAlphaComponent(0.5).setFill()
                NSBezierPath(ovalIn: NSRect(x: x, y: 38, width: 4, height: 4)).fill()
                NSBezierPath(ovalIn: NSRect(x: x, y: 1158, width: 4, height: 4)).fill()
            }
        }
        for index in 0..<3 {
            let rect = style.photoRects?[index] ?? cells[index]
            if style.photoRects == nil {
                NSColor(hex: 0xF8F4EA).setFill()
                rect.insetBy(dx: -8, dy: -8).fill()
            }
            if photos.indices.contains(index) {
                fill(photos[index], in: rect)
            } else {
                NSColor(hex: 0xD7DEDA).setFill()
                rect.fill()
                text(String(format: "%02d", index + 1), in: rect.insetBy(dx: 40, dy: 155),
                     font: .systemFont(ofSize: 100, weight: .ultraLight), color: ink.withAlphaComponent(0.4))
                text("YOUR PHOTO HERE", in: NSRect(x: rect.minX, y: rect.minY + 315, width: rect.width, height: 40),
                     font: .systemFont(ofSize: 18, weight: .medium), color: ink.withAlphaComponent(0.6), tracking: 4)
            }
        }
        if style.photoRects == nil {
        let titleRect = cells[3]
        if let artwork = style.titleArtwork {
            fill(artwork, in: titleRect)
        } else {
            NSColor(hex: 0xF7F2E7).setFill()
            titleRect.fill()
            accent.setFill()
            NSRect(x: titleRect.minX + 56, y: titleRect.minY + 48, width: 64, height: 8).fill()
            text("THE PHOTO COLLECTION", in: NSRect(x: titleRect.minX + 56, y: titleRect.minY + 82, width: 688, height: 32),
                 font: .systemFont(ofSize: 17, weight: .semibold), color: ink.withAlphaComponent(0.65), tracking: 3, alignment: .left)
            let titleBox = NSRect(x: titleRect.minX + 54, y: titleRect.minY + 147, width: 692, height: 225)
            let title = style.title.isEmpty ? "YOUR EVENT" : style.title
            var fontSize: CGFloat = 72
            while fontSize > 24 {
                let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
                let bounds = (title as NSString).boundingRect(with: NSSize(width: titleBox.width, height: 1000),
                                                               options: [.usesLineFragmentOrigin, .usesFontLeading],
                                                               attributes: [.font: font])
                if bounds.height <= titleBox.height - 8 { break }
                fontSize -= 2
            }
            text(title, in: titleBox, font: .systemFont(ofSize: fontSize, weight: .bold), color: ink, alignment: .left)
            ink.withAlphaComponent(0.18).setFill()
            NSRect(x: titleRect.minX + 56, y: titleRect.maxY - 92, width: 688, height: 1).fill()
            text(style.subtitle, in: NSRect(x: titleRect.minX + 56, y: titleRect.maxY - 66, width: 688, height: 42),
                 font: .systemFont(ofSize: 19, weight: .medium), color: ink.withAlphaComponent(0.75), tracking: 1, alignment: .left)
        }
        }
        if let overlay = style.overlay {
            overlay.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .sourceOver,
                         fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
        }
    }

    static func fill(_ image: NSImage, in rect: NSRect) {
        let source = image.size
        guard source.width > 0 && source.height > 0 else { return }
        let ratio = max(rect.width / source.width, rect.height / source.height)
        let crop = NSRect(x: (source.width - rect.width / ratio) / 2,
                          y: (source.height - rect.height / ratio) / 2,
                          width: rect.width / ratio, height: rect.height / ratio)
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: rect).addClip()
        image.draw(in: rect, from: crop, operation: .sourceOver, fraction: 1,
                   respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func text(_ text: String, in rect: NSRect, font: NSFont, color: NSColor,
                             tracking: CGFloat = 0, alignment: NSTextAlignment = .center) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byWordWrapping
        (text as NSString).draw(in: rect, withAttributes: [.font: font, .foregroundColor: color,
                                                         .paragraphStyle: paragraph, .kern: tracking])
    }

    static func jpeg(_ image: NSImage, dpi: Int = 300) throws -> Data {
        var rect = NSRect(origin: .zero, size: image.size)
        guard let cgImage = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
            throw BoothError.message("The image could not be prepared for saving.")
        }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw BoothError.message("The JPEG file could not be created.")
        }
        CGImageDestinationAddImage(destination, cgImage, [kCGImageDestinationLossyCompressionQuality: 0.96,
                                                        kCGImagePropertyDPIWidth: dpi,
                                                        kCGImagePropertyDPIHeight: dpi] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw BoothError.message("The JPEG file could not be saved.") }
        return data as Data
    }
}

extension NSColor {
    convenience init(hex: Int) {
        self.init(srgbRed: CGFloat((hex >> 16) & 255) / 255,
                  green: CGFloat((hex >> 8) & 255) / 255,
                  blue: CGFloat(hex & 255) / 255, alpha: 1)
    }
}

enum BoothError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case let .message(message) = self { return message }; return nil }
}
