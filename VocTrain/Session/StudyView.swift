import SwiftUI
import VocabCore

/// A study session in the style of flash cards: the question, a tap shows the answer,
/// and the learner grades with Forgot, or with Hard, Good and Easy below it.
struct StudyView: View {
    var model: StudyModel
    var onClose: () -> Void

    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        NavigationStack {
            Group {
                if model.isFinished {
                    StudySummaryView(model: model, onClose: onClose)
                } else if let card = model.currentCard {
                    cardArea(card)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !model.isFinished {
                        Button("End Session", systemImage: "chevron.backward", action: onClose)
                    }
                }
                ToolbarItem(placement: .principal) {
                    // In landscape the progress sits between the grade buttons.
                    if !model.isFinished && verticalSizeClass != .compact {
                        progress
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    // In a menu, so a stray tap doesn't suspend the card; Undo comes first
                    // (#293). The summary keeps the menu for Undo.
                    Menu("More", systemImage: "ellipsis.circle") {
                        // Only reviews and suspensions of this session: undo beyond them
                        // would change cards the session doesn't show.
                        Button("Undo", systemImage: "arrow.uturn.backward") {
                            model.document.undoManager?.undo()
                        }
                        .disabled(!model.hasUndoableSteps || model.document.undoManager?.canUndo != true)
                        if !model.isFinished {
                            Button("Suspend Card", systemImage: "pause.circle") {
                                model.suspendCurrentCard()
                            }
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            // iOS 26 adds a back button of its own; End Session takes its place.
            .navigationBarBackButtonHidden()
        }
    }

    /// The progress in the row of buttons: the bar at the height of their middle, the
    /// numbers small below it.
    private var rowProgress: some View {
        let session = model.session
        return ProgressView(value: Double(session.completedCount), total: Double(max(session.totalCount, 1)))
            .frame(width: 120)
            .overlay(alignment: .top) {
                Text("\(session.completedCount) / \(session.totalCount)")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .fixedSize()
                    .offset(y: 8)
            }
    }

    private var progress: some View {
        let session = model.session
        return VStack(spacing: 4) {
            Text("\(session.completedCount) / \(session.totalCount)")
                .font(.subheadline)
                .monospacedDigit()
            ProgressView(value: Double(session.completedCount), total: Double(max(session.totalCount, 1)))
                .frame(width: 120)
        }
    }

    /// In portrait the buttons sit below the card. In landscape the iPhone is too low
    /// for that: the card takes the full width, the buttons one row below it, Forgot
    /// and the capsule on either side of the progress.
    @ViewBuilder
    private func cardArea(_ card: Card) -> some View {
        if verticalSizeClass == .compact {
            VStack(spacing: 12) {
                cardText(card, centered: true)
                buttonRow
            }
            .padding()
        } else {
            VStack(spacing: 24) {
                cardText(card, centered: false)
                actions
            }
            .padding()
        }
    }

    private func cardText(_ card: Card, centered: Bool) -> some View {
        Group {
            if centered {
                fixedDividerCard(card)
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        question(of: card)
                        if model.stage == .revealed {
                            Divider()
                            answer(of: card)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 48)
                }
            }
        }
        .multilineTextAlignment(.center)
        // The whole card shows the answer, not only the button.
        .contentShape(Rectangle())
        .onTapGesture { model.reveal() }
    }

    /// The divider stays in one place, whatever the card says: the question above it,
    /// the answer below. It sits a little above the middle, as the row of buttons below
    /// weighs more than the text. Text too long for its half gets smaller.
    private func fixedDividerCard(_ card: Card) -> some View {
        let revealed = model.stage == .revealed
        return VStack(spacing: 16) {
            question(of: card)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            Group {
                Divider()
                answer(of: card)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .opacity(revealed ? 1 : 0)
            .accessibilityHidden(!revealed)
            Color.clear
                .frame(height: 24)
        }
        .minimumScaleFactor(0.5)
    }

    private func question(of card: Card) -> some View {
        VStack(spacing: 16) {
            Text(card.question)
                .font(.largeTitle.weight(.semibold))
            if !card.hint.isEmpty {
                Text(card.hint)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func answer(of card: Card) -> some View {
        Text(card.answer)
            .font(.largeTitle)
    }

    @ViewBuilder
    private var actions: some View {
        if model.stage == .revealed {
            GradeChoice(intervals: model.gradeIntervals, onGrade: model.grade)
        } else {
            Button {
                model.reveal()
            } label: {
                Text("Show Answer")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    /// Forgot, the progress, then Hard, Good and Easy in their capsule. Before the answer
    /// shows, a Show button takes the place of the capsule, and the progress stays where
    /// it is.
    private var buttonRow: some View {
        HStack(spacing: 12) {
            if model.stage == .revealed {
                GradeChoice(part: .forgot, intervals: model.gradeIntervals, isCompact: true, onGrade: model.grade)
                    .frame(maxWidth: Self.forgotWidth)
                rowProgress
                GradeChoice(part: .recalled, intervals: model.gradeIntervals, isCompact: true, onGrade: model.grade)
            } else {
                Color.clear
                    .frame(maxWidth: Self.forgotWidth, maxHeight: 0)
                rowProgress
                Button {
                    model.reveal()
                } label: {
                    Text("Show")
                        .frame(maxWidth: .infinity, minHeight: 32)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private static let forgotWidth: CGFloat = 170
}
