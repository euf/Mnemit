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

/// An activity ring in the manner of the Fitness rings: a gradient along a round-capped stroke
/// from `color` to `tipColor`, a dim track behind it, and, once `progress` passes 1, a tip with a
/// shadow where the ring overlaps itself. The ring fills the frame it is given.
///
/// From WolfActivityRing: the `trim` and `AngularGradient` stroke whose gradient ends at the
/// head, the half-disc tip that carries the shadow (`RingCap`) and the annulus that cuts the
/// shadow off at the edges of the stroke (`RingClipShape`). Left out: the options struct, the
/// outline, the content closure, the tip that shows from 95 %. Changed: past 1 the first lap is
/// a closed ring in `tipColor` and the gradient runs over the part of the next lap, so the head
/// matches the tip; the shadow is sized by the stroke and comes only past 100 %; the view is
/// `Animatable`, so the gradient, the tip and the lap move together; the animation is the
/// caller's (Reduce Motion).
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
            let angle = Angle.degrees(360 * progress).radians
            // The part of the lap the head is in: the gradient runs over it, from the top to the head. A
            // whole number of laps leaves the head at the top, which has no tip: it is a closed ring.
            let rest = progress.truncatingRemainder(dividingBy: 1)
            let lap = progress > 1 && rest > 0 ? rest : min(progress, 1)
            ZStack {
                Circle()
                    .stroke(tipColor.opacity(0.25), lineWidth: lineWidth)
                    .frame(width: radius * 2)
                if progress >= 1 {
                    // The first lap, closed, in the colour of the head: the lap on top of it starts light.
                    Circle()
                        .stroke(tipColor, lineWidth: lineWidth)
                        .frame(width: radius * 2)
                }
                if progress > 0 {
                    Circle()
                        .trim(from: 0, to: lap)
                        .stroke(
                            AngularGradient(gradient: Gradient(colors: [color, tipColor]), center: .center, startAngle: .zero, endAngle: .degrees(360 * lap)),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: radius * 2)
                }
                RingCap(progress: progress, ringRadius: radius)
                    .fill(tipColor, strokeBorder: tipColor, lineWidth: 1)  // hides the seam
                    .frame(width: lineWidth, height: lineWidth)
                    .shadow(color: .black.opacity(0.5), radius: lineWidth * 0.3, x: lineWidth * 0.2 * cos(angle), y: lineWidth * 0.2 * sin(angle))
                    .clipShape(RingClipShape(radius: radius, thickness: lineWidth))
                    .opacity(progress > 1 && rest > 0 ? 1 : 0)
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
