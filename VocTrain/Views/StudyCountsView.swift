import SwiftUI
import VocabCore

/// One of the three counts of today's session, in the order and with the meaning of
/// Anki's deck list: new, learning, review.
private enum StudyCount: CaseIterable {
    case new, learning, review

    func value(in counts: StudyCounts) -> Int {
        switch self {
        case .new: counts.new
        case .learning: counts.learning
        case .review: counts.review
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .new: "New"
        case .learning: "Learning"
        case .review: "Review"
        }
    }

    /// Blue for new cards, the red of Again for cards in learning, the green of Good for
    /// reviews. Each has at least 4.8:1 against the light and the grouped background in
    /// both appearances; the title beside it tells them apart for colour-vision
    /// deficiencies. A count of 0 is grey, so the cards left stand out.
    var color: Color {
        switch self {
        case .new: Color(light: 0x1F6AC2, dark: 0x6AA6F0)
        case .learning: Color(light: 0xD70015, dark: 0xFF6B60)
        case .review: Color(light: 0x167A38, dark: 0x55CC78)
        }
    }

    func style(for value: Int) -> Color {
        value > 0 ? color : Color.secondary
    }
}

/// The counts of today's session as three columns, a figure above its title; the deck
/// screen shows them large.
struct StudyCountsColumns: View {
    var counts: StudyCounts

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(StudyCount.allCases, id: \.self) { count in
                let value = count.value(in: counts)
                VStack(spacing: 2) {
                    Text(value, format: .number)
                        .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .foregroundStyle(count.style(for: value))
                    Text(count.title)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// The counts of today's session in a line, each figure before its title; a row of
/// the deck list shows them under the name of the deck.
struct StudyCountsLine: View {
    var counts: StudyCounts

    var body: some View {
        HStack(spacing: 12) {
            ForEach(StudyCount.allCases, id: \.self) { count in
                let value = count.value(in: counts)
                HStack(spacing: 4) {
                    Text(value, format: .number)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                        .foregroundStyle(count.style(for: value))
                    Text(count.title)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .font(.subheadline)
        .lineLimit(1)
    }
}
