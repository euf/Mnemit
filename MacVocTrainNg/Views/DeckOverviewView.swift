import SwiftUI
import VocabCore

/// The first screen of a deck window, the iPhone's deck screen: what today's plan takes from the deck, Study This
/// Deck (Push On once nothing is due), the practices, and the ways to the cards, the statistics and the options. A
/// deck opens on it, so a window shows a deck to study before a table to edit.
struct DeckOverviewView: View {
    @ObservedObject var document: VocabularyDocument
    var canEdit: Bool
    var start: (SessionViewModel.Entry) -> Void
    var show: (DocumentView.Screen) -> Void
    var showOptions: () -> Void

    var body: some View {
        let counts = document.dueCards.counts
        let now = document.clock.now
        let mistakes = document.deck.mistakes(onDayOf: now, calendar: document.calendar).count
        let newest = document.deck.newestBatchIDs.count
        let hasCards = !document.deck.cards.isEmpty
        Form {
            Section {
                CountsRow(counts: counts)
            } header: {
                Text("Today")
            } footer: {
                Group {
                    if document.deck.learningOptions.isPaused {
                        Text("Paused. Today's plan leaves this deck out.")
                    } else if counts.total == 0, let nextDue = counts.nextDue {
                        Text("Nothing due. Next review \(Format.due(nextDue, now: now))")
                    } else {
                        Text("What today's plan takes from this deck.")
                    }
                }
                .foregroundStyle(.secondary)
            }

            Section {
                VStack(spacing: Spacing.hairline) {
                    Button {
                        start(counts.total > 0 ? .study : .pushOn)
                    } label: {
                        Text(counts.total > 0 ? "Study This Deck" : "Push On")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(counts.total > 0 ? nil : .secondary)
                    .controlSize(.extraLarge)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canEdit || !hasCards)
                    if counts.total == 0 {
                        Text("More reviews in the days ahead")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, Spacing.hairline)
            }

            if canEdit, mistakes > 0 || newest > 0 {
                Section {
                    if newest > 0 {
                        OverviewRow(title: "Practice Newest Words", symbol: "rectangle.stack.badge.play") { start(.practiceNewest) }
                    }
                    if mistakes > 0 {
                        OverviewRow(title: "Practice Today's Mistakes", symbol: "arrow.counterclockwise") { start(.practiceMistakes) }
                    }
                } header: {
                    Text("Practice")
                } footer: {
                    Text("Practice doesn't change when cards come back")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                OverviewRow(title: "Cards", symbol: "rectangle.stack", value: document.deck.cards.count) { show(.cards) }
                OverviewRow(title: "Statistics", symbol: "chart.bar") { show(.statistics) }
                OverviewRow(title: "Learning Options…", symbol: "slider.horizontal.3", action: showOptions)
                    .disabled(!canEdit)
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
    }
}

/// A row of the overview, as the iPhone's deck screen draws one: the title in the text colour, its symbol in the
/// accent, a count where there is one, and a chevron; the whole row is the button.
private struct OverviewRow: View {
    var title: LocalizedStringKey
    var symbol: String
    var value: Int?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.tight) {
                Image(systemName: symbol)
                    .foregroundStyle(.tint)
                    .frame(width: 22)
                Text(title)
                Spacer()
                if let value {
                    Text(value, format: .number)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
