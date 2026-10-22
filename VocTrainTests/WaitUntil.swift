import Testing

/// Lets the main actor run until `condition` holds, for at most `timeout` by the clock.
///
/// The tests of a run share the main actor, and a snapshot test keeps it busy for seconds at a
/// time. What a test waits for, such as a file the UIDocument reads again and the merge after
/// it, needs the main actor too. A wait of a hundred sleeps of 100 ms lasts two or three times
/// as long as it says on a loaded machine, and still ends too early. So the deadline is
/// generous, and a wait that is over early costs nothing.
@MainActor
func waitUntil(
    _ comment: Comment,
    timeout: Duration = .seconds(120),
    sourceLocation: SourceLocation = #_sourceLocation,
    _ condition: () -> Bool
) async throws {
    let deadline = ContinuousClock.now + timeout
    while !condition(), ContinuousClock.now < deadline {
        try await Task.sleep(for: .milliseconds(20))
    }
    try #require(condition(), "Timed out waiting until \(comment)", sourceLocation: sourceLocation)
}

/// Runs `write`, a change to the file by another device, and waits until `condition` holds; if
/// it doesn't within `interval`, writes again, until `timeout`.
///
/// While other tests keep the main actor busy, a change to the file may go unreported to the
/// deck's UIDocument: it never reads the file again, however long the test waits, and the same
/// test alone passes at once. Measured in the full run, 22.10.2026: the first write was not
/// noticed, a second or third was. The test asks what the app does with a change it hears
/// of, so it writes again until the app has heard.
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
