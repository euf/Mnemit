import SwiftUI

/// The celebration of a big moment: the ring swells from 1.0 to 1.12 and back, and a dozen small
/// specks of the accent fly out of it and fade, all in under a second. It marks the ring that arrives
/// at the rest of a round and the words-in-memory milestone, and nothing else.
///
/// Drawn by a `Canvas` in a `TimelineView`, so nothing is laid out while it runs. With Reduce Motion
/// the caller passes no start, and the content stands still.
enum RingBurstTiming {
    /// The specks fly and fade for this long, in seconds.
    static let duration = 0.8
    /// The swell is over after this long.
    static let swell = 0.4
    static let peakScale = 1.12
    static let speckCount = 12
}

/// One instant of the burst, `elapsed` seconds after it began: the content at its swelling and the
/// specks around it. A test draws a single instant; `RingBurst` draws the running ones.
struct RingBurstFrame<Content: View>: View {
    var elapsed: TimeInterval
    /// The diameter of the content: the specks leave from its edge and reach a third to two thirds of it further.
    var diameter: CGFloat
    var content: Content

    init(elapsed: TimeInterval, diameter: CGFloat, @ViewBuilder content: () -> Content) {
        self.elapsed = elapsed
        self.diameter = diameter
        self.content = content()
    }

    /// 1 at rest, `RingBurstTiming.peakScale` half way through the swell.
    static func scale(at elapsed: TimeInterval) -> CGFloat {
        guard elapsed > 0, elapsed < RingBurstTiming.swell else { return 1 }
        return 1 + (RingBurstTiming.peakScale - 1) * sin(.pi * elapsed / RingBurstTiming.swell)
    }

    var body: some View {
        content
            .scaleEffect(Self.scale(at: elapsed))
            .overlay {
                if elapsed > 0, elapsed < RingBurstTiming.duration {
                    Canvas { context, size in
                        draw(&context, size: size)
                    }
                    .frame(width: diameter * 3, height: diameter * 3)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            }
    }

    private func draw(_ context: inout GraphicsContext, size: CGSize) {
        let t = elapsed / RingBurstTiming.duration
        let eased = 1 - pow(1 - t, 3)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let count = RingBurstTiming.speckCount
        for index in 0..<count {
            // A fixed scatter, so a frame is the same wherever it is drawn.
            let jitter = fraction(Double(index) * 12.9898)
            let angle = (Double(index) + (jitter - 0.5) * 0.6) / Double(count) * 2 * .pi
            let reach = diameter / 2 + 4 + diameter * (0.35 + 0.35 * fraction(Double(index) * 78.233)) * eased
            let radius = max(1, (2.5 + 1.5 * fraction(Double(index) * 39.346)) * (1 - 0.5 * t))
            let point = CGPoint(x: center.x + cos(angle) * reach, y: center.y + sin(angle) * reach)
            let alpha = pow(1 - t, 1.5)
            context.fill(
                Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)),
                with: .color(Color.appAccent.opacity(alpha)))
        }
    }

    /// The part of `value` after the point: a deterministic stand-in for a random number.
    private func fraction(_ value: Double) -> Double {
        let x = sin(value) * 43758.5453
        return x - floor(x)
    }
}

/// The running burst around `content`: starts when `startedAt` is set and ends by itself. `nil` is
/// no burst, and the content stands as it is.
struct RingBurst<Content: View>: View {
    var startedAt: Date?
    var diameter: CGFloat
    var content: Content
    @State private var isOver = true

    init(startedAt: Date?, diameter: CGFloat, @ViewBuilder content: () -> Content) {
        self.startedAt = startedAt
        self.diameter = diameter
        self.content = content()
    }

    var body: some View {
        TimelineView(.animation(paused: startedAt == nil || isOver)) { context in
            RingBurstFrame(elapsed: startedAt.map { context.date.timeIntervalSince($0) } ?? 0, diameter: diameter) { content }
        }
        .task(id: startedAt) {
            guard startedAt != nil else { return }
            isOver = false
            try? await Task.sleep(for: .seconds(RingBurstTiming.duration + 0.1))
            isOver = true
        }
    }
}

/// The sparkles of the words-in-memory milestone, with the burst the first time the line shows
/// for a milestone. `MilestoneCelebration` remembers which one has had it.
struct MilestoneSparkles: View {
    var milestone: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt: Date?

    var body: some View {
        RingBurst(startedAt: startedAt, diameter: 20) {
            Image(systemName: "sparkles")
                .foregroundStyle(Color.appAccent)
        }
        .task(id: milestone) {
            guard let milestone, MilestoneCelebration.claim(milestone) else { return }
            if !reduceMotion { startedAt = .now }
        }
    }
}

/// Which milestone has had its burst, so the line, which stays all day, bursts once.
enum MilestoneCelebration {
    static let key = "celebratedMilestone"

    /// Whether `milestone` is new to the burst; it is not the next time. The day's milestone is the
    /// highest the number passed, so a lower one never comes back.
    @discardableResult
    static func claim(_ milestone: Int, defaults: UserDefaults = .standard) -> Bool {
        guard defaults.integer(forKey: key) != milestone else { return false }
        defaults.set(milestone, forKey: key)
        return true
    }
}
