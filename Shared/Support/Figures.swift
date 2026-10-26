import SwiftUI

/// The parts of the screens' grammar (`references/product-model.md`, "The grammar of the screens"), taken from Apple's
/// Fitness Summary: a card's title inside it, a figure as a label over a large value in its entity's colour, and tiles.

/// The title row inside a card: the title in `.headline`, and a chevron at the end where the card opens more.
struct CardTitle: View {
    var title: LocalizedStringKey
    var showsChevron = false

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer(minLength: 8)
            if showsChevron {
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityAddTraits(.isHeader)
    }
}

/// A figure: a label over a large value, "Day streak / 12", "To keep your streak / ≈ 2 min". The value is rounded and in its
/// entity's colour (`Color.appAccent` for the ring's minutes, `Color.streak` for the days), else the primary colour; a
/// `unit` follows it smaller, in small capitals ("12 days" reads "12 DAYS"); a `caption` sits after it in secondary
/// ("412 +12 today"). `leading` goes before the value, a flame say.
struct Figure<Leading: View>: View {
    var label: Text
    var value: Text
    var unit: Text?
    var caption: Text?
    var tint: Color = .primary
    @ViewBuilder var leading: Leading

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            label
                .font(.subheadline)
                .foregroundStyle(.primary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                leading
                value
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(tint)
                if let unit {
                    unit
                        .font(.system(.callout, design: .rounded, weight: .semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(tint)
                }
                if let caption {
                    caption
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

extension Figure where Leading == EmptyView {
    init(label: Text, value: Text, unit: Text? = nil, caption: Text? = nil, tint: Color = .primary) {
        self.init(label: label, value: value, unit: unit, caption: caption, tint: tint) { EmptyView() }
    }
}

/// A tile, two to a row: a figure on its own ground, with at most one small line under it ("started at 2.5").
struct Tile: View {
    var label: Text
    var value: Text
    var unit: Text?
    var footnote: Text?
    var tint: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Figure(label: label, value: value, unit: unit, tint: tint)
            if let footnote {
                footnote
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.tileGround, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
}

extension Color {
    /// The ground of a tile and of a card outside a list: the grouped rows' white on the iPhone (the page is the grouped
    /// grey), a light fill on the Mac.
    static var tileGround: Color {
        #if os(iOS)
        Color(.secondarySystemGroupedBackground)
        #else
        Color(nsColor: .quaternarySystemFill)
        #endif
    }
}
