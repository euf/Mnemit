import SwiftUI
import VocabCore

/// The third step of the introduction: four sample cards, not those of a deck, each asking for
/// one swipe: left, up, down, right. The prompt above the card names what the direction means,
/// so the four meanings are the rules of the app. The card is the study screen's own,
/// `FlightCard` driven by `CardFlight` and `GradeSwipe`, and it goes the way of the study
/// screen: the word first, the answer when the finger lands (`StudyView.touch`), then the
/// swipe, which tints, flies and gives way as it will there; only nothing is graded.
///
/// A swipe the other way springs the card back with a warning and a shake of the prompt. After
/// a moment without a touch the card itself shows the way: it moves a step the way a real swipe
/// in the direction would move it, in the tint of the grade, and springs back, again and again
/// until a finger lands. With Reduce Motion it stays and the tint shows alone.
struct GesturePracticeView: View {
    /// How long a card waits for a touch before it shows the way, in seconds.
    static let idleBeforeHint = 2.0
    /// The pause between two such hints, from the end of one.
    static let hintPause = 2.5
    /// How strong the tint of the hint is when the card doesn't move (Reduce Motion).
    static let stillTint = 0.35
    /// The tallest the card grows; below it the card fills the room between prompt and button.
    static let cardMaxHeight: CGFloat = 460
    /// How far a finger moves before it swipes the card, in points, as in `StudyView`.
    private static let swipeStartDistance: CGFloat = 6

    var done: () -> Void

    @State private var practice: SwipePractice
    @State private var flight: CardFlight
    /// A swipe in the wrong direction: the haptic and the shake count them.
    @State private var mistakes = 0
    @State private var nudges = 0
    /// The swipe was too short to count: the prompt asks for more.
    @State private var wasShort = false
    /// The answer of the card in front shows: the finger has landed on it.
    @State private var isRevealed: Bool
    /// The tint the hint gives a card that stays in place.
    @State private var stillHint = 0.0
    /// Whether a finger is down on the card, still or moving.
    @GestureState private var isTouching = false
    /// Whether the swipe has begun; a drag the system cancels still springs the card back.
    @GestureState private var isDragging = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// `practice`, `isRevealed` and `flight` let the snapshot tests start at a later card, with
    /// its answer shown, and with the card moved.
    init(
        practice: SwipePractice = SwipePractice(), isRevealed: Bool = false, flight: CardFlight? = nil,
        done: @escaping () -> Void
    ) {
        _practice = State(initialValue: practice)
        _isRevealed = State(initialValue: isRevealed)
        _flight = State(initialValue: flight ?? CardFlight())
        self.done = done
    }

    /// What the idle timer depends on: it starts again with every card and every touch.
    private struct Idle: Equatable {
        var card: Int
        var isWaiting: Bool
    }

    private var idle: Idle {
        Idle(card: practice.index, isWaiting: !practice.isDone && !isTouching && !flight.isFlying)
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                Text("Try the Gestures")
                    .font(.title.bold())
                Spacer()
                if !practice.isDone {
                    Button("Skip", action: done)
                }
            }

            dots

            // Stays in its place, unseen, after the last card, so the Well Done sits where the
            // card was.
            prompt(for: SwipePractice.order[min(practice.index, SwipePractice.order.count - 1)])
                .opacity(practice.isDone ? 0 : 1)
                .accessibilityHidden(practice.isDone)

            // The room between the prompt and the bottom of the screen: the card grows to
            // `cardMaxHeight` and sits in the middle of it; at the end the Well Done and its
            // button fill it.
            Group {
                if let grade = practice.current {
                    card(for: grade)
                        .frame(maxHeight: Self.cardMaxHeight)
                        // Room for the hint's step up, so the card doesn't touch the prompt.
                        .padding(.vertical, 12)
                } else {
                    VStack(spacing: 16) {
                        success
                        Button(action: done) {
                            Text("Continue")
                                .frame(maxWidth: .infinity, minHeight: 36)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(20)
        .sensoryFeedback(.warning, trigger: mistakes)
        .task(id: idle) {
            guard idle.isWaiting, let grade = practice.current else { return }
            var wait = Self.idleBeforeHint
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(wait))
                if Task.isCancelled { return }
                await nudge(grade)
                wait = Self.hintPause
            }
        }
    }

    /// Shows the way on the card: a step as a real swipe in the direction of the grade moves it, in its tint, and back
    /// with a spring. With Reduce Motion the card stays and the tint comes and goes. A finger
    /// landing cancels the task; the card goes back the same way, so it is never left moved.
    private func nudge(_ grade: Grade) async {
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.2)) { stillHint = Self.stillTint }
            try? await Task.sleep(for: .seconds(0.5))
            withAnimation(.easeOut(duration: 0.3)) { stillHint = 0 }
        } else {
            // Revealed or not: the nudge shows direction and colour, the answer is for the touch.
            flight.drag(SwipePractice.nudge(for: grade), isRevealed: true, glide: .easeOut(duration: 0.25))
            try? await Task.sleep(for: .seconds(0.4))
            flight.springBack()
        }
    }

    /// One dot per card: the colour of the grade once the card is done, a ring on the card in
    /// front.
    private var dots: some View {
        let total = SwipePractice.order.count
        return HStack(spacing: 10) {
            ForEach(Array(SwipePractice.order.enumerated()), id: \.offset) { index, grade in
                Circle()
                    .fill(index < practice.index ? grade.color : Color.secondary.opacity(0.25))
                    .overlay {
                        if index == practice.index {
                            Circle().strokeBorder(Color.primary.opacity(0.6), lineWidth: 1.5)
                        }
                    }
                    .frame(width: 12, height: 12)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Card \(min(practice.index + 1, total)) of \(total)"))
    }

    /// What the card in front asks for: the arrow in the colour of the grade and its meaning.
    private func prompt(for grade: Grade) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Text(grade.arrow)
                    .font(.title2.bold())
                    .foregroundStyle(grade.onColor)
                    .frame(width: 44, height: 44)
                    .background(grade.color, in: Circle())
                    .accessibilityHidden(true)
                Text(grade.meaning)
                    .font(.title2.bold())
            }
            .keyframeAnimator(initialValue: 0.0, trigger: nudges) { content, offset in
                content.offset(x: offset)
            } keyframes: { _ in
                KeyframeTrack {
                    LinearKeyframe(-9, duration: 0.05)
                    LinearKeyframe(9, duration: 0.1)
                    LinearKeyframe(-6, duration: 0.1)
                    LinearKeyframe(6, duration: 0.1)
                    LinearKeyframe(0, duration: 0.05)
                }
            }
            // Both lines take their room, one of them unseen, so the card doesn't move when the
            // line changes.
            ZStack {
                Text("Touch the card to see the answer, then swipe toward the arrow.")
                    .opacity(wasShort ? 0 : 1)
                    .accessibilityHidden(wasShort)
                Text("Swipe a little farther toward the arrow.")
                    .opacity(wasShort ? 1 : 0)
                    .accessibilityHidden(!wasShort)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            // The line takes the height it needs at the largest text sizes; the card gives way.
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }

    private func card(for grade: Grade) -> some View {
        let sample = SwipePractice.sample(for: grade)
        return FlightCard(flight: flight) {
            VStack(spacing: 12) {
                Text(verbatim: sample.question)
                    .font(.largeTitle.weight(.semibold))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                // The answer is in the layout all the time and fades in, as on the study card.
                Group {
                    Divider()
                    Text(verbatim: sample.answer)
                        .font(.title)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                .opacity(isRevealed ? 1 : 0)
                .animation(.easeOut(duration: 0.15), value: isRevealed)
            }
            .minimumScaleFactor(0.5)
            .multilineTextAlignment(.center)
            .padding(20)
            // The tint of the hint that doesn't move the card, under the text like the card's own.
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(grade.color)
                    .opacity(stillHint)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(touch(expecting: grade))
        .onChange(of: isDragging) { _, isDragging in
            if !isDragging { flight.springBack() }
        }
        // The haptic of `swipeHaptics`, but only from a finger: a hint is not a touch.
        .sensoryFeedback(.impact(weight: .medium), trigger: flight.gradeFeedback) { _, _ in isDragging || flight.isFlying }
        // VoiceOver can't swipe: the action does what the swipe does.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Sample card: \(sample.question), \(sample.answer)"))
        .accessibilityAction(named: Text(grade.meaning)) { commit(grade, expecting: grade) }
    }

    /// A finger on the card, as on the study screen (`StudyView.touch`), in the coordinates of
    /// the card's place, which stays put as the card moves with the finger. It shows the answer
    /// as the finger lands, so one gesture reveals and grades: touch, look, swipe on. Past
    /// `swipeStartDistance` it swipes the card. A hint under way ends where the finger lands:
    /// the task of the hint sees the touch and springs the card back.
    private func touch(expecting expected: Grade) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .updating($isTouching) { _, isTouching, _ in isTouching = true }
            .updating($isDragging) { value, isDragging, _ in
                if !isDragging, hypot(value.translation.width, value.translation.height) >= Self.swipeStartDistance {
                    isDragging = true
                }
            }
            .onChanged { value in
                isRevealed = true
                // Once the swipe has begun the card follows the finger, however near it comes back.
                guard isDragging || hypot(value.translation.width, value.translation.height) >= Self.swipeStartDistance else { return }
                flight.drag(value.translation, from: value.startLocation, isRevealed: isRevealed)
            }
            .onEnded { value in
                guard isRevealed, let grade = GradeSwipe.released(translation: value.translation, predictedEnd: value.predictedEndTranslation) else {
                    flight.springBack()
                    if hypot(value.translation.width, value.translation.height) >= GradeSwipe.deadZone {
                        wasShort = true
                    }
                    return
                }
                commit(grade, expecting: expected)
            }
    }

    /// The swipe asked for flies the card out and brings the next one; any other springs it
    /// back, with the warning and the shake.
    private func commit(_ grade: Grade, expecting expected: Grade) {
        guard !flight.isFlying, practice.accepts(expected) else { return }
        guard grade == expected else {
            flight.springBack()
            mistakes += 1
            if !reduceMotion {
                nudges += 1
            }
            return
        }
        wasShort = false
        flight.fly(grade, reduceMotion: reduceMotion) {
            // The next card starts with its word alone, and doesn't fade its answer out.
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { isRevealed = false }
            withAnimation(.easeInOut(duration: 0.25)) { practice.advance() }
            if let next = practice.current {
                AccessibilityNotification.Announcement(next.meaning).post()
            }
        }
    }

    /// The end of the practice: nothing to swipe any more, only the rule that holds for every
    /// card of every deck.
    private var success: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            Text("Well Done")
                .font(.title.bold())
            Text("Every card works like this.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}
