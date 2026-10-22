import Foundation

/// A website of free decks that the deck browser shows. A name, not a string of the catalog.
struct DeckSource: Identifiable, Equatable, Sendable {
    var title: String
    var url: URL
    var id: URL { url }

    /// The host without a leading "www.": the source and its subdomains share it.
    var domain: String {
        let host = url.host?.lowercased() ?? ""
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    init(_ title: String, _ address: String) {
        self.title = title
        url = URL(string: address)!
    }
}

/// The sites the deck browser shows (`DeckWebBrowser`). The learner browses them like any
/// website; the app takes only the file that the learner chose to download. Nothing here reads a
/// page, and nothing is fetched by the app.
enum DeckSources {
    /// The one list of sites: their hosts stay in the browser and every other host goes to
    /// Safari, and they are the bookmarks of its toolbar. The first is the start page. A new
    /// source is one more line.
    static let all = [
        DeckSource("AnkiWeb Shared Decks", "https://ankiweb.net/shared/decks"),
        DeckSource("MintDeck Free Decks", "https://www.mintdeck.app/decks"),
    ]

    static var start: URL { all[0].url }

    /// Whether `url` is on one of the sources: https, and the host or a subdomain of it. A blob
    /// URL, which a page makes for a file it hands over, counts by the page that made it.
    static func isKnown(_ url: URL?) -> Bool {
        guard var url else { return false }
        if url.scheme == "blob" {
            guard let page = URL(string: String(url.absoluteString.dropFirst("blob:".count))) else { return false }
            url = page
        }
        guard url.scheme == "https", let host = url.host?.lowercased() else { return false }
        return all.contains { host == $0.domain || host.hasSuffix("." + $0.domain) }
    }

    /// Whether `url` goes to Safari instead of the browser. Only a click on a link leaves: a
    /// redirect that a source makes itself, to a file store for one, stays in the browser.
    static func opensInSafari(_ url: URL?, isLinkActivation: Bool) -> Bool {
        isLinkActivation && !isKnown(url)
    }
}

/// What the browser takes as a download, and where it puts it. The files are the ones the
/// import takes: an Anki package, or a CSV or TSV table.
enum DeckDownload {
    static let extensions: Set<String> = ["apkg", "csv", "tsv"]

    /// What a source sends a file as: a package is a zip that WebKit has no view for, and a
    /// table is text that it would show instead of saving.
    private static let mimeTypes: Set<String> = [
        "application/octet-stream", "application/zip", "application/x-zip-compressed", "application/x-apkg",
        "text/csv", "text/tab-separated-values",
    ]

    /// The folder of the downloads under the temporary directory, which the system clears.
    static let folder = URL.temporaryDirectory.appending(path: "DeckDownloads", directoryHint: .isDirectory)

    /// Whether the response of a page is a file to save: a name with one of the extensions, an
    /// attachment, one of the types above, or anything the view can't show.
    static func shouldDownload(url: URL?, mimeType: String?, contentDisposition: String?, canShow: Bool) -> Bool {
        let disposition = parse(contentDisposition)
        if let name = disposition.fileName ?? url?.lastPathComponent,
            extensions.contains((name as NSString).pathExtension.lowercased())
        {
            return true
        }
        if disposition.type == "attachment" {
            return true
        }
        if let mimeType, mimeTypes.contains(mimeType.lowercased()) {
            return true
        }
        return !canShow
    }

    /// The type and the file name of a Content-Disposition header; `filename*` (RFC 5987) wins
    /// over `filename`. ponytail: a quoted name that holds a ";" is cut there, add a real parser
    /// if a source sends one.
    static func parse(_ header: String?) -> (type: String, fileName: String?) {
        guard let header else { return ("", nil) }
        let parts = header.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }
        var plain: String?
        var encoded: String?
        for part in parts.dropFirst() {
            guard let equals = part.firstIndex(of: "=") else { continue }
            let key = part[..<equals].lowercased()
            let value = String(part[part.index(after: equals)...]).trimmingCharacters(in: .whitespaces)
            if key == "filename*" {
                // charset'language'percent-encoded name
                let name = value.range(of: "''").map { String(value[$0.upperBound...]) } ?? value
                encoded = name.removingPercentEncoding
            } else if key == "filename" {
                plain = value.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            }
        }
        return (parts.first?.lowercased() ?? "", encoded ?? plain)
    }

    /// The name of the file that is saved: the name the source suggested, without any folders,
    /// and with an extension the import knows: a file that has none is taken for a package, and
    /// the import tells the learner if it isn't one.
    static func localName(forSuggested name: String) -> String {
        var name = (name as NSString).lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty || name == "/" {
            name = "Deck"
        }
        return extensions.contains((name as NSString).pathExtension.lowercased()) ? name : name + ".apkg"
    }

    /// A new folder for the download suggested as `name`, and the URL of the file in it. The
    /// folders of earlier downloads go: they were taken over by the import before the next one.
    static func makeDestination(forSuggested name: String, in folder: URL = folder) throws -> URL {
        try? FileManager.default.removeItem(at: folder)
        let directory = folder.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: localName(forSuggested: name), directoryHint: .notDirectory)
    }
}
