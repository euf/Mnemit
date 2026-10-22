import SwiftUI
import VocabCore

/// The daily ring: today's cards done against the daily goal (`ProgressRing`). After the goal the ring
/// goes on in laps, the way the Fitness rings do. In its middle the streak in days, or, with
/// `inStream`, the lap from the second on ("×2"). A tap shows the figures in a popover: today,
/// the lap, the streak, and the repair of a missed day when one is open.
///
/// On the Mac in the header of the study stream, on the rest screen of the iPhone, and in the
/// widget. The model (`DailyRingModel`) takes the figures from the review logs of all decks the
/// app knows.
struct DailyRingView: View {
    /// `nil` before the first evaluation: an empty ring.
    var progress: DailyProgress?
    var diameter: CGFloat = 28
    /// Whether the ring sits in the study stream: the middle then counts laps, not days.
    var inStream = false
    /// What the ring shows as done while it is ahead of the figures, a card having landed in it; `nil`
    /// shows the figures.
    var shown: Double?
    @State private var isShowingDetails = false

    var body: some View {
        Button {
            isShowingDetails = true
        } label: {
            ProgressRing(fraction: DailyRingFigure.fraction(progress, shown: shown), diameter: diameter, center: center)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isShowingDetails) { details }
        .accessibilityLabel(center.spokenLabel.map { Text(verbatim: $0) } ?? Text("Daily Goal"))
        .accessibilityValue(progress.map { Text("\($0.ring.done) / \($0.ring.goal)") } ?? Text(verbatim: ""))
    }

    private var center: RingCenter { RingCenter(progress, inStream: inStream) }

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
                    Text("\(ring.done) / \(ring.goal)")
                }
                if ring.laps >= 1 {
                    GridRow {
                        Text("Goal reached")
                            .foregroundStyle(.secondary)
                        Image(systemName: "checkmark")
                    }
                    GridRow {
                        Text("Lap")
                            .foregroundStyle(.secondary)
                        Text(verbatim: "×\(ring.laps + 1)")
                    }
                }
                GridRow {
                    Text("Streak")
                        .foregroundStyle(.secondary)
                    Text("\(progress.streak.days) days")
                }
            }
            .monospacedDigit()
            if let repair = progress.streak.repairCards {
                Text("Repair: \(repair) today")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(minWidth: 200, alignment: .leading)
    }
}
