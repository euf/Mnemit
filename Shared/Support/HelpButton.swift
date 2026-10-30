import SwiftUI

/// The "?" next to an option of the deck options screens: a button that opens a popover with a few plain words
/// about the row. On the iPhone the popover stays a popover, as a sheet would cover the row it explains.
struct HelpButton: View {
    var text: LocalizedStringKey
    @State private var isShown = false

    var body: some View {
        Button {
            isShown = true
        } label: {
            Image(systemName: "questionmark.circle")
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Help")
        .popover(isPresented: $isShown) {
            // A fixed width: with only a maximum the popover measures the text on one line and cuts the lines past it.
            // The scroll view is for a text taller than the room above or below the row: it scrolls instead of being cut.
            ScrollView {
                Text(text)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: 280, alignment: .leading)
                    .padding()
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxHeight: 320)
            .presentationCompactAdaptation(.popover)
        }
    }
}

extension View {
    /// The row with its `HelpButton` at the end.
    func helpButton(_ text: LocalizedStringKey) -> some View {
        HStack {
            self
            HelpButton(text: text)
        }
    }
}
