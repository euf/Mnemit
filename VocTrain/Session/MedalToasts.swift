import SwiftUI
import VocabCore

/// The medals earned in the stream, one toast at a time: `offer` takes the achievements of today not celebrated
/// yet, each shows for `Timing.stay` and is marked celebrated as it comes in, and what comes while one is up
/// waits its turn. A rest drops the queue (`clear`): it shows today's medals itself and marks them.
@MainActor @Observable
final class MedalToasts {
    enum Timing {
        static let stay = 2.5
        /// Between the one that has gone and the next.
        static let gap = 0.4
    }

    /// The medal on screen.
    private(set) var current: Achievement?
    /// How many toasts have come in: the trigger of the haptic and of the ring's bump.
    private(set) var shown = 0
    @ObservationIgnored private let store: CelebratedMedals
    @ObservationIgnored private var queue: [Achievement] = []
    @ObservationIgnored private var task: Task<Void, Never>?

    /// - Parameter frozen: A medal on screen without a timer, for a picture of the toast fully in.
    init(store: CelebratedMedals = .shared, frozen: Achievement? = nil) {
        self.store = store
        current = frozen
    }

    /// Queues what `progress` holds of today not celebrated yet.
    func offer(_ progress: DailyProgress?) {
        guard let progress, let today = progress.records.last?.day else { return }
        let fresh = store.pending(progress.achievements, today: today).filter { $0.day == today && !queue.contains($0) }
        queue += fresh
        if task == nil, !queue.isEmpty { task = Task { await run() } }
    }

    /// Drops what waits and takes down what shows.
    func clear() {
        task?.cancel()
        task = nil
        queue = []
        current = nil
    }

    private func run() async {
        while !queue.isEmpty, !Task.isCancelled {
            let next = queue.removeFirst()
            store.mark([next])
            current = next
            shown += 1
            try? await Task.sleep(for: .seconds(Timing.stay))
            guard !Task.isCancelled else { return }
            current = nil
            try? await Task.sleep(for: .seconds(Timing.gap))
        }
        if !Task.isCancelled { task = nil }
    }
}

/// A medal as a toast: a capsule of material with the disc, the title and what it took.
struct MedalToast: View {
    var kind: AchievementKind

    var body: some View {
        HStack(spacing: Spacing.gap) {
            MedalDisc(kind: kind, size: 36)
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: kind.title)
                    .font(.subheadline.weight(.semibold))
                if let detail = kind.detail {
                    Text(verbatim: detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .multilineTextAlignment(.leading)
        }
        .padding(.vertical, Spacing.tight)
        .padding(.leading, Spacing.tight)
        .padding(.trailing, Spacing.margin)
        .background(.regularMaterial, in: Capsule())
        .padding(.horizontal, Spacing.margin)
        .accessibilityElement(children: .combine)
    }
}
