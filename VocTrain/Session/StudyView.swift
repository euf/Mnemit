import SwiftUI
import VocabCore

/// The study stream in the style of flash cards: the question, a touch shows the answer,
/// and the learner grades with Forgot, or with Hard, Good and Easy below it. The stream has
/// no end of its own: today's plan, a short rest (`StreamRestView`), then review ahead and
/// practice. Every grade is saved at once, so leaving loses nothing. The bar shows the close
/// button, today's reviews against the goal as a small ring with "14 of 20", and the menu.
///
/// Once the answer shows, the card can be swiped instead of the buttons: left is Forgot,
/// right Good, up on the right Easy, down on the right Hard (`GradeSwipe`). The card follows
/// the finger, turning about the point it was grabbed at, and takes the colour of the grade the
/// swipe would give; letting go far enough, or flicking, grades and sends the card off in that
/// direction. The buttons stay for VoiceOver and as a legend: during a swipe the button of the
/// grade it would give stands out and the others step back. A line under the bar offers Undo
/// for a few seconds after each grade, and a shake undoes too.
///
/// The card and the grade area keep their size from the question to the answer: the grade
/// buttons are in the layout all the time and fade in, and Show Answer sits on top of them.
///
/// A touch that starts on a speaker button belongs to the button: it neither shows the answer,
/// nor swipes the card, nor opens the card's info (`SpeakerPlaces`).
///
/// A long press on the card opens what the app knows about it (`CardInfoSheet`). With
/// "Speak Greek automatically" on, a Greek question is spoken when its card has settled, and
/// a Greek answer when it is shown; see `GreekSpeech.cardAppeared(_:)`.
struct StudyView: View {
    var model: StudyModel
    var ring: DailyRingModel
    var onClose: () -> Void

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(GreekSpeech.autoSpeakKey) private var autoSpeak = true
    @State private var flight: CardFlight
    /// The card whose info shows in a sheet.
    @State private var info: Card?
    /// Whether a finger is down; a drag the system cancels still springs the card back.
    @GestureState private var isDragging = false
    /// Where the speaker buttons of the card are; a touch that starts on one is the button's,
    /// not the card's.
    @State private var speakers = SpeakerPlaces()

    /// - Parameter flight: The card's movement; a test passes one it has moved.
    init(model: StudyModel, ring: DailyRingModel, flight: CardFlight? = nil, onClose: @escaping () -> Void) {
        self.model = model
        self.ring = ring
        self.onClose = onClose
        _flight = State(initialValue: flight ?? CardFlight())
    }

    private var isCompact: Bool { verticalSizeClass == .compact }

    private var isRevealed: Bool { model.stage == .revealed }

    var body: some View {
        NavigationStack {
            Group {
                if model.isResting {
                    VStack(spacing: 0) {
                        chip
                        StreamRestView(
                            rest: model.rest, progress: ring.progress,
                            onKeepGoing: model.keepGoing, onAddNewCards: model.addNewCards, onDone: onClose)
                    }
                } else if let card = model.currentCard {
                    cardArea(card)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    closeButton
                }
                ToolbarItem(placement: .principal) {
                    if !model.isResting {
                        header
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    // In a menu, so a stray tap doesn't suspend the card; Undo comes first
                    // (#293). The rest keeps the menu for Undo and the new cards.
                    Menu("More", systemImage: "ellipsis") {
                        // Only reviews and suspensions of this stream: undo beyond them
                        // would change cards the stream doesn't show.
                        Button("Undo", systemImage: "arrow.uturn.backward") {
                            model.document.undoManager?.undo()
                        }
                        .disabled(!model.hasUndoableSteps || model.document.undoManager?.canUndo != true)
                        if !model.isResting {
                            Button("Card Info", systemImage: "info.circle") {
                                info = model.currentCard
                            }
                            Button("Suspend Card", systemImage: "pause.circle") {
                                model.suspendCurrentCard()
                            }
                        }
                        if let extra = model.extraNew {
                            Button {
                                model.addNewCards()
                            } label: {
                                Text("+\(extra.cards) new")
                                Text("≈ +\(extra.reviewsPerDay) reviews/day next week")
                            }
                        }
                        if GreekSpeech.shared.voice != nil {
                            Divider()
                            Toggle("Speak Greek Automatically", systemImage: "speaker.wave.2", isOn: $autoSpeak)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            // iOS 26 adds a back button of its own; the close button takes its place.
            .navigationBarBackButtonHidden()
        }
        .onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in
            model.undoLast()
        }
        .sheet(item: $info) { card in
            CardInfoSheet(document: model.document, card: card)
        }
        // After the card has flown out: the question changes when the grade is given. The
        // speech waits until the new card has settled.
        .onChange(of: model.questionNumber, initial: true) {
            GreekSpeech.shared.cardAppeared(model.currentCard)
        }
        .onChange(of: model.stage) { _, stage in
            if stage == .revealed, let card = model.currentCard {
                GreekSpeech.shared.answerRevealed(of: card)
            }
        }
        .onDisappear { GreekSpeech.shared.close() }
    }

    /// The standard Close button of the platform; an `xmark` before iOS 26 has none.
    @ViewBuilder
    private var closeButton: some View {
        if #available(iOS 26, *) {
            Button(role: .close, action: onClose)
        } else {
            Button("Close", systemImage: "xmark", action: onClose)
        }
    }

    /// Names the last grade and offers Undo for a few seconds, at the top of the screen,
    /// under the bar. It keeps its place when empty, so nothing below it moves.
    private var chip: some View {
        UndoChip(receipt: model.receipt, onUndo: model.undoLast, onExpire: model.dismissReceipt)
    }

    /// The middle of the bar: today's ring with its figures, and the stage before it when the
    /// learner is not at today's plan: review ahead doesn't change the plan, and practice
    /// changes neither the plan nor the schedule, so it shows no ring.
    private var header: some View {
        HStack(spacing: 8) {
            switch model.streamStage {
            case .practiceMistakes, .practiceNewest:
                Text("Practice")
                    .font(.subheadline.weight(.semibold))
            case .reviewAhead:
                Text("Review Ahead")
                    .font(.subheadline.weight(.semibold))
                ringAndFigures
            case .plan, .rest:
                ringAndFigures
            }
        }
    }

    /// "14 of 20", or "26 today" once the goal is met, beside a small ring.
    @ViewBuilder
    private var ringAndFigures: some View {
        let daily = ring.progress?.ring
        HStack(spacing: 8) {
            StreamRing(fraction: daily?.fraction ?? 0)
            if let daily {
                Group {
                    if daily.isGoalMet {
                        Text("\(daily.reviews) today")
                    } else {
                        Text("\(daily.reviews) of \(daily.goal)")
                    }
                }
                .font(.subheadline)
                .monospacedDigit()
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// In portrait the buttons sit below the card. In landscape the iPhone is too low for the
    /// two rows: Forgot and the three others share one row. The gaps are from `Spacing`: 12
    /// between the chip, the card and the buttons (8 in landscape), 12 under the buttons, above
    /// the safe area, and the 16 of the side margins.
    private func cardArea(_ card: Card) -> some View {
        VStack(spacing: isCompact ? Spacing.tight : Spacing.gap) {
            chip
            cardView(card)
            gradeArea
        }
        .padding(.horizontal, Spacing.margin)
        .padding(.bottom, Spacing.gap)
    }

    /// The card, which the learner touches to show the answer and swipes to grade it. The
    /// gestures sit on a place that stays put, as the card moves away under the finger; it is
    /// also the space the speaker buttons report their places in (`SpeakerPlaces`).
    private func cardView(_ card: Card) -> some View {
        FlightCard(flight: flight) {
            CardFace(card: card, isRevealed: model.stage == .revealed)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.speakerPlaces, speakers)
        .coordinateSpace(name: SpeakerPlaces.space)
        .contentShape(Rectangle())
        // Next to the buttons inside the card, not instead of them: a touch on a speaker goes
        // to both, and `touch` is the one that lets it go.
        .simultaneousGesture(touch)
        // Gives up at the distance where the swipe starts, so it doesn't hold the swipe back.
        .onLongPressGesture(maximumDistance: Self.swipeStartDistance) {
            if !speakers.touchBeganOnSpeaker { info = card }
        }
        .onChange(of: isDragging) { _, isDragging in
            if !isDragging { flight.springBack() }
        }
        .swipeHaptics(flight)
    }

    private func startsOnSpeaker(_ value: DragGesture.Value) -> Bool {
        speakers.contains(value.startLocation)
    }

    /// A finger on the card, in the card's own coordinates, which stay put while the card moves:
    /// the translation is the finger's, and the start is where the card was grabbed. The touch
    /// shows the answer as the finger lands, so one gesture reveals and grades: touch, look,
    /// swipe on (owner, 21.10.2026). Past `swipeStartDistance` it swipes the card. A touch that
    /// starts on a speaker does neither: the speaker speaks and nothing else happens.
    private var touch: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .updating($isDragging) { value, isDragging, _ in
                if !isDragging, hypot(value.translation.width, value.translation.height) >= Self.swipeStartDistance, !startsOnSpeaker(value) {
                    isDragging = true
                }
            }
            .onChanged { value in
                let onSpeaker = startsOnSpeaker(value)
                speakers.touchBeganOnSpeaker = onSpeaker
                guard !onSpeaker else { return }
                model.reveal()
                // Once the swipe has begun the card follows the finger, however near it comes back.
                guard isDragging || hypot(value.translation.width, value.translation.height) >= Self.swipeStartDistance else { return }
                flight.drag(value.translation, from: value.startLocation, isRevealed: model.stage == .revealed)
            }
            .onEnded { value in
                guard !startsOnSpeaker(value) else { return }
                guard model.stage == .revealed, let grade = GradeSwipe.released(translation: value.translation, predictedEnd: value.predictedEndTranslation) else {
                    flight.springBack()
                    return
                }
                commit(grade)
            }
    }

    /// Flies the card out in the direction of `grade`, then grades. A swipe, a button and
    /// VoiceOver all come here. What the card was saying stops with it.
    private func commit(_ grade: Grade) {
        guard model.stage == .revealed, !flight.isFlying else { return }
        GreekSpeech.shared.stop()
        flight.fly(grade, reduceMotion: reduceMotion) { model.grade(grade) }
    }

    /// The same space for Show Answer and for the grade buttons: both are in the layout, one
    /// of them invisible, so the card keeps its height at the reveal. Show Answer fills all of
    /// it, from where Forgot's top is to where the bottom of the row of buttons is.
    private var gradeArea: some View {
        grades
            .opacity(isRevealed ? 1 : 0)
            .allowsHitTesting(isRevealed)
            .accessibilityHidden(!isRevealed)
            // An overlay has the size of the grades, which is the size the area has.
            .overlay {
                if !isRevealed {
                    showAnswer
                }
            }
            .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var grades: some View {
        if isCompact {
            HStack(spacing: 12) {
                GradeChoice(part: .forgot, isCompact: true, highlighted: flight.highlighted, onGrade: commit)
                    .frame(maxWidth: Self.forgotWidth)
                GradeChoice(part: .recalled, isCompact: true, highlighted: flight.highlighted, onGrade: commit)
            }
        } else {
            GradeChoice(highlighted: flight.highlighted, onGrade: commit)
        }
    }

    /// As wide and as high as the grade buttons below the card, in the same corner radius.
    private var showAnswer: some View {
        Button {
            model.reveal()
        } label: {
            Text("Show Answer")
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 14))
        .controlSize(.large)
    }

    private static let forgotWidth: CGFloat = 170
    /// How far a finger moves before it swipes the card, in points.
    private static let swipeStartDistance: CGFloat = 6
}

/// Today's reviews against the goal as a small ring in the bar; the laps after the goal go on
/// in a lighter arc, as `DailyRingView` does. It has no streak and no popover: the bar is calm.
private struct StreamRing: View {
    var fraction: Double
    private let lineWidth: CGFloat = 3

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.12), lineWidth: lineWidth)
            if fraction > 0 {
                arc(min(fraction, 1), color: .dailyRing)
            }
            if fraction > 1 {
                arc(min(fraction - 1, 1), color: .dailyRingLap)
            }
        }
        .frame(width: 22, height: 22)
        .animation(.easeOut(duration: 0.4), value: fraction)
    }

    private func arc(_ fraction: Double, color: Color) -> some View {
        Circle()
            .trim(from: 0, to: fraction)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .rotationEffect(.degrees(-90))
    }
}
