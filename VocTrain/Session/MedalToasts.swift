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

    /// Queues what `progress` holds not celebrated yet: of today, or with `earlierDays` of the days before it, the
    /// medals earned on another device.
    func offer(_ progress: DailyProgress?, earlierDays: Bool = false) {
        guard let progress, let today = progress.records.last?.day else { return }
        let fresh = store.pending(progress.achievements, today: today).filter {
            (earlierDays ? $0.day < today : $0.day == today) && !queue.contains($0)
        }
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

extension View {
    /// The toasts of `toasts` over the top of the view, under the bar.
    func medalToast(_ toasts: MedalToasts) -> some View {
        overlay(alignment: .top) { MedalToastLayer(toasts: toasts) }
    }
}

/// The toast on screen: it slides down and fades in, and goes up and out; with Reduce Motion it only fades. A
/// success haptic plays as it comes, and VoiceOver hears the medal's title.
private struct MedalToastLayer: View {
    var toasts: MedalToasts
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if let medal = toasts.current {
                MedalToast(kind: medal.kind)
                    .id(medal)
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.25) : .smooth(duration: 0.4), value: toasts.current)
        .padding(.top, Spacing.tight)
        .allowsHitTesting(false)
        .sensoryFeedback(.success, trigger: toasts.shown)
        .onChange(of: toasts.shown) {
            if let medal = toasts.current { AccessibilityNotification.Announcement(medal.kind.title).post() }
        }
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
