import UIKit

extension Notification.Name {
    /// Posted when the learner shakes the iPhone; `StudyView` takes it as Undo.
    ///
    /// The system's own shake to undo asks the responder chain for an undo manager, and the
    /// deck's belongs to its document, which is not in the chain. So the window tells.
    static let deviceDidShake = Notification.Name("deviceDidShake")
}

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        if motion == .motionShake {
            NotificationCenter.default.post(name: .deviceDidShake, object: nil)
        }
    }
}
