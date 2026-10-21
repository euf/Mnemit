import SwiftUI
import VocabCore

/// A study session in the style of flash cards: the question, a tap shows the answer,
/// and the learner grades with Forgot, or with Hard, Good and Easy below it.
///
/// Once the answer shows, the card can be swiped instead of the buttons: left is Forgot,
/// right Good, right and up Easy, right and down Hard. The card follows the finger and
/// takes the colour of the grade the swipe would give; letting go far enough, or flicking,
/// grades and sends the card off in that direction. The buttons stay for VoiceOver and as
/// a legend: during a swipe the button of the grade it would give stands out and the others
/// step back. A line under the progress offers Undo for a few seconds after each grade, and
/// a shake undoes too.
struct StudyView: View {
    var model: StudyModel
    var onClose: () -> Void

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var flight = CardFlight()
    /// Whether a finger is down; a drag the system cancels still springs the card back.
    @GestureState private var isDragging = false

    var body: some View {
        NavigationStack {
            Group {
                if model.isFinished {
                    VStack(spacing: 0) {
                        chip
                        StudySummaryView(model: model, onClose: onClose)
                    }
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
        .onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in
            model.undoLast()
        }
    }

    /// Names the last grade and offers Undo for a few seconds, at the top of the screen,
    /// under the progress.
    private var chip: some View {
        UndoChip(receipt: model.receipt, onUndo: model.undoLast, onExpire: model.dismissReceipt)
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
    /// and the three others on either side of the progress.
    @ViewBuilder
    private func cardArea(_ card: Card) -> some View {
        if verticalSizeClass == .compact {
            VStack(spacing: 8) {
                chip
                cardView(card)
                buttonRow
                    .padding(.top, 4)
            }
            .padding()
        } else {
            VStack(spacing: 8) {
                chip
                cardView(card)
                actions
                    .padding(.top, 16)
            }
            .padding()
        }
    }

    /// The card, which the learner taps to show the answer and swipes to grade it. The
    /// gestures sit on a place that stays put, as the card moves away under the finger.
    private func cardView(_ card: Card) -> some View {
        FlightCard(flight: flight) {
            face(of: card)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { model.reveal() }
        .gesture(swipe)
        .onChange(of: isDragging) { _, isDragging in
            if !isDragging { flight.springBack() }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: flight.committing) { _, committing in
            committing != nil
        }
    }

    /// Global coordinates: the card moves with the finger, and a drag measured in its own
    /// would shrink as it follows.
    private var swipe: some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .global)
            .updating($isDragging) { _, isDragging, _ in isDragging = true }
            .onChanged { value in
                flight.drag(value.translation, isRevealed: model.stage == .revealed)
            }
            .onEnded { value in
                guard model.stage == .revealed, let grade = GradeSwipe.released(translation: value.translation, predictedEnd: value.predictedEndTranslation) else {
                    flight.springBack()
                    return
                }
                commit(grade)
            }
    }

    /// Flies the card out in the direction of `grade`, then grades. A swipe, a button and
    /// VoiceOver all come here.
    private func commit(_ grade: Grade) {
        guard model.stage == .revealed, !flight.isFlying else { return }
        flight.fly(grade, reduceMotion: reduceMotion) { model.grade(grade) }
    }

    /// The divider stays in one place, whatever the card says: the question above it,
    /// the answer below. It sits a little above the middle, as the row of buttons below
    /// weighs more than the text. Text too long for its half gets smaller.
    private func face(of card: Card) -> some View {
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
            // The hidden answer has no speaker button to tap.
            .allowsHitTesting(revealed)
            .accessibilityHidden(!revealed)
            Color.clear
                .frame(height: 24)
        }
        .minimumScaleFactor(0.5)
        .multilineTextAlignment(.center)
        .padding(20)
    }

    private func question(of card: Card) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                Text(card.question)
                    .font(.largeTitle.weight(.semibold))
                SpeakButton(text: card.question)
            }
            if !card.hint.isEmpty {
                Text(card.hint)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func answer(of card: Card) -> some View {
        HStack(spacing: 8) {
            Text(card.answer)
                .font(.largeTitle)
            SpeakButton(text: card.answer)
        }
    }

    @ViewBuilder
    private var actions: some View {
        if model.stage == .revealed {
            GradeChoice(highlighted: flight.highlighted, onGrade: commit)
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

    /// Forgot, the progress, then Hard, Good and Easy in a row. Before the answer shows, a
    /// Show button takes the place of the row, and the progress stays where it is.
    private var buttonRow: some View {
        HStack(spacing: 12) {
            if model.stage == .revealed {
                GradeChoice(part: .forgot, isCompact: true, highlighted: flight.highlighted, onGrade: commit)
                    .frame(maxWidth: Self.forgotWidth)
                rowProgress
                GradeChoice(part: .recalled, isCompact: true, highlighted: flight.highlighted, onGrade: commit)
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
