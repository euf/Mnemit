import Testing

/// Runs `write`, a change to the file by another process, and waits until `condition` holds; if
/// it doesn't within `interval`, writes again, until `timeout`.
///
/// While other tests keep the main actor busy, a change to the file may go unreported to the
/// deck's document: it never reads the file again, however long the test waits, and the same
/// test alone passes at once. The test asks what the app does with a change it hears of, so it
/// writes again until the app has heard.
@MainActor
func writeUntil(
    _ comment: Comment,
    interval: Duration = .seconds(10),
    timeout: Duration = .seconds(120),
    sourceLocation: SourceLocation = #_sourceLocation,
    write: () async throws -> Void,
    until condition: () -> Bool
) async throws {
    let deadline = ContinuousClock.now + timeout
    repeat {
        try await write()
        let retry = ContinuousClock.now + interval
        while !condition(), ContinuousClock.now < retry {
            try await Task.sleep(for: .milliseconds(20))
        }
    } while !condition() && ContinuousClock.now < deadline
    try #require(condition(), "Timed out waiting until \(comment)", sourceLocation: sourceLocation)
}
