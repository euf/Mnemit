import SwiftUI
import WebKit

/// The web view of a `DeckWebBrowser`, as a view.
#if canImport(UIKit)
struct DeckWebView: UIViewRepresentable {
    var webView: WKWebView

    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ view: WKWebView, context: Context) {}
}
#else
struct DeckWebView: NSViewRepresentable {
    var webView: WKWebView

    func makeNSView(context: Context) -> WKWebView { webView }
    func updateNSView(_ view: WKWebView, context: Context) {}
}
#endif

/// The browser for the sites of free decks, in a sheet on the iPhone and a window on the Mac:
/// the page, a bar for Back, Forward and Reload, the bookmarks of `DeckSources`, "Open in
/// Safari", a bar of progress while a page loads and a note while a file downloads. `done`
/// closes it; the Mac's window has a close button of its own and passes `nil`. Whatever the
/// learner downloads goes to `DeckWebBrowser.onFile`.
struct DeckWebBrowserView: View {
    var browser: DeckWebBrowser
    var done: (() -> Void)?

    var body: some View {
        NavigationStack {
            DeckWebView(webView: browser.webView)
                .overlay(alignment: .top) {
                    if browser.isLoading {
                        ProgressView(value: browser.progress)
                            .progressViewStyle(.linear)
                    }
                }
                .overlay(alignment: .bottom) {
                    if let download = browser.download {
                        DownloadNote(download: download)
                            .padding()
                    }
                }
                .navigationTitle(browser.pageTitle.isEmpty ? Text("Shared Decks") : Text(verbatim: browser.pageTitle))
                .inlineTitle()
                .toolbar { toolbar }
        }
        .alert(
            browser.failure?.title ?? "",
            isPresented: Binding(get: { browser.failure != nil }, set: { if !$0 { browser.failure = nil } })
        ) {
            Button("OK") {}
        } message: {
            Text(verbatim: browser.failure?.message ?? "")
        }
        .onDisappear { browser.stop() }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        #if os(iOS)
        if let done {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done", action: done)
            }
        }
        ToolbarItemGroup(placement: .primaryAction) {
            bookmarks
            moreMenu
        }
        ToolbarItem(placement: .bottomBar) {
            Button("Back", systemImage: "chevron.backward", action: browser.goBack)
                .disabled(!browser.canGoBack)
        }
        ToolbarItem(placement: .bottomBar) {
            Button("Forward", systemImage: "chevron.forward", action: browser.goForward)
                .disabled(!browser.canGoForward)
        }
        ToolbarSpacer(.flexible, placement: .bottomBar)
        ToolbarItem(placement: .bottomBar) {
            Button("Reload", systemImage: "arrow.clockwise", action: browser.reload)
        }
        #else
        ToolbarItemGroup(placement: .navigation) {
            Button("Back", systemImage: "chevron.backward", action: browser.goBack)
                .disabled(!browser.canGoBack)
            Button("Forward", systemImage: "chevron.forward", action: browser.goForward)
                .disabled(!browser.canGoForward)
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Button("Reload", systemImage: "arrow.clockwise", action: browser.reload)
            bookmarks
            moreMenu
        }
        #endif
    }

    private var bookmarks: some View {
        Menu("Bookmarks", systemImage: "bookmark") {
            ForEach(DeckSources.all) { source in
                Button(source.title) { browser.load(source.url) }
            }
        }
    }

    private var moreMenu: some View {
        Menu("More", systemImage: "ellipsis") {
            Button("Open in Safari", systemImage: "safari", action: browser.openInSafari)
        }
    }
}

extension View {
    /// The small title of the iPhone's bar; the Mac's window has its own.
    fileprivate func inlineTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}

/// The file that is coming down, with how far it is once the size is known.
private struct DownloadNote: View {
    var download: DeckWebBrowser.Download

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if download.name.isEmpty {
                Text("Downloading…")
            } else {
                Text("Downloading “\(download.name)”…")
            }
            ProgressView(value: download.fraction > 0 ? download.fraction : nil)
        }
        .padding()
        .frame(maxWidth: 420, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
