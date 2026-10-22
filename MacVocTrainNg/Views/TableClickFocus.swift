import AppKit
import SwiftUI

/// Makes the table first responder when the learner clicks into it.
///
/// A click on a row of a SwiftUI `Table` selects the row, but on macOS 27 it doesn't ask for
/// the keyboard focus: it never reaches `NSTableView.mouseDown`, which is what makes an
/// AppKit table first responder, so the field the learner was typing in keeps the focus. The
/// selection is then drawn grey, and Delete, ⌘E and the arrow keys go to the field.
/// Measured with a real click on 22.10.2026: the selection changed, and no `makeFirstResponder`
/// came from the table, nor from SwiftUI's own focus state.
///
/// Put as the background of the table. Only a click of the learner moves the focus: the
/// monitor sees mouse downs, so a selection that changes by itself (a filter, a new card)
/// and typing in the search field or the form leave the focus alone.
struct TableClickFocus: NSViewRepresentable {
    func makeNSView(context: Context) -> ClickFocusView { ClickFocusView() }

    func updateNSView(_ view: ClickFocusView, context: Context) {}
}

final class ClickFocusView: NSView {
    private var monitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        stop()
        guard window != nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            MainActor.assumeIsolated { self?.mouseDown(in: event) }
            return event
        }
    }

    /// A view that leaves its window moves to none first, so the monitor ends with the view.
    private func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    /// Moves the focus into the table if `event` is a click on it, once the table has handled
    /// the click, as the click may rebuild the table (a sort).
    func mouseDown(in event: NSEvent) {
        guard let window, event.window === window, !event.modifierFlags.contains(.control),
            let hit = window.contentView?.superview?.hitTest(event.locationInWindow),
            let table = hit.enclosingScrollView?.documentView as? NSTableView
        else { return }
        DispatchQueue.main.async { [weak table, weak window] in
            guard let table, let window, table.window === window, window.firstResponder !== table else { return }
            window.makeFirstResponder(table)
        }
    }
}
