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

/// A figure: a label over a large value, "Day streak / 12", "To keep your streak / ≈ 2 min". The value is rounded and in its
/// entity's colour (`Color.appAccent` for the ring's minutes, `Color.streak` for the days), else the primary colour; a
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
                value
                    .font(size.valueFont)
                    .monospacedDigit()
                    .foregroundStyle(tint)
                    .widgetAccentable(accentable)
                if let unit {
                    unit
                        .font(size.unitFont)
                        .textCase(.uppercase)
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
