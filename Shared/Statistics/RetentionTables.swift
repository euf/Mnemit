import SwiftUI
import VocabCore

/// The retention tables of the statistics screens, in both apps: how often the learner
/// recalled cards in the review phase, by period and by young/mature interval, then the
/// same by review mode and card kind for one period, read against the deck's target recall.
/// The host puts the title above.
struct RetentionTables: View {
    var retention: TrueRetention
    @State private var breakdownPeriod = TrueRetention.Period.last30Days

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Cards in the review phase that you recalled (Hard, Good or Easy) when they were asked again.")
                    .foregroundStyle(.secondary)
                Text("Target recall: \(Format.percent(retention.desiredRetention))")
                    .font(.callout.weight(.medium))
            }

            RetentionGrid(
                rows: TrueRetention.Period.allCases.map { RetentionRow(id: "\($0)", title: $0.title, split: retention.all[$0]) })

            let groups = groupRows
            if !groups.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("By review mode and card kind")
                        .font(.headline)
                    Picker("Period", selection: $breakdownPeriod) {
                        ForEach(TrueRetention.Period.allCases, id: \.self) { period in
                            Text(period.title).tag(period)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    RetentionGrid(rows: groups)
                }
            }

            Text("Young cards had an interval under 21 days when they were asked, mature cards 21 days or more. Learning steps, first reviews and further reviews on the same study day are not counted.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    /// Review modes, then card kinds, that have reviews in the deck, for `breakdownPeriod`.
    private var groupRows: [RetentionRow] {
        let modes: [(mode: ReviewMode, title: String)] = [
            (.typed, String(localized: "Typed reviews")),
            (.revealed, String(localized: "Revealed reviews")),
        ]
        let kinds: [(kind: CardKind, title: String)] = [
            (.recognition, String(localized: "Recognition cards")),
            (.production, String(localized: "Production cards")),
        ]
        let byMode = modes.compactMap { entry in
            retention.byMode[entry.mode].map { RetentionRow(id: entry.title, title: entry.title, split: $0[breakdownPeriod]) }
        }
        let byKind = kinds.compactMap { entry in
            retention.byKind[entry.kind].map { RetentionRow(id: entry.title, title: entry.title, split: $0[breakdownPeriod]) }
        }
        return byMode + byKind
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
                Text("Young cards")
                Text("Mature cards")
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
        case .last7Days: String(localized: "Last 7 days")
        case .last30Days: String(localized: "Last 30 days")
        case .last365Days: String(localized: "Last 365 days")
        }
    }
}
