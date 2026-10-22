/*
 Ported from MKRingProgressView by Max Konovalov,
 https://github.com/maxkonovalov/MKRingProgressView
 (MKRingProgressView/MKRingProgressLayer.swift, `drawContent(in:)`, and
 MKRingProgressView/MKGradientGenerator.swift), under its licence:

 The MIT License (MIT)

 Copyright (c) 2015 Max Konovalov

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

import CoreGraphics
import Foundation
import SwiftUI

/// An activity ring as MKRingProgressView draws the Fitness rings: a dim backdrop circle, past one
/// lap a solid arc in `color`, the end circle with its shadow clipped to the ring, and the arc with
/// the conic gradient from `color` to `tipColor` on top. `RingDrawing.draw` is MK's
/// `drawContent(in:)` line for line in a `Canvas`, so it works on iOS, macOS and in the widget. MK's
/// defaults except `hidesRingForZeroProgress` (on: an empty ring shows only the backdrop) and the
/// gradient image scale (the display's). `Animatable`: the caller animates.
struct ActivityRing: View, Animatable {
    /// 0 to 1 is the first lap; more is the laps after it.
    var progress: Double
    /// MK's `startColor`: the start of the ring and the solid laps under the head.
    var color: Color
    /// MK's `endColor`: the head.
    var tipColor: Color
    var lineWidth: CGFloat

    @Environment(\.displayScale) private var displayScale

    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        Canvas { context, size in
            let start = color.resolve(in: context.environment).cgColor
            let end = tipColor.resolve(in: context.environment).cgColor
            let progress = CGFloat(progress)
            let lineWidth = lineWidth
            let scale = displayScale
            context.withCGContext { cg in
                RingDrawing.draw(in: cg, bounds: CGRect(origin: .zero, size: size), progress: progress, startColor: start, endColor: end, ringWidth: lineWidth, gradientImageScale: scale)
            }
        }
    }
}

/// MK's `RingProgressLayer.drawContent(in:)`. `UIBezierPath(arcCenter:…, clockwise: true)` is
/// `CGMutablePath.addArc(…, clockwise: false)` in the y-down context both draw in.
enum RingDrawing {
    static let endShadowOpacity: CGFloat = 1.0
    static let hidesRingForZeroProgress = true

    static func draw(in context: CGContext, bounds: CGRect, progress: CGFloat, startColor: CGColor, endColor: CGColor, ringWidth: CGFloat, gradientImageScale: CGFloat) {
        context.setShouldAntialias(true)
        context.setAllowsAntialiasing(true)

        let useGradient = startColor != endColor

        let squareSize = min(bounds.width, bounds.height)
        let squareRect = CGRect(
            x: (bounds.width - squareSize) / 2,
            y: (bounds.height - squareSize) / 2,
            width: squareSize,
            height: squareSize
        )
        let gradientRect = squareRect.integral

        let w = min(ringWidth, squareSize / 2)
        let r = min(bounds.width, bounds.height) / 2 - w / 2
        let c = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
        let p = max(0.0, progress)
        let angleOffset = CGFloat.pi / 2
        let angle = 2 * .pi * p - angleOffset
        let minAngle = 1.1 * atan(0.5 * w / r)
        let maxAngle = 2 * .pi - 3 * minAngle - angleOffset

        let circleRect = squareRect.insetBy(dx: w / 2, dy: w / 2)
        let circlePath = CGPath(ellipseIn: circleRect, transform: nil)

        let angle1 = angle > maxAngle ? maxAngle : angle

        context.setLineWidth(w)
        context.setLineCap(.round)

        // Draw backdrop circle

        context.addPath(circlePath)
        let bgColor = startColor.copy(alpha: 0.15)!
        context.setStrokeColor(bgColor)
        context.strokePath()

        // Draw solid arc

        if angle > maxAngle {
            let offset = angle - maxAngle

            let arc2Path = CGMutablePath()
            arc2Path.addArc(center: c, radius: r, startAngle: -angleOffset, endAngle: offset, clockwise: false)
            context.addPath(arc2Path)
            context.setStrokeColor(startColor)
            context.strokePath()

            context.translateBy(x: circleRect.midX, y: circleRect.midY)
            context.rotate(by: offset)
            context.translateBy(x: -circleRect.midX, y: -circleRect.midY)
        }

        // Draw shadow and progress end

        if p > 0.0 || !hidesRingForZeroProgress {
            context.saveGState()

            if endShadowOpacity > 0.0 {
                context.addPath(
                    CGPath(
                        __byStroking: circlePath,
                        transform: nil,
                        lineWidth: w,
                        lineCap: .round,
                        lineJoin: .round,
                        miterLimit: 0
                    )!
                )
                context.clip()

                let shadowOffset = CGSize(
                    width: w / 10 * cos(angle + angleOffset),
                    height: w / 10 * sin(angle + angleOffset)
                )
                context.setShadow(
                    offset: shadowOffset,
                    blur: w / 3,
                    color: CGColor(gray: 0.0, alpha: endShadowOpacity)
                )
            }

            let arcEnd = CGPoint(x: c.x + r * cos(angle1), y: c.y + r * sin(angle1))

            let shadowPath = CGPath(
                ellipseIn: CGRect(x: arcEnd.x - w / 2, y: arcEnd.y - w / 2, width: w, height: w),
                transform: nil
            )

            let shadowFillColor: CGColor = {
                let fadeStartProgress: CGFloat = 0.02
                if !hidesRingForZeroProgress || p > fadeStartProgress {
                    return startColor
                }
                // gradually decrease shadow opacity
                return startColor.copy(alpha: p / fadeStartProgress)!
            }()
            context.addPath(shadowPath)
            context.setFillColor(shadowFillColor)
            context.fillPath()

            context.restoreGState()
        }

        // Draw gradient arc

        let gradient: CGImage? = {
            guard useGradient else {
                return nil
            }
            let s = Float(1.5 * w / (2 * .pi * r))
            return GradientGenerator.image(
                scale: gradientImageScale,
                size: gradientRect.size,
                colors: [endColor, endColor, startColor, startColor],
                locations: [0.0, s, 1.0 - s, 1.0],
                endPoint: CGPoint(x: 0.5 - CGFloat(2 * s), y: 1.0)
            )
        }()

        if p > 0.0 {
            let arc1Path = CGMutablePath()
            arc1Path.addArc(center: c, radius: r, startAngle: -angleOffset, endAngle: angle1, clockwise: false)
            if let gradient {
                context.saveGState()

                context.addPath(
                    CGPath(
                        __byStroking: arc1Path,
                        transform: nil,
                        lineWidth: w,
                        lineCap: .round,
                        lineJoin: .round,
                        miterLimit: 0
                    )!
                )
                context.clip()

                context.interpolationQuality = .none
                context.draw(gradient, in: gradientRect)

                context.restoreGState()
            } else {
                context.setStrokeColor(startColor)
                context.setLineWidth(w)
                context.setLineCap(.round)
                context.addPath(arc1Path)
                context.strokePath()
            }
        }
    }
}

/// MK's `GradientGenerator`: a conic gradient rendered pixel by pixel. The image depends on the size
/// and colours, not on the progress, so the last few are kept while a ring animates: the study screen's
/// small ring and the big one of its rest alternate, and each costs the main thread a moment to make.
enum GradientGenerator {
    private struct Key: Equatable {
        var scale: CGFloat
        var size: CGSize
        var colors: [CGColor]
        var locations: [Float]
        var endPoint: CGPoint
    }

    /// The images made last, the newest at the end; a handful of ring sizes are on screen in a session.
    nonisolated(unsafe) private static var cached: [(Key, CGImage)] = []
    private static let cacheSize = 4
    private static let lock = NSLock()

    static func image(scale: CGFloat, size: CGSize, colors: [CGColor], locations: [Float], startPoint: CGPoint = CGPoint(x: 0.5, y: 0.5), endPoint: CGPoint) -> CGImage? {
        let key = Key(scale: scale, size: size, colors: colors, locations: locations, endPoint: endPoint)
        lock.lock()
        defer { lock.unlock() }
        if let hit = cached.first(where: { $0.0 == key }) {
            return hit.1
        }

        let w = Int(size.width * scale)
        let h = Int(size.height * scale)

        guard w > 0, h > 0 else {
            return nil
        }

        let bitsPerComponent: Int = MemoryLayout<UInt8>.size * 8
        let bytesPerPixel: Int = bitsPerComponent * 4 / 8

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)

        var data = [ARGB]()
        data.reserveCapacity(w * h)
        // Converted once: a conversion per pixel took a second at the size of a big ring.
        let converted = colors.map(ARGB.init)

        for y in 0..<h {
            for x in 0..<w {
                let c = pixelDataForGradient(
                    at: CGPoint(x: x, y: y),
                    size: CGSize(width: w, height: h),
                    colors: converted,
                    locations: locations,
                    startPoint: startPoint,
                    endPoint: endPoint
                )
                data.append(c)
            }
        }

        let image: CGImage? = data.withUnsafeMutableBytes { buffer -> CGImage? in
            guard
                let ctx = CGContext(
                    data: buffer.baseAddress,
                    width: w,
                    height: h,
                    bitsPerComponent: bitsPerComponent,
                    bytesPerRow: w * bytesPerPixel,
                    space: colorSpace,
                    bitmapInfo: bitmapInfo.rawValue
                )
            else {
                return nil
            }
            ctx.interpolationQuality = .none
            ctx.setShouldAntialias(false)

            return ctx.makeImage()
        }

        if let image {
            cached.append((key, image))
            if cached.count > cacheSize { cached.removeFirst() }
        }
        return image
    }

    private static func pixelDataForGradient(at point: CGPoint, size: CGSize, colors: [ARGB], locations: [Float], startPoint: CGPoint, endPoint: CGPoint) -> ARGB {
        let t = conicalGradientStop(point, size, startPoint, endPoint)
        return interpolatedColor(t, colors, locations)
    }

    private static func conicalGradientStop(_ point: CGPoint, _ size: CGSize, _ g0: CGPoint, _ g1: CGPoint) -> Float {
        let c = CGPoint(x: size.width * g0.x, y: size.height * g0.y)
        let s = CGPoint(x: size.width * (g1.x - g0.x), y: size.height * (g1.y - g0.y))
        let q = atan2(s.y, s.x)
        let p = CGPoint(x: point.x - c.x, y: point.y - c.y)
        var a = atan2(p.y, p.x) - q
        if a < 0 {
            a += 2 * .pi
        }
        let t = a / (2 * .pi)
        return Float(t)
    }

    private static func interpolatedColor(_ t: Float, _ colors: [ARGB], _ locations: [Float]) -> ARGB {
        assert(!colors.isEmpty)
        assert(colors.count == locations.count)

        var p0: Float = 0
        var p1: Float = 1

        var c0 = colors.first!
        var c1 = colors.last!

        for (i, v) in locations.enumerated() {
            if v > p0, t >= v {
                p0 = v
                c0 = colors[i]
            }
            if v < p1, t <= v {
                p1 = v
                c1 = colors[i]
            }
        }

        let p: Float
        if p0 == p1 {
            p = 0
        } else {
            p = lerp(t, inRange: p0...p1, outRange: 0...1)
        }

        return c0.interpolateTo(c1, p)
    }
}

// MARK: - Color Data

private struct ARGB {
    var a: UInt8 = 0xFF
    var r: UInt8
    var g: UInt8
    var b: UInt8
}

extension ARGB {
    /// MK reads the components as they are; the resolved SwiftUI colours are extended sRGB, so
    /// they are converted to device RGB first.
    init(_ color: CGColor) {
        let rgb = color.converted(to: CGColorSpaceCreateDeviceRGB(), intent: .defaultIntent, options: nil) ?? color
        let c = rgb.components!.map { min(max($0, 0.0), 1.0) }
        switch rgb.numberOfComponents {
        case 2:
            self.init(r: UInt8(c[0] * 0xFF), g: UInt8(c[0] * 0xFF), b: UInt8(c[0] * 0xFF))
        case 4:
            self.init(r: UInt8(c[0] * 0xFF), g: UInt8(c[1] * 0xFF), b: UInt8(c[2] * 0xFF))
        default:
            self.init(r: 0, g: 0, b: 0)
        }
    }

    func interpolateTo(_ color: ARGB, _ t: Float) -> ARGB {
        let r = lerp(t, self.r, color.r)
        let g = lerp(t, self.g, color.g)
        let b = lerp(t, self.b, color.b)
        return ARGB(r: r, g: g, b: b)
    }
}

// MARK: - Utility

private func lerp(_ t: Float, _ a: UInt8, _ b: UInt8) -> UInt8 {
    UInt8(Float(a) + min(max(t, 0), 1) * (Float(b) - Float(a)))
}

private func lerp(_ value: Float, inRange: ClosedRange<Float>, outRange: ClosedRange<Float>) -> Float {
    (value - inRange.lowerBound) * (outRange.upperBound - outRange.lowerBound) / (inRange.upperBound - inRange.lowerBound) + outRange.lowerBound
}
