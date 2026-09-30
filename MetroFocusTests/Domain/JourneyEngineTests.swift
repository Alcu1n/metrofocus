import XCTest
import SwiftData
@testable import MetroFocus

@MainActor
final class JourneyEngineTests: XCTestCase {
    private final class Clock {
        var date = Date(timeIntervalSince1970: 1_800_000_000)
        func advance(_ seconds: TimeInterval) { date.addTimeInterval(seconds) }
    }

    func testOfflineRecoveryStopsAtManualDeparture() throws {
        let clock = Clock()
        let store = try MetroFocusStore.makeContainer(inMemory: true)
        let engine = JourneyEngine(modelContainer: store, now: { clock.date })
        engine.start(.preset(.standard, task: "Write", line: .writing))
        clock.advance(30 + 25 * 60 + 5 * 60 + 86_400)
        engine.refresh()
        XCTAssertEqual(engine.state?.phase, .awaitingDeparture)
        XCTAssertEqual(engine.state?.segmentIndex, 0)
        XCTAssertEqual(engine.totalFocusSeconds(), 1_500, accuracy: 0.001)
        XCTAssertTrue(engine.tickets.isEmpty)
        engine.continueJourney()
        XCTAssertEqual(engine.state?.segmentIndex, 1)
        XCTAssertEqual(engine.state?.remaining(at: clock.date), 1_500)
    }

    func testPauseResumeExcludesPausedTimeAndKeepsRemaining() throws {
        let clock = Clock()
        let engine = JourneyEngine(modelContainer: try MetroFocusStore.makeContainer(inMemory: true), now: { clock.date })
        engine.start(.preset(.shuttle, task: "Read", line: .reading))
        engine.skipBoarding()
        clock.advance(123)
        engine.pause()
        clock.advance(3_600)
        engine.resume()
        XCTAssertEqual(engine.state?.remaining(at: clock.date), 777)
        clock.advance(77)
        engine.cancelJourney()
        XCTAssertEqual(engine.totalFocusSeconds(), 200, accuracy: 0.001)
        XCTAssertEqual(engine.state?.phase, .cancelled)
        XCTAssertTrue(engine.tickets.isEmpty)
    }

    func testCompletionAndPunchRemainIdempotentAfterReload() throws {
        let clock = Clock()
        let store = try MetroFocusStore.makeContainer(inMemory: true)
        let engine = JourneyEngine(modelContainer: store, now: { clock.date })
        engine.start(.preset(.shuttle, task: "Finish", line: .coding))
        engine.skipBoarding()
        clock.advance(901)
        engine.refresh()
        engine.refresh()
        let ticket = try XCTUnwrap(engine.tickets.first)
        XCTAssertEqual(engine.tickets.count, 1)
        XCTAssertEqual(ticket.focusSeconds, 900)
        XCTAssertNil(ticket.punchedAt)
        let reloaded = JourneyEngine(modelContainer: store, now: { clock.date })
        XCTAssertEqual(reloaded.tickets.count, 1)
        XCTAssertEqual(reloaded.tickets.first?.id, ticket.id)
        XCTAssertNil(reloaded.tickets.first?.punchedAt, "An interruption before punching must restore the same unpunched ticket.")
        reloaded.punch(ticketID: ticket.id)
        let punchedAt = reloaded.tickets.first?.punchedAt
        clock.advance(10)
        reloaded.punch(ticketID: ticket.id)
        XCTAssertEqual(reloaded.tickets.first?.punchedAt, punchedAt)
        XCTAssertEqual(reloaded.totalFocusSeconds(line: .coding), 900)
        let afterPunchRestart = JourneyEngine(modelContainer: store, now: { clock.date })
        XCTAssertEqual(afterPunchRestart.tickets.count, 1)
        XCTAssertEqual(afterPunchRestart.tickets.first?.punchedAt, punchedAt, "A restart after punching must preserve the saved stamp.")
        XCTAssertEqual(afterPunchRestart.totalFocusSeconds(line: .coding), 900)
    }

    func testReloadKeepsActiveAnchorAndDisallowsSecondJourney() throws {
        let clock = Clock()
        let store = try MetroFocusStore.makeContainer(inMemory: true)
        let engine = JourneyEngine(modelContainer: store, now: { clock.date })
        engine.start(.preset(.shuttle, task: "First", line: .life))
        engine.skipBoarding()
        clock.advance(60)
        let reloaded = JourneyEngine(modelContainer: store, now: { clock.date })
        reloaded.start(.preset(.express, task: "Second", line: .coding))
        XCTAssertEqual(reloaded.state?.plan.task, "First")
        XCTAssertEqual(reloaded.totalFocusSeconds(), 60)
        XCTAssertEqual(reloaded.sessions.count, 1)
    }

    func testEarlyDepartureAndRestPauseDoNotCountAsFocus() throws {
        let clock = Clock()
        let engine = JourneyEngine(modelContainer: try MetroFocusStore.makeContainer(inMemory: true), now: { clock.date })
        engine.start(.preset(.standard, task: "Build", line: .coding))
        engine.skipBoarding()
        clock.advance(1_500)
        engine.refresh()
        XCTAssertEqual(engine.state?.phase, .resting)
        clock.advance(30)
        engine.pause()
        clock.advance(700)
        engine.resume()
        XCTAssertEqual(engine.state?.remaining(at: clock.date), 270)
        engine.continueJourney()
        clock.advance(100)
        engine.cancelJourney()
        XCTAssertEqual(engine.totalFocusSeconds(), 1_600)
    }

    func testFailedCompletionSaveDoesNotExposeTicketUntilRetry() throws {
        struct SaveFailure: Error {}
        let clock = Clock()
        var shouldFail = false
        let engine = JourneyEngine(
            modelContainer: try MetroFocusStore.makeContainer(inMemory: true),
            now: { clock.date },
            save: { context in
                if shouldFail { throw SaveFailure() }
                try context.save()
            }
        )
        engine.start(.preset(.shuttle, task: "Save", line: .writing))
        engine.skipBoarding()
        shouldFail = true
        clock.advance(900)
        engine.refresh()
        XCTAssertNotNil(engine.errorMessage)
        XCTAssertTrue(engine.tickets.isEmpty)
        shouldFail = false
        engine.retrySave()
        XCTAssertNil(engine.errorMessage)
        XCTAssertEqual(engine.tickets.count, 1)
        engine.retrySave()
        XCTAssertEqual(engine.tickets.count, 1)
    }

    func testInvalidTaskDoesNotStartJourney() throws {
        let engine = JourneyEngine(modelContainer: try MetroFocusStore.makeContainer(inMemory: true))
        engine.start(.preset(.shuttle, task: "  ", line: .writing))
        XCTAssertNil(engine.state)
        XCTAssertNotNil(engine.errorMessage)
    }
}
