import AppKit
import SwiftUI

/// The content of the welcome window: what to do on the left, the decks to open on the
/// right: those in the Mnemit folder, once the learner chose it, and the recent ones.
struct WelcomeView: View {
    private var folder = DeckFolder.shared
    @State private var recent = NSDocumentController.shared.recentDocumentURLs

    var body: some View {
        HStack(spacing: 0) {
            actions
                .frame(width: 340)
            Divider()
            decks
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.quaternary.opacity(0.5))
        }
        .frame(width: 760, height: 440)
        .onAppear(perform: refresh)
        // The decks may have changed while the window was behind others.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in refresh() }
    }

    private var actions: some View {
        VStack(spacing: 6) {
            Spacer()
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 88, height: 88)
                .accessibilityHidden(true)
            Text(verbatim: "Mnemit")
                .font(.system(size: 30, weight: .bold))
            Text("Remember a little every day")
                .foregroundStyle(.secondary)
            Text("Version \(version)")
                .font(.caption)
                .foregroundStyle(.tertiary)
            VStack(spacing: 8) {
                Button {
                    folder.choose()
                } label: {
                    Text("Open Mnemit Folder…")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                Button {
                    importCards()
                } label: {
                    Text("Import Cards…")
                        .frame(maxWidth: .infinity)
                }
                Button("Open Deck…") {
                    NSDocumentController.shared.openDocument(nil)
                }
                .buttonStyle(.link)
                Button("Shared Decks on AnkiWeb…") {
                    DeckWebWindow.show()
                }
                .buttonStyle(.link)
            }
            .controlSize(.large)
            .frame(width: 240)
            .padding(.top, 20)
            Spacer()
        }
        .multilineTextAlignment(.center)
    }

    private var decks: some View {
        List {
            if let url = folder.url {
                Section {
                    ForEach(folder.decks, id: \.self) { deck in
                        DeckRow(deck: deck, subtitle: url.lastPathComponent)
                    }
                } header: {
                    Text("Decks in “\(url.lastPathComponent)”")
                }
            }
            if !others.isEmpty {
                Section {
                    ForEach(others, id: \.self) { deck in
                        DeckRow(deck: deck, subtitle: deck.deletingLastPathComponent().lastPathComponent)
                    }
                } header: {
                    Text("Recent Decks")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .overlay {
            if folder.url == nil, recent.isEmpty {
                ContentUnavailableView {
                    Label("No Decks Yet", systemImage: "rectangle.stack")
                } description: {
                    Text("Open your Mnemit folder to see the decks in it, or import cards from a table.")
                }
            }
        }
    }

    /// The recent decks that the folder doesn't list already.
    private var others: [URL] {
        recent.filter { deck in folder.decks.allSatisfy { $0.standardizedFileURL != deck.standardizedFileURL } }
    }

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    private func refresh() {
        folder.refresh()
        recent = NSDocumentController.shared.recentDocumentURLs
    }

    /// Imports into a new deck, which the learner saves after: the import starts as its
    /// window opens, see `DocumentView`.
    private func importCards() {
        WelcomeRequest.requestImportCards()
        NSDocumentController.shared.newDocument(nil)
    }
}

/// A deck of the list: a click opens it, and the welcome window has done its work.
private struct DeckRow: View {
    var deck: URL
    var subtitle: String

    var body: some View {
        Button {
            DeckFolder.open(deck)
            WelcomeWindow.close()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.stack")
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(deck.deletingPathExtension().lastPathComponent)
                        .fontWeight(.semibold)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 2)
    }
}
