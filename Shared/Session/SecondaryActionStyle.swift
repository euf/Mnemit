import SwiftUI

/// The button under the prominent one on the study screens (Learn 10 New Words under Done, Edit and Suspend Card under
/// Continue): the accent on a wash of the accent, in a hairline of it, as wide as the prominent one and as high as the
/// system's large capsule. The system's `.bordered` fills with grey, which is also how a disabled control looks.
struct SecondaryActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.appAccent)
            .padding(.vertical, 14)
            .padding(.horizontal, Spacing.margin)
            .frame(maxWidth: .infinity)
            .background(Color.appAccent.opacity(0.14), in: Capsule())
            .overlay { Capsule().strokeBorder(Color.appAccent.opacity(0.45), lineWidth: 1) }
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

extension View {
    /// `SecondaryActionStyle` on the iPhone; the Mac keeps its bordered button, which is not grey there.
    @ViewBuilder
    func secondaryAction() -> some View {
        #if os(iOS)
        buttonStyle(SecondaryActionStyle())
        #else
        buttonStyle(.bordered)
        #endif
    }
}
