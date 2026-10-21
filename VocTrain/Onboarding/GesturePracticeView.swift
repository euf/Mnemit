import SwiftUI
import VocabCore

/// The second step of the introduction: four sample cards, not those of a deck, each asking for
/// one swipe: right, left, right and up, right and down. The prompt above the card names what
/// the direction means, so the four meanings are the rules of the app. The card is the study
/// screen's own, `FlightCard` driven by `CardFlight` and `GradeSwipe`, so the swipe tints, flies
/// and gives way as it will there; only nothing is graded.
///
/// A swipe the other way springs the card back with a warning and a shake of the prompt. After
/// a moment without a touch an arrow shows the direction, moving, or still with Reduce Motion.
struct GesturePracticeView: View {
    /// How long a card waits for a touch before the arrow shows the way, in seconds.
    static let idleBeforeHint = 2.0

    var done: () -> Void

    @State private var practice: SwipePractice
    @State private var flight = CardFlight()
    /// A swipe in the wrong direction: the haptic and the shake count them.
    @State private var mistakes = 0
    @State private var nudges = 0
    /// The swipe was too short to count: the prompt asks for more.
    @State private var wasShort = false
    @State private var showsHint = false
    /// Whether a finger is down; a drag the system cancels still springs the card back.
    @GestureState private var isDragging = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// `practice` lets the snapshot tests start at a later card.
    init(practice: SwipePractice = SwipePractice(), done: @escaping () -> Void) {
        _practice = State(initialValue: practice)
        self.done = done
    }

    /// What the idle timer depends on: it starts again with every card and every touch.
    private struct Idle: Equatable {
        var card: Int
        var isWaiting: Bool
    }

    private var idle: Idle {
        Idle(card: practice.index, isWaiting: !practice.isDone && !isDragging && !flight.isFlying)
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

            if let grade = practice.current {
                prompt(for: grade)
                card(for: grade)
                    .frame(maxHeight: 340)
            } else {
                success
            }

            Spacer(minLength: 0)

            Button(action: done) {
                Text("Continue")
                    .frame(maxWidth: .infinity, minHeight: 36)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            // Stays in its place and out of the way until the practice is over.
            .opacity(practice.isDone ? 1 : 0)
            .disabled(!practice.isDone)
            .accessibilityHidden(!practice.isDone)
        }
        .padding(20)
        .sensoryFeedback(.warning, trigger: mistakes)
        .task(id: idle) {
            showsHint = false
            guard idle.isWaiting else { return }
            try? await Task.sleep(for: .seconds(Self.idleBeforeHint))
            if !Task.isCancelled {
                showsHint = true
            }
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
            Group {
                if wasShort {
                    Text("Swipe farther, in the direction of the arrow: the card leaves once you pass the threshold.")
                } else {
                    Text("Swipe the card in the direction of the arrow.")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .top)
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
                Divider()
                Text(verbatim: sample.answer)
                    .font(.title)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .minimumScaleFactor(0.5)
            .multilineTextAlignment(.center)
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            if showsHint {
                SwipeHint(grade: grade, reduceMotion: reduceMotion)
            }
        }
        .contentShape(Rectangle())
        .gesture(swipe(expecting: grade))
        .onChange(of: isDragging) { _, isDragging in
            if !isDragging { flight.springBack() }
        }
        .swipeHaptics(flight)
        // VoiceOver can't swipe: the action does what the swipe does.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Sample card: \(sample.question), \(sample.answer)"))
        .accessibilityAction(named: Text(grade.meaning)) { commit(grade, expecting: grade) }
    }

    /// The study screen's swipe, in the coordinates of the card's place, which stays put as the
    /// card moves with the finger.
    private func swipe(expecting expected: Grade) -> some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .local)
            .updating($isDragging) { _, isDragging, _ in isDragging = true }
            .onChanged { value in
                flight.drag(value.translation, from: value.startLocation, isRevealed: true)
            }
            .onEnded { value in
                guard let grade = GradeSwipe.released(translation: value.translation, predictedEnd: value.predictedEndTranslation) else {
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
                .foregroundStyle(.green)
                .accessibilityHidden(true)
            Text("Well Done")
                .font(.title.bold())
            Text("Every card in your decks works like this: look at the answer, then swipe how well you remembered it.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .transition(.opacity)
    }
}

/// The arrow that shows the way of the swipe: it leaves the middle of the card in that
/// direction, and again, fading as it goes. With Reduce Motion it stands still, further out.
private struct SwipeHint: View {
    var grade: Grade
    var reduceMotion: Bool

    @State private var isMoving = false

    private static let travel: CGFloat = 80

    var body: some View {
        let exit = GradeSwipe.exit(of: grade)
        let length = hypot(exit.width, exit.height)
        let end = CGSize(width: exit.width / length * Self.travel, height: exit.height / length * Self.travel)
        Text(grade.arrow)
            .font(.title.bold())
            .foregroundStyle(grade.onColor)
            .frame(width: 56, height: 56)
            .background(grade.color, in: Circle())
            .offset(reduceMotion || isMoving ? end : .zero)
            .opacity(!reduceMotion && isMoving ? 0 : 1)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeOut(duration: 1.1).repeatForever(autoreverses: false)) {
                    isMoving = true
                }
            }
    }
}
