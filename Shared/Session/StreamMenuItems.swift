import SwiftUI

/// The items of the stream's menu "More", the same in both apps: edit the card, what the app knows about it,
/// suspend it, and the switch that has the app speak by itself. The first three need a card on screen and are
/// there, disabled, at the rest too, so the menu never changes; the switch is there where the device has a
/// Greek voice. The iPhone adds Undo above them.
struct StreamMenuItems: View {
    /// A card is being asked.
    var hasCard: Bool
    var onEdit: () -> Void
    var onInfo: () -> Void
    var onSuspend: () -> Void

    @AppStorage(GreekSpeech.autoSpeakKey) private var autoSpeak = true

    var body: some View {
        Button("Edit Card", systemImage: "pencil", action: onEdit)
            .disabled(!hasCard)
        Button("Card Info", systemImage: "info.circle", action: onInfo)
            .disabled(!hasCard)
        Button("Suspend Card", systemImage: "pause.circle", action: onSuspend)
            .disabled(!hasCard)
            .help("Don't ask this card again until you resume it in the card list")
        if GreekSpeech.shared.voice != nil {
            Divider()
            Toggle("Pronounce Automatically", systemImage: "speaker.wave.2", isOn: $autoSpeak)
        }
    }
}
