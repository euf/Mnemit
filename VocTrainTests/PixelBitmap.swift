import UIKit

/// A picture as rows of pixels, to measure what a screen shows: where an edge lies, how far
/// two things are apart. Sizes and positions are in points (`scale` pixels to the point), rows
/// counted from the top.
struct PixelBitmap {
    let width: Int
    let height: Int
    let scale: CGFloat
    private let bytes: [UInt8]

    /// The picture has no pixels: a renderer under load sometimes gives an image without a backing store.
    struct Empty: Error {}

    init(_ image: UIImage) throws {
        // Under a loaded simulator the image may lack its bitmap; a test then fails instead of crashing its host.
        guard let cgImage = image.cgImage else { throw Empty() }
        let (w, h) = (cgImage.width, cgImage.height)
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        bytes.withUnsafeMutableBytes { buffer in
            let context = CGContext(
                data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        (width, height, scale, self.bytes) = (w, h, image.scale, bytes)
    }

    /// The pixel as red, green and blue, 0 to 255.
    func rgb(_ x: Int, _ y: Int) -> (r: Int, g: Int, b: Int) {
        let i = (y * width + x) * 4
        return (Int(bytes[i]), Int(bytes[i + 1]), Int(bytes[i + 2]))
    }

    /// 0 for black to 1 for white.
    func luminance(_ x: Int, _ y: Int) -> Double {
        let (r, g, b) = rgb(x, y)
        return (0.2126 * Double(r) + 0.7152 * Double(g) + 0.0722 * Double(b)) / 255
    }

    /// Whether two pixels differ by more than `tolerance` in any channel.
    func differs(_ x: Int, _ y: Int, from other: PixelBitmap, tolerance: Int = 2) -> Bool {
        let (a, b) = (rgb(x, y), other.rgb(x, y))
        return abs(a.r - b.r) > tolerance || abs(a.g - b.g) > tolerance || abs(a.b - b.b) > tolerance
    }

    func points(_ pixels: Int) -> Double { Double(pixels) / Double(scale) }

    /// The rows, from `from` on, where the colour of the pixel in column `x` first becomes
    /// different from the one in its row `from`, by more than `tolerance`: the top edge of
    /// whatever begins under that row. Nil if nothing begins.
    func firstChange(inColumn x: Int, from: Int, tolerance: Int = 6) -> Int? {
        let base = rgb(x, from)
        for y in from..<height {
            let c = rgb(x, y)
            if abs(c.r - base.r) > tolerance || abs(c.g - base.g) > tolerance || abs(c.b - base.b) > tolerance { return y }
        }
        return nil
    }

    /// The runs of rows, from `from` to `to`, in which some pixel of column `x` is one for which
    /// `isInk` holds, as a list of (first row, last row).
    func runs(inColumn x: Int, rows: Range<Int>, where isInk: (Int, Int, Int) -> Bool) -> [ClosedRange<Int>] {
        var runs: [ClosedRange<Int>] = []
        var start: Int?
        for y in rows {
            let c = rgb(x, y)
            if isInk(c.r, c.g, c.b) {
                if start == nil { start = y }
            } else if let s = start {
                runs.append(s...(y - 1))
                start = nil
            }
        }
        if let s = start { runs.append(s...(rows.upperBound - 1)) }
        return runs
    }
}
