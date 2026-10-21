// Renders the app icons into the asset catalogs of the Mac app and the iPhone app.
// Usage: swift Tools/make-app-icon.swift [--preview <file.png>]   (from the repository root)
//
// Mnemit's icon: a flashcard carrying a lowercase Greek mu (μνήμη, memory) with a second
// card behind it (the two directions of study), on the greens of the grade ramp in
// Shared/Support/Presentation.swift. The iPhone gets a dark variant as well; tinted falls
// back to the system's automatic rendering.

import AppKit

let macDirectory = URL(fileURLWithPath: "MacVocTrainNg/Resources/Assets.xcassets/AppIcon.appiconset")
let iOSDirectory = URL(fileURLWithPath: "VocTrain/Resources/Assets.xcassets/AppIcon.appiconset")

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

struct Theme {
    var top: UInt32
    var bottom: UInt32
    var backCard: UInt32
    var frontCard: UInt32
    var mark: UInt32
    var shadow: UInt32

    /// Easy's deep green (0x09471F) as tile and mark, off-white cards.
    static let light = Theme(
        top: 0x14702F, bottom: 0x09471F, backCard: 0xBFDCC6, frontCard: 0xF8F6EE, mark: 0x09471F,
        shadow: 0x01190A)
    /// Dark appearance on iOS: the dark end of the ramp, a pale green mu.
    static let dark = Theme(
        top: 0x0B2C16, bottom: 0x03120A, backCard: 0x2C6B40, frontCard: 0x16422A, mark: 0x93E8A5,
        shadow: 0x000000)
}

/// Draws the icon on a 1024 × 1024 canvas (origin bottom left). With `fullBleed`, the
/// tile fills the canvas without rounded corners and shadow: iOS rounds them itself.
func drawIcon(in context: CGContext, fullBleed: Bool, theme: Theme) {
    // Tile: macOS icon grid, 824 pt rounded square centred on the canvas.
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath: CGPath
    if fullBleed {
        // Enlarges the tile to the canvas; everything on it is drawn as for macOS.
        context.scaleBy(x: 1024 / tile.width, y: 1024 / tile.height)
        context.translateBy(x: -tile.minX, y: -tile.minY)
        tilePath = CGPath(rect: tile, transform: nil)
    } else {
        tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x000000, alpha: 0.35))
        context.addPath(tilePath)
        context.setFillColor(color(theme.bottom))
        context.fillPath()
        context.restoreGState()
    }

    context.saveGState()
    context.addPath(tilePath)
    context.clip()
    let gradient = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
        colors: [color(theme.top), color(theme.bottom)] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    context.restoreGState()

    // A flashcard, drawn centred at the origin.
    func card(rotation: CGFloat, offset: CGPoint, fill: UInt32) {
        let size = CGSize(width: 570, height: 430)
        let rect = CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)
        context.saveGState()
        context.translateBy(x: 512 + offset.x, y: 512 + offset.y)
        context.rotate(by: rotation * .pi / 180)
        context.setShadow(offset: CGSize(width: 0, height: -12), blur: 26, color: color(theme.shadow, alpha: 0.38))
        context.addPath(CGPath(roundedRect: rect, cornerWidth: 42, cornerHeight: 42, transform: nil))
        context.setFillColor(color(fill))
        context.fillPath()
        context.restoreGState()
    }

    let frontRotation: CGFloat = -4
    let frontOffset = CGPoint(x: -24, y: -32)
    card(rotation: 10, offset: CGPoint(x: 18, y: 34), fill: theme.backCard)
    card(rotation: frontRotation, offset: frontOffset, fill: theme.frontCard)

    // The mu, centred on the front card by the bounds of its outline.
    context.saveGState()
    context.translateBy(x: 512 + frontOffset.x, y: 512 + frontOffset.y)
    context.rotate(by: frontRotation * .pi / 180)
    let base = NSFont.systemFont(ofSize: 450, weight: .heavy)
    let font = base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: 450) } ?? base
    let line = CTLineCreateWithAttributedString(
        NSAttributedString(
            string: "μ", attributes: [.font: font, .foregroundColor: NSColor(cgColor: color(theme.mark))!]))
    let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
    context.textPosition = CGPoint(x: -bounds.midX, y: -bounds.midY)
    CTLineDraw(line, context)
    context.restoreGState()
}

/// Renders the icon. The full-bleed icon has no alpha channel, as the App Store requires
/// for iOS.
func render(pixels: Int, fullBleed: Bool = false, theme: Theme = .light) -> CGImage {
    let context = CGContext(
        data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: (fullBleed ? CGImageAlphaInfo.noneSkipLast : .premultipliedLast).rawValue
    )!
    context.interpolationQuality = .high
    context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    drawIcon(in: context, fullBleed: fullBleed, theme: theme)
    return context.makeImage()!
}

func png(_ image: CGImage) -> Data {
    NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
}

func writeContents(_ images: [[String: Any]], to directory: URL) throws {
    let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
    let json = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    try json.write(to: directory.appendingPathComponent("Contents.json"))
    print("Wrote \(images.count) icon images to \(directory.path)")
}

/// A contact sheet for judging the sizes: Mac 1024, 128, 32, 16 (the last two also
/// magnified without smoothing) and iPhone 1024 and 60 pt @3x, light and dark, masked
/// like iOS does.
func writePreview(to url: URL) throws {
    let gap = 40
    let width = 2 * 1024 + 2 * 180 + 5 * gap
    let height = 2 * 1024 + 3 * gap
    let sheet = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    sheet.setFillColor(color(0xEDEDED))
    sheet.fill(CGRect(x: 0, y: 0, width: width, height: height))
    // Dark panel behind the dark iPhone icons.
    sheet.setFillColor(color(0x101010))
    sheet.fill(CGRect(x: 1024 + 180 + 3 * gap - gap / 2, y: 0, width: width, height: 1024 + gap + gap / 2))

    // Draws `image` with its top left corner at (x, y), measured from the top of the sheet.
    func place(_ image: CGImage, x: Int, y: Int, magnify: Int = 1, mask: Bool = false) {
        let side = image.width * magnify
        let rect = CGRect(x: x, y: height - y - side, width: side, height: side)
        sheet.saveGState()
        if mask {
            sheet.addPath(CGPath(roundedRect: rect, cornerWidth: rect.width * 0.2237, cornerHeight: rect.width * 0.2237, transform: nil))
            sheet.clip()
        }
        sheet.interpolationQuality = magnify > 1 ? .none : .high
        sheet.draw(image, in: rect)
        sheet.restoreGState()
    }

    var x = gap
    place(render(pixels: 1024), x: x, y: gap)
    x += 1024 + gap
    place(render(pixels: 128), x: x, y: gap)
    x += 128 + gap
    place(render(pixels: 32), x: x, y: gap)
    place(render(pixels: 32), x: x, y: gap + 32 + gap, magnify: 4)
    x += 128 + gap
    place(render(pixels: 16), x: x, y: gap)
    place(render(pixels: 16), x: x, y: gap + 16 + gap, magnify: 8)

    let secondRow = 1024 + 2 * gap
    place(render(pixels: 1024, fullBleed: true), x: gap, y: secondRow, mask: true)
    place(render(pixels: 180, fullBleed: true), x: 1024 + 2 * gap, y: secondRow, mask: true)
    place(render(pixels: 1024, fullBleed: true, theme: .dark), x: 1024 + 180 + 3 * gap, y: secondRow, mask: true)
    place(render(pixels: 180, fullBleed: true, theme: .dark), x: 2 * 1024 + 180 + 4 * gap, y: secondRow, mask: true)
    try png(sheet.makeImage()!).write(to: url)
    print("Wrote preview to \(url.path)")
}

var macImages: [[String: Any]] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        try png(render(pixels: points * scale)).write(to: macDirectory.appendingPathComponent(name))
        macImages.append(["idiom": "mac", "scale": "\(scale)x", "size": "\(points)x\(points)", "filename": name])
    }
}
try writeContents(macImages, to: macDirectory)

// iOS takes a single image per appearance and scales it to every size.
let iOSName = "icon_1024x1024.png"
let iOSDarkName = "icon_1024x1024_dark.png"
try png(render(pixels: 1024, fullBleed: true)).write(to: iOSDirectory.appendingPathComponent(iOSName))
try png(render(pixels: 1024, fullBleed: true, theme: .dark)).write(to: iOSDirectory.appendingPathComponent(iOSDarkName))
try writeContents(
    [
        ["idiom": "universal", "platform": "ios", "size": "1024x1024", "filename": iOSName],
        [
            "appearances": [["appearance": "luminosity", "value": "dark"]],
            "idiom": "universal", "platform": "ios", "size": "1024x1024", "filename": iOSDarkName,
        ],
    ], to: iOSDirectory)

if let flag = CommandLine.arguments.firstIndex(of: "--preview"), flag + 1 < CommandLine.arguments.count {
    try writePreview(to: URL(fileURLWithPath: CommandLine.arguments[flag + 1]))
}
