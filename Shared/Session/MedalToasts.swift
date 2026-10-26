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

/// Where a medal's toast stands: never over the ring, the card or a button (`references/product-model.md`, "Surfaces").
enum MedalToastPlace {
    /// Over the large title, under the bar's buttons: Today on the iPhone.
    case title
    /// One compact line in the gap under the card, above the answer's buttons: the iPhone's stream. Applied to the card with
    /// the room for the stack's edges under it (`StackPose.reserve`) and `Spacing.gap` to the buttons.
    case gap
    /// One compact line in the middle of the header's row, between the figures and the buttons: the Mac's stream.
    case header
    /// Below the content, which gives up that room while the toast stands: the Mac's Today, under the Study button.
    case inset

    fileprivate var isCompact: Bool { self == .gap || self == .header }
}

extension View {
    /// The toasts of `toasts` where the view's layout leaves room for them (`MedalToastPlace`).
    @ViewBuilder
    func medalToast(_ toasts: MedalToasts, at place: MedalToastPlace) -> some View {
        switch place {
        case .title:
            // An inset of no height at the bar's bottom edge, large title included: it moves nothing, and the toast stands on it.
            safeAreaInset(edge: .top, spacing: 0) {
                Color.clear.frame(height: 0).overlay(alignment: .bottom) { MedalToastLayer(toasts: toasts, place: place) }
            }
        case .gap:
            // The compact toast is 32 tall, the gap 32 (the stack's edges) + `Spacing.gap` tall: its middle, 6 below the view's foot.
            overlay(alignment: .bottom) { MedalToastLayer(toasts: toasts, place: place).offset(y: Spacing.gap / 2) }
        case .header:
            overlay { MedalToastLayer(toasts: toasts, place: place) }
        case .inset:
            safeAreaInset(edge: .bottom, spacing: 0) { MedalToastLayer(toasts: toasts, place: place) }
        }
    }
}

/// The toast on screen: it slides in from its edge and fades in, and goes back out; with Reduce Motion it only fades. A
/// success haptic plays as it comes, and VoiceOver hears the medal's title.
private struct MedalToastLayer: View {
    var toasts: MedalToasts
    var place: MedalToastPlace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// From the top for the title, from below for the toast under the content, in place (it grows from 0.9) for the lines.
    private var transition: AnyTransition {
        if reduceMotion { return .opacity }
        switch place {
        case .title: return .move(edge: .top).combined(with: .opacity)
        case .inset: return .move(edge: .bottom).combined(with: .opacity)
        case .gap, .header: return .scale(scale: 0.9).combined(with: .opacity)
        }
    }

    var body: some View {
        ZStack {
            if let medal = toasts.current {
                MedalToast(kind: medal.kind, compact: place.isCompact)
                    .padding(.vertical, place == .inset ? Spacing.tight : 0)
                    .id(medal)
                    .transition(transition)
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.25) : .smooth(duration: 0.4), value: toasts.current)
        .allowsHitTesting(false)
        .sensoryFeedback(.success, trigger: toasts.shown)
        .onChange(of: toasts.shown) {
            if let medal = toasts.current { AccessibilityNotification.Announcement(medal.kind.title).post() }
        }
    }
}

/// A medal as a toast: a capsule of material with the disc, the title and what it took; `compact`, a line with the disc and the
/// title only.
struct MedalToast: View {
    var kind: AchievementKind
    var compact = false

    var body: some View {
        HStack(spacing: Spacing.gap) {
            MedalDisc(kind: kind, size: compact ? 24 : 36)
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: kind.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(compact ? 1 : nil)
                if !compact, let detail = kind.detail {
                    Text(verbatim: detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .multilineTextAlignment(.leading)
        }
        .padding(.vertical, compact ? Spacing.hairline : Spacing.tight)
        .padding(.leading, compact ? Spacing.hairline : Spacing.tight)
        .padding(.trailing, compact ? Spacing.gap : Spacing.margin)
        .background(.regularMaterial, in: Capsule())
        .padding(.horizontal, Spacing.margin)
        .accessibilityElement(children: .combine)
    }
}
