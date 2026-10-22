import Foundation

/// The top-level fields of one protobuf message, for the few places where an Anki
/// package holds one: the `meta` entry (`PackageMetadata`), and the `config` blobs of
/// note types and templates in the collection. Nested messages are not parsed;
/// `bytes` of a field can be passed to another `ProtobufFields`.
struct ProtobufFields {
    private enum Value {
        case varint(UInt64)
        case bytes(Data)
    }

    private var fields: [(number: Int, value: Value)] = []

    /// Reads as many fields as the data holds; a malformed tail ends the list.
    init(_ data: Data) {
        let bytes = [UInt8](data)
        var position = 0

        func varint() -> UInt64? {
            var result: UInt64 = 0
            var shift: UInt64 = 0
            while position < bytes.count, shift < 64 {
                let byte = bytes[position]
                position += 1
                result |= UInt64(byte & 0x7F) << shift
                if byte & 0x80 == 0 { return result }
                shift += 7
            }
            return nil
        }

        while let key = varint() {
            let number = Int(key >> 3)
            switch key & 7 {
            case 0:
                guard let value = varint() else { return }
                fields.append((number, .varint(value)))
            case 1, 5:
                position += key & 7 == 1 ? 8 : 4
            case 2:
                guard let length = varint(), length <= UInt64(bytes.count - position) else { return }
                fields.append((number, .bytes(Data(bytes[position..<position + Int(length)]))))
                position += Int(length)
            default:
                return
            }
        }
    }

    /// The last value of a varint field, as protobuf says; `nil` if it is absent, which
    /// proto3 also writes for the value 0.
    func varint(_ number: Int) -> UInt64? {
        for field in fields.reversed() where field.number == number {
            if case let .varint(value) = field.value { return value }
        }
        return nil
    }

    /// The last value of a string or bytes field.
    func bytes(_ number: Int) -> Data? {
        for field in fields.reversed() where field.number == number {
            if case let .bytes(value) = field.value { return value }
        }
        return nil
    }
}
