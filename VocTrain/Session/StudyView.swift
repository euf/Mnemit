import SwiftUI
import VocabCore

/// The study stream in the style of flash cards: the question, a touch shows the answer,
/// and the learner grades with Forgot, or with Hard, Good and Easy below it. The stream has
/// no end of its own: today's plan, a short rest (`StreamRestView`), then review ahead and
/// practice. Every grade is saved at once, so leaving loses nothing. The bar shows the close
/// button, today's reviews against the goal as a small ring with "14 of 30 today", and the menu.
///
/// Once the answer shows, the card can be swiped instead of the buttons: left is Forgot,
/// right Good, up Easy, down Hard (`GradeSwipe`, four sectors around the axes, with a gap
/// between Forgot and the two grades next to it where no grade is given). The card goes with
/// the finger, bent toward the grade's target (a swipe up moves it up and to the right),
/// turning about the point it was grabbed at, and takes the colour of the grade the swipe would
/// give; letting go far enough, or flicking, grades and sends the card off in the direction of
/// the grade. The buttons stay for VoiceOver and as a legend: during a swipe the button of the
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
    /// Whether a finger is on the card; resets by itself when the touch ends or is cancelled.
    @GestureState private var isTouching = false
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
                    // (#293). New cards beyond the limit are offered only at rest
                    // ("Done for today"), when the plan is done.
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
    /// learner is not at today's plan: catching up and review ahead don't change the plan but
    /// fill the ring's laps, and practice changes neither the plan nor the schedule, so it
    /// shows no ring.
    private var header: some View {
        HStack(spacing: 8) {
            switch model.streamStage {
            case .practiceMistakes, .practiceNewest:
                Text("Practice")
                    .font(.subheadline.weight(.semibold))
            case .catchUp:
                Text("Catch Up")
                    .font(.subheadline.weight(.semibold))
                ringAndFigures
            case .reviewAhead:
                Text("Review Ahead")
                    .font(.subheadline.weight(.semibold))
                ringAndFigures
            case .plan, .rest:
                ringAndFigures
            }
        }
    }

    /// "14 of 30 today", or "36 today" once the goal is met, beside a small ring.
    @ViewBuilder
    private var ringAndFigures: some View {
        let daily = ring.progress?.ring
        HStack(spacing: 8) {
            StreamRing(progress: ring.progress)
            if let daily {
                Group {
                    if daily.isGoalMet {
                        Text("\(daily.reviews) today")
                    } else {
                        Text("\(daily.reviews) of \(daily.goal) today")
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
            // Decided once, as the finger lands: the reveal puts the answer's speaker on the
            // card, and a swipe that began where it appears must not turn into a touch on it.
            .updating($isTouching) { value, isTouching, _ in
                if !isTouching {
                    isTouching = true
                    speakers.touchBeganOnSpeaker = startsOnSpeaker(value)
                }
            }
            .updating($isDragging) { value, isDragging, _ in
                if !isDragging, hypot(value.translation.width, value.translation.height) >= Self.swipeStartDistance, !speakers.touchBeganOnSpeaker {
                    isDragging = true
                }
            }
            .onChanged { value in
                guard !speakers.touchBeganOnSpeaker else { return }
                model.reveal()
                // Once the swipe has begun the card follows the finger, however near it comes back.
                guard isDragging || hypot(value.translation.width, value.translation.height) >= Self.swipeStartDistance else { return }
                flight.drag(value.translation, from: value.startLocation, isRevealed: model.stage == .revealed)
            }
            .onEnded { value in
                guard !speakers.touchBeganOnSpeaker else { return }
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
    /// of them invisible, so the card keeps its height at the reveal. Show Answer takes Forgot's
    /// place and height; the row of the other grades below it stays empty until the reveal.
    private var gradeArea: some View {
        grades
            .opacity(isRevealed ? 1 : 0)
            .allowsHitTesting(isRevealed)
            .accessibilityHidden(!isRevealed)
            .overlay(alignment: .top) {
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

    /// As wide and as high as Forgot, in the same corner radius.
    private var showAnswer: some View {
        Button {
            model.reveal()
        } label: {
            Text("Show Answer")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: showAnswerHeight)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    /// Forgot's height, `GradeChoice.scaledHeight`.
    @ScaledMetric(relativeTo: .body) private var showAnswerHeight: CGFloat = 50

    private static let forgotWidth: CGFloat = 170
    /// How far a finger moves before it swipes the card, in points.
    private static let swipeStartDistance: CGFloat = 6
}

/// Today's reviews against the goal as a ring in the bar (`ProgressRing`), with the lap in its
/// middle from the second on: "×2" once the goal is reached. No streak and no popover: the bar
/// is calm. As big as the figures beside it need for "×2", and it grows with the text size up
/// to a ceiling, as the bar has only so much height. VoiceOver reads the lap ("Lap 2") with the
/// figures beside it, which the bar combines into one element.
struct StreamRing: View {
    var progress: DailyProgress?
    @ScaledMetric(relativeTo: .subheadline) private var diameter: CGFloat = 30

    var body: some View {
        ProgressRing(
            fraction: progress?.ring.fraction ?? 0, diameter: min(diameter, 44), center: RingCenter(progress, inStream: true), speaksCenter: true)
    }
}
