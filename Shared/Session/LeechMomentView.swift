import SwiftUI
import VocabCore

/// The stop in the stream right after a Forgot that made a card a leech, before the next card (`SessionDriver.leechMoment`,
/// `references/product-model.md` §5): "Keeps slipping" with a sentence under it that counts the lapses and names the choice, the
/// card's question and answer as it shows them, media included, and three ways on. Edit opens the card's edit sheet and goes on
/// once it is saved; Suspend Card suspends the card, or, when the review already did (the deck's action Suspend), Keep Card
/// resumes it, the words of the deck's options; Continue goes on with the stream. The Mac has the keys: Return continues, E
/// edits, S suspends or keeps.
///
/// VoiceOver reads the title, the sentence, the question, the answer, then the three actions.
struct LeechMomentView: View {
    var card: Card
    /// The deck's media, for the images and sounds of the card.
    var media: DeckMedia
    var onEdit: () -> Void
    var onToggleAside: () -> Void
    var onContinue: () -> Void

    /// The review suspended the card, so the way to suspend it is already taken: Keep Card resumes it.
    private var asideTitle: LocalizedStringKey { card.isSuspended ? "Keep Card" : "Suspend Card" }

    /// What the card did and what the choice is, in the words of the buttons.
    private var explanation: Text {
        let lapses = card.learningState?.lapses ?? 0
        return card.isSuspended
            ? Text("Forgotten \(lapses) times and suspended by the deck. Keep Card asks it again.")
            : Text("Forgotten \(lapses) times. Suspend it, or keep asking?")
    }

    var body: some View {
        VStack(spacing: Spacing.margin) {
            Spacer(minLength: 0)
            VStack(spacing: Spacing.tight) {
                Text("Keeps slipping")
                    .font(.title2.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                explanation
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            face
            actions
                .frame(maxWidth: Metrics.actionsWidth)
            Spacer(minLength: 0)
        }
        .padding(Metrics.margin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }

    /// The card: its question above the divider, its answer below, on the surface of the stream's card.
    private var face: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        return CardFace(card: card, isRevealed: true, media: media)
            .background { shape.fill(Color.cardSurface) }
            .overlay { shape.strokeBorder(Color.primary.opacity(0.12)) }
            .frame(maxWidth: Metrics.cardWidth, minHeight: Metrics.cardMinHeight, maxHeight: Metrics.cardMaxHeight)
    }

    private var actions: some View {
        VStack(spacing: Spacing.gap) {
            Button(action: onContinue) {
                label("Continue", key: "↩")
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.appAccent)
            #if os(macOS)
            .keyboardShortcut(.defaultAction)
            #endif
            secondaryRow
                .secondaryAction()
        }
        .controlSize(.large)
    }

    /// Edit and Suspend Card side by side; on the iPhone, one under the other when a long title ("Приостановить карточку") does
    /// not leave them the width.
    @ViewBuilder
    private var secondaryRow: some View {
        #if os(iOS)
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.gap) {
                editButton
                asideButton
            }
            VStack(spacing: Spacing.gap) {
                editButton
                asideButton
            }
        }
        #else
        HStack(spacing: Spacing.gap) {
            editButton
            asideButton
        }
        #endif
    }

    private var editButton: some View {
        Button(action: onEdit) {
            label("Edit", key: "E")
        }
        #if os(macOS)
        .keyboardShortcut("e", modifiers: [])
        #endif
    }

    private var asideButton: some View {
        Button(action: onToggleAside) {
            label(asideTitle, key: "S")
        }
        #if os(macOS)
        .keyboardShortcut("s", modifiers: [])
        #endif
    }

    /// The button's title, and on the Mac the key it answers to.
    private func label(_ title: LocalizedStringKey, key: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
            #if os(macOS)
            KeyCap(Text(verbatim: key))
            #endif
        }
        .frame(maxWidth: .infinity, minHeight: Metrics.labelHeight)
    }

    private enum Metrics {
        #if os(macOS)
        static let margin: CGFloat = 24
        static let cardWidth: CGFloat = 560
        static let cardMinHeight: CGFloat = 200
        static let cardMaxHeight: CGFloat = 320
        static let actionsWidth: CGFloat = 440
        static let labelHeight: CGFloat = 28
        #else
        static let margin: CGFloat = Spacing.margin
        static let cardWidth: CGFloat = .infinity
        static let cardMinHeight: CGFloat = 200
        static let cardMaxHeight: CGFloat = 340
        static let actionsWidth: CGFloat = 400
        static let labelHeight: CGFloat = 26
        #endif
    }
}
