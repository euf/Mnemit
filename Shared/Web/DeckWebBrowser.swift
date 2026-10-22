import SwiftUI
import WebKit

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// A web browser for the sites of free decks (`DeckSources`), which the learner drives: a plain
/// `WKWebView` with its own data store, so a login stays, and no script, no user agent of ours
/// and no request that the learner didn't make. The app only takes the file the learner chooses
/// to download: Anki packages, and CSV or TSV tables. `onFile` gets it once it is saved, in
/// `DeckDownload.folder`. A link to any other host opens in Safari.
///
/// WebKit stays out of the widget, which compiles all of `Shared`: the project excludes this file
/// and `DeckWebBrowserView` from its membership.
@MainActor @Observable
final class DeckWebBrowser: NSObject, Identifiable {
    /// A download under way.
    struct Download: Equatable {
        var name: String
        /// 0 until the size is known.
        var fraction: Double
    }

    struct Failure: Equatable {
        var title: String
        var message: String
    }

    let webView: WKWebView
    private(set) var canGoBack = false
    private(set) var canGoForward = false
    private(set) var isLoading = false
    private(set) var progress = 0.0
    private(set) var pageTitle = ""
    private(set) var url: URL?
    private(set) var download: Download?
    var failure: Failure?
    /// Called with the file of a finished download.
    @ObservationIgnored var onFile: (URL) -> Void = { _ in }

    @ObservationIgnored private var observations: [NSKeyValueObservation] = []
    @ObservationIgnored private var progressObservation: NSKeyValueObservation?
    @ObservationIgnored private var currentDownload: WKDownload?
    @ObservationIgnored private var destination: URL?

    nonisolated var id: ObjectIdentifier { ObjectIdentifier(self) }

    init(start: URL = DeckSources.start) {
        webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        watch(\.canGoBack)
        watch(\.canGoForward)
        watch(\.isLoading)
        watch(\.estimatedProgress)
        watch(\.title)
        watch(\.url)
        webView.load(URLRequest(url: start))
    }

    /// Shows the page at `url`, a bookmark.
    func load(_ url: URL) {
        webView.load(URLRequest(url: url))
    }

    func goBack() { webView.goBack() }
    func goForward() { webView.goForward() }
    func reload() { webView.reload() }

    func openInSafari() {
        openExternally(webView.url ?? DeckSources.start)
    }

    /// Ends what is under way: the learner has left the browser.
    func stop() {
        webView.stopLoading()
        currentDownload?.cancel { _ in }
        currentDownload = nil
        download = nil
    }

    private func watch<Value>(_ keyPath: KeyPath<WKWebView, Value>) {
        observations.append(webView.observe(keyPath) { [weak self] _, _ in Task { @MainActor in self?.sync() } })
    }

    private func sync() {
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        isLoading = webView.isLoading
        progress = webView.estimatedProgress
        pageTitle = webView.title ?? ""
        url = webView.url
    }

    private func openExternally(_ url: URL) {
        #if canImport(UIKit)
        UIApplication.shared.open(url)
        #else
        NSWorkspace.shared.open(url)
        #endif
    }

    private func report(_ error: any Error) {
        let error = error as NSError
        // A cancelled load is none, nor is the load that a download replaced.
        if error.domain == NSURLErrorDomain, error.code == NSURLErrorCancelled { return }
        if error.domain == "WebKitErrorDomain", error.code == 102 { return }
        failure = Failure(title: String(localized: "Couldn't Load the Page"), message: error.localizedDescription)
    }

    private func adopt(_ download: WKDownload) {
        currentDownload?.cancel { _ in }
        download.delegate = self
        currentDownload = download
        destination = nil
        self.download = Download(name: "", fraction: 0)
        progressObservation = download.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
            let fraction = progress.fractionCompleted
            Task { @MainActor in self?.download?.fraction = fraction }
        }
    }

    private func endDownload() {
        progressObservation = nil
        currentDownload = nil
        download = nil
    }
}

extension DeckWebBrowser: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        let isLink = navigationAction.navigationType == .linkActivated
        if let url = navigationAction.request.url, DeckSources.opensInSafari(url, isLinkActivation: isLink) {
            openExternally(url)
            return .cancel
        }
        // A link with the download attribute, which the page serves from a blob.
        return navigationAction.shouldPerformDownload ? .download : .allow
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse) async -> WKNavigationResponsePolicy {
        guard navigationResponse.isForMainFrame else { return .allow }
        let response = navigationResponse.response
        let disposition = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Disposition")
        let isDownload = DeckDownload.shouldDownload(
            url: response.url, mimeType: response.mimeType, contentDisposition: disposition,
            canShow: navigationResponse.canShowMIMEType)
        return isDownload ? .download : .allow
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        adopt(download)
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        adopt(download)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
        report(error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        report(error)
    }
}

extension DeckWebBrowser: WKUIDelegate {
    /// A link that wants a window of its own: the page of a source loads here, a link to
    /// another host goes to Safari, a script that opens a window is left alone.
    func webView(
        _ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        guard let url = navigationAction.request.url else { return nil }
        if DeckSources.isKnown(url) {
            webView.load(navigationAction.request)
        } else if navigationAction.navigationType == .linkActivated {
            openExternally(url)
        }
        return nil
    }
}

extension DeckWebBrowser: WKDownloadDelegate {
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String) async -> URL? {
        do {
            let file = try DeckDownload.makeDestination(forSuggested: suggestedFilename)
            destination = file
            self.download?.name = file.lastPathComponent
            return file
        } catch {
            endDownload()
            failure = Failure(title: String(localized: "Download Failed"), message: error.localizedDescription)
            return nil
        }
    }

    func downloadDidFinish(_ download: WKDownload) {
        let file = destination
        endDownload()
        if let file {
            onFile(file)
        }
    }

    func download(_ download: WKDownload, didFailWithError error: any Error, resumeData: Data?) {
        endDownload()
        if (error as NSError).code != NSURLErrorCancelled {
            failure = Failure(title: String(localized: "Download Failed"), message: error.localizedDescription)
        }
    }
}
