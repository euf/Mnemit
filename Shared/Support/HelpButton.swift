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
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 300, alignment: .leading)
                .padding()
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
