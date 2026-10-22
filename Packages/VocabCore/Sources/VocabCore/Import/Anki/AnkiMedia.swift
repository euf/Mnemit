import Foundation

/// The media files an Anki package holds, and how to unpack them. The package names them in an
/// entry `media`; the files themselves are numbered entries.
///
/// | Layout   | `media`                                     | A file                      |
/// |----------|---------------------------------------------|-----------------------------|
/// | Legacy 1 | JSON, entry number → file name              | the entry, as it is         |
/// | Legacy 2 | the same                                    | the entry, as it is         |
/// | Latest   | zstd, protobuf `MediaEntries` (name, size, sha1); a file's entry number is its place in the list | the entry, zstd |
struct AnkiMedia {
    /// The entry of the archive that holds each file, by the file's name in Anki. A `String` is
    /// the same key in its composed and its decomposed form, as Anki's names are NFC and those of a
    /// field may be typed on a Mac.
    private var entries: [String: String] = [:]

    init() {}

    /// Reads the list of files; a package whose list can't be read has no media rather than none
    /// of its cards, as media only add to a card.
    init(archive: ZipArchive, isCompressed: Bool) {
        guard let map = try? archive.contents(of: "media") else { return }
        if isCompressed {
            guard let list = try? Zstd.decompress(map) else { return }
            for (index, entry) in ProtobufFields(list).allBytes(1).enumerated() {
                let fields = ProtobufFields(entry)
                guard let name = fields.bytes(1) else { continue }
                // `legacy_zip_filename` (255) is set when a package keeps the entry number of an older one.
                entries[String(decoding: name, as: UTF8.self)] = fields.varint(255).map { String($0) } ?? String(index)
            }
        } else if let object = try? JSONSerialization.jsonObject(with: map) as? [String: Any] {
            for (entry, name) in object {
                if let name = name as? String { entries[name] = entry }
            }
        }
    }

    var isEmpty: Bool { entries.isEmpty }

    /// The name of the file `reference` means, as the package knows it, or `nil` if it holds none:
    /// the reference as it stands, or percent-decoded as Anki does for the `src` of an image.
    func name(for reference: String) -> String? {
        let candidates = [reference, reference.removingPercentEncoding].compactMap { $0 }
        return candidates.first { entries[$0] != nil }
    }

    /// What unpacking put on disk.
    struct Unpacked {
        var media = DeckMedia()
        /// The name of each unpacked file in the deck's media, by its name in Anki.
        var names: [String: String] = [:]
        /// The size of each file in bytes, by its name in the deck's media.
        var sizes: [String: Int] = [:]
    }

    /// Unpacks the files `names` (as `name(for:)` gives them) from `archive` into a temporary folder,
    /// hashed and named as a deck's media are (`DeckMedia`). Identical files are unpacked once. The
    /// folder lives as long as the media of the result do. A file that can't be read is left out.
    func unpack(_ names: Set<String>, from archive: ZipArchive, isCompressed: Bool) -> Unpacked {
        var result = Unpacked()
        guard !names.isEmpty else { return result }
        let folder = TemporaryFolder()
        for name in names.sorted() {
            guard let entry = entries[name], var data = try? archive.contents(of: entry) else { continue }
            if isCompressed {
                guard let plain = try? Zstd.decompress(data) else { continue }
                data = plain
            }
            let hashed = DeckMedia.name(for: data, fileExtension: (name as NSString).pathExtension)
            let url = folder.url.appending(path: hashed)
            if result.sizes[hashed] == nil {
                guard (try? data.write(to: url)) != nil else { continue }
                result.media.add(fileAt: url, named: hashed, owner: folder)
                result.sizes[hashed] = data.count
            }
            result.names[name] = hashed
        }
        return result
    }
}

/// A folder in the temporary directory, removed once nothing holds it any more.
final class TemporaryFolder: @unchecked Sendable {
    let url: URL

    init() {
        url = FileManager.default.temporaryDirectory.appending(path: "AnkiMedia-\(UUID().uuidString)", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }
}
