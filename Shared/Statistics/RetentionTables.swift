import SwiftUI
import VocabCore

/// The retention tables of the statistics screens, in both apps: how often the learner
/// recalled cards in the review phase, by period and by young/mature interval, read against
/// the deck's desired retention.
/// The host puts the title above.
struct RetentionTables: View {
    var retention: TrueRetention

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Recalled means Hard, Good or Easy.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Desired retention: \(Format.percent(retention.desiredRetention))")
                    .font(.callout.weight(.medium))
            }

            RetentionGrid(
                rows: TrueRetention.Period.allCases.map { RetentionRow(id: "\($0)", title: $0.title, split: retention.all[$0]) })

            Text("Young: an interval under 21 days when asked; mature: 21 days or more. Learning steps, first reviews and repeats on the same day don't count.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

private struct RetentionRow: Identifiable {
    var id: String
    var title: String
    var split: TrueRetention.Split
}

/// Rows of retention figures under the columns young, mature and total.
private struct RetentionGrid: View {
    var rows: [RetentionRow]

    #if os(macOS)
    private let columnSpacing: CGFloat = 28
    #else
    private let columnSpacing: CGFloat = 12
    #endif

    var body: some View {
        Grid(alignment: .trailing, horizontalSpacing: columnSpacing, verticalSpacing: 8) {
            GridRow {
                Text(verbatim: "")
                Text("Young")
                Text("Mature")
                Text("Total")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.trailing)

            Divider()

            ForEach(rows) { row in
                GridRow {
                    Text(row.title)
                        .font(.callout)
                        .multilineTextAlignment(.leading)
                        .gridColumnAlignment(.leading)
                    RetentionCell(tally: row.split.young)
                    RetentionCell(tally: row.split.mature)
                    RetentionCell(tally: row.split.total)
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

/// A retention with one decimal and, beneath it, the reviews it passed out of all; a dash
/// when there are none.
private struct RetentionCell: View {
    var tally: TrueRetention.Tally

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(verbatim: tally.retention.map(Self.percent) ?? "—")
                .font(.callout)
            Text(verbatim: tally.reviews > 0 ? "\(tally.passed)/\(tally.reviews)" : " ")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .monospacedDigit()
    }

    private static func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(1)))
    }
}

extension TrueRetention.Period {
    fileprivate var title: String {
        switch self {
        case .today: String(localized: "Today")
        case .yesterday: String(localized: "Yesterday")
        case .last7Days: String(localized: "7 days")
        case .last30Days: String(localized: "30 days")
        case .last365Days: String(localized: "1 year")
        }
    }
}
