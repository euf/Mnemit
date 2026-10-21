import SwiftUI
import VocabCore

/// The face of a flash card in the study stream, on both platforms: the question above the
/// divider, the answer below it, each in a half of its own. The layout is the same whether or
/// not the answer shows, as the answer only fades in, so the question stays where it is and the
/// card never changes size at the reveal.
///
/// Every part has one size, whatever the card says: the Greek word is the largest, the gloss in
/// the learner's language the second, the example the smallest. `minimumScaleFactor(0.6)` is
/// only a valve for the largest Dynamic Type sizes; nothing in the face is laid out again while
/// the card is swiped.
struct CardFace: View {
    var question: String
    var hint: String
    var answer: String
    var isRevealed: Bool

    init(card: Card, isRevealed: Bool) {
        self.init(question: card.question, hint: card.hint, answer: card.answer, isRevealed: isRevealed)
    }

    init(question: String, hint: String, answer: String, isRevealed: Bool) {
        self.question = question
        self.hint = hint
        self.answer = answer
        self.isRevealed = isRevealed
    }

    /// The answer split at its first line break: the head, which `SpeakButton` speaks, and an
    /// example sentence, if there is one.
    private var parts: (head: String, example: String?) {
        let lines = answer.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: true)
        return (lines.first.map(String.init) ?? answer, lines.count > 1 ? String(lines[1]) : nil)
    }

    var body: some View {
        VStack(spacing: Metrics.spacing) {
            questionBlock
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            Group {
                Divider()
                answerBlock
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .opacity(isRevealed ? 1 : 0)
            // The hidden answer has no speaker button to tap, nor a place the card's touch
            // would leave to it (a disabled speaker reports none).
            .allowsHitTesting(isRevealed)
            .disabled(!isRevealed)
            .accessibilityHidden(!isRevealed)
            .animation(.easeOut(duration: 0.15), value: isRevealed)
            #if os(iOS)
            // Lifts the divider a little above the middle: the buttons below weigh more.
            Color.clear
                .frame(height: Spacing.section)
            #endif
        }
        .multilineTextAlignment(.center)
        .padding(Metrics.padding)
    }

    private var questionBlock: some View {
        VStack(spacing: Metrics.questionHintSpacing) {
            SpokenWord(text: question, font: Metrics.question(isGreek: question.containsGreek))
            if !hint.isEmpty {
                Text(hint)
                    .font(Metrics.hint)
                    .foregroundStyle(Color.cardSecondary)
                    .minimumScaleFactor(0.6)
                    .selectable()
            }
        }
    }

    private var answerBlock: some View {
        let parts = parts
        return VStack(spacing: Metrics.answerExampleSpacing) {
            SpokenWord(text: parts.head, font: Metrics.answerHead(isGreek: parts.head.containsGreek))
            if let example = parts.example {
                Text(example)
                    .font(Metrics.example)
                    .foregroundStyle(Color.cardSecondary)
                    .minimumScaleFactor(0.6)
                    .selectable()
            }
        }
    }

    /// Sizes per platform: the iPhone follows Dynamic Type, the Mac has fixed sizes (it has no
    /// Dynamic Type; its built-in styles are 26, 22, 17, 15 and 13 points). The iPhone's gaps
    /// are from `Spacing`: 24 round the card's content, 16 between the question, the divider and
    /// the answer, 12 between a word and the line under it.
    private enum Metrics {
        #if os(macOS)
        static let padding: CGFloat = 20
        static let spacing: CGFloat = 10
        static let questionHintSpacing: CGFloat = 16
        static let answerExampleSpacing: CGFloat = 12
        static func question(isGreek: Bool) -> Font { .system(size: isGreek ? 32 : 26, weight: .semibold) }
        static func answerHead(isGreek: Bool) -> Font { isGreek ? .system(size: 32, weight: .semibold) : .title }
        static let hint = Font.title3
        static let example = Font.title3
        #else
        static let padding = Spacing.section
        static let spacing = Spacing.margin
        static let questionHintSpacing = Spacing.gap
        static let answerExampleSpacing = Spacing.gap
        static func question(isGreek: Bool) -> Font { isGreek ? .largeTitle.weight(.semibold) : .title.weight(.semibold) }
        static func answerHead(isGreek: Bool) -> Font { isGreek ? .largeTitle.weight(.semibold) : .title2 }
        static let hint = Font.title3
        static let example = Font.body
        #endif
    }
}

/// A word of the card with the speaker that says it, beside it. On the iPhone the speaker takes
/// the font of the word, so it grows and shrinks with it, and the row is aligned by the first
/// baseline, so the speaker stands by the word's first line: a word that wraps ("απαντάω
/// (απάντησα)") has the speaker by its first line, not between the two. On the Mac the speaker
/// is a small button at its own size, centred beside the word.
struct SpokenWord: View {
    var text: String
    var font: Font

    var body: some View {
        #if os(iOS)
        HStack(alignment: .firstTextBaseline, spacing: Spacing.tight) {
            word
            SpeakButton(text: text, font: font)
        }
        #else
        // The Mac's speaker is a small button at its own size, centred beside the word.
        HStack(spacing: Spacing.tight) {
            word
            SpeakButton(text: text)
        }
        #endif
    }

    private var word: some View {
        Text(text)
            .font(font)
            .minimumScaleFactor(0.6)
            .selectable()
    }
}

extension View {
    /// The Mac lets the learner select the text of a card.
    @ViewBuilder
    fileprivate func selectable() -> some View {
        #if os(macOS)
        textSelection(.enabled)
        #else
        self
        #endif
    }
}
