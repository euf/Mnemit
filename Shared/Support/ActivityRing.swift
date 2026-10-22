//  Ported from WolfActivityRing by Wolf McNally,
//  https://github.com/wolfmcnally/WolfActivityRing (Sources/WolfActivityRing/WolfActivityRing.swift).
//  The repository has no LICENSE file; the source file carries this notice, kept as it is:
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

import SwiftUI

/// An activity ring in the manner of the Fitness rings, as WolfActivityRing draws it: one
/// round-capped stroke trimmed to `progress` with a gradient from `color` at the top to `tipColor`
/// at the head, a dim track behind it, and from 95 % a tip that covers the start of the stroke
/// where the ring closes and overlaps itself, without a shadow, as Wolf's own Fitness rings. Past 1 the stroke stays a full circle and
/// the gradient keeps stretching, so the head is always the brightest. The ring fills the frame it
/// is given; the track is `tipColor` at 25 %, the rest of the drawing is Wolf's as written. The view is `Animatable`; the animation is the caller's.
struct ActivityRing: View, Animatable {
    /// 0 to 1 is the first lap; more is the laps after it.
    var progress: Double
    /// The start of the gradient, at the top.
    var color: Color
    /// The end of the gradient and the colour of the tip.
    var tipColor: Color
    var lineWidth: CGFloat

    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        GeometryReader { geometry in
            let radius = (min(geometry.size.width, geometry.size.height) - lineWidth) / 2
            ZStack {
                Circle()
                    .stroke(tipColor.opacity(0.25), lineWidth: lineWidth)
                    .frame(width: radius * 2)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(gradient: Gradient(colors: [color, tipColor]), center: .center, startAngle: .degrees(0), endAngle: .degrees(360 * progress)),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: radius * 2)
                RingCap(progress: progress, ringRadius: radius)
                    .fill(tipColor, strokeBorder: tipColor, lineWidth: 1)  // hides the seam
                    .frame(width: lineWidth, height: lineWidth)
                    .clipShape(RingClipShape(radius: radius, thickness: lineWidth))
                    .opacity(progress < 0.95 ? 0 : 1)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}

extension Shape {
    fileprivate func fill<Fill: ShapeStyle, Stroke: ShapeStyle>(_ fillStyle: Fill, strokeBorder strokeStyle: Stroke, lineWidth: CGFloat = 1) -> some View {
        self
            .stroke(strokeStyle, lineWidth: lineWidth)
            .background(self.fill(fillStyle))
    }
}

/// The ring itself, as the shadow is cut to it: the area between two circles.
private struct RingClipShape: Shape {
    let radius: Double
    let thickness: Double

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        path.addArc(center: center, radius: radius + thickness / 2, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: true)
        path.addArc(center: center, radius: radius - thickness / 2, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)
        return path
    }
}

/// The half disc at the head of the ring, the side the ring is going to. Its frame is the
/// stroke's width, centred on the ring's, so the path is placed at the head from there.
private struct RingCap: Shape {
    var progress: Double
    let ringRadius: Double

    func path(in rect: CGRect) -> Path {
        guard progress > 0 else { return Path() }
        var path = Path()
        let angle = Angle(degrees: 360 * progress - 90)
        let tipRadius = rect.width / 2
        let center = CGPoint(x: ringRadius * cos(angle.radians) + tipRadius, y: ringRadius * sin(angle.radians) + tipRadius)
        path.addArc(center: center, radius: tipRadius, startAngle: angle + .degrees(180), endAngle: angle, clockwise: true)
        path.closeSubpath()
        return path
    }
}
