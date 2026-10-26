import SwiftUI
import VocabCore

/// The screen of the day's stack: asks today's plan one card after another and ends with it
/// (`StreamRestView`: Done, or Learn 10 New Words past the end). Every grade is saved
/// at once, so "Done" leaves at any time and loses nothing. The ring in the header shows
/// today's cards done against the goal, with the streak's flame in its middle.
///
/// Keyboard flow: Space or Return shows the answer, then ← Forgot, ↓ Hard, → Good, ↑ Easy, or 1–4 for
/// Forgot, Hard, Good and Easy, and Space or Return mean Good; each grade button shows its arrow. The card
/// flies out in the direction of its grade, while the button of the grade flashes. A line under the progress
/// names the grade and when the card comes back, and offers Undo for a few seconds; Z, Esc and ⌘Z take the
/// review back. S speaks the Greek side, and the preference "Pronounce Automatically" does it by itself, see
/// `GreekSpeech.cardAppeared(_:)`.
///
/// ⌘E edits the card being asked (#289); before the answer is shown, without showing it.
///
/// The menu "More" is the iPhone's (`StreamMenuItems`): Edit Card, Card Info, Suspend Card, which leaves out
/// the card from now on, until the learner resumes it (#290), and Pronounce Automatically.
struct SessionView: View {
    @Bindable var model: SessionViewModel
    var ring: DailyRingModel
    /// The deck of the folder to go on with at the end of this deck's plan, see `NextDeck`.
    var nextDeck: NextDeck? = nil
    var onClose: () -> Void

    /// The medals a grade earns, as toasts under the bar, as on the iPhone.
    @State private var toasts = MedalToasts()
    @State private var sheet: StreamSheet?

    /// The card that `CardEditSheet` edits, as it was when the sheet opened, and whether
    /// the sheet hides its answer.
    struct EditRequest {
        var card: Card
        var hidesAnswer: Bool
    }

    /// What the stream's one sheet shows: the card edited, or what the app knows about it; Edit in the
    /// info takes the place of the info.
    enum StreamSheet: Identifiable {
        case edit(EditRequest)
        case info(Card)

        var id: String {
            switch self {
            case let .edit(request): "edit \(request.card.id)"
            case let .info(card): "info \(card.id)"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if model.isResting {
                // A rest with a medal and Push On's line is taller than a short window: it scrolls
                // under the header instead of pushing the header out of the window, and is centred
                // as before when it fits.
                GeometryReader { proxy in
                    ScrollView {
                        StreamRestView(
                            rest: model.rest, progress: ring.progress,
                            onAddNewCards: model.addNewCards, onNextRound: model.continueRound, onDone: onClose, nextDeck: nextDeck
                        )
                        .frame(minHeight: proxy.size.height)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
            } else if let card = model.currentCard {
                cardArea(card)
            }
        }
        .background(Color.studyBackdrop)
        .medalToast(toasts)
        // A medal earned by a grade is celebrated once the ring has been evaluated; a rest shows its own.
        .onChange(of: ring.progress) {
            if !model.isResting { toasts.offer(ring.progress) }
        }
        .onChange(of: model.isResting) { _, isResting in
            if isResting { toasts.clear() }
        }
        .background { keys }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case let .edit(request):
                CardEditSheet(document: model.document, card: request.card, hidesAnswer: request.hidesAnswer)
            case let .info(card):
                CardInfoSheet(document: model.document, card: card) { id in
                    if let card = model.document.card(withID: id) { self.sheet = .edit(EditRequest(card: card, hidesAnswer: false)) }
                }
            }
        }
        // With "Pronounce Automatically": a Greek question when its card comes up, after
        // the card has flown out and with the next one; else a Greek answer once it shows.
        .onChange(of: model.questionNumber, initial: true) {
            GreekSpeech.shared.cardAppeared(model.currentCard, media: model.document.deck.media)
        }
        .onChange(of: isAnswerShown) { _, isShown in
            if isShown, let card = model.currentCard {
                GreekSpeech.shared.answerRevealed(of: card, media: model.document.deck.media)
            }
        }
        .onAppear { GreekSpeech.shared.open() }
        .onDisappear {
            GreekSpeech.shared.close()
            toasts.clear()
        }
    }

    /// Edits the card being asked; its answer stays hidden until it is shown.
    private func editCurrentCard() {
        guard let card = model.currentCard else { return }
        sheet = .edit(EditRequest(card: card, hidesAnswer: model.stage == .asking))
    }

    private func showCardInfo() {
        guard let card = model.currentCard else { return }
        sheet = .info(card)
    }

    /// Keys without a button to show: Z and Esc take back the review, which ⌘Z does too; S speaks
    /// the card's Greek side. The keys that grade belong to `GradeChoice`.
    private var keys: some View {
        Group {
            Group {
                Button("Undo", action: model.undoLast)
                    .keyboardShortcut("z", modifiers: [])
                // Esc undoes instead of leaving the stream, whose button has no shortcut.
                Button("Undo", action: model.undoLast)
                    .keyboardShortcut(.escape, modifiers: [])
                // ⌘Z too, ahead of Edit ▸ Undo: in a stream over several decks the last step may be another deck's,
                // which the undo of this window's deck would miss.
                Button("Undo", action: model.undoLast)
                    .keyboardShortcut("z", modifiers: .command)
            }
            .disabled(!model.canUndoLast)
            if let spokenText {
                Button("Pronounce") { GreekSpeech.shared.speak(spokenText) }
                    .keyboardShortcut("s", modifiers: [])
            }
        }
        .hidden()
    }

    /// What S speaks: the question if it is Greek, else the answer once it shows.
    private var spokenText: String? {
        guard let card = model.currentCard else { return nil }
        if GreekSpeech.shared.canSpeak(card.question) { return card.question }
        // The head of the answer: a Greek example under a Russian gloss is not a Greek answer.
        return isAnswerShown && GreekSpeech.shared.canSpeak(String(card.answer.prefix { !$0.isNewline })) ? card.answer : nil
    }

    private var isAnswerShown: Bool {
        switch model.stage {
        case .revealed: true
        case .asking, .resting: false
        }
    }

    /// Today's ring, empty inside, the streak's flame by its state and what the iPhone's bar says: the minutes to the next
    /// moment of the day, "≈ 4 min". The ring comes first, so it does not move when the
    /// text changes its width.
    private var ringAndFigures: some View {
        HStack(spacing: 8) {
            ProgressRing(fraction: DailyRingFigure.fraction(ring.progress, shown: nil), diameter: 28)
            if let progress = ring.progress {
                StreakFlame(state: progress.streakState)
                    .font(.body.weight(.semibold))
                    .accessibilityLabel(Text(verbatim: NextStep(progress).spoken))
                Group {
                    if let minutes = NextStep(progress).minutes {
                        Text(verbatim: Format.timeLeft(minutes: minutes))
                    }
                }
                .monospacedDigit()
                .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// The bar of the iPhone's stream: Done leading and right after it today's ring with its figures, or the name of a
    /// practice; Undo and the menu (`StreamMenuItems`) trailing. The same controls in every state, question,
    /// answer and rest, so the bar never changes and nothing below it moves; what doesn't apply is disabled.
    private var header: some View {
        HStack(spacing: 12) {
            // Esc takes back a review, see `keys`; Done is ⌘., the Mac's key for stopping.
            Button("Done", action: onClose)
                .keyboardShortcut(".", modifiers: .command)
            Group {
                switch model.streamStage {
                case .practiceMistakes, .practiceNewest:
                    stageLabel
                case .plan, .rest:
                    ringAndFigures
                }
            }
            .layoutPriority(1)
            Spacer(minLength: 12)
            HStack(spacing: 8) {
                Button("Undo", systemImage: "arrow.uturn.backward", action: model.undoLast)
                    .labelStyle(.iconOnly)
                    .disabled(!model.canUndoLast)
                    .help("Undo the last answer")
                Menu("More", systemImage: "ellipsis.circle") {
                    StreamMenuItems(
                        hasCard: model.currentCard != nil && !model.isResting, onEdit: editCurrentCard, onInfo: showCardInfo,
                        onSuspend: { model.suspendCurrentCard() })
                }
                .menuIndicator(.hidden)
                .labelStyle(.iconOnly)
                .fixedSize()
                .help("More")
            }
        }
        // ⌘E edits the card from anywhere in the stream; the menu item shows no key of its own.
        .background {
            Button("Edit Card", action: editCurrentCard)
                .keyboardShortcut("e", modifiers: .command)
                .disabled(model.currentCard == nil || model.isResting)
                .hidden()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    /// Names where the stream is when it isn't the plan: what the learner catches up on or reviews
    /// ahead changes nothing about today's plan, and practice nothing about the schedule.
    @ViewBuilder
    private var stageLabel: some View {
        switch model.streamStage {
        case .practiceMistakes, .practiceNewest:
            Text("Practice")
                .font(.headline)
                .help("Practice doesn't change when cards come back")
        case .plan, .rest:
            EmptyView()
        }
    }

    private func cardArea(_ card: Card) -> some View {
        VStack(spacing: 12) {
            // Under the progress, in the same place on every card.
            UndoChip(receipt: model.receipt, onUndo: model.undoLast, onExpire: model.dismissReceipt)

            Spacer()

            FlashcardView(
                card: card, isRevealed: model.stage == .revealed, media: model.document.deck.media,
                memory: CardMemory(card: card, in: model.document.deck, at: model.document.clock.now, calendar: model.document.calendar),
                edges: min(model.cardsBehind, StackPose.maxEdges), onReveal: { model.reveal() }, onGrade: { grade in model.grade(grade) })

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

}

/// The card with the question, then the answer under it, and below it the button
/// that shows the answer or the grade buttons. The card flies out in the direction of its
/// grade. The card and the area below it keep their size from the question to the answer: the
/// grade buttons are in the layout all the time, invisible and disabled until the answer shows,
/// and Show Answer sits on top of them.
private struct FlashcardView: View {
    var card: Card
    var isRevealed: Bool
    /// The deck's media, for the images and sounds of the card.
    var media: DeckMedia
    var memory: CardMemory?
    /// The edges of the stack under the card, as on the iPhone: the cards of the round behind it, at most four.
    var edges: Int
    var onReveal: () -> Void
    var onGrade: @MainActor (Grade) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var flight = CardFlight()

    var body: some View {
        VStack(spacing: 14) {
            FlightCard(flight: flight) {
                CardFace(card: card, isRevealed: isRevealed, media: media, memory: memory)
            }
            .background { StackEdges(edges: edges) }
            .frame(maxWidth: 560, minHeight: 200, idealHeight: 300, maxHeight: 340)
            .contentShape(Rectangle())
            .onTapGesture(perform: onReveal)
            // The room of the edges under the card, the same however many there are.
            .padding(.bottom, StackPose.reserve)

            actions
                .frame(maxWidth: 440)
        }
    }

    private var actions: some View {
        ZStack(alignment: .top) {
            // Space and Return showed the answer and now mean Good; the arrows grade as the
            // swipes do on the iPhone. Disabled before, so their keys belong to Show Answer.
            GradeChoice(defaultGrade: .good, acceptsSpace: true, acceptsArrows: true, isNew: card.isNew, highlighted: flight.highlighted, onGrade: commit)
                .opacity(isRevealed ? 1 : 0)
                .disabled(!isRevealed)
                .accessibilityHidden(!isRevealed)
            if !isRevealed {
                showAnswer
            }
        }
    }

    /// The prominent button of the iPhone's stream, in the app's indigo, as wide as the grade buttons under it; it
    /// is the default button, and the keys are on it.
    private var showAnswer: some View {
        Button(action: onReveal) {
            HStack(spacing: 8) {
                Text("Show Answer")
                KeyCap(Text("Space or ↩"))
            }
            .frame(maxWidth: .infinity)
        }
        .keyboardShortcut(.defaultAction)
        .buttonStyle(.borderedProminent)
        .controlSize(.extraLarge)
        // A button takes one shortcut; Space shows the answer too.
        .background {
            Button(action: onReveal) {
                Text(verbatim: "")
            }
            .keyboardShortcut(.space, modifiers: [])
            .opacity(0)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
        }
    }

    /// Flies the card out in the direction of `grade`, then grades. Keys, buttons and
    /// VoiceOver all come here, so a second key press while the card flies does nothing.
    private func commit(_ grade: Grade) {
        guard isRevealed, !flight.isFlying else { return }
        GreekSpeech.shared.stop()
        flight.fly(grade, reduceMotion: reduceMotion) { onGrade(grade) }
    }
}
