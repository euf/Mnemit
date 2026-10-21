// Renders the app icons into the asset catalogs of the Mac app and the iPhone app.
// Usage (from the repository root):
//   swift Tools/make-app-icon.swift [--concept A|B|C|D] [--preview <file.png>]
//   swift Tools/make-app-icon.swift --sheet <file.png>
//
// Without `--concept` the current icon is written: a flashcard carrying a lowercase Greek mu with a
// second card behind it, on the greens of the grade ramp in Shared/Support/Presentation.swift.
// `--concept` writes one of the four alternatives instead, `--sheet` renders all four side by
// side (Mac 1024, 64, 16, iPhone light and dark) and leaves the asset catalogs alone. The iPhone
// gets a dark variant of every concept; tinted falls back to the system's automatic rendering.
//
//   A  Flip loop      a flashcard mid-flip inside a circular arrow (the review cycle), indigo
//   B  M of cards     two cards leaning into each other, their outline reads as an M, warm clay
//   C  Steps          cards rising as a staircase, each one brighter (growing intervals), sand
//   D  Recall ripple  a card with arcs radiating from one corner (a memory echo), coral

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
    var shadow: UInt32 = 0x000000
    /// The colours of the mark, in the order the drawing function of the concept documents.
    var inks: [UInt32]
}

enum Concept: String, CaseIterable {
    case current
    case a = "A"
    case b = "B"
    case c = "C"
    case d = "D"

    var title: String {
        switch self {
        case .current: "Current"
        case .a: "Flip loop"
        case .b: "M of cards"
        case .c: "Steps"
        case .d: "Recall ripple"
        }
    }

    func theme(dark: Bool) -> Theme {
        switch (self, dark) {
        // inks: back card, front card, mu. Easy's deep green (0x09471F) as tile and mark.
        case (.current, false):
            Theme(top: 0x14702F, bottom: 0x09471F, shadow: 0x01190A, inks: [0xBFDCC6, 0xF8F6EE, 0x09471F])
        case (.current, true):
            Theme(top: 0x0B2C16, bottom: 0x03120A, inks: [0x2C6B40, 0x16422A, 0x93E8A5])
        // inks: card, arrows.
        case (.a, false):
            Theme(top: 0x6657DC, bottom: 0x3F2FA6, inks: [0xF7F5FF, 0xCFC8FF])
        case (.a, true):
            Theme(top: 0x211A57, bottom: 0x110C33, inks: [0xE2DEF5, 0x8E85E6])
        // inks: left card, right card.
        case (.b, false):
            Theme(top: 0xCB7250, bottom: 0xAB5233, inks: [0xF3E6D3, 0xFCF3E6])
        case (.b, true):
            Theme(top: 0x5E2E1F, bottom: 0x3A1B11, inks: [0xCDB69C, 0xE9D8C0])
        // inks: the cards from lowest to highest.
        case (.c, false):
            Theme(top: 0xDCA444, bottom: 0xC08728, inks: [0x6E4410, 0x95601A, 0xF1D698, 0xFFF6E0])
        case (.c, true):
            Theme(top: 0x45310F, bottom: 0x271A07, inks: [0x7A5518, 0xA37424, 0xDDB25E, 0xFFE9B8])
        // inks: card, the three arcs from the card outwards.
        case (.d, false):
            Theme(top: 0xF47A55, bottom: 0xD94A2D, inks: [0xFFF5EC, 0xFFE3D6, 0xFFC3AE, 0xFFA48C])
        case (.d, true):
            Theme(top: 0x4D1B14, bottom: 0x2C0E0A, inks: [0xF1DED3, 0xFF9C80, 0xCF6A52, 0x9B4636])
        }
    }
}

func roundedRect(_ rect: CGRect, _ radius: CGFloat, _ transform: CGAffineTransform = .identity) -> CGPath {
    var transform = transform
    return CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: &transform)
}

/// A polygon with rounded corners.
func roundedPolygon(_ points: [CGPoint], radius: CGFloat) -> CGPath {
    let path = CGMutablePath()
    let last = points[points.count - 1]
    path.move(to: CGPoint(x: (points[0].x + last.x) / 2, y: (points[0].y + last.y) / 2))
    for index in points.indices {
        path.addArc(tangent1End: points[index], tangent2End: points[(index + 1) % points.count], radius: radius)
    }
    path.closeSubpath()
    return path
}

func fill(_ context: CGContext, _ path: CGPath, _ hex: UInt32, alpha: CGFloat = 1) {
    context.addPath(path)
    context.setFillColor(color(hex, alpha: alpha))
    context.fillPath()
}

/// Concept A. inks: card, arrows. A card caught in a flip, the place it left as a pale ghost
/// behind it, inside two arrows that chase each other round it.
func drawFlipLoop(_ context: CGContext, theme: Theme, coarse: Bool) {
    let center = CGPoint(x: 512, y: 512)
    let radius: CGFloat = coarse ? 268 : 292
    let width: CGFloat = coarse ? 80 : 54
    let head: CGFloat = coarse ? 80 : 56

    // Arrow: an arc turning clockwise from `from` down to `to` (degrees), head at `to`.
    func arrow(from: CGFloat, to: CGFloat) {
        let a0 = from * .pi / 180
        let a1 = to * .pi / 180
        let arc = CGMutablePath()
        arc.addArc(center: center, radius: radius, startAngle: a0, endAngle: a1, clockwise: true)
        context.addPath(arc.copy(strokingWithWidth: width, lineCap: .butt, lineJoin: .miter, miterLimit: 10))
        context.setFillColor(color(theme.inks[1]))
        context.fillPath()
        // Head: tip ahead of the arc end along the tangent (clockwise: direction (sin, -cos)).
        let tip = CGPoint(
            x: center.x + radius * cos(a1) + head * 1.15 * sin(a1),
            y: center.y + radius * sin(a1) - head * 1.15 * cos(a1))
        let outer = CGPoint(x: center.x + (radius + head) * cos(a1), y: center.y + (radius + head) * sin(a1))
        let inner = CGPoint(x: center.x + (radius - head) * cos(a1), y: center.y + (radius - head) * sin(a1))
        let triangle = CGMutablePath()
        triangle.addLines(between: [outer, tip, inner])
        triangle.closeSubpath()
        fill(context, triangle, theme.inks[1])
    }
    arrow(from: 158, to: 28)
    arrow(from: 338, to: 208)

    // Ghost of the card before the flip (too small to matter in the coarse icon), then the
    // card turned away from us.
    if !coarse {
        fill(context, roundedRect(CGRect(x: 512 - 188, y: 512 - 138, width: 376, height: 276), 40), 0xFFFFFF, alpha: 0.2)
    }
    let near: CGFloat = coarse ? 178 : 188
    let far: CGFloat = coarse ? 140 : 142
    let flipped = roundedPolygon(
        [
            CGPoint(x: 512 - 112, y: 512 + far), CGPoint(x: 512 + 116, y: 512 + near),
            CGPoint(x: 512 + 116, y: 512 - near), CGPoint(x: 512 - 112, y: 512 - far),
        ], radius: 34)
    fill(context, flipped, theme.inks[0])
}

/// Concept B. inks: left card, right card. Two cards leaning into each other, each with its top
/// cut on a slope that falls to the middle: peaks at the outer corners, a deep notch and a slit
/// between the cards read as an M. (Plain rotated cards read as a tent, not as an M.)
func drawCardsM(_ context: CGContext, theme: Theme) {
    let half: CGFloat = 300
    let height: CGFloat = 540
    let notch: CGFloat = 0.58 * height
    let gap: CGFloat = 28
    for (mirror, ink) in [(false, theme.inks[0]), (true, theme.inks[1])] {
        let side: CGFloat = mirror ? -1 : 1
        // Counter-clockwise from the outer top corner of the left card, mirrored for the right one.
        let corners = [
            CGPoint(x: -half, y: height / 2), CGPoint(x: -half, y: -height / 2),
            CGPoint(x: -gap / 2, y: -height / 2), CGPoint(x: -gap / 2, y: height / 2 - notch),
        ]
        fill(context, roundedPolygon(corners.map { CGPoint(x: 512 + side * $0.x, y: 512 + $0.y) }, radius: 40), ink)
    }
}

/// Concept C. inks: the four cards from the lowest to the highest. Each card sits a step higher
/// than the last and in front of it, and is a little brighter: growing intervals as a staircase.
/// The coarse icon keeps three of them, larger.
func drawSteps(_ context: CGContext, theme: Theme, coarse: Bool) {
    let size = coarse ? CGSize(width: 270, height: 310) : CGSize(width: 220, height: 270)
    let step = coarse ? CGPoint(x: 185, y: 155) : CGPoint(x: 155, y: 125)
    let inks = coarse ? [theme.inks[0], theme.inks[2], theme.inks[3]] : theme.inks
    let count = inks.count
    let origin = CGPoint(
        x: 512 - (CGFloat(count - 1) * step.x + size.width) / 2,
        y: 512 - (CGFloat(count - 1) * step.y + size.height) / 2)
    for (index, ink) in inks.enumerated() {
        let rect = CGRect(x: origin.x + CGFloat(index) * step.x, y: origin.y + CGFloat(index) * step.y, width: size.width, height: size.height)
        fill(context, roundedRect(rect, 40), ink)
    }
}

/// Concept D. inks: card, then the three arcs from the card outwards. Arcs fading away from the
/// upper right corner of a card, like the echo of something just remembered. The coarse icon
/// has two thicker arcs of one colour.
func drawRipple(_ context: CGContext, theme: Theme, coarse: Bool) {
    let corner = CGPoint(x: 524, y: 500)
    let cardRect = CGRect(x: corner.x - 370, y: corner.y - 296, width: 370, height: 296)
    fill(context, roundedRect(cardRect, 40), theme.inks[0])
    context.setLineCap(.round)
    context.setLineWidth(coarse ? 76 : 48)
    let radii: [CGFloat] = coarse ? [140, 290] : [118, 210, 302]
    for (index, radius) in radii.enumerated() {
        context.addArc(center: corner, radius: radius, startAngle: 0, endAngle: .pi / 2, clockwise: false)
        context.setStrokeColor(color(theme.inks[coarse ? 1 : index + 1]))
        context.strokePath()
    }
}

/// The current icon: a flashcard carrying a lowercase Greek mu (the start of memory in Greek),
/// a second card behind it for the two directions of study.
func drawCurrent(_ context: CGContext, theme: Theme) {
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
    card(rotation: 10, offset: CGPoint(x: 18, y: 34), fill: theme.inks[0])
    card(rotation: frontRotation, offset: frontOffset, fill: theme.inks[1])

    // The mu, centred on the front card by the bounds of its outline.
    context.saveGState()
    context.translateBy(x: 512 + frontOffset.x, y: 512 + frontOffset.y)
    context.rotate(by: frontRotation * .pi / 180)
    let base = NSFont.systemFont(ofSize: 450, weight: .heavy)
    let font = base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: 450) } ?? base
    let line = CTLineCreateWithAttributedString(
        NSAttributedString(
            string: "μ", attributes: [.font: font, .foregroundColor: NSColor(cgColor: color(theme.inks[2]))!]))
    let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
    context.textPosition = CGPoint(x: -bounds.midX, y: -bounds.midY)
    CTLineDraw(line, context)
    context.restoreGState()
}

/// Draws the icon on a 1024 × 1024 canvas (origin bottom left). With `fullBleed`, the
/// tile fills the canvas without rounded corners and shadow: iOS rounds them itself. `coarse`
/// asks the concepts that have fine detail for a bolder version, for tiles under 40 pixels.
func drawIcon(in context: CGContext, fullBleed: Bool, concept: Concept, dark: Bool, coarse: Bool = false) {
    let theme = concept.theme(dark: dark)
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

    switch concept {
    case .current: drawCurrent(context, theme: theme)
    case .a: drawFlipLoop(context, theme: theme, coarse: coarse)
    case .b: drawCardsM(context, theme: theme)
    case .c: drawSteps(context, theme: theme, coarse: coarse)
    case .d: drawRipple(context, theme: theme, coarse: coarse)
    }
}

/// Renders the icon. The full-bleed icon has no alpha channel, as the App Store requires
/// for iOS.
func render(pixels: Int, fullBleed: Bool = false, dark: Bool = false, concept: Concept = .current) -> CGImage {
    let context = CGContext(
        data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: (fullBleed ? CGImageAlphaInfo.noneSkipLast : .premultipliedLast).rawValue
    )!
    context.interpolationQuality = .high
    context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    let tilePixels = fullBleed ? pixels : pixels * 824 / 1024
    drawIcon(in: context, fullBleed: fullBleed, concept: concept, dark: dark, coarse: tilePixels < 40)
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
func writePreview(to url: URL, concept: Concept) throws {
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
    place(render(pixels: 1024, concept: concept), x: x, y: gap)
    x += 1024 + gap
    place(render(pixels: 128, concept: concept), x: x, y: gap)
    x += 128 + gap
    place(render(pixels: 32, concept: concept), x: x, y: gap)
    place(render(pixels: 32, concept: concept), x: x, y: gap + 32 + gap, magnify: 4)
    x += 128 + gap
    place(render(pixels: 16, concept: concept), x: x, y: gap)
    place(render(pixels: 16, concept: concept), x: x, y: gap + 16 + gap, magnify: 8)

    let secondRow = 1024 + 2 * gap
    place(render(pixels: 1024, fullBleed: true, concept: concept), x: gap, y: secondRow, mask: true)
    place(render(pixels: 180, fullBleed: true, concept: concept), x: 1024 + 2 * gap, y: secondRow, mask: true)
    place(render(pixels: 1024, fullBleed: true, dark: true, concept: concept), x: 1024 + 180 + 3 * gap, y: secondRow, mask: true)
    place(render(pixels: 180, fullBleed: true, dark: true, concept: concept), x: 2 * 1024 + 180 + 4 * gap, y: secondRow, mask: true)
    try png(sheet.makeImage()!).write(to: url)
    print("Wrote preview to \(url.path)")
}

/// One row per concept A–D to choose from: Mac 1024 scaled down, Mac 64, 16 and 16 magnified
/// ×6 without smoothing, iPhone light and dark at 180 px, masked like iOS does.
func writeSheet(to url: URL) throws {
    let gap = 40
    let rows = Concept.allCases.filter { $0 != .current }
    let rowHeight = 300 + gap + 28
    let columns = [
        ("Mac 1024", 300), ("Mac 64", 64), ("Mac 16", 16), ("16 ×6", 96), ("iPhone light", 180), ("iPhone dark", 180),
    ]
    let width = gap + columns.map { $0.1 + gap }.reduce(0, +)
    let height = gap + 30 + rows.count * rowHeight
    let sheet = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    sheet.setFillColor(color(0xEDEDED))
    sheet.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let darkX = gap + columns.dropLast().map { $0.1 + gap }.reduce(0, +)
    sheet.setFillColor(color(0x101010))
    sheet.fill(CGRect(x: darkX - gap / 2, y: 0, width: width, height: height))

    func text(_ string: String, x: Int, y: Int, size: CGFloat, weight: NSFont.Weight = .regular, hex: UInt32 = 0x444444) {
        let line = CTLineCreateWithAttributedString(
            NSAttributedString(
                string: string,
                attributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: NSColor(cgColor: color(hex))!]))
        sheet.textPosition = CGPoint(x: x, y: height - y)
        CTLineDraw(line, sheet)
    }
    func place(_ image: CGImage, x: Int, y: Int, side: Int, magnify: Int = 1, mask: Bool = false) {
        let side = side * magnify
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
    for (title, side) in columns {
        text(title, x: x, y: gap, size: 14, hex: x >= darkX ? 0xBBBBBB : 0x444444)
        x += side + gap
    }
    for (index, concept) in rows.enumerated() {
        let top = gap + 30 + index * rowHeight
        text("\(concept.rawValue) · \(concept.title)", x: gap, y: top + 20, size: 22, weight: .semibold, hex: 0x222222)
        let y = top + 28
        var x = gap
        place(render(pixels: 1024, concept: concept), x: x, y: y, side: 300)
        x += 300 + gap
        place(render(pixels: 64, concept: concept), x: x, y: y + (300 - 64) / 2, side: 64)
        x += 64 + gap
        place(render(pixels: 16, concept: concept), x: x, y: y + (300 - 16) / 2, side: 16)
        x += 16 + gap
        place(render(pixels: 16, concept: concept), x: x, y: y + (300 - 96) / 2, side: 16, magnify: 6)
        x += 96 + gap
        place(render(pixels: 180, fullBleed: true, concept: concept), x: x, y: y + (300 - 180) / 2, side: 180, mask: true)
        x += 180 + gap
        place(render(pixels: 180, fullBleed: true, dark: true, concept: concept), x: x, y: y + (300 - 180) / 2, side: 180, mask: true)
    }
    try png(sheet.makeImage()!).write(to: url)
    print("Wrote sheet to \(url.path)")
}

let arguments = CommandLine.arguments
func value(of flag: String) -> String? {
    guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
    return arguments[index + 1]
}

if let sheet = value(of: "--sheet") {
    try writeSheet(to: URL(fileURLWithPath: sheet))
    exit(0)
}

var concept = Concept.current
if let name = value(of: "--concept") {
    guard let chosen = Concept(rawValue: name.uppercased()), chosen != .current else {
        print("Unknown concept \(name); choose A, B, C or D")
        exit(1)
    }
    concept = chosen
}

var macImages: [[String: Any]] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        try png(render(pixels: points * scale, concept: concept)).write(to: macDirectory.appendingPathComponent(name))
        macImages.append(["idiom": "mac", "scale": "\(scale)x", "size": "\(points)x\(points)", "filename": name])
    }
}
try writeContents(macImages, to: macDirectory)

// iOS takes a single image per appearance and scales it to every size.
let iOSName = "icon_1024x1024.png"
let iOSDarkName = "icon_1024x1024_dark.png"
try png(render(pixels: 1024, fullBleed: true, concept: concept)).write(to: iOSDirectory.appendingPathComponent(iOSName))
try png(render(pixels: 1024, fullBleed: true, dark: true, concept: concept)).write(to: iOSDirectory.appendingPathComponent(iOSDarkName))
try writeContents(
    [
        ["idiom": "universal", "platform": "ios", "size": "1024x1024", "filename": iOSName],
        [
            "appearances": [["appearance": "luminosity", "value": "dark"]],
            "idiom": "universal", "platform": "ios", "size": "1024x1024", "filename": iOSDarkName,
        ],
    ], to: iOSDirectory)

if let preview = value(of: "--preview") {
    try writePreview(to: URL(fileURLWithPath: preview), concept: concept)
}
