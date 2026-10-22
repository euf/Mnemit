import SwiftUI
import VocabCore

/// What the last grade did, for the chip that offers to take it back: the grade and when
/// the card comes back. The only place that tells the learner the interval, after the
/// grade and not on the buttons.
struct GradeReceipt: Equatable {
    let id = UUID()
    var grade: Grade
    /// As `Scheduler.previewIntervals` told before the grade; `nil` in practice, which
    /// schedules nothing.
    var interval: ReviewInterval?
    /// The grade made the card a leech, which suspended it.
    var isLeech = false
    /// The part of a card the grade added to the ring, 0 to 1 (`Card.credit(onDayOf:calendar:steps:)`):
    /// what was left of it for a card the grade let go, a step's share for one in its steps, 0 for Forgot.
    var gain = 0.0
    /// The step of the ladder of memory the grade lifted the card to, from Young up; `nil` for the many grades
    /// that lift it nowhere, and for a new card learned, which every new card is.
    var climb: MaturityCategory?

    /// What shows beside the ring as a done card leaves: its interval, and the step it climbed to,
    /// "in 25 days · Maturing".
    var caption: String? {
        guard let flightLabel else { return nil }
        return climb.map { "\(flightLabel) · \($0.cardTitle)" } ?? flightLabel
    }

    /// The grade by the name its button has: "Forgot", not the scheduler's "Again".
    var title: String {
        grade == .again ? String(localized: "Forgot") : grade.title
    }

    /// What came of the grade: "in 4 days", "again today", "leech, suspended"; `nil` in practice.
    var detail: String? {
        if isLeech { return String(localized: "leech, suspended") }
        return interval.map { Format.interval($0) }
    }

    /// "Good · in 4 days", "Forgot · again today", "Forgot · leech, suspended".
    var text: String {
        detail.map { "\(title) · \($0)" } ?? title
    }

    /// Where the card goes when it is graded, which decides what the screen does after it has left on the iPhone.
    enum Destination: Equatable {
        /// To another day, so the card is done: it leaves, the stack loses a sheet, the ring steps and bursts.
        case ring
        /// Back today, in a learning step or after a lapse: it leaves and comes back in as a sheet under the stack.
        case stack
        /// Nowhere the screen shows: a practice, which schedules nothing, or a leech, which
        /// is suspended. The card leaves and that is all.
        case away
    }

    var destination: Destination {
        if isLeech { return .away }
        switch interval {
        case .days: return .ring
        case .learning: return .stack
        case nil: return .away
        }
    }

    /// What the bar says beside the ring for a moment after a done card: "tomorrow", "in 8 days", "in 3 months";
    /// "again today" and "suspended · leech" for the others; `nil` in practice.
    var flightLabel: String? {
        if isLeech { return String(localized: "suspended · leech") }
        if case .days(1) = interval { return String(localized: "tomorrow") }
        return interval.map { Format.interval($0) }
    }

    /// What VoiceOver announces as the card leaves, since the interval is gone in a moment: "Good, in 8 days".
    var announcement: String {
        [title, flightLabel].compactMap { $0 }.joined(separator: ", ")
    }

    /// Stands in for the real one where only the size of a chip matters.
    fileprivate static let sizing = GradeReceipt(grade: .good, interval: .days(1))
}

/// A chip under the bar that names the last grade and offers Undo, for a few seconds: a
/// capsule of system material, the grade as a small capsule of its own colour with the arrow
/// of its swipe, what came of it, and Undo as a text button in the accent. The chip keeps its
/// place whether or not it shows (an invisible copy holds its height), so it takes the same
/// spot on every card and never moves or covers the card or the buttons. It is one line at
/// every text size; when the whole of it doesn't fit, the "in 4 days" goes first.
struct UndoChip: View {
    /// How long the chip stays, in seconds.
    static let lifetime = 3.0

    var receipt: GradeReceipt?
    var onUndo: () -> Void
    /// Called once the chip has been shown for `lifetime`.
    var onExpire: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            chip(.sizing).hidden()
            if let receipt {
                chip(receipt)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.94)))
            }
        }
        .frame(maxWidth: .infinity)
        // Past this size the chip would take more of the screen than the card gives up.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .animation(.easeInOut(duration: 0.2), value: receipt)
        .task(id: receipt?.id) {
            guard receipt != nil else { return }
            try? await Task.sleep(for: .seconds(Self.lifetime))
            // The chip going changes the screen: not while a card speaks.
            await GreekSpeech.shared.whenQuiet()
            if !Task.isCancelled { onExpire() }
        }
    }

    private func chip(_ receipt: GradeReceipt) -> some View {
        ViewThatFits(in: .horizontal) {
            row(receipt, showsDetail: true)
            row(receipt, showsDetail: false)
        }
        .font(.footnote)
        .lineLimit(1)
        .background { surface }
    }

    /// The grade's badge sits a hairline inside the capsule, with the same curve, so the two
    /// are concentric. Undo is as high as the capsule and as wide as its word and 12 pt each
    /// side, so the touch has room.
    private func row(_ receipt: GradeReceipt, showsDetail: Bool) -> some View {
        HStack(spacing: 0) {
            Label(receipt.title, systemImage: receipt.grade.arrowSymbol)
                .labelStyle(.titleAndIcon)
                .fontWeight(.semibold)
                .foregroundStyle(receipt.grade.onColor)
                .padding(.horizontal, Spacing.gap)
                .padding(.vertical, Spacing.hairline)
                .background { Capsule().fill(receipt.grade.color) }
                .padding(Spacing.hairline)
                .accessibilityHidden(true)
            if showsDetail, let detail = receipt.detail {
                Text(detail)
                    .foregroundStyle(.secondary)
                    .padding(.leading, Spacing.hairline)
                    .accessibilityHidden(true)
            }
            Button(action: onUndo) {
                Text("Undo")
                    .fontWeight(.semibold)
                    .padding(.horizontal, Spacing.gap)
                    .padding(.vertical, Spacing.tight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
        }
        // Never squeezed: if the row doesn't fit, `ViewThatFits` takes the shorter one.
        .fixedSize(horizontal: true, vertical: false)
        // What VoiceOver reads for the chip, as before: the grade and the interval.
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: receipt.text))
    }

    private var surface: some View {
        Capsule()
            .fill(.regularMaterial)
            .overlay { Capsule().strokeBorder(Color.primary.opacity(0.08)) }
    }
}
