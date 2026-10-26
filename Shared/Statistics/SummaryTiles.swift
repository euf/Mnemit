import SwiftUI
import VocabCore

/// The tiles at the top of a deck's statistics, the same on both apps: Cards, Due, New, Suspended (once a card is)
/// and Recall Now. Due, New and Suspended are the counts of the card filters (`references/quality-plan.md` §4.1).
struct SummaryTiles: View {
    var summary: DeckStatistics.Summary

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
            Tile(title: "Cards", value: summary.total.formatted())
            Tile(title: "Due", value: summary.due.formatted())
            Tile(title: "New", value: summary.new.formatted())
            if summary.suspended > 0 {
                Tile(title: "Suspended", value: summary.suspended.formatted(), help: "Cards no study session asks until you resume them in the card list.")
            }
            Tile(
                title: "Recall Now",
                value: summary.averageRecallProbability.map(Format.percent) ?? "–",
                help: "Average recall probability of the cards in the review phase right now, except suspended ones."
            )
        }
    }
}

private struct Tile: View {
    var title: LocalizedStringKey
    var value: String
    var help: LocalizedStringKey?
    @ScaledMetric(relativeTo: .title) private var figureSize: CGFloat = 28

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: figureSize, weight: .semibold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
        .help(help ?? title)
    }
}
