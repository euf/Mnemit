import Compression
import Foundation

/// The central directory of a ZIP file and the contents of its entries: just enough
/// for `.apkg` packages, which hold a few large entries and, if they have media, many
/// numbered small ones.
///
/// Entries are stored or deflated. Encrypted archives, ZIP64 (more than 65 534
/// entries or 4 GiB) and every other method are refused: Anki writes none of them for
/// a package that fits in memory on a phone. The CRC is not checked; a damaged entry
/// shows up as a size mismatch or as an unreadable collection.
struct ZipArchive {
    struct Entry {
        var method: UInt16
        var compressedSize: Int
        var size: Int
        var headerOffset: Int
    }

    /// An entry that decompresses to more than this is refused, so a forged size in the
    /// directory can't make the importer allocate gigabytes.
    static let maximumEntrySize = 1 << 30

    private let bytes: Data
    private(set) var entries: [String: Entry] = [:]

    /// - Throws: `AnkiImport.Error.unreadableArchive` for anything that isn't a plain
    ///   ZIP file of the kind above.
    init(_ bytes: Data) throws {
        // Index from zero whatever slice the caller passes.
        self.bytes = bytes.startIndex == 0 ? bytes : Data(bytes)
        let end = try Self.findEndOfCentralDirectory(in: self.bytes)
        let count = Int(self.bytes.u16(at: end + 10))
        let directorySize = Int(self.bytes.u32(at: end + 12))
        let directoryOffset = Int(self.bytes.u32(at: end + 16))
        // 0xFFFF and 0xFFFFFFFF mean the real value is in the ZIP64 record.
        guard count != 0xFFFF, directorySize != 0xFFFF_FFFF, directoryOffset != 0xFFFF_FFFF,
            directoryOffset + directorySize <= self.bytes.count
        else { throw AnkiImport.Error.unreadableArchive }

        var position = directoryOffset
        for _ in 0..<count {
            guard position + 46 <= self.bytes.count, self.bytes.u32(at: position) == 0x0201_4B50 else {
                throw AnkiImport.Error.unreadableArchive
            }
            let flags = self.bytes.u16(at: position + 8)
            let nameLength = Int(self.bytes.u16(at: position + 28))
            let extraLength = Int(self.bytes.u16(at: position + 30))
            let commentLength = Int(self.bytes.u16(at: position + 32))
            let nameStart = position + 46
            guard nameStart + nameLength <= self.bytes.count, flags & 1 == 0 else { throw AnkiImport.Error.unreadableArchive }
            let name = String(decoding: self.bytes[nameStart..<nameStart + nameLength], as: UTF8.self)
            entries[name] = Entry(
                method: self.bytes.u16(at: position + 10),
                compressedSize: Int(self.bytes.u32(at: position + 20)),
                size: Int(self.bytes.u32(at: position + 24)),
                headerOffset: Int(self.bytes.u32(at: position + 42)))
            position = nameStart + nameLength + extraLength + commentLength
        }
    }

    /// The contents of the entry `name`, or `nil` if there is none.
    func contents(of name: String) throws -> Data? {
        guard let entry = entries[name] else { return nil }
        let header = entry.headerOffset
        guard header + 30 <= bytes.count, bytes.u32(at: header) == 0x0403_4B50 else { throw AnkiImport.Error.unreadableArchive }
        let start = header + 30 + Int(bytes.u16(at: header + 26)) + Int(bytes.u16(at: header + 28))
        guard start + entry.compressedSize <= bytes.count, entry.size <= Self.maximumEntrySize else {
            throw AnkiImport.Error.unreadableArchive
        }
        let stored = bytes[start..<start + entry.compressedSize]
        switch entry.method {
        case 0:
            guard entry.compressedSize == entry.size else { throw AnkiImport.Error.unreadableArchive }
            return Data(stored)
        case 8:
            return try Self.inflate(stored, size: entry.size)
        default:
            throw AnkiImport.Error.unreadableArchive
        }
    }

    /// Apple's `COMPRESSION_ZLIB` is raw deflate, which is what a ZIP entry holds.
    private static func inflate(_ compressed: Data, size: Int) throws -> Data {
        guard size > 0 else { return Data() }
        var output = Data(count: size)
        let written = output.withUnsafeMutableBytes { destination in
            compressed.withUnsafeBytes { source in
                compression_decode_buffer(
                    destination.bindMemory(to: UInt8.self).baseAddress!, size,
                    source.bindMemory(to: UInt8.self).baseAddress!, compressed.count,
                    nil, COMPRESSION_ZLIB)
            }
        }
        guard written == size else { throw AnkiImport.Error.unreadableArchive }
        return output
    }

    /// The offset of the record that ends the file; it may be followed by a comment of up
    /// to 65 535 bytes.
    private static func findEndOfCentralDirectory(in bytes: Data) throws -> Int {
        guard bytes.count >= 22 else { throw AnkiImport.Error.unreadableArchive }
        let lowest = max(0, bytes.count - 22 - 0xFFFF)
        var offset = bytes.count - 22
        while offset >= lowest {
            if bytes.u32(at: offset) == 0x0605_4B50 { return offset }
            offset -= 1
        }
        throw AnkiImport.Error.unreadableArchive
    }
}

extension Data {
    /// Little-endian integers at an offset from the start; the caller checks the bounds.
    fileprivate func u16(at offset: Int) -> UInt16 {
        UInt16(self[startIndex + offset]) | UInt16(self[startIndex + offset + 1]) << 8
    }

    fileprivate func u32(at offset: Int) -> UInt32 {
        UInt32(u16(at: offset)) | UInt32(u16(at: offset + 2)) << 16
    }
}
