import SwiftUI

/// "How It Works": three plain sentences about the ring, Catch Up and Learn 10 New Words, then the numbers under
/// the ring and the rounds, in a grouped form with the rule of each section in its footer. Shows what `HowTodayWorks` holds, and a spinner until it is there.
/// No charts and no controls.
struct HowTodayWorksView: View {
    var content: HowTodayWorks?

    var body: some View {
        Form {
            if let content {
                ForEach(Array(content.sections.enumerated()), id: \.offset) { _, section in
                    Section {
                        ForEach(Array(section.rows.enumerated()), id: \.offset) { _, row in
                            RowView(row: row)
                        }
                    } header: {
                        Text(verbatim: section.title)
                    } footer: {
                        if !section.footer.isEmpty {
                            Text(verbatim: section.footer)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .monospacedDigit()
        .navigationTitle("How It Works")
        .overlay {
            if content == nil {
                ProgressView()
            }
        }
    }

    private struct RowView: View {
        var row: HowTodayWorks.Row

        var body: some View {
            switch row {
            case let .text(sentence):
                Text(verbatim: sentence)
            case let .value(label, value, note):
                LabeledContent {
                    Text(verbatim: value)
                        .multilineTextAlignment(.trailing)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: label)
                        if let note {
                            Text(verbatim: note)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            case let .numbers(text):
                Text(verbatim: text)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
            case let .table(header, rows):
                Grid(alignment: .trailing, horizontalSpacing: 16, verticalSpacing: 8) {
                    GridRow {
                        ForEach(Array(header.enumerated()), id: \.offset) { column, title in
                            Text(verbatim: title)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .gridColumnAlignment(column == 0 ? .leading : .trailing)
                        }
                    }
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, cells in
                        GridRow {
                            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                                Text(verbatim: cell)
                            }
                        }
                    }
                }
            }
        }
    }
}
