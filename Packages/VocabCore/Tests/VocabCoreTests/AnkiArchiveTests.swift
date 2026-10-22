import Foundation
import Testing

@testable import VocabCore

/// The parts under `AnkiImport`: ZIP, zstd, protobuf and the reduction of HTML.
struct AnkiArchiveTests {
    // MARK: ZIP

    @Test func readsStoredAndDeflatedEntries() throws {
        let text = Data(String(repeating: "γάτα cat ", count: 200).utf8)
        let file = AnkiFixtures.zip([("a", text), ("dir/b", Data([1, 2, 3])), ("empty", Data())], stored: ["dir/b"])
        let archive = try ZipArchive(file)
        #expect(try archive.contents(of: "a") == text)
        #expect(try archive.contents(of: "dir/b") == Data([1, 2, 3]))
        #expect(try archive.contents(of: "empty") == Data())
        #expect(try archive.contents(of: "missing") == nil)
        #expect(Set(archive.entries.keys) == ["a", "dir/b", "empty"])
        // Really deflated: the entry is shorter than its contents.
        #expect(try #require(archive.entries["a"]).compressedSize < text.count)
    }

    @Test func readsAFileWithATrailingCommentAndASlice() throws {
        let file = AnkiFixtures.zip([("a", Data("x".utf8))], comment: Data(repeating: 0x41, count: 5000))
        #expect(try ZipArchive(file).contents(of: "a") == Data("x".utf8))
        // A slice doesn't start at index 0.
        let padded = Data([9, 9, 9]) + file
        #expect(try ZipArchive(padded.dropFirst(3)).contents(of: "a") == Data("x".utf8))
    }

    @Test func refusesWhatIsNotAZip() {
        #expect(throws: AnkiImport.Error.unreadableArchive) { try ZipArchive(Data()) }
        #expect(throws: AnkiImport.Error.unreadableArchive) { try ZipArchive(Data("not a zip file at all, just text".utf8)) }
        var file = AnkiFixtures.zip([("a", Data("x".utf8))])
        file.removeLast(10)
        #expect(throws: AnkiImport.Error.unreadableArchive) { try ZipArchive(file) }
    }

    @Test func refusesZip64AndEncryptedEntries() throws {
        var file = AnkiFixtures.zip([("a", Data("x".utf8))])
        // The entry count 0xFFFF in the end record says the real count is in a ZIP64 record.
        file[file.count - 12] = 0xFF
        file[file.count - 11] = 0xFF
        #expect(throws: AnkiImport.Error.unreadableArchive) { try ZipArchive(file) }

        var encrypted = AnkiFixtures.zip([("a", Data("x".utf8))])
        let directory = try #require(encrypted.range(of: Data([0x50, 0x4B, 0x01, 0x02])))
        encrypted[directory.lowerBound + 8] = 1
        #expect(throws: AnkiImport.Error.unreadableArchive) { try ZipArchive(encrypted) }
    }

    @Test func refusesACorruptEntry() throws {
        // Text that deflates to a few hundred bytes, so the damage stays inside the entry.
        var seed: UInt32 = 1
        let text = Data(
            (0..<2000).map { _ -> UInt8 in
                seed = seed &* 1_664_525 &+ 1_013_904_223
                return UInt8(truncatingIfNeeded: seed >> 28) &+ 97
            })
        var file = AnkiFixtures.zip([("a", text)])
        let archive = try ZipArchive(file)
        #expect(try archive.contents(of: "a") == text)
        for offset in 60..<80 { file[offset] ^= 0xFF }
        let damaged = try ZipArchive(file)
        #expect(throws: AnkiImport.Error.unreadableArchive) { try damaged.contents(of: "a") }
    }

    @Test func refusesAForgedSize() throws {
        var file = AnkiFixtures.zip([("a", Data("x".utf8))], stored: ["a"])
        let directory = try #require(file.range(of: Data([0x50, 0x4B, 0x01, 0x02])))
        // Uncompressed size 4 GiB - 1.
        for offset in 24..<28 { file[directory.lowerBound + offset] = 0xFF }
        let archive = try ZipArchive(file)
        #expect(throws: AnkiImport.Error.unreadableArchive) { try archive.contents(of: "a") }
    }

    // MARK: zstd

    @Test func decompressesZstd() throws {
        let text = Data(String(repeating: "σπίτι house ", count: 20_000).utf8)
        let packed = AnkiFixtures.zstd(text)
        #expect(packed.count < text.count / 10)
        // Larger than the decoder's output chunk, so it takes several rounds.
        #expect(try Zstd.decompress(packed) == text)
        #expect(try Zstd.decompress(AnkiFixtures.zstd(Data())) == Data())
    }

    @Test func decompressesFramesInARow() throws {
        let packed = AnkiFixtures.zstd(Data("one ".utf8)) + AnkiFixtures.zstd(Data("two".utf8))
        #expect(try Zstd.decompress(packed) == Data("one two".utf8))
    }

    @Test func refusesBrokenZstd() {
        let packed = AnkiFixtures.zstd(Data(String(repeating: "abc", count: 1000).utf8))
        #expect(throws: AnkiImport.Error.unreadableArchive) { try Zstd.decompress(Data()) }
        #expect(throws: AnkiImport.Error.unreadableArchive) { try Zstd.decompress(Data("plain text".utf8)) }
        #expect(throws: AnkiImport.Error.unreadableArchive) { try Zstd.decompress(packed.dropLast(3)) }
        #expect(throws: AnkiImport.Error.unreadableArchive) { try Zstd.decompress(packed + Data([1, 2, 3])) }
    }

    @Test func limitsTheDecompressedSize() {
        let packed = AnkiFixtures.zstd(Data(repeating: 0, count: 1_000_000))
        #expect(throws: AnkiImport.Error.unreadableArchive) { try Zstd.decompress(packed, limit: 100_000) }
    }

    // MARK: Protobuf

    @Test func readsFieldsOfAMessage() {
        let message = AnkiFixtures.varintField(1, 300) + AnkiFixtures.stringField(2, "{{Back}}") + AnkiFixtures.varintField(3, 0)
        let fields = ProtobufFields(message)
        #expect(fields.varint(1) == 300)
        #expect(fields.bytes(2).map { String(decoding: $0, as: UTF8.self) } == "{{Back}}")
        #expect(fields.varint(3) == 0)
        #expect(fields.varint(2) == nil)
        #expect(fields.bytes(1) == nil)
        #expect(fields.varint(4) == nil)
    }

    @Test func skipsFixedWidthFieldsAndTakesTheLastValue() {
        // Field 5 as a 32-bit and field 6 as a 64-bit value sit between two values of field 1.
        let message = AnkiFixtures.varintField(1, 1) + Data([5 << 3 | 5, 1, 2, 3, 4]) + Data([6 << 3 | 1, 1, 2, 3, 4, 5, 6, 7, 8]) + AnkiFixtures.varintField(1, 3)
        #expect(ProtobufFields(message).varint(1) == 3)
    }

    @Test func aMalformedTailEndsTheList() {
        let message = AnkiFixtures.varintField(1, 2) + Data([2 << 3 | 2, 50, 1])
        let fields = ProtobufFields(message)
        #expect(fields.varint(1) == 2)
        #expect(fields.bytes(2) == nil)
        #expect(ProtobufFields(Data()).varint(1) == nil)
        #expect(ProtobufFields(Data([0xFF, 0xFF])).varint(1) == nil)
    }

    // MARK: Text

    @Test func reducesHTMLToPlainText() {
        func plain(_ html: String) -> String { AnkiText.plain(html).text }
        #expect(plain("<b>σπίτι</b><br>το") == "σπίτι\nτο")
        #expect(plain("a<br/>b<BR />c") == "a\nb\nc")
        #expect(plain("<div>one</div><div>two</div>") == "one\ntwo")
        #expect(plain("<div>one<br></div><div>two</div>") == "one\ntwo")
        #expect(plain("one<br><br>two") == "one\n\ntwo")
        #expect(plain("<p>x</p><ul><li>y</li><li>z</li></ul>") == "x\ny\nz")
        #expect(plain("<span style=\"color: red\">red</span> and <a href=\"x\">link</a>") == "red and link")
        #expect(plain("  \n padded \n ") == "padded")
        #expect(plain("") == "")
    }

    @Test func decodesEntities() {
        func plain(_ html: String) -> String { AnkiText.plain(html).text }
        #expect(plain("house &amp; home&nbsp;now") == "house & home now")
        #expect(plain("&lt;b&gt; &quot;q&quot; &apos;a&apos;") == "<b> \"q\" 'a'")
        #expect(plain("&#948;&#x3B1;&#X3b9;") == "δαι")
        #expect(plain("a&hellip; b&ndash;c") == "a… b–c")
        // Not an entity: stays as written.
        #expect(plain("fish &chips; &#xZZ; &#1114112; R&D") == "fish &chips; &#xZZ; &#1114112; R&D")
        #expect(plain("&amp;lt;") == "&lt;")
        #expect(plain("a\u{00A0}b") == "a b")
    }

    @Test func aLessThanSignThatOpensNoTagStays() {
        #expect(AnkiText.plain("1 < 2 and 3 <4").text == "1 < 2 and 3 <4")
        #expect(AnkiText.plain("unfinished <b").text == "unfinished <b")
    }

    @Test func removesMediaAndReportsIt() {
        let image = AnkiText.plain("front <img src=\"paste-1.jpg\"> text")
        #expect(image.text == "front  text")
        #expect(image.hadMedia)
        let sound = AnkiText.plain("word [sound:x.mp3]")
        #expect(sound.text == "word")
        #expect(sound.hadMedia)
        #expect(!AnkiText.plain("an [sound] and [sound: no end").hadMedia)
        #expect(AnkiText.plain("<img src=a.png>").text == "")
        #expect(!AnkiText.plain("<b>plain</b>").hadMedia)
    }
}
