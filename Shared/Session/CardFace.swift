import SwiftUI
import VocabCore

/// The face of a flash card in the study stream, on both platforms: the question above the
/// divider, the answer below it, each in a half of its own. The layout is the same whether or
/// not the answer shows, as the answer only fades in, so the question stays where it is and the
/// card never changes size at the reveal.
///
/// Every part has one size, whatever the card says: the Greek word is the largest, the gloss in
/// the learner's language the second, the example the smallest. `smallestScale` is only a valve
/// for the largest Dynamic Type sizes, where a half of the card holds less than its text asks;
/// nothing in the face is laid out again while the card is swiped, and it is one bitmap while it
/// moves (`FlightCard`), so it cannot scroll.
///
/// A side with an image shows it above its text, scaled to fit and at most `maxImageShare` of the
/// card's height; one with a sound has the speaker button for it. `media` is the deck's, which
/// holds the files the card names; without it the face shows the texts only.
struct CardFace: View {
    var question: String
    var hint: String
    var answer: String
    var isRevealed: Bool
    var cardMedia = CardMedia()
    var media: DeckMedia?
    /// What FSRS knows of the card, for the corner of the face; `nil` draws no corner.
    var memory: CardMemory?

    /// The card's height, to cap the image by.
    @State private var height: CGFloat = 0

    #if os(iOS)
    @Environment(\.dynamicTypeSize) private var textSize
    /// The room the question leaves at the card's top for the corner's badge, which grows with its text: the question
    /// never lies under it.
    @ScaledMetric(relativeTo: .caption2) private var badgeClearance: CGFloat = 16
    #endif

    /// The accessibility sizes, where the card's room is dear.
    private var isLargeText: Bool {
        #if os(iOS)
        textSize.isAccessibilitySize
        #else
        false
        #endif
    }

    /// The room above the question for the badge in the corner; the Mac's text has a fixed size and room enough.
    private var clearanceForBadge: CGFloat {
        #if os(iOS)
        memory == nil ? 0 : badgeClearance
        #else
        0
        #endif
    }

    /// How much of the card's height an image takes at most.
    static let maxImageShare: CGFloat = 0.4

    /// How far a text shrinks to fit its half of the card before it is cut with "…".
    static let smallestScale: CGFloat = 0.5

    init(card: Card, isRevealed: Bool, media: DeckMedia? = nil, memory: CardMemory? = nil) {
        self.init(question: card.question, hint: card.hint, answer: card.answer, isRevealed: isRevealed, cardMedia: card.media, media: media)
        self.memory = memory
    }

    init(question: String, hint: String, answer: String, isRevealed: Bool, cardMedia: CardMedia = CardMedia(), media: DeckMedia? = nil) {
        self.question = question
        self.hint = hint
        self.answer = answer
        self.isRevealed = isRevealed
        self.cardMedia = cardMedia
        self.media = media
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
                .padding(.top, clearanceForBadge)
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
            // Lifts the divider a little above the middle: the buttons below weigh more. Large text needs the room.
            Color.clear
                .frame(height: isLargeText ? 0 : Spacing.section)
            #endif
        }
        .multilineTextAlignment(.center)
        .padding(Metrics.padding)
        .overlay(alignment: .topLeading) {
            if let memory {
                MemoryBadge(memory: memory, showsRecall: isRevealed)
                    .padding(14)
            }
        }
        .onGeometryChange(for: CGFloat.self, of: { $0.size.height }, action: { height = $0 })
        // As the buttons below: past AX3 a two-word headword with its ending would not fit the card's width.
        .dynamicTypeSize(...GradeChoice.largestText)
    }

    /// The image of a side, which waits for the card's height: it has no room before.
    @ViewBuilder
    private func image(_ name: String?) -> some View {
        if name != nil, media != nil {
            SideImage(name: name, media: media, maxHeight: height * Self.maxImageShare)
        }
    }

    private var questionBlock: some View {
        VStack(spacing: Metrics.questionHintSpacing) {
            image(cardMedia.questionImage)
            if !question.isEmpty || cardMedia.questionAudio != nil {
                SpokenWord(text: question, font: Metrics.question(isGreek: question.containsGreek), sound: cardMedia.questionAudio, media: media)
            }
            if !hint.isEmpty {
                Text(hint)
                    .font(Metrics.hint)
                    .foregroundStyle(Color.cardSecondary)
                    .minimumScaleFactor(CardFace.smallestScale)
                    .selectable()
            }
        }
    }

    private var answerBlock: some View {
        let parts = parts
        return VStack(spacing: Metrics.answerExampleSpacing) {
            image(cardMedia.answerImage)
            if !parts.head.isEmpty || cardMedia.answerAudio != nil {
                SpokenWord(text: parts.head, font: Metrics.answerHead(isGreek: parts.head.containsGreek), sound: cardMedia.answerAudio, media: media)
            }
            if let example = parts.example {
                Text(example)
                    .font(Metrics.example)
                    .foregroundStyle(Color.cardSecondary)
                    .minimumScaleFactor(CardFace.smallestScale)
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
    /// The deck's sound of the side, in `media`: the speaker plays it, and a side without text
    /// shows the speaker alone.
    var sound: String?
    var media: DeckMedia?

    var body: some View {
        #if os(iOS)
        HStack(alignment: .firstTextBaseline, spacing: Spacing.tight) {
            word
            SpeakButton(text: text, font: font, sound: sound, media: media)
        }
        #else
        // The Mac's speaker is a small button at its own size, centred beside the word.
        HStack(spacing: Spacing.tight) {
            word
            SpeakButton(text: text, sound: sound, media: media)
        }
        #endif
    }

    @ViewBuilder
    private var word: some View {
        if let (first, second) = text.glossHalves {
            // "отвечать · to answer": on one line when both fit, else each half is a unit of its own and the dot is gone,
            // so no "·" dangles at the end of a line.
            ViewThatFits(in: .horizontal) {
                line(text).lineLimit(1)
                VStack(spacing: 0) {
                    line(first)
                    line(second)
                }
                .accessibilityElement(children: .combine)
            }
        } else if !text.isEmpty {
            line(text)
        }
    }

    private func line(_ text: String) -> some View {
        Text(text.keepingEndingsTogether)
            .font(font)
            .minimumScaleFactor(CardFace.smallestScale)
            .selectable()
    }
}

extension String {
    /// The word of a dictionary line with its endings ("υπεύθυνος, -η, -ο") as one unit for the line breaker: the space
    /// after a comma that a hyphened ending follows is a non-breaking one, so "-ο" never stands alone on a line. A unit
    /// too wide for the line shrinks (`minimumScaleFactor`) before it breaks. What the speaker says is the text as it is.
    var keepingEndingsTogether: String {
        let characters = Array(self)
        return String(
            characters.indices.map { index in
                let isTied =
                    characters[index] == " " && index > 0 && characters[index - 1] == "," && index + 2 < characters.count
                    && characters[index + 1] == "-" && characters[index + 2].isLetter
                return isTied ? "\u{00A0}" : characters[index]
            })
    }
}

extension String {
    /// A line of "the learner's language · English" as its two halves; `nil` for any other text. The deck's answers
    /// are written so, and the halves wrap on their own.
    var glossHalves: (String, String)? {
        guard let separator = range(of: " · ") else { return nil }
        let first = self[..<separator.lowerBound].trimmingCharacters(in: .whitespaces)
        let second = self[separator.upperBound...].trimmingCharacters(in: .whitespaces)
        return first.isEmpty || second.isEmpty ? nil : (first, second)
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

/// What FSRS knows of a card, for the corner of its face: its step on the ladder of memory and its chance of
/// recall now, before the answer (`references/learning-flow.md`, "Progression").
struct CardMemory: Equatable {
    var step: MaturityCategory
    var recall: Double?

    init(step: MaturityCategory, recall: Double?) {
        self.step = step
        self.recall = recall
    }

    init(card: Card, in deck: Deck, at now: Date, calendar: StudyCalendar) {
        self.init(step: MaturityCategory(card: card), recall: deck.recallProbability(of: card, at: now, calendar: calendar))
    }
}

/// The corner of a card: its step as five small bars in the step's colour, rising like a signal, or "New" for a
/// card never studied; once the answer shows, the chance of recall FSRS gave it, "82%".
struct MemoryBadge: View {
    var memory: CardMemory
    var showsRecall: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if memory.step == .new {
                Text(verbatim: MaturityCategory.new.cardTitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.secondary.opacity(0.15)))
            } else {
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(1...5, id: \.self) { level in
                        Capsule()
                            .fill(level <= memory.step.rawValue ? memory.step.color : Color.secondary.opacity(0.25))
                            .frame(width: 3, height: 4 + 2 * CGFloat(level))
                    }
                }
                if showsRecall, let recall = memory.recall {
                    Text(verbatim: Format.percent(recall))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .transition(.opacity)
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: showsRecall)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: label))
    }

    private var label: String {
        let recall = showsRecall ? memory.recall.map { "\(String(localized: "Recall Probability")) \(Format.percent($0))" } : nil
        return [memory.step.cardTitle, recall].compactMap { $0 }.joined(separator: ", ")
    }
}
