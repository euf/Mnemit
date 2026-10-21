import AppKit
import SwiftUI

/// The cheat sheet of the keys of a flash card session: it comes up by itself in the first
/// session, with "?" in a session and with Keyboard Shortcuts in the Help menu, and any key
/// closes it again.
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

    @ObservationIgnored private weak var window: NSWindow?
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
    /// Puts the cheat sheet over the view, and lets `help` watch the keys of the view's window.
    func shortcutsHelp(_ help: ShortcutsHelp) -> some View {
        modifier(ShortcutsHelpModifier(help: help))
    }
}

private struct ShortcutsHelpModifier: ViewModifier {
    var help: ShortcutsHelp

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
                    ShortcutsOverlay { help.isShown = false }
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

/// The keys of a flash card session, over a dimmed window; a click closes it too.
private struct ShortcutsOverlay: View {
    var close: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .contentShape(Rectangle())
                .onTapGesture(perform: close)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 18) {
                Text("Keyboard Shortcuts")
                    .font(.title2.weight(.semibold))

                Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 18, verticalSpacing: 12) {
                    row(keys: [String(localized: "Space")]) {
                        Text("Show the answer, then grade Good")
                    }
                    row(keys: ["←", "→", "↑", "↓"]) {
                        Text("Grade: ← Forgot, → Good, ↑ Easy, ↓ Hard")
                    }
                    row(keys: ["Z", "Esc"], areAlternatives: true) {
                        Text("Undo the last grade")
                    }
                    row(keys: ["S"]) {
                        Text("Pronounce")
                    }
                    row(keys: ["?"]) {
                        Text("This help")
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
