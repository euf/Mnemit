import SwiftUI
import VocabCore

/// The three counts of today's plan side by side, a figure above its title. Neutral: the
/// words tell them apart, and the colours belong to the grades. A count of 0 steps back.
struct CountsRow: View {
    var counts: StudyCounts
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout =
            typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 0))
        layout {
            cell("New", counts.new)
            cell("Learning", counts.learning)
            cell("Review", counts.review)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private func cell(_ title: LocalizedStringKey, _ value: Int) -> some View {
        VStack(alignment: typeSize.isAccessibilitySize ? .leading : .center, spacing: 2) {
            Text(value, format: .number)
                .font(.title2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(value > 0 ? .primary : .secondary)
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: typeSize.isAccessibilitySize ? .leading : .center)
    }
}
