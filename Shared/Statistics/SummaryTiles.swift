import SwiftUI
import VocabCore

/// The tiles at the top of a deck's statistics, the same on both apps: Cards, Due, New, Suspended (once a card is)
/// and Remembered Now, two to a row, one column at accessibility sizes. Due, New and Suspended are the counts of the card filters
/// (`references/quality-plan.md` §4.1).
struct SummaryTiles: View {
    var summary: DeckStatistics.Summary
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        LazyVGrid(
            columns: dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.adaptive(minimum: 150), spacing: Spacing.gap)],
            spacing: Spacing.gap
        ) {
            tile("Cards", summary.total.formatted())
            tile("Due", summary.due.formatted())
            tile("New", summary.new.formatted())
            if summary.suspended > 0 {
                tile("Suspended", summary.suspended.formatted(), help: "Cards no session asks.")
            }
            tile(
                "Remembered Now", summary.averageRecallProbability.map(Format.percent) ?? "–",
                help: "Average chance of recall now, over cards in review.", footnote: "Estimated")
        }
    }

    private func tile(_ title: LocalizedStringKey, _ value: String, help: LocalizedStringKey? = nil, footnote: LocalizedStringKey? = nil) -> some View {
        FigureTile(label: Text(title), value: Text(verbatim: value), footnote: footnote.map { Text($0) })
            .help(help ?? title)
    }
}
