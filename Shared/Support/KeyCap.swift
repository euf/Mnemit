#if os(macOS)
import SwiftUI

/// The key that presses a control, drawn inside the control: the glyph on a small rounded cap.
/// It takes the control's own text colour, so it reads on whatever fill the control has, also
/// when the window is inactive and a prominent button turns grey.
struct KeyCap: View {
    var label: Text

    init(_ label: Text) {
        self.label = label
    }

    var body: some View {
        label
            .font(.system(.callout, design: .rounded).weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 6)
            .frame(minWidth: 22, minHeight: 20)
            .background(.primary.opacity(0.22), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            // The control says what it does; the key is for the eyes.
            .accessibilityHidden(true)
    }
}
#endif
