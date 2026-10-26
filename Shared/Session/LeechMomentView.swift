import SwiftUI
import VocabCore

/// The stop in the stream right after a Forgot that made a card a leech, before the next card (`SessionDriver.leechMoment`,
/// `references/product-model.md` §5): "Keeps slipping", the card's question and answer as it shows them, media included, and
/// three ways on. Edit opens the card's edit sheet and goes on once it is saved; Set Aside suspends the card, or, when the
/// review already did (the deck's action Suspend), Keep It resumes it; Continue goes on with the stream. The Mac has the keys:
/// Return continues, E edits, S sets aside or keeps.
///
/// VoiceOver reads the title, the question, the answer, then the three actions.
struct LeechMomentView: View {
    var card: Card
    /// The deck's media, for the images and sounds of the card.
    var media: DeckMedia
    var onEdit: () -> Void
    var onToggleAside: () -> Void
    var onContinue: () -> Void

    /// The review suspended the card, so the way to put it aside is already taken: Keep It resumes it.
    private var asideTitle: LocalizedStringKey { card.isSuspended ? "Keep It" : "Set Aside" }

    var body: some View {
        VStack(spacing: Spacing.margin) {
            Spacer(minLength: 0)
            Text("Keeps slipping")
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
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
            #if os(macOS)
            .keyboardShortcut(.defaultAction)
            #endif
            HStack(spacing: Spacing.gap) {
                Button(action: onEdit) {
                    label("Edit", key: "E")
                }
                #if os(macOS)
                .keyboardShortcut("e", modifiers: [])
                #endif
                Button(action: onToggleAside) {
                    label(asideTitle, key: "S")
                }
                #if os(macOS)
                .keyboardShortcut("s", modifiers: [])
                #endif
            }
            .buttonStyle(.bordered)
        }
        .controlSize(.large)
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
