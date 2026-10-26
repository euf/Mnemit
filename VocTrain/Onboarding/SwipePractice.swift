import Foundation
import VocabCore

extension Grade {
    /// What the grade means, in the words of the practice: the four meanings are the rules
    /// of the app.
    var meaning: String {
        switch self {
        case .again: String(localized: "Forgot")
        case .hard: String(localized: "Remembered with effort")
        case .good: String(localized: "Remembered")
        case .easy: String(localized: "Remembered instantly")
        }
    }
}

/// A sample card of the practice: not one of a deck.
struct PracticeSample: Equatable {
    var question: String
    var answer: String
}

/// The practice of the swipes, the second step of the introduction: four cards in a fixed
/// order, each asking for one direction. Nothing is graded; only the order and the progress
/// are kept here, so the view stays a drawing of it.
struct SwipePractice: Equatable {
    /// The directions, in the order they are asked: left, up, down, right.
    static let order: [Grade] = [.again, .easy, .hard, .good]

    /// How many cards are done.
    private(set) var index = 0

    init(index: Int = 0) {
        self.index = min(max(index, 0), Self.order.count)
    }

    /// The grade the card in front asks for; `nil` once all four are done.
    var current: Grade? {
        index < Self.order.count ? Self.order[index] : nil
    }

    var isDone: Bool { current == nil }

    /// Whether `grade` is the swipe the card in front asks for.
    func accepts(_ grade: Grade) -> Bool {
        grade == current
    }

    /// Moves on to the next card.
    mutating func advance() {
        index = min(index + 1, Self.order.count)
    }

    /// How far the hint moves a card, in points: past the dead zone of `GradeSwipe`, so the card
    /// takes the tint of the grade.
    static let nudgeTravel: CGFloat = 24

    /// The finger's step the hint plays for `grade`: `nudgeTravel` points along the grade's
    /// reference direction (`GradeSwipe.reference(of:)`, the middle of its sector), which
    /// `GradeSwipe.zone` reads as the grade. The card moves by the pull of `CardFlight.drag` like
    /// under a real finger: for Easy up and to the right, at compass 37.5° (the finger at 15°, the target at 60°).
    static func nudge(for grade: Grade) -> CGSize {
        let radians = GradeSwipe.reference(of: grade) * .pi / 180
        return CGSize(width: nudgeTravel * cos(radians), height: -nudgeTravel * sin(radians))
    }

    /// The card that asks for `grade`. The four come from four languages, so the app doesn't
    /// look as if it were for one of them.
    static func sample(for grade: Grade) -> PracticeSample {
        switch grade {
        case .good: PracticeSample(question: "la mariposa", answer: String(localized: "the butterfly"))
        case .again: PracticeSample(question: "la bibliothèque", answer: String(localized: "the library"))
        case .easy: PracticeSample(question: "il treno", answer: String(localized: "the train"))
        case .hard: PracticeSample(question: "η αστυνομία", answer: String(localized: "the police"))
        }
    }
}

/// The first step after the welcome: one new word on its first showing, answered with Don't know or Know, the two
/// buttons of a new card. Nothing is graded or recorded. What it says comes true in the stream: a new card graded
/// Again or Good is in learning and due at once, so the session asks it again (`Scheduler.review`); Good is one of the
/// `LearningOptions.steps` it needs, 2 unless the deck says otherwise, so a Know brings it back once more. The session
/// asks a card back after a few others (`SessionQueue`).
struct FirstShowing: Equatable {
    /// A fifth language next to the four of the swipe practice.
    static let sample = PracticeSample(question: "a janela", answer: String(localized: "the window"))

    /// The button pressed: `nil` while the card waits.
    private(set) var answer: Grade?

    init(answer: Grade? = nil) {
        self.answer = answer.flatMap(Self.isOffered)
    }

    var isAnswered: Bool { answer != nil }

    /// Takes the answer of Don't know (`.again`) or Know (`.good`), once; returns whether it counted.
    mutating func give(_ grade: Grade) -> Bool {
        guard answer == nil, Self.isOffered(grade) != nil else { return false }
        answer = grade
        return true
    }

    /// What really happens to the word after `grade`, in a line.
    static func line(after grade: Grade) -> String? {
        switch grade {
        case .again: String(localized: "It comes back after a few cards.")
        case .good: String(localized: "It comes back once more before you're done.")
        case .hard, .easy: nil
        }
    }

    private static func isOffered(_ grade: Grade) -> Grade? {
        grade == .again || grade == .good ? grade : nil
    }
}

/// The steps of the introduction, in the order they come. Skipping the practice goes on to
/// the next step: the storage choice and the reminder are not for skipping.
enum OnboardingStep: CaseIterable {
    case welcome, firstShowing, swipe, day, sync, reminder

    /// The step after this one; `nil` after the last, where the introduction ends.
    var next: OnboardingStep? {
        Self.allCases.drop { $0 != self }.dropFirst().first
    }
}
