import Foundation
import libzstd

/// Decompresses zstd frames with the reference library (`facebook/zstd`); Apple's
/// Compression framework has no zstd.
enum Zstd {
    /// The decompressed bytes of `data`, one frame or several in a row.
    ///
    /// - Throws: `AnkiImport.Error.unreadableArchive` for damaged or truncated input,
    ///   and for output larger than `limit`, so a forged frame can't fill memory.
    static func decompress(_ data: Data, limit: Int = ZipArchive.maximumEntrySize) throws -> Data {
        guard let stream = ZSTD_createDStream() else { throw AnkiImport.Error.unreadableArchive }
        defer { ZSTD_freeDStream(stream) }

        var output = Data()
        var chunk = [UInt8](repeating: 0, count: ZSTD_DStreamOutSize())
        var failed = false
        data.withUnsafeBytes { source in
            var input = ZSTD_inBuffer(src: source.baseAddress, size: source.count, pos: 0)
            var finished = false
            while !finished && !failed {
                chunk.withUnsafeMutableBytes { destination in
                    var out = ZSTD_outBuffer(dst: destination.baseAddress, size: destination.count, pos: 0)
                    // 0 means a frame is complete; otherwise a hint of how much input it still wants.
                    let hint = ZSTD_decompressStream(stream, &out, &input)
                    output.append(contentsOf: destination[0..<out.pos])
                    if ZSTD_isError(hint) != 0 || output.count > limit {
                        failed = true
                    } else if input.pos == input.size && out.pos < out.size {
                        // All input used and nothing left in the decoder: the last frame is
                        // complete, or cut short.
                        finished = true
                        failed = hint != 0
                    }
                }
            }
        }
        guard !failed else { throw AnkiImport.Error.unreadableArchive }
        return output
    }
}
