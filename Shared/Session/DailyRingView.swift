import SwiftUI
import VocabCore

/// The daily ring: today's reviews against the goal, with the streak in its middle. After the
/// goal the ring keeps filling in laps, a lighter arc over the first, and a small badge
/// counts the laps from the second on, as the Fitness rings do. A tap shows the figures in a
/// popover: today, laps, streak, and the repair of a missed day when one is open.
///
/// In the header of the study stream, in the Mac toolbar and on the deck screen. The model
/// (`DailyRingModel`) takes the figures from the review logs of all decks the app knows.
struct DailyRingView: View {
    /// `nil` before the first evaluation: an empty ring.
    var progress: DailyProgress?
    var diameter: CGFloat = 28
    @State private var isShowingDetails = false

    var body: some View {
        Button {
            isShowingDetails = true
        } label: {
            ring
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isShowingDetails) { details }
        .accessibilityLabel(Text("Daily Goal"))
        .accessibilityValue(progress.map { Text("\($0.ring.reviews) / \($0.ring.goal)") } ?? Text(verbatim: ""))
    }

    /// The popover, which stays one on the iPhone too, small as it is.
    @ViewBuilder
    private var details: some View {
        if let progress {
            #if os(iOS)
            DailyRingDetails(progress: progress).presentationCompactAdaptation(.popover)
            #else
            DailyRingDetails(progress: progress)
            #endif
        }
    }

    private var ring: some View {
        let fraction = progress?.ring.fraction ?? 0
        let lineWidth = max(3, diameter * 0.14)
        return ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.12), lineWidth: lineWidth)
            if fraction > 0 {
                arc(min(fraction, 1), color: .dailyRing, lineWidth: lineWidth)
            }
            if fraction > 1 {
                arc(min(fraction - 1, 1), color: .dailyRingLap, lineWidth: lineWidth)
            }
            center
        }
        .frame(width: diameter, height: diameter)
        .overlay(alignment: .topTrailing) {
            if let laps = progress?.ring.laps, laps >= 2 {
                Text(verbatim: "×\(laps)")
                    .font(.system(size: max(9, diameter * 0.3), weight: .bold, design: .rounded))
                    .foregroundStyle(.background)
                    .padding(.horizontal, 4)
                    .background(.primary, in: Capsule())
                    .offset(x: diameter * 0.25, y: -diameter * 0.2)
            }
        }
        .animation(.easeOut(duration: 0.4), value: fraction)
        .contentShape(Circle())
    }

    private func arc(_ fraction: Double, color: Color, lineWidth: CGFloat) -> some View {
        Circle()
            .trim(from: 0, to: fraction)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .rotationEffect(.degrees(-90))
    }

    /// The streak, if there is one.
    @ViewBuilder
    private var center: some View {
        if let days = progress?.streak.days, days > 0 {
            Text(days, format: .number)
                .font(.system(size: diameter * 0.4, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .padding(diameter * 0.2)
        }
    }
}

/// What the popover of the ring shows.
private struct DailyRingDetails: View {
    var progress: DailyProgress

    var body: some View {
        let ring = progress.ring
        VStack(alignment: .leading, spacing: 10) {
            Text("Daily Goal")
                .font(.headline)
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                GridRow {
                    Text("Today")
                        .foregroundStyle(.secondary)
                    Text("\(ring.reviews) / \(ring.goal)")
                }
                if ring.laps >= 1 {
                    GridRow {
                        Text("Goal reached")
                            .foregroundStyle(.secondary)
                        if ring.laps >= 2 {
                            Text(verbatim: "×\(ring.laps)")
                        } else {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                GridRow {
                    Text("Streak")
                        .foregroundStyle(.secondary)
                    Text("\(progress.streak.days) days")
                }
            }
            .monospacedDigit()
            if let repair = progress.streak.repairReviews {
                Text("Repair: \(repair) today")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(minWidth: 200, alignment: .leading)
    }
}
