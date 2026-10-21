import SwiftUI

/// A short message over the bottom of the window that goes away by itself, for what the
/// learner should know without an alert: "Added 6 cards".
struct Toast: Equatable, Identifiable {
    let id = UUID()
    var text: String

    init(_ text: String) {
        self.text = text
    }
}

struct ToastView: View {
    /// How long a toast stays, in seconds.
    static let lifetime = 4.5

    var toast: Toast
    var dismiss: () -> Void

    var body: some View {
        Text(toast.text)
            .font(.callout)
            .foregroundStyle(Color(nsColor: .windowBackgroundColor))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(Color.primary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .frame(maxWidth: 560)
            .padding(.bottom, 18)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            .onTapGesture(perform: dismiss)
            .accessibilityAddTraits(.isStaticText)
            .task(id: toast.id) {
                AccessibilityNotification.Announcement(toast.text).post()
                do {
                    try await Task.sleep(for: .seconds(Self.lifetime))
                } catch {
                    return
                }
                dismiss()
            }
    }
}
