import SwiftUI
import WidgetKit

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

/// How large a figure is drawn: the screens' (`regular`), or a widget's, which has the room of a few lines (`compact`).
enum FigureSize {
    case regular, compact

    var labelFont: Font { self == .regular ? .subheadline : .caption }
    var valueFont: Font { .system(self == .regular ? .title2 : .headline, design: .rounded, weight: .semibold) }
    var unitFont: Font { .system(self == .regular ? .callout : .caption, design: .rounded, weight: .semibold) }
    var captionFont: Font { self == .regular ? .footnote : .caption2 }
}

/// A figure: a label over a large value, "Day streak / 12", "Keep your streak / 2 min". The value is rounded and in its
/// entity's colour (`Color.appAccent` for the ring's minutes, the flame's colour for the days, `StreakState.tint`), else the primary colour; a
/// `unit` follows it smaller, in small capitals ("12 days" reads "12 DAYS"); a `caption` sits after it in secondary
/// ("412 +12 today"). `leading` goes before the value, a flame say. In a widget `accentable` marks the value for the tinted
/// rendering (`widgetAccentable`), where the label stays in the primary group.
struct Figure<Leading: View>: View {
    var label: Text
    var value: Text
    var unit: Text?
    var caption: Text?
    var tint: Color = .primary
    var size: FigureSize = .regular
    var accentable = false
    @ViewBuilder var leading: Leading

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            label
                .font(size.labelFont)
                .foregroundStyle(.primary)
                // A widget has the room of one line, and a label that wraps there costs the figure its height.
                .lineLimit(size == .compact ? 1 : nil)
                .minimumScaleFactor(size == .compact ? 0.75 : 1)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                leading
                // Proportional figures: nothing here ticks in place, and tabular ones open a gap inside "11".
                value
                    .font(size.valueFont)
                    .foregroundStyle(tint)
                    .widgetAccentable(accentable)
                if let unit {
                    unit
                        .font(size.unitFont)
                        .foregroundStyle(tint)
                        .widgetAccentable(accentable)
                }
                if let caption {
                    caption
                        .font(size.captionFont)
                        // The secondary grey is 3.5:1 on white, small in a widget wants more.
                        .foregroundStyle(size == .compact ? Color.cardSecondary : Color.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

extension Figure where Leading == EmptyView {
    init(label: Text, value: Text, unit: Text? = nil, caption: Text? = nil, tint: Color = .primary, size: FigureSize = .regular, accentable: Bool = false) {
        self.init(label: label, value: value, unit: unit, caption: caption, tint: tint, size: size, accentable: accentable) { EmptyView() }
    }
}

/// A tile, two to a row: a figure on its own ground, with at most one small line under it ("started at 2.5").
struct FigureTile: View {
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
        .tile()
        .accessibilityElement(children: .combine)
    }
}

extension View {
    /// A tile's ground: the content at the top left, 14 pt in, on `Color.tileGround` with 14 pt corners, as tall as the
    /// place it is given, so the tiles of a row (`TileGrid`) end on one line.
    func tile() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(14)
            .background(Color.tileGround, in: RoundedRectangle(cornerRadius: 14))
    }
}

/// Tiles in rows: as many columns as fit at `minimum` wide (or `columns`), the gap between them the same both ways, and
/// each row as tall as its tallest tile, which every tile of the row fills (`tile()`), so their tops and bottoms line up.
/// `LazyVGrid` centres tiles of different heights in their row instead.
struct TileGrid: Layout {
    var columns: Int?
    var minimum: CGFloat = 150
    var spacing: CGFloat = Spacing.gap

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? minimum * 2 + spacing
        let rows = heights(subviews, width: width)
        return CGSize(width: width, height: rows.reduce(0, +) + spacing * CGFloat(max(0, rows.count - 1)))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let count = count(bounds.width)
        let width = columnWidth(bounds.width, count)
        var y = bounds.minY
        for (row, height) in heights(subviews, width: bounds.width).enumerated() {
            for column in 0..<count where row * count + column < subviews.count {
                let x = bounds.minX + CGFloat(column) * (width + spacing)
                subviews[row * count + column].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: width, height: height))
            }
            y += height + spacing
        }
    }

    private func count(_ width: CGFloat) -> Int { columns ?? max(1, Int((width + spacing) / (minimum + spacing))) }

    private func columnWidth(_ width: CGFloat, _ count: Int) -> CGFloat { (width - spacing * CGFloat(count - 1)) / CGFloat(count) }

    /// The height of each row: its tallest tile at the column's width.
    private func heights(_ subviews: Subviews, width: CGFloat) -> [CGFloat] {
        let count = count(width)
        let column = ProposedViewSize(width: columnWidth(width, count), height: nil)
        return stride(from: 0, to: subviews.count, by: count).map { start in
            subviews[start..<min(start + count, subviews.count)].map { $0.sizeThatFits(column).height }.max() ?? 0
        }
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
