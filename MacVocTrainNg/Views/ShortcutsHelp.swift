import AppKit
import SwiftUI
import VocabCore

/// The cheat sheet of the keys: in a flash card session those of the session, anywhere else those
/// of the menus (`MenuKey`). It comes up by itself in the first session, with "?" in a session and
/// with Keyboard Shortcuts in the Help menu, and any key closes it again.
///
/// A key goes through the window's key equivalents before any view sees it, and the keys of
/// a session are such equivalents, so the sheet watches the keys itself, with a monitor for
/// its window's key events. While the sheet is up the monitor takes every key, so the one
/// that closes it doesn't also grade the card; a key with ⌘ goes on to the menu.
@MainActor @Observable
final class ShortcutsHelp {
    /// Whether the cheat sheet has come up by itself in a session already; kept in the user defaults.
    static let seenKey = "shortcutsHelpSeen"

    /// Whether the cheat sheet is up.
    var isShown = false
    /// Whether "?" opens it: while a session asks flash cards.
    var opensWithQuestionMark = false

    /// The window of the document's view, once it has one.
    @ObservationIgnored private(set) weak var window: NSWindow?
    @ObservationIgnored private var monitor: Any?

    /// Shows the cheat sheet at the start of the first flash card session, once.
    func showForFirstSession(_ defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: Self.seenKey) else { return }
        defaults.set(true, forKey: Self.seenKey)
        isShown = true
    }

    /// Starts watching the keys of `window`; the document's view calls it when it knows its window.
    func watch(_ window: NSWindow) {
        self.window = window
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let isTaken = MainActor.assumeIsolated { self?.take(event) ?? false }
            return isTaken ? nil : event
        }
    }

    func stopWatching() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    /// Whether the cheat sheet took `event`.
    private func take(_ event: NSEvent) -> Bool {
        // Only while the document's own window has the keys, and not while a sheet has them or
        // for a key with ⌘. The window is asked, not `event.window`: an event that carries no
        // window number, as those of other tools do, has none.
        guard let window, window.isKeyWindow, window.attachedSheet == nil, !event.modifierFlags.contains(.command) else { return false }
        if isShown {
            isShown = false
            return true
        }
        // A flash card session has no field to type "?" into, so the first responder isn't checked.
        guard opensWithQuestionMark, Self.isQuestionMark(event) else { return false }
        isShown = true
        return true
    }

    /// "?", or Shift with the key that carries it on a US keyboard: another layout's
    /// characters for that key are other ones.
    private static func isQuestionMark(_ event: NSEvent) -> Bool {
        event.characters == "?" || (event.keyCode == 44 && event.modifierFlags.contains(.shift))
    }
}

extension View {
    /// Puts the cheat sheet over the view, and lets `help` watch the keys of the view's window. `menu` is what the
    /// menus say now, for the titles of the rows.
    func shortcutsHelp(_ help: ShortcutsHelp, menu: @escaping () -> MenuState) -> some View {
        modifier(ShortcutsHelpModifier(help: help, menu: menu))
    }
}

private struct ShortcutsHelpModifier: ViewModifier {
    var help: ShortcutsHelp
    var menu: () -> MenuState

    func body(content: Content) -> some View {
        content
            .background(
                WindowReader { window in
                    if let window {
                        help.watch(window)
                    } else {
                        help.stopWatching()
                    }
                }
            )
            .overlay {
                if help.isShown {
                    ShortcutsOverlay(inSession: help.opensWithQuestionMark, menu: menu) { help.isShown = false }
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.15), value: help.isShown)
    }
}

/// Tells what window the view it sits in has, and when it has none any more.
private struct WindowReader: NSViewRepresentable {
    var onWindow: @MainActor (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        Finder(onWindow: onWindow)
    }

    func updateNSView(_ view: NSView, context: Context) {}

    private final class Finder: NSView {
        let onWindow: @MainActor (NSWindow?) -> Void

        init(onWindow: @escaping @MainActor (NSWindow?) -> Void) {
            self.onWindow = onWindow
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) is not used")
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            onWindow(window)
        }
    }
}

/// The keys of a flash card session or of the menus, over a dimmed window; a click closes it too.
private struct ShortcutsOverlay: View {
    var inSession: Bool
    var menu: () -> MenuState
    var close: () -> Void
    @AppStorage(GradeChoice.showsFourButtonsKey) private var showsFourButtons = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .contentShape(Rectangle())
                .onTapGesture(perform: close)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 18) {
                Text("Keyboard Shortcuts")
                    .font(.title2.weight(.semibold))

                // Twelve rows of the menus fit the window's least height at this spacing.
                Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 18, verticalSpacing: inSession ? 12 : 6) {
                    if inSession {
                        sessionRows(grades: GradeChoice.buttonGrades(isNew: menu().onNewCard, showsFourButtons: showsFourButtons), isNew: menu().onNewCard)
                    } else {
                        let state = menu()
                        ForEach(MenuKey.allCases, id: \.self) { key in
                            row(keys: key.caps) {
                                Text(key.title(state))
                            }
                        }
                    }
                }

                HStack {
                    Text("Any key closes this help.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Got It", action: close)
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(24)
            .frame(width: 520)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(radius: 24, y: 8)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        }
    }

    /// The first showing of a card has Don't know and Know where the later ones have Forgot and Good. The grade row
    /// lists the arrows of the grades that have a button (`grades`), as many as there are keys that give a grade.
    @ViewBuilder
    private func sessionRows(grades: [Grade], isNew: Bool) -> some View {
        row(keys: [String(localized: "Space")]) {
            if isNew {
                Text("Show the answer, then grade Know")
            } else {
                Text("Show the answer, then grade Good")
            }
        }
        row(keys: grades.map(\.arrow)) {
            if isNew {
                Text("Grade: ← Don't know, → Know")
            } else if grades.count == 2 {
                Text("Grade: ← Forgot, → Good")
            } else {
                Text("Grade: ← Forgot, → Good, ↑ Easy, ↓ Hard")
            }
        }
        row(keys: ["Z", "Esc"], areAlternatives: true) {
            Text("Undo the last grade")
        }
        row(keys: ["S"]) {
            Text("Pronounce")
        }
        row(keys: ["⌘."]) {
            Text("Done")
        }
        row(keys: ["?"]) {
            Text("This help")
        }
    }

    private func row(keys: [String], areAlternatives: Bool = false, @ViewBuilder meaning: () -> some View) -> some View {
        GridRow {
            HStack(spacing: 4) {
                ForEach(Array(keys.enumerated()), id: \.offset) { index, key in
                    if areAlternatives, index > 0 {
                        Text("or")
                            .foregroundStyle(.secondary)
                    }
                    Text(verbatim: key)
                        .font(.system(.callout, design: .rounded, weight: .medium))
                        .frame(minWidth: 18)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay { RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(.separator) }
                }
            }
            .gridColumnAlignment(.leading)
            meaning()
        }
    }
}
