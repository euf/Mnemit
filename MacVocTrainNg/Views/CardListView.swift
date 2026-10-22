import SwiftUI
import VocabCore

struct CardListView: View {
    @ObservedObject var document: VocabularyDocument
    /// `false` while the deck can only be viewed, see `DocumentView.isEditable`, or
    /// can't be changed yet, see `VocabularyDocument.isReadyToEdit`.
    var isEditable: Bool
    @State private var selection = Set<Card.ID>()
    @State private var sortOrder = [KeyPathComparator(\CardRow.position)]
    @State private var columnCustomization = TableColumnCustomization<CardRow>()
    /// Read only in `sortOrderKeepingFocus` and `focusNewTable`, never in `body`: the
    /// table would lose the click that moves the focus into it (#171).
    @FocusState private var tableIsFocused: Bool
    @State private var searchText = ""
    /// The filter of the scope bar, see `CardFilter`.
    @State private var scope = CardFilter.all
    @State private var showingInspector = false
    @State private var table = CardTable()
    /// The card that `CardEditSheet` edits, as it was when the sheet opened.
    @State private var editedCard: Card?

    var body: some View {
        // Re-evaluated every minute because cards become due as time passes. The rows
        // stay in `table`, so a tick only formats the visible due dates again. The
        // status bar reads the counts of `DueCardCounter`, which ticks at the same time.
        TimelineView(.everyMinute) { _ in
            list(at: document.clock.now)
        }
        .searchable(text: $searchText, prompt: "Search cards")
        .inspector(isPresented: $showingInspector) {
            CardInspector(document: document, selection: selection, isEditable: isEditable, onEdit: edit, onDelete: delete, onSelect: show)
                .inspectorColumnWidth(min: 260, ideal: 300, max: 420)
        }
        .sheet(item: $editedCard) { card in
            CardEditSheet(document: document, card: card)
        }
        .toolbar {
            ToolbarItem {
                Button {
                    showingInspector.toggle()
                } label: {
                    Label("Details", systemImage: "sidebar.trailing")
                }
                .help("Show or hide card details")
            }
        }
    }

    private func list(at now: Date) -> some View {
        let rows = rows(at: now)

        return VStack(spacing: 0) {
            ScopeBar(scope: $scope, counts: document.deck.filterCounts(at: now))

            Divider()

            AddCardForm(document: document) { id in
                selection = [id]
            }
            .disabled(!isEditable)
            .padding(12)

            Divider()

            Table(rows, selection: $selection, sortOrder: sortOrderKeepingFocus, columnCustomization: $columnCustomization) {
                TableColumn("Question", value: \.question) { row in
                    SideText(text: row.question, image: row.media.questionImage, audio: row.media.questionAudio)
                }
                .customizationID("question")
                .disabledCustomizationBehavior([.reorder, .visibility])
                TableColumn("Answer", value: \.answer) { row in
                    SideText(text: row.answer, image: row.media.answerImage, audio: row.media.answerAudio)
                }
                .customizationID("answer")
                .disabledCustomizationBehavior([.reorder, .visibility])
                TableColumn("Hint", value: \.hint)
                    .customizationID("hint")
                    .disabledCustomizationBehavior([.reorder, .visibility])
                TableColumn("Kind", value: \.kindRank) { row in
                    Text(row.kind?.title ?? "")
                        .foregroundStyle(.secondary)
                }
                .width(min: 130, ideal: 160)
                .customizationID("kind")
                .disabledCustomizationBehavior([.reorder, .visibility])
                TableColumn("Maturity", value: \.categoryRank) { row in
                    MaturityLabel(category: row.category)
                }
                .width(min: 90, ideal: 110)
                .customizationID("maturity")
                .disabledCustomizationBehavior([.reorder, .visibility])
                TableColumn("Due", value: \.dueSortKey) { row in
                    // Formatted per visible cell rather than for all rows up front.
                    DueText(due: row.due, isSuspended: row.isSuspended, now: now)
                }
                .width(min: 80, ideal: 110)
                .customizationID("due")
                .disabledCustomizationBehavior([.reorder, .visibility])
            }
            .focused($tableIsFocused)
            .background(TableClickFocus())
            // A new sort order builds a new table: diffing the old order against the
            // new one moves every row on its own, which is slow with many cards (#168).
            // The column widths live in `columnCustomization`, and the focus moves over
            // through `sortOrderKeepingFocus`.
            .id(sortOrder)
            .contextMenu(forSelectionType: Card.ID.self) { ids in
                if !ids.isEmpty {
                    Button("Show Details") {
                        selection = ids
                        showingInspector = true
                    }
                    Group {
                        if ids.count == 1, let id = ids.first {
                            Button("Edit…") { edit(id) }
                        }
                        SuspensionButtons(document: document, ids: ids)
                        Button("Reset Learning State") {
                            document.resetLearningState(of: ids)
                        }
                        Divider()
                        Button("Delete", role: .destructive) {
                            delete(ids)
                        }
                    }
                    .disabled(!isEditable)
                }
            } primaryAction: { ids in
                // A double-click edits one card and shows the details of several.
                selection = ids
                if ids.count == 1, let id = ids.first {
                    edit(id)
                } else {
                    showingInspector = true
                }
            }
            .onDeleteCommand {
                delete(selection)
            }
            .overlay {
                if rows.isEmpty {
                    emptyState
                }
            }

            Divider()

            StatusBar(document: document, shownCount: rows.count, isFiltered: !searchText.isEmpty || scope != .all)
        }
    }

    @ViewBuilder private var emptyState: some View {
        if !searchText.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else if let description = scope.emptyDescription {
            ContentUnavailableView("No Matching Cards", systemImage: "checkmark.circle", description: Text(description))
        } else {
            ContentUnavailableView(
                "No Cards Yet",
                systemImage: "rectangle.stack.badge.plus",
                description: Text("Enter a question and its answer above to add your first card.")
            )
        }
    }

    /// Sets the sort order and hands the focus of the old table to the new one. A focused
    /// search field keeps its focus.
    ///
    /// `tableIsFocused` is read only here and in `focusNewTable`, never in `body`: a view
    /// that reads it is rebuilt while a click moves the focus into the table, and the
    /// table then loses that click instead of selecting the row (#171).
    private var sortOrderKeepingFocus: Binding<[KeyPathComparator<CardRow>]> {
        Binding {
            sortOrder
        } set: { newOrder in
            // The same order builds no new table, so there is no focus to hand over.
            guard newOrder != sortOrder else { return }
            let tableWasFocused = tableIsFocused
            sortOrder = newOrder
            if tableWasFocused {
                focusNewTable(waitingUntil: .now() + .seconds(1))
            }
        }
    }

    /// Gives the focus to the new table once the old one has left the window and given
    /// the focus up. Asked for earlier, the focus is lost: `tableIsFocused` is still true
    /// for the old table, setting it changes nothing, and SwiftUI drops the request with
    /// that table. The window swaps the tables some time after SwiftUI has built the new
    /// one, at times only after several turns of the run loop (#226).
    private func focusNewTable(waitingUntil deadline: DispatchTime) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(10)) {
            if !tableIsFocused {
                tableIsFocused = true
            } else if .now() < deadline {
                focusNewTable(waitingUntil: deadline)
            }
        }
    }

    /// The rows of the cards that match the search and the scope bar's filter at `now`.
    private func rows(at now: Date) -> [CardRow] {
        let deck = document.deck
        let rows = table.rows(of: deck.cards, sortedBy: sortOrder, matching: searchText)
        guard scope != .all else { return rows }
        let threshold = deck.learningOptions.leechThreshold
        // A row's position is that of its card in the deck.
        return rows.filter { scope.matches(deck.cards[$0.position], at: now, leechThreshold: threshold) }
    }

    /// Selects the card in the table, e.g. the sibling the inspector links to. A card that
    /// the search or the filter leaves out is shown by taking both off first.
    private func show(_ id: Card.ID) {
        if !rows(at: document.clock.now).contains(where: { $0.id == id }) {
            searchText = ""
            scope = .all
        }
        selection = [id]
    }

    /// Context menu, double-click and inspector all edit through here: nothing opens the
    /// sheet while the deck can only be viewed.
    private func edit(_ id: Card.ID) {
        guard isEditable, let card = document.card(withID: id) else { return }
        editedCard = card
    }

    /// Context menu, delete key and inspector all delete through here, so the selection
    /// loses the cards too: `Table` keeps the IDs of removed rows selected (#184).
    private func delete(_ ids: Set<Card.ID>) {
        guard isEditable else { return }
        document.delete(ids)
        selection.subtract(ids)
    }
}

private struct DueText: View {
    var due: Date?
    var isSuspended: Bool
    var now: Date

    var body: some View {
        if isSuspended {
            Text("Suspended")
                .foregroundStyle(.secondary)
        } else {
            Text(Format.due(due, now: now))
                .foregroundStyle(due == nil ? .secondary : .primary)
        }
    }
}

/// "Suspend" for the cards with `ids` that aren't suspended, "Resume" for those that
/// are (#290); both if some are, some not.
struct SuspensionButtons: View {
    @ObservedObject var document: VocabularyDocument
    var ids: Set<Card.ID>

    var body: some View {
        let cards = ids.compactMap { document.card(withID: $0) }
        if cards.contains(where: { !$0.isSuspended }) {
            Button("Suspend") {
                document.setSuspended(true, of: ids)
            }
            .help("Don't ask these cards in study sessions until you resume them")
        }
        if cards.contains(where: \.isSuspended) {
            Button("Resume") {
                document.setSuspended(false, of: ids)
            }
            .help("Ask these cards in study sessions again")
        }
    }
}

private struct StatusBar: View {
    @ObservedObject var document: VocabularyDocument
    var shownCount: Int
    var isFiltered: Bool

    var body: some View {
        let total = document.deck.cards.count
        let today = document.dueCards.counts
        HStack(spacing: 16) {
            if isFiltered {
                Text("\(shownCount) of \(total) cards")
            } else {
                Text("\(total) cards")
            }
            Text("Today: \(today.new) new · \(today.learning) learning · \(today.review) review")
            if today.catchUp > 0 {
                Text("+\(today.catchUp) to catch up this week")
            }
            Spacer()
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .monospacedDigit()
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

/// The filters All, Due, New, Learning, Suspended and Difficult under the toolbar, each with
/// its count in the whole deck.
///
/// A segmented control in the content area, above the table it filters: the HIG offers a
/// segmented control for switching among a few closely related views, at most five to seven
/// segments, with noun labels of the same weight [HIG segmented-controls]. SwiftUI's
/// `searchScopes` is the system's scope bar, but on the Mac it shows only while a search is
/// active, and these filters stay in force and visible without one. When the content column
/// is too narrow for the segments (a window at its minimum width with the inspector open),
/// the same choice becomes a pop-up button.
private struct ScopeBar: View {
    @Binding var scope: CardFilter
    var counts: [CardFilter: Int]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            picker.pickerStyle(.segmented).fixedSize()
            picker.pickerStyle(.menu).fixedSize()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var picker: some View {
        Picker("Filter", selection: $scope) {
            ForEach(CardFilter.allCases) { filter in
                Text(verbatim: "\(filter.title) \((counts[filter] ?? 0).formatted())")
                    .tag(filter)
            }
        }
        .labelsHidden()
    }
}
