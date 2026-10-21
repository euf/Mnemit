import Combine
import Foundation
import Observation
import UIKit

/// Whether an undo manager has something to undo, and what it is called, for a view to show
/// an Undo button while there is something. `UndoManager` isn't observable: this listens to
/// the notifications it posts as groups close and as it undoes and redoes.
///
/// A deck's undo manager starts empty when the deck opens, so what it can undo is what the
/// learner did on the screens of this deck since.
@MainActor @Observable
final class UndoWatch {
    private(set) var canUndo = false
    /// What the next undo takes back, e.g. "Delete Card", as the document named it.
    private(set) var actionName = ""
    @ObservationIgnored private let undoManager: UndoManager?
    @ObservationIgnored private var observations: [AnyCancellable] = []

    init(_ undoManager: UndoManager?) {
        self.undoManager = undoManager
        refresh()
        guard let undoManager else { return }
        let names: [Notification.Name] = [.NSUndoManagerDidCloseUndoGroup, .NSUndoManagerDidUndoChange, .NSUndoManagerDidRedoChange]
        observations = names.map { name in
            NotificationCenter.default.publisher(for: name, object: undoManager)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in MainActor.assumeIsolated { self?.refresh() } }
        }
    }

    func undo() {
        undoManager?.undo()
        refresh()
    }

    private func refresh() {
        canUndo = undoManager?.canUndo ?? false
        actionName = undoManager?.undoActionName ?? ""
    }
}

extension UIApplication {
    /// Whether no sheet or cover is up in any window of the app: a shake then means Undo
    /// for the screen below, and not for what a sheet is doing.
    var isShowingNoPresentation: Bool {
        connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).allSatisfy { $0.rootViewController?.presentedViewController == nil }
    }
}
