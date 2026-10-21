import SwiftUI
import VocabCore

extension Grade {
    /// The name on the grade buttons, which say Forgot where `title` says Again.
    var buttonTitle: String {
        self == .again ? String(localized: "Forgot") : title
    }

    /// The direction of the swipe that gives the grade.
    var arrow: String {
        switch self {
        case .again: "←"
        case .hard: "↘"
        case .good: "→"
        case .easy: "↗"
        }
    }
}

/// The second step of the introduction: a sample card, not one of a deck, to swipe once in
/// each of the four directions. It is the study screen's own card, `FlightCard` driven by
/// `CardFlight` and `GradeSwipe`, so the swipe tints, flies and gives way as it will there;
/// only nothing is graded.
struct GesturePracticeView: View {
    var next: () -> Void
    var skip: () -> Void

    @State private var flight = CardFlight()
    @State private var practised: Set<Grade> = []
    @State private var message = String(localized: "Left means forgot, right means recalled, right and up means easy, right and down means hard.")
    /// Whether a finger is down; a drag the system cancels still springs the card back.
    @GestureState private var isDragging = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let order: [Grade] = [.again, .good, .easy, .hard]

    private var isDone: Bool {
        practised.count == Self.order.count
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Try the Gestures")
                        .font(.title.bold())
                    Group {
                        if isDone {
                            Text("All four gestures practised")
                        } else {
                            Text("Swipe the card each way, once.")
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Skip", action: skip)
            }

            card
                .frame(height: 250)

            Text(message)
                .font(.subheadline)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .topLeading)
                .accessibilityAddTraits(.updatesFrequently)

            checklist

            Spacer(minLength: 0)

            Button(action: next) {
                Text("Next")
                    .frame(maxWidth: .infinity, minHeight: 36)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!isDone)
        }
        .padding(20)
    }

    /// The card, with the faint arrows at its edges that show where each grade lies.
    private var card: some View {
        FlightCard(flight: flight) {
            VStack(spacing: 12) {
                Text(verbatim: "η αστυνομία")
                    .font(.largeTitle.weight(.semibold))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                Divider()
                Text("the police")
                    .font(.title)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .minimumScaleFactor(0.5)
            .multilineTextAlignment(.center)
            .padding(20)
            .overlay { edgeHints }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(swipe)
        .onChange(of: isDragging) { _, isDragging in
            if !isDragging { flight.springBack() }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: flight.committing) { _, committing in
            committing != nil
        }
        // VoiceOver can't swipe: the actions do what the swipes do.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Sample card: η αστυνομία, the police"))
        .accessibilityAction(named: Text(Grade.again.buttonTitle)) { commit(.again) }
        .accessibilityAction(named: Text(Grade.good.buttonTitle)) { commit(.good) }
        .accessibilityAction(named: Text(Grade.easy.buttonTitle)) { commit(.easy) }
        .accessibilityAction(named: Text(Grade.hard.buttonTitle)) { commit(.hard) }
    }

    private var edgeHints: some View {
        GeometryReader { proxy in
            ForEach(Grade.allCases, id: \.self) { grade in
                Text(grade.arrow)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(grade.onColor)
                    .frame(width: 28, height: 28)
                    .background(grade.color, in: Circle())
                    .opacity(0.55)
                    .position(hintPosition(of: grade, in: proxy.size))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func hintPosition(of grade: Grade, in size: CGSize) -> CGPoint {
        let inset: CGFloat = 22
        switch grade {
        case .again: return CGPoint(x: inset, y: size.height * 0.5)
        case .easy: return CGPoint(x: size.width - inset, y: size.height * 0.3)
        case .good: return CGPoint(x: size.width - inset, y: size.height * 0.5)
        case .hard: return CGPoint(x: size.width - inset, y: size.height * 0.7)
        }
    }

    private var checklist: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Self.order, id: \.self) { grade in
                let isPractised = practised.contains(grade)
                HStack(spacing: 10) {
                    Image(systemName: isPractised ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isPractised ? grade.color : Color.secondary)
                    Text(grade.arrow)
                        .fontWeight(.bold)
                        .frame(width: 20)
                    Text(grade.buttonTitle)
                }
                .accessibilityElement(children: .combine)
                .accessibilityValue(isPractised ? Text("Practised") : Text(verbatim: ""))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The study screen's swipe, in global coordinates, as the card moves with the finger.
    private var swipe: some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .global)
            .updating($isDragging) { _, isDragging, _ in isDragging = true }
            .onChanged { value in
                flight.drag(value.translation, isRevealed: true)
            }
            .onEnded { value in
                guard let grade = GradeSwipe.released(translation: value.translation, predictedEnd: value.predictedEndTranslation) else {
                    flight.springBack()
                    if hypot(value.translation.width, value.translation.height) >= GradeSwipe.deadZone {
                        message = String(localized: "Swipe farther, in the direction of the arrow: the card leaves once you pass the threshold.")
                    }
                    return
                }
                commit(grade)
            }
    }

    /// Flies the card out in the direction of `grade`, as the study screen does, and ticks
    /// the grade off.
    private func commit(_ grade: Grade) {
        guard !flight.isFlying else { return }
        practised.insert(grade)
        message = Self.meaning(of: grade)
        flight.fly(grade, reduceMotion: reduceMotion) {}
    }

    private static func meaning(of grade: Grade) -> String {
        switch grade {
        case .again: String(localized: "Forgot: you didn't recall it, or got it wrong. The card comes back soon.")
        case .hard: String(localized: "Hard: you recalled it, but with effort. It comes back sooner than usual.")
        case .good: String(localized: "Good: you recalled it as usual. It comes back in a few days.")
        case .easy: String(localized: "Easy: you recalled it instantly. It comes back much later.")
        }
    }
}
