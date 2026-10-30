import Foundation
import Observation
import UserNotifications

/// What a URL the app was opened with asks for, see `StartScreen.open(_:)`.
enum IncomingLink: Equatable {
    /// The widget's `mnemit://study`: Study starts at once.
    case study
    /// An Anki package from "Open in Mnemit" in Files, Safari or Mail: its cards go to a deck
    /// the learner chooses.
    case ankiPackage
    /// A deck file from Files, which joins the list; any other URL ends up here, too.
    case deck

    init(_ url: URL) {
        if WidgetLink.isStudy(url) {
            self = .study
        } else if url.isAnkiPackage {
            self = .ankiPackage
        } else {
            self = .deck
        }
    }
}

/// The taps on the app's reminders, which go where the widget's tap goes: Study starts at once (`IncomingLink.study`).
/// The delegate counts them and `StartScreen` follows the count, so a tap that launched the app is not lost to a screen
/// that was not there yet.
@MainActor @Observable
final class ReminderTaps {
    static let shared = ReminderTaps()
    private(set) var count = 0

    func tapped() {
        count += 1
    }
}

/// Hears the taps on the reminders (`Reminders` puts `userInfo` on each). Set as the notification center's delegate
/// before the app has finished launching, as a tap that opens the app is delivered right after.
final class ReminderTapDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = ReminderTapDelegate()
    /// What every reminder carries.
    static var userInfo: [AnyHashable: Any] { ["mnemitRoute": "study"] }

    /// Whether the learner opened the notification itself (not dismissed it) and it is one of the reminders.
    nonisolated static func isStudyTap(actionIdentifier: String, userInfo: [AnyHashable: Any]) -> Bool {
        actionIdentifier == UNNotificationDefaultActionIdentifier && userInfo["mnemitRoute"] as? String == "study"
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let isStudy = Self.isStudyTap(actionIdentifier: response.actionIdentifier, userInfo: response.notification.request.content.userInfo)
        completionHandler()
        if isStudy {
            Task { @MainActor in ReminderTaps.shared.tapped() }
        }
    }
}

/// A package that "Open in Mnemit" brought, as the copy `IncomingPackages` made of it.
struct IncomingPackage: Identifiable {
    let id = UUID()
    var url: URL
}

/// The copies of Anki packages that "Open in Mnemit" brought. The URL the system hands over may
/// be security-scoped, in the Inbox, or in iCloud Drive without being downloaded, and it is
/// read much later than the call, so the package is copied at once. A copy lives in a folder of
/// its own under the temporary directory until the next package comes; the system clears the
/// directory in between.
enum IncomingPackages {
    static let folder = URL.temporaryDirectory.appending(path: "IncomingAnki", directoryHint: .isDirectory)

    /// Copies the package at `url` off the main thread and returns the copy, which keeps the name.
    static func copy(_ url: URL, into folder: URL = folder) async throws -> URL {
        try await Task.detached {
            let isScoped = url.startAccessingSecurityScopedResource()
            defer { if isScoped { url.stopAccessingSecurityScopedResource() } }
            let directory = folder.appending(path: UUID().uuidString, directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let target = directory.appending(path: url.lastPathComponent, directoryHint: .notDirectory)
            var coordination: NSError?
            var failure: (any Error)?
            // Coordinated, as a file of iCloud Drive is downloaded first.
            NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordination) { source in
                do {
                    try FileManager.default.copyItem(at: source, to: target)
                } catch {
                    failure = error
                }
            }
            if let coordination { throw coordination }
            if let failure { throw failure }
            return target
        }.value
    }

    /// Removes every copy.
    static func purge(_ folder: URL = folder) {
        try? FileManager.default.removeItem(at: folder)
    }
}
