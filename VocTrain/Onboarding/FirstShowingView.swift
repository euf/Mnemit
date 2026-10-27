import SwiftUI
import VocabCore

/// The second step of the introduction: a new word's first showing, drawn as the study stream draws it: the question,
/// the answer on a touch, then the two wide buttons, Don't know and Know. Either answer says in one line what happens
/// to the word next, and the card slides under a small stack, the way a card that comes back does. Nothing is graded
/// or recorded: it is a practice, like the swipes after it.
struct FirstShowingView: View {
    /// How many sheets lie under the card.
    private static let sheets = 3
    /// The tallest the card grows.
    private static let cardMaxHeight: CGFloat = 320
    /// How far each sheet lies lower than the one above it, and how much narrower on each side, as in the study stack.
    private static let lineDrop: CGFloat = 8
    private static let lineInset: CGFloat = 7

    var done: () -> Void

    @State private var showing: FirstShowing
    @State private var isRevealed: Bool
    /// Whether the card lies on top of the stack; once it is answered it slides under.
    @State private var isOnTop: Bool
    /// -1 or 1 while the card is out of the way, towards the side it left by.
    @State private var side: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Forgot's height in the study screen, which Show Answer takes.
    @ScaledMetric(relativeTo: .body) private var buttonHeight: CGFloat = 50

    /// `showing` and `isRevealed` let the snapshot tests start at a later moment.
    init(showing: FirstShowing = FirstShowing(), isRevealed: Bool = false, done: @escaping () -> Void) {
        _showing = State(initialValue: showing)
        _isRevealed = State(initialValue: isRevealed || showing.isAnswered)
        _isOnTop = State(initialValue: !showing.isAnswered)
        self.done = done
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                Text("A New Word")
                    .font(.title.bold())
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                if !showing.isAnswered {
                    Button("Skip", action: done)
                }
            }
            stack
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            outcome
            footer
        }
        .padding(20)
    }

    // MARK: The stack

    private var stack: some View {
        ZStack {
            // The sheets under the card, and one more for the card itself once it lies under them. From the first answer on only
            // their edges show: the place of the card stays empty, never a blank card face.
            ZStack {
                ForEach(1...Self.sheets + 1, id: \.self) { level in
                    placed(surface(level: level), level: level)
                        .opacity(level > Self.sheets && isOnTop ? 0 : 1)
                        .zIndex(Double(-level))
                }
            }
            .mask { edges }
            let level = isOnTop ? 0 : Self.sheets + 1
            placed(card(level: level), level: level)
                .offset(x: side * 480)
                .opacity(isOnTop ? 1 : 0)
        }
        .accessibilityElement(children: .contain)
    }

    /// Everything but, once the card is answered, the card's own place: what is left of the sheets is their edges.
    private var edges: some View {
        ZStack {
            Rectangle().padding(-Self.lineDrop * CGFloat(Self.sheets + 2))
            if showing.isAnswered {
                placed(RoundedRectangle(cornerRadius: 22, style: .continuous), level: 0)
                    .blendMode(.destinationOut)
            }
        }
        .compositingGroup()
    }

    private func placed(_ content: some View, level: Int) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: Self.cardMaxHeight)
            .padding(.horizontal, Self.lineInset * CGFloat(level))
            .offset(y: Self.lineDrop * CGFloat(level))
    }

    /// A sheet of the stack: the card's surface, darker the deeper it lies.
    private func surface(level: Int) -> some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        return
            shape
            .fill(Color.cardSurface)
            .overlay { shape.fill(Color.primary.opacity(0.035 * Double(level))) }
            .overlay { shape.strokeBorder(Color(.opaqueSeparator)) }
            .accessibilityHidden(true)
    }

    private func card(level: Int) -> some View {
        let sample = FirstShowing.sample
        return surface(level: level)
            .overlay {
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
                // Under the stack the card shows its edge only.
                .opacity(isOnTop ? 1 : 0)
            }
            .contentShape(Rectangle())
            // A touch shows the answer, as on the study screen.
            .gesture(DragGesture(minimumDistance: 0).onChanged { _ in isRevealed = true }, isEnabled: !showing.isAnswered)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(isRevealed ? Text("Sample card: \(sample.question), \(sample.answer)") : Text(verbatim: sample.question))
            .accessibilityAction(named: Text("Show Answer")) { isRevealed = true }
            .accessibilityHidden(!isOnTop)
    }

    // MARK: What happens next

    /// One line per answer, both in the layout, one of them unseen, so nothing moves when it shows.
    private var outcome: some View {
        ZStack {
            ForEach([Grade.again, .good], id: \.self) { grade in
                Text(FirstShowing.line(after: grade) ?? "")
                    .opacity(showing.answer == grade ? 1 : 0)
                    .accessibilityHidden(showing.answer != grade)
            }
        }
        .font(.body)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .animation(.easeOut(duration: 0.2), value: showing.answer)
    }

    // MARK: Buttons

    /// Show Answer, then the two wide buttons, then Continue, in one place of one height, as the stream keeps its place.
    private var footer: some View {
        ZStack(alignment: .bottom) {
            if showing.isAnswered {
                Button(action: done) {
                    Text("Continue")
                        .frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .transition(.opacity)
            } else {
                gradeArea
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 2 * buttonHeight + Spacing.gap, alignment: .bottom)
        .animation(.easeInOut(duration: 0.25), value: showing.isAnswered)
    }

    /// Both are in the layout, one invisible: Show Answer takes the top of the place of the buttons until the reveal.
    private var gradeArea: some View {
        GradeChoice(isNew: true, onGrade: answer)
            .opacity(isRevealed ? 1 : 0)
            .allowsHitTesting(isRevealed)
            .accessibilityHidden(!isRevealed)
            .overlay(alignment: .top) {
                if !isRevealed {
                    showAnswer
                }
            }
    }

    private var showAnswer: some View {
        Button {
            isRevealed = true
        } label: {
            Text("Show Answer")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: buttonHeight)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: The answer

    private func answer(_ grade: Grade) {
        guard isRevealed, showing.give(grade) else { return }
        Task { await slideUnder(leaving: grade) }
    }

    /// The card leaves by the side of its answer, Don't know on the left and Know on the right as the swipes do, and
    /// comes back under the stack. Reduce Motion: it only fades into the stack.
    private func slideUnder(leaving grade: Grade) async {
        guard !reduceMotion else {
            withAnimation(.easeInOut(duration: 0.2)) { isOnTop = false }
            return
        }
        withAnimation(.easeIn(duration: 0.22)) { side = grade == .again ? -1 : 1 }
        try? await Task.sleep(for: .seconds(0.24))
        withAnimation(.spring(duration: 0.5, bounce: 0.15)) {
            isOnTop = false
            side = 0
        }
    }
}
