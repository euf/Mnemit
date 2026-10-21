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

    /// "Good · in 4 days", "Forgot · again today", "Forgot · leech, suspended".
    var text: String {
        if isLeech { return "\(grade.title) · \(String(localized: "leech, suspended"))" }
        guard let interval else { return grade.title }
        return "\(grade.title) · \(Format.interval(interval))"
    }
}

/// A line under the progress that names the last grade and offers Undo, for a few seconds.
/// It keeps its height whether or not it shows, so it takes the same spot on every card
/// and never covers the card or the buttons.
struct UndoChip: View {
    /// How long the chip stays, in seconds.
    static let lifetime = 3.0

    var receipt: GradeReceipt?
    var onUndo: () -> Void
    /// Called once the chip has been shown for `lifetime`.
    var onExpire: () -> Void

    var body: some View {
        ZStack {
            if let receipt {
                HStack(spacing: 10) {
                    Text(verbatim: receipt.text)
                    Button("Undo", action: onUndo)
                        .buttonStyle(.plain)
                        .fontWeight(.semibold)
                }
                .font(.footnote)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .foregroundStyle(.background)
                .background(.primary, in: Capsule())
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 32)
        .animation(.easeInOut(duration: 0.2), value: receipt)
        .task(id: receipt?.id) {
            guard receipt != nil else { return }
            try? await Task.sleep(for: .seconds(Self.lifetime))
            if !Task.isCancelled { onExpire() }
        }
    }
}
