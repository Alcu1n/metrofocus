import XCTest

/// Rendered UI and interaction evidence. These tests exercise Dynamic Type and
/// accessibility-exposed actions, but do not claim a real VoiceOver session.
@MainActor
final class VisualAcceptanceTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws { continueAfterFailure = false }
    override func tearDown() async throws {
        if let app, app.state == .runningForeground { capture("Final state – \(name)") }
        app?.terminate()
    }

    func testChineseStationRouteSettingsAndEmptyCollections() throws {
        launch(language: "zh-Hans", scale: 1)
        let shuttle = app.buttons["service_shuttle"]
        let standard = app.buttons["service_standard"]
        XCTAssertTrue(shuttle.isHittable, "The first service and its number must be visible without scrolling.")
        XCTAssertTrue(standard.isHittable, "The second service should be visible on the first screen.")
        XCTAssertTrue(shuttle.label.contains("15"))
        XCTAssertTrue(standard.label.contains("25"))
        XCTAssertLessThanOrEqual(shuttle.frame.maxY, app.buttons["departButton"].frame.minY)
        capture("Chinese station – first-screen service selection")

        tap("editRoute")
        capture("Route editor – standard form")
        tap("servicePicker")
        let custom = app.buttons.matching(NSPredicate(format: "label == %@", "跨城专线")).firstMatch
        XCTAssertTrue(custom.waitForExistence(timeout: 5))
        custom.tap()
        XCTAssertTrue(app.steppers.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(app.steppers.count, 3, "Custom routes expose focus, rest, and segment controls.")
        capture("Custom route – three bounded native steppers")
        tap("routeEditorDone")

        tap("settingsButton")
        let preview = app.buttons.matching(NSPredicate(format: "label == %@", "试听 地下铁")).firstMatch
        XCTAssertTrue(preview.waitForExistence(timeout: 5))
        capture("Settings – offline soundscape controls")
        preview.tap()
        expectValue(preview, "播放中", timeout: 3)
        capture("Underground preview is playing")
        expectValue(preview, "未播放", timeout: 12)
        capture("Preview stopped automatically after eight seconds")
        let done = app.navigationBars.buttons.matching(NSPredicate(format: "label == %@", "完成")).firstMatch
        XCTAssertTrue(done.exists)
        done.tap()
        XCTAssertTrue(app.buttons["departButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["departButton"].label.contains("检票发车"), "Previewing audio must not create or start a journey.")
        XCTAssertFalse(app.staticTexts["phaseStatus"].exists)

        selectTab(["路网", "Atlas"])
        XCTAssertTrue(app.staticTexts["0.0"].waitForExistence(timeout: 5))
        capture("Empty city – no fabricated progress")
        selectTab(["票夹", "Tickets"])
        XCTAssertTrue(app.staticTexts["第一张，留给下一程。"].waitForExistence(timeout: 5))
        XCTAssertEqual(ticketRows.count, 0)
        capture("Empty ticket wallet")
    }

    func testLargestDynamicTypeEnglishControlsRemainUsable() throws {
        launch(language: "en", scale: 1, largeType: true)
        capture("English station – accessibility XXXL top")
        let shuttle = app.buttons["service_shuttle"]
        reveal(shuttle, scrollingUp: true)
        shuttle.tap()
        XCTAssertTrue(shuttle.isSelected, "Selecting the shuttle must replace any remembered service before departure.")
        // Allow the intentionally animated selection color and summary to
        // finish before capturing editorial screenshot evidence (0.25 s UI).
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        capture("English station – accessibility XXXL service selection")
        let field = app.textFields["destinationField"]
        reveal(field, scrollingUp: false)
        field.tap()
        field.typeText("Make room for focus")
        submitKeyboard(field)
        tap("departButton")
        tap("skipBoarding")
        expectPhase("focusing")
        capture("English focus – accessibility XXXL")
        let pause = app.buttons["pauseJourney"]
        reveal(pause, scrollingUp: true)
        pause.tap()
        expectPhase("paused")
        XCTAssertTrue(app.buttons["resumeJourney"].isHittable)
        capture("Accessible paused journey and resume action")
        tap("resumeJourney")
        expectPhase("focusing")
        let cancel = app.buttons["cancelJourney"]
        reveal(cancel, scrollingUp: true)
        cancel.tap()
        tap("cancelConfirm")
        XCTAssertTrue(app.buttons["departButton"].waitForExistence(timeout: 5))
    }

    func testBackgroundExpiryThenProcessRelaunchIssuesOneTicket() throws {
        // 15 minutes becomes 13.5 seconds; persistence and lifecycle are real.
        launch(language: "en", scale: 0.015)
        let shuttle = app.buttons["service_shuttle"]
        reveal(shuttle, scrollingUp: true)
        shuttle.tap()
        XCTAssertTrue(shuttle.isSelected, "Selecting the shuttle must replace any remembered service before departure.")
        let field = app.textFields["destinationField"]
        reveal(field, scrollingUp: false)
        field.tap()
        field.typeText("Return to an arrival")
        submitKeyboard(field)
        tap("departButton")
        expectPhase("focusing")
        capture("Journey before backgrounding")
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 5))
        // Observe the real app remaining in the background across the deadline.
        // No internal engine action or fake clock is used while it is suspended.
        let foreground = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "state == %d", XCUIApplication.State.runningForeground.rawValue),
            object: app
        )
        foreground.isInverted = true
        XCTAssertEqual(XCTWaiter.wait(for: [foreground], timeout: 16), .completed)
        app.terminate()
        app.launchArguments.removeAll { $0 == "--reset-store" }
        app.launch()
        XCTAssertTrue(app.buttons["ticketPunch"].waitForExistence(timeout: 30))
        capture("Completed unpunched ticket recovered after termination")
        app.buttons["ticketPunch"].press(forDuration: 1.1)
        XCTAssertTrue(app.staticTexts["punchedStamp"].waitForExistence(timeout: 5))
        tap("ticketDone")
        selectTab(["票夹", "Tickets"])
        XCTAssertTrue(ticketRows.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(ticketRows.count, 1, "Recovery must settle the journey and mint its ticket only once.")
        capture("Exactly one ticket after background expiry and process relaunch")
    }

    private var ticketRows: XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "ticketRow_"))
    }

    private func launch(language: String, scale: Double, largeType: Bool = false) {
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-store", "--time-scale", String(scale),
                               "-AppleLanguages", "(\(language))", "-AppleLocale", language == "en" ? "en_US" : "zh_CN"]
        if largeType {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        XCTAssertTrue(app.textFields["destinationField"].waitForExistence(timeout: 10))
    }

    private func tap(_ identifier: String) {
        let action = app.buttons.matching(identifier: identifier).firstMatch
        XCTAssertTrue(action.exists || action.waitForExistence(timeout: 5), "Missing action \(identifier)")
        action.tap()
    }

    private func selectTab(_ labels: [String]) {
        let tab = app.tabBars.buttons.matching(NSPredicate(format: "label IN %@", labels)).firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 5))
        tab.tap()
    }

    private func reveal(_ element: XCUIElement, scrollingUp: Bool) {
        let content = app.scrollViews.firstMatch
        XCTAssertTrue(content.exists, "The content scroll view must be available before revealing an offscreen control.")
        func isReady() -> Bool {
            guard element.isHittable else { return false }
            // XCTest can report a service as hittable while its center is
            // still obscured by the fixed departure area. Require its actual
            // frame to be inside the visible content before asking it to tap.
            guard element.identifier.hasPrefix("service_") || element.identifier == "destinationField" else { return true }
            let frame = element.frame
            let footer = app.buttons["departButton"].frame
            let lowerEdge = min(content.frame.maxY, footer.minY - 8)
            let upperEdge = max(content.frame.minY, 110)
            let visibleHeight = min(frame.maxY, lowerEdge) - max(frame.minY, upperEdge)
            return frame.midY >= upperEdge + 20 && frame.midY <= lowerEdge - 20
                && visibleHeight >= min(frame.height, 100)
        }
        for _ in 0..<8 where !isReady() {
            let lowerContent = content.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.48))
            let upperContent = content.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.20))
            if scrollingUp { lowerContent.press(forDuration: 0.05, thenDragTo: upperContent) }
            else { upperContent.press(forDuration: 0.05, thenDragTo: lowerContent) }
        }
        XCTAssertTrue(isReady(), "The control must be visibly inside the scroll viewport, above fixed actions, before a tap: \(element.frame)")
    }

    private func submitKeyboard(_ field: XCUIElement) {
        guard app.keyboards.firstMatch.exists else { return }
        field.typeText("\n")
        let hidden = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.keyboards.firstMatch)
        XCTAssertEqual(XCTWaiter.wait(for: [hidden], timeout: 5), .completed,
                       "Return must dismiss the task keyboard before tapping the departure action.")
    }

    private func expectPhase(_ phase: String) {
        let status = app.staticTexts["phaseStatus"]
        XCTAssertTrue(status.exists || status.waitForExistence(timeout: 5))
        expectValue(status, phase, timeout: 5)
    }

    private func expectValue(_ element: XCUIElement, _ value: String, timeout: TimeInterval) {
        let expected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expected], timeout: timeout), .completed, "Expected \(value), got \(String(describing: element.value))")
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
