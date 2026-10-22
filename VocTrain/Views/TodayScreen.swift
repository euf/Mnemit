import SwiftUI
import VocabCore

/// What the Study button runs: every deck with cards due, one stream after the other, or
/// one deck.
enum StudyScope: Hashable {
    case all
    case deck(URL)
}

/// Today: the root of the app. What is due over all decks, the daily ring and the streak,
/// the decks with what today's plan takes from each, and Study. A tap on Study or on a deck
/// shows the first card at once; the info button of a row opens the deck's details.
///
/// Shows what it is given and holds no state, so the snapshot test can render it, see
/// `StartScreen` for where the figures come from.
struct TodayScreen: View {
    var decks: [KnownDeck]
    /// What today's plan takes from each deck; a deck missing here is not read yet, or can't be.
    var counts: [URL: StudyCounts]
    /// `nil` until evaluated.
    var progress: DailyProgress?
    var now: Date
    /// Whether the deck can be taken off the list, which it can't in the folder: the list
    /// would take it up again.
    var canForget: (KnownDeck) -> Bool
    var study: (StudyScope) -> Void
    var showDetails: (KnownDeck) -> Void
    var forget: (KnownDeck) -> Void
    var chooseFolder: () -> Void
    var openDeck: () -> Void
    var showSettings: () -> Void
    var refresh: () async -> Void

    private var due: Int {
        decks.reduce(0) { $0 + (counts[$1.url]?.total ?? 0) }
    }

    var body: some View {
        Group {
            if decks.isEmpty {
                ContentUnavailableView {
                    Label("No Decks", systemImage: "rectangle.stack")
                } description: {
                    Text("Decks are created in Mnemit on the Mac. Choose the Mnemit folder in iCloud Drive, or open a single deck.")
                } actions: {
                    Button("Choose Mnemit Folder…", action: chooseFolder)
                        .buttonStyle(.borderedProminent)
                    Button("Open Deck…", action: openDeck)
                }
            } else {
                list
            }
        }
        .navigationTitle("Today")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu("More", systemImage: "ellipsis") {
                    Button("Choose Mnemit Folder…", systemImage: "folder", action: chooseFolder)
                    Button("Open Deck…", systemImage: "plus", action: openDeck)
                    Divider()
                    Button("Settings", systemImage: "gearshape", action: showSettings)
                }
            }
        }
    }

    private var list: some View {
        List {
            Section {
                SummaryRow(
                    due: due, progress: progress, nextDue: counts.values.compactMap(\.nextDue).min(),
                    now: now, isLoaded: !counts.isEmpty)
            }
            Section("Decks") {
                ForEach(decks) { deck in
                    DeckRow(
                        name: deck.name, counts: counts[deck.url], now: now,
                        start: { study(.deck(deck.url)) }, details: { showDetails(deck) }
                    )
                    .swipeActions {
                        if canForget(deck) {
                            Button("Remove from List", systemImage: "minus.circle", role: .destructive) { forget(deck) }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await refresh() }
        .safeAreaBar(edge: .bottom) {
            StudyButton(isDue: due > 0 || counts.isEmpty, due: due) { study(.all) }
        }
    }
}

/// The one prominent button of the screen. With nothing due it is not prominent: Keep Going
/// opens the stream at its rest, which offers review ahead and new cards.
struct StudyButton: View {
    /// Whether to study: cards are due, or the decks are not read yet.
    var isDue: Bool
    var due: Int
    var action: () -> Void

    var body: some View {
        let label = Button(action: action) {
            Text(isDue ? "Study" : "Keep Going")
                .frame(maxWidth: .infinity)
        }
        Group {
            if isDue {
                label.buttonStyle(.glassProminent)
            } else {
                label.buttonStyle(.glass)
            }
        }
        .controlSize(.large)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .accessibilityValue(due > 0 ? Text("\(due) due") : Text(verbatim: ""))
    }
}

/// What is due, today's ring and the streak.
struct SummaryRow: View {
    var due: Int
    var progress: DailyProgress?
    /// When something comes back that today's plans leave out.
    var nextDue: Date?
    var now: Date
    /// `false` until the decks are read: the figures are placeholders then.
    var isLoaded: Bool
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .title2) private var diameter = 72

    var body: some View {
        let layout =
            typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 16))
        layout {
            ProgressRing(fraction: progress?.ring.fraction ?? 0, diameter: min(diameter, 96), center: RingCenter(progress, inStream: false))
            VStack(alignment: .leading, spacing: 2) {
                headline
                    .font(.title2.weight(.semibold))
                detail
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let streak = progress?.streak, streak.days > 0 {
                    // Not a Label: in a list it puts its icon in a column of its own.
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(progress?.ring.isGoalMet == true ? Color.accentColor : Color.secondary)
                        Text("\(streak.days)-day streak")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                }
            }
            .monospacedDigit()
        }
        .padding(.vertical, 8)
        .redacted(reason: isLoaded ? [] : .placeholder)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var headline: some View {
        if due > 0 {
            Text("\(due) due")
        } else if let ring = progress?.ring, ring.reviews > 0 {
            Text("All done")
        } else {
            Text("Nothing due")
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let ring = progress?.ring, ring.reviews > 0 {
            if due > 0 {
                Text("\(ring.reviews) of \(ring.goal) today")
            } else {
                Text("\(ring.reviews) reviews today")
            }
        } else if due == 0, let nextDue {
            Text("Next review \(Format.due(nextDue, now: now))")
        }
    }
}

/// A deck: a tap studies it, the info button opens its details.
///
/// Two buttons in one row: each has a style of its own, as with the automatic style a tap
/// anywhere in the row would fire both.
struct DeckRow: View {
    var name: String
    var counts: StudyCounts?
    var now: Date
    var start: () -> Void
    var details: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: start) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name)
                        if let subtitle {
                            subtitle
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                    Spacer(minLength: 0)
                    if let counts {
                        if counts.total > 0 {
                            Text(counts.total, format: .number)
                                .monospacedDigit()
                        } else {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Button(action: details) {
                Image(systemName: "info.circle")
                    .imageScale(.large)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(Text("Deck Details"))
        }
    }

    private var subtitle: Text? {
        guard let counts else { return nil }
        if counts.total > 0 {
            return Text("\(counts.new) new · \(counts.learning) learning · \(counts.review) review")
        }
        return counts.nextDue.map { Text("Next review \(Format.due($0, now: now))") }
    }
}
