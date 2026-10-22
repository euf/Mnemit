import Foundation

/// Names a piece of work, so the stall probe of the tests (`SpeechWindowStallTests`) can say what
/// ran while the main thread was held up. Work that runs on another thread gets " (off main)"
/// after its name. In the app nothing is set and `measure(_:_:)` and `mark(_:)` cost a load and a
/// branch.
enum StallTrace {
    /// Set by a test for the length of a run: the name, and when the work began and ended, in
    /// nanoseconds of `DispatchTime.now().uptimeNanoseconds`.
    nonisolated(unsafe) static var sink: (@Sendable (String, UInt64, UInt64) -> Void)?

    /// A moment the probe should know of, such as a change of the screen that takes no time itself.
    static func mark(_ name: @autoclosure () -> String) {
        guard let sink else { return }
        let now = DispatchTime.now().uptimeNanoseconds
        sink(name(), now, now)
    }

    static func measure<T>(_ name: @autoclosure () -> String, _ work: () throws -> T) rethrows -> T {
        guard let sink else { return try work() }
        let start = DispatchTime.now().uptimeNanoseconds
        let isMain = Thread.isMainThread
        defer { sink(isMain ? name() : name() + " (off main)", start, DispatchTime.now().uptimeNanoseconds) }
        return try work()
    }
}
