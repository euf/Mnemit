import SwiftUI
import VocabCore

/// The study stream in the style of flash cards: the question, a touch shows the answer,
/// and the learner grades with Forgot, or with Hard, Good and Easy below it. The stack is
/// today's plan, which rests at the streak step and at the ring (`StreamRestView`) and ends with
/// the plan; Push On adds new cards past the end.
/// Every grade is saved at once, so leaving loses nothing. The bar shows the close button, today's
/// done cards against the daily goal as a small ring with "Round 2 of 4", and the menu.
///
/// Once the answer shows, the card can be swiped instead of the buttons: left is Forgot,
/// right Good, up Easy, down Hard (`GradeSwipe`, four sectors around the axes, with a gap
/// between Forgot and the two grades next to it where no grade is given). The card goes with
/// the finger, bent toward the grade's target (a swipe up moves it up and to the right),
/// turning about the point it was grabbed at, and takes the colour of the grade the swipe would
/// give; letting go far enough, or flicking, grades. The buttons stay for VoiceOver and as a legend:
/// during a swipe the button of the grade it would give stands out and the others step back.
///
/// A grade is applied at once, and the card shows where it went (`StudyMotion`, `DepartingCard`): a
/// card that FSRS lets go to another day flies, shrinking, into the small ring in the bar and steps it,
/// with "in 8 days" on it; a card that comes back today slides under the bottom of the stack of the
/// cards still waiting in the round; a practice or a leech flies off in the direction of the grade. The
/// card under it rises into its place and takes the next touch while the first still flies. Undo, the
/// button next to the menu or a shake, plays it backwards, and the card returns with its answer showing.
/// At the end of a round the ring comes down from the bar into the empty place of the card, bursts, and the
/// rest's lines come in under it one by one; Next Round takes it back up and deals the stack again.
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
    /// What moves besides the card under the finger: the cards that leave, the ring, the stack.
    @State private var motion: StudyMotion
    /// The medals earned on the way, one toast after another.
    @State private var toasts: MedalToasts
    /// The card whose info shows in a sheet.
    @State private var info: Card?
    /// Whether a finger is down; a drag the system cancels still springs the card back.
    @GestureState private var isDragging = false
    /// Whether a finger is on the card; resets by itself when the touch ends or is cancelled.
    @GestureState private var isTouching = false
    /// Where the speaker buttons of the card are; a touch that starts on one is the button's,
    /// not the card's.
    @State private var speakers = SpeakerPlaces()

    /// - Parameters:
    ///   - flight: The card's movement; a test passes one it has moved.
    ///   - motion: What moves around it; a test passes one it has frozen.
    ///   - toasts: The medals' toasts; a test passes one with its own store, or one with a toast frozen in.
    init(
        model: StudyModel, ring: DailyRingModel, flight: CardFlight? = nil, motion: StudyMotion? = nil, toasts: MedalToasts? = nil,
        onClose: @escaping () -> Void
    ) {
        self.model = model
        self.ring = ring
        self.onClose = onClose
        _flight = State(initialValue: flight ?? CardFlight())
        let motion = motion ?? StudyMotion(ring: ring)
        if model.isResting, motion.frozen == nil { motion.snapRest(true) }
        _motion = State(initialValue: motion)
        _toasts = State(initialValue: toasts ?? MedalToasts())
    }

    private var isCompact: Bool { verticalSizeClass == .compact }

    private var isRevealed: Bool { model.stage == .revealed }

    /// How far each edge of the stack shows below the one above it.

    var body: some View {
        NavigationStack {
            Group {
                if motion.showsRest {
                    restLayer
                } else if let card = model.currentCard {
                    cardArea(card)
                }
            }
            // Reduce Motion: the rest comes with a crossfade, not by the ring's way.
            .animation(reduceMotion ? .easeInOut(duration: 0.25) : nil, value: motion.showsRest)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            // Under the bar, over the top of the card.
            .medalToast(toasts)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    closeButton
                }
                ToolbarItem(placement: .principal) {
                    StudyHeader(model: model, ring: ring, motion: motion)
                }
                ToolbarItem(placement: .primaryAction) {
                    // Next to the menu, which holds it too: the same condition for both.
                    Button("Undo", systemImage: "arrow.uturn.backward", action: undo)
                        .labelStyle(.iconOnly)
                        .disabled(!canUndo)
                }
                ToolbarItem(placement: .primaryAction) {
                    // In a menu, so a stray tap doesn't suspend the card; Undo comes first
                    // (#293). New cards beyond the limit are offered only at rest
                    // ("Done for today"), when the plan is done.
                    Menu("More", systemImage: "ellipsis") {
                        // Only reviews and suspensions of this stream: undo beyond them
                        // would change cards the stream doesn't show.
                        Button("Undo", systemImage: "arrow.uturn.backward", action: undo)
                            .disabled(!canUndo)
                        if !model.isResting {
                            Button("Card Info", systemImage: "info.circle") {
                                info = model.currentCard
                            }
                            Button("Suspend Card", systemImage: "pause.circle") {
                                suspend()
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
        // Above the bar too: the cards that leave fly into the ring in it, and the ring comes down from it.
        .overlay { motionLayer }
        .onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in
            undo()
        }
        .sheet(item: $info) { card in
            CardInfoSheet(document: model.document, card: card)
        }
        // After the card has flown out: the question changes when the grade is given. The
        // speech waits until the new card has settled.
        .onChange(of: model.questionNumber, initial: true) {
            if !motion.showsRest { motion.arrival = .still }
            speakCurrentCard()
        }
        .onChange(of: model.stage) { _, stage in
            if stage == .revealed, !model.returnedByUndo, let card = model.currentCard {
                GreekSpeech.shared.answerRevealed(of: card, media: model.document.deck.media)
            }
        }
        // A rest nobody sent for, say a card gone from the deck: the screen follows without a show.
        .onChange(of: model.isResting) { _, isResting in
            if isResting != motion.showsRest, !motion.isChoreographing { motion.snapRest(isResting) }
        }
        .onChange(of: ring.progress?.ring.done) {
            motion.figuresChanged()
        }
        // A medal earned by a grade is celebrated when the ring has been evaluated; the rest does it by itself.
        .onChange(of: ring.progress) {
            if !motion.showsRest { toasts.offer(ring.progress) }
        }
        .onChange(of: motion.showsRest) { _, showsRest in
            if showsRest { toasts.clear() }
        }
        // The ring in the bar plays what a card landing in it does.
        .onChange(of: toasts.shown) { motion.celebrate() }
        .onDisappear {
            GreekSpeech.shared.close()
            toasts.clear()
        }
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

    /// The cards that have been graded and fly on, and the ring that comes down to the rest.
    private var motionLayer: some View {
        ZStack {
            GeometryReader { proxy in
                let origin = proxy.frame(in: .global).origin
                ForEach(motion.departures) { departure in
                    DepartingCard(departure: departure, frozen: motion.frozen?.departure)
                        .frame(width: departure.slot.width, height: departure.slot.height)
                        .position(x: departure.slot.midX - origin.x, y: departure.slot.midY - origin.y)
                }
            }
            .allowsHitTesting(false)
            RingTraveler(motion: motion, progress: ring.progress, reduceMotion: reduceMotion)
        }
    }

    // MARK: The cards

    /// In portrait the buttons sit below the card. In landscape the iPhone is too low for the
    /// two rows: Forgot and the three others share one row. The gaps are from `Spacing`: 12
    /// between the card and the buttons (8 in landscape), with the room for the stack's edges
    /// in it, 12 under the buttons, above the safe area, and the 16 of the side margins.
    private func cardArea(_ card: Card) -> some View {
        VStack(spacing: isCompact ? Spacing.tight : Spacing.gap) {
            cardView(card)
                .padding(.bottom, StackPose.reserve)
            gradeArea
        }
        .padding(.horizontal, Spacing.margin)
        .padding(.top, Spacing.tight)
        .padding(.bottom, Spacing.gap)
    }

    /// The card, which the learner touches to show the answer and swipes to grade it. The
    /// gestures sit on a place that stays put, as the card moves away under the finger; it is
    /// also the space the speaker buttons report their places in (`SpeakerPlaces`). Behind it
    /// the cards of the round that wait, as a stack of blank edges.
    private func cardView(_ card: Card) -> some View {
        TopCard(flight: flight, arrival: motion.arrival, frozenRise: motion.frozen?.rise) {
            CardFace(
                card: card, isRevealed: model.stage == .revealed, media: model.document.deck.media,
                memory: CardMemory(card: card, in: model.document.deck, at: model.document.clock.now, calendar: model.document.calendar))
        }
        // A card of its own for each question: the one under rises into place from the stack.
        .id(model.questionNumber)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { CardStack(edges: motion.edges(cardsBehind: model.cardsBehind), sheets: motion.sheets, frozenSheet: motion.frozen?.sheet, dealt: false) }
        .environment(\.speakerPlaces, speakers)
        .coordinateSpace(name: SpeakerPlaces.space)
        .onGeometryChange(for: CGRect.self) {
            $0.frame(in: .global)
        } action: {
            motion.cardSlot = $0
        }
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
                guard model.stage == .revealed, let grade = SwipeTally.shared.released(translation: value.translation, predictedEnd: value.predictedEndTranslation) else {
                    flight.springBack()
                    return
                }
                commit(grade, velocity: value.velocity)
            }
    }

    // MARK: Grading and Undo

    /// Gives `grade` and sends the card off, from where it was let go with the speed of the finger. The
    /// grade is applied at once, so the next card is on top and takes the next touch while this one flies;
    /// where the card goes follows from what the grade did (`GradeReceipt.destination`). A swipe, a button
    /// and VoiceOver all come here. What the card was saying stops with it.
    private func commit(_ grade: Grade, velocity: CGSize = .zero) {
        guard model.stage == .revealed, let card = model.currentCard else { return }
        GreekSpeech.shared.stop()
        let release = flight.release
        let behind = model.cardsBehind
        motion.arrival = .rises
        guard let receipt = model.grade(grade) else {
            motion.arrival = .still
            flight.springBack()
            return
        }
        flight.didRelease(grade)
        motion.depart(card, receipt: receipt, release: release, velocity: velocity, behind: behind, reduceMotion: reduceMotion)
        // The label is gone in a moment.
        AccessibilityNotification.Announcement(receipt.announcement).post()
        if model.isResting {
            motion.restBegan(afterExit: receipt.destination == .ring, reduceMotion: reduceMotion)
        }
    }

    private func suspend() {
        motion.arrival = .rises
        model.suspendCurrentCard()
    }

    private var canUndo: Bool { model.canUndo && !motion.isChoreographing }

    /// Takes back the last grade the way it went: the card comes back in from the edge it left by, with its answer
    /// showing, and the ring gives the grade's step back. From the rest the ring goes up to the bar first.
    private func undo() {
        guard canUndo, let target = model.undoReturn else { return }
        let receipt = model.undoReceipt
        let arrival = motion.returnArrival(receipt, reduceMotion: reduceMotion)
        if target.fromRest {
            motion.leaveRest(
                snapshot: model.rest, reduceMotion: reduceMotion, cardsAfter: StudyMotion.Timing.travel, arrival: arrival,
                apply: { model.undoLast() }, didLeave: { !model.isResting },
                then: { motion.undone(receipt, reduceMotion: reduceMotion) })
        } else {
            motion.arrival = arrival
            model.undoLast()
            motion.undone(receipt, reduceMotion: reduceMotion)
        }
    }

    /// Goes on from the rest: the ring goes back up to the bar and the cards are dealt.
    private func leaveRest(_ action: @escaping () -> Void) {
        guard !motion.isChoreographing else { return }
        motion.leaveRest(
            snapshot: model.rest, reduceMotion: reduceMotion, cardsAfter: 0.3, arrival: .rises, apply: action, didLeave: { !model.isResting },
            then: { speakCurrentCard() })
    }

    /// A card that came by a move of the stream speaks once it has settled; one that came back by Undo
    /// was heard, and the rest has no card.
    private func speakCurrentCard() {
        guard !motion.showsRest, !model.returnedByUndo else { return }
        GreekSpeech.shared.cardAppeared(model.currentCard, media: model.document.deck.media)
    }

    // MARK: The rest

    /// The stop at the end of a round or of the plan. The ring is the one that came down from the bar: this
    /// only leaves it its place and, until it has come, the empty place of the card.
    private var restLayer: some View {
        StreamRestView(
            rest: motion.restSnapshot ?? model.rest, progress: ring.progress,
            onAddNewCards: { leaveRest(model.addNewCards) },
            onNextRound: { leaveRest(model.continueRound) }, onDone: onClose,
            ringPlace: reduceMotion ? nil : { motion.ringRest = $0 }, staggers: !reduceMotion, arrived: motion.hasArrived || reduceMotion,
            frozenStep: motion.frozen?.lines
        )
        .background {
            GeometryReader { proxy in
                let slot = motion.cardSlot
                let origin = proxy.frame(in: .global).origin
                if slot.width > 0 {
                    SlotOutline()
                        .frame(width: slot.width, height: slot.height)
                        .position(x: slot.midX - origin.x, y: slot.midY - origin.y)
                        .opacity(motion.showsSlot ? 1 : 0)
                        .animation(.easeOut(duration: 0.2), value: motion.showsSlot)
                }
            }
        }
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
                GradeChoice(part: .forgot, isCompact: true, highlighted: flight.highlighted, onGrade: { commit($0) })
                    .frame(maxWidth: Self.forgotWidth)
                GradeChoice(part: .recalled, isCompact: true, highlighted: flight.highlighted, onGrade: { commit($0) })
            }
        } else {
            GradeChoice(highlighted: flight.highlighted, onGrade: { commit($0) })
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

/// The middle of the bar: today's ring with its figures, and the stage before it when the
/// learner is not at today's plan: practice changes neither the plan nor the schedule, so it
/// shows no ring.
///
/// A view of its own, so a new figure of the ring, which comes a moment after each grade, redraws
/// the bar and not the whole screen with its card. The ring is where the cards go: it reports its
/// place (`StudyMotion.ringHome`), steps when a card lands in it, and gives way to the ring that
/// comes down to the rest (`RingTraveler`) while that is away. The bar is empty while the rest has the ring.
private struct StudyHeader: View {
    var model: StudyModel
    var ring: DailyRingModel
    var motion: StudyMotion
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 8) {
            switch model.streamStage {
            case .practiceMistakes, .practiceNewest:
                Text("Practice")
                    .font(.subheadline.weight(.semibold))
            case .plan, .rest:
                ringAndFigures
            }
        }
        .opacity(motion.showsRest && motion.travel >= 1 ? 0 : 1)
        .animation(.easeOut(duration: 0.2), value: motion.showsRest && motion.travel >= 1)
    }

    /// A small ring, and beside it the time left, "≈ 4 min", while the goal is open, or "36 cards today" once it is
    /// met. For a moment after a done card the interval it was given, "in 8 days", takes their place.
    @ViewBuilder
    private var ringAndFigures: some View {
        let daily = ring.progress?.ring
        HStack(spacing: 8) {
            StreamRing(progress: ring.progress, shown: motion.shown, burstAt: reduceMotion ? nil : motion.barBurstAt)
                .ringBump(motion.landings, reduceMotion: reduceMotion)
                .opacity(motion.travels ? 0 : 1)
                .onGeometryChange(for: CGRect.self) {
                    $0.frame(in: .global)
                } action: {
                    motion.ringHome = $0
                }
            if let daily {
                ZStack(alignment: .leading) {
                    if daily.isGoalMet {
                        Text("\(daily.done) cards today")
                            .opacity(motion.interval == nil ? 1 : 0)
                    } else if let minutes = ring.progress?.minutesLeft {
                        Text(verbatim: Format.timeLeft(minutes: minutes))
                            .opacity(motion.interval == nil ? 1 : 0)
                    }
                    if let interval = motion.interval {
                        Text(verbatim: interval)
                            .transition(.opacity)
                            // VoiceOver has it from the announcement of the grade.
                            .accessibilityHidden(true)
                    }
                }
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: motion.interval)
                .font(.subheadline)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
        }
        .accessibilityElement(children: .combine)
        // A grade that adds only a part of a card changes the figures and not the count of done cards.
        .onChange(of: ring.progress?.ring.fraction) {
            motion.figuresChanged()
        }
    }
}

/// Today's done cards against the daily goal as a ring in the bar (`ProgressRing`), with the
/// lap in its middle from the second on: "×2" once the goal is reached. No streak and no popover: the bar
/// is calm. As big as the figures beside it need for "×2", and it grows with the text size up
/// to a ceiling, as the bar has only so much height. VoiceOver reads the lap ("Lap 2") with the
/// figures beside it, which the bar combines into one element. `shown` is what the ring shows as
/// done when it is ahead of the figures, a grade having stepped it. `burstAt` starts the small burst around it.
struct StreamRing: View {
    var progress: DailyProgress?
    var shown: Double?
    var burstAt: Date?
    @ScaledMetric(relativeTo: .subheadline) private var diameter: CGFloat = 30

    var body: some View {
        RingBurst(startedAt: burstAt, diameter: min(diameter, 44)) {
            ProgressRing(
                fraction: DailyRingFigure.fraction(progress, shown: shown), diameter: min(diameter, 44), center: RingCenter(progress, inStream: true),
                speaksCenter: true)
        }
    }
}
