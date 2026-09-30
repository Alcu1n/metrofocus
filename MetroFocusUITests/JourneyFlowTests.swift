import XCTest

/// These flows use the production UI, state machine, and isolated on-disk SwiftData store.
/// Only duration is accelerated with a DEBUG launch argument. This does not validate
/// real lock-screen delivery, notification permissions, audio interruptions, or haptics.
@MainActor
final class JourneyFlowTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
    }

    override func tearDown() async throws {
        if let app, app.state == .runningForeground {
            attachScreenshot("Final state – \(name)")
        }
        app?.terminate()
    }

    func testChineseFirstJourneyTicketPunchHistoryAndCardExport() throws {
        launch(language: "zh-Hans", locale: "zh_CN", scale: 0.015)
        startJourney(task: "完成今天的一页", service: "shuttle")
        XCTAssertTrue(app.staticTexts["focusTimer"].waitForExistence(timeout: 5))
        attachScreenshot("Chinese focusing cabin")
        punchCompletedTicket()
        tap("ticketDone")
        tap("tabTickets")
        let row = ticketRows.firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertEqual(ticketRows.count, 1, "A completed journey must produce exactly one persisted ticket.")
        row.tap()
        XCTAssertTrue(app.staticTexts["punchedStamp"].waitForExistence(timeout: 5))
        attachScreenshot("Punched ticket restored from history")
        tap("shareTicket")
        selectExport("exportCard")
        assertShareSheet(filenameSuffix: "-card")
        attachScreenshot("Share card export")
    }

    func testEnglishJourneyExportsTransparentTicket() throws {
        launch(language: "en", locale: "en_US", scale: 0.015)
        startJourney(task: "Finish one small thing", service: "shuttle")
        punchCompletedTicket()
        attachScreenshot("English completed ticket")
        tap("shareTicket")
        selectExport("exportTransparent")
        assertShareSheet(filenameSuffix: "-ticket")
        attachScreenshot("Transparent PNG system share sheet")
    }

    func testRestExpiryWaitsForExplicitDeparture() throws {
        launch(language: "en", locale: "en_US", scale: 0.008)
        startJourney(task: "Build something useful", service: "standard")
        waitForPhase("awaitingDeparture", timeout: 30)
        XCTAssertFalse(app.buttons["ticketPunch"].exists)
        attachScreenshot("Rest finished, train waits at platform")
        // Stay beyond another accelerated focus+rest interval. No unattended
        // segment may be consumed while explicit departure is required.
        let remainsWaiting = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "focusing"),
            object: app.staticTexts["phaseStatus"]
        )
        XCTAssertEqual(XCTWaiter.wait(for: [remainsWaiting], timeout: 18), .timedOut)
        XCTAssertEqual(app.staticTexts["phaseStatus"].value as? String, "awaitingDeparture")
        tap("continueJourney")
        waitForPhase("focusing", timeout: 30)
        attachScreenshot("Second segment started by explicit confirmation")
    }

    func testPauseReturnRelaunchResumeAndCancelPreservesJourney() throws {
        launch(language: "en", locale: "en_US", scale: 0.05)
        startJourney(task: "Keep my place", service: "shuttle")
        tap("pauseJourney")
        waitForPhase("paused")
        let pausedTime = app.staticTexts["focusTimer"].label
        attachScreenshot("Paused journey")
        tap("journeyClose")
        XCTAssertTrue(app.buttons["departButton"].waitForExistence(timeout: 5))
        app.terminate()
        // Keep the same isolated persistent store across process termination.
        app.launchArguments.removeAll { $0 == "--reset-store" }
        app.launch()
        if !app.buttons["resumeJourney"].waitForExistence(timeout: 2) {
            tap("departButton")
        }
        waitForPhase("paused")
        XCTAssertEqual(app.staticTexts["focusTimer"].label, pausedTime, "Time spent paused or relaunching must not reduce the remaining interval.")
        tap("resumeJourney")
        waitForPhase("focusing")
        tap("cancelJourney")
        tap("cancelConfirm")
        XCTAssertTrue(app.buttons["departButton"].waitForExistence(timeout: 5))
        tap("tabTickets")
        XCTAssertEqual(ticketRows.count, 0, "An interrupted journey keeps its focus history without minting a completed ticket.")
        attachScreenshot("Cancelled journey has no completed ticket")
        tap("tabAtlas")
        attachScreenshot("Route growth after interrupted focus")
    }

    func testCompleteFourSegmentStandardJourneyWithManualTransfersAndLongPressPunch() throws {
        // Each 25-minute focus interval takes 18 seconds and each 5-minute rest
        // takes 3.6 seconds. All four intervals and all three transfer gates use
        // the real journey engine, UI actions, and persistent store.
        launch(language: "zh-Hans", locale: "zh_CN", scale: 0.012)
        let task = "完成完整四段旅程"
        startJourney(task: task, service: "standard")
        attachScreenshot("Standard service – first of four focus intervals")
        for completedSegment in 1...3 {
            waitForPhase("awaitingDeparture", timeout: 30)
            XCTAssertFalse(app.buttons["ticketPunch"].exists, "An intermediate stop cannot issue a completed ticket.")
            XCTAssertTrue(app.buttons["continueJourney"].isHittable)
            attachScreenshot("Transfer \(completedSegment) – break complete, awaiting explicit departure")
            XCTAssertEqual(app.staticTexts["phaseStatus"].value as? String, "awaitingDeparture",
                           "The train must remain at the manual transfer gate while the user inspects the screen.")
            tap("continueJourney")
            waitForPhase("focusing", timeout: 30)
            attachScreenshot("Standard service – focus interval \(completedSegment + 1) of four")
        }
        XCTAssertTrue(app.buttons["ticketPunch"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.staticTexts["100"].firstMatch.exists, "All four focus intervals should settle exactly 100 focused minutes.")
        XCTAssertTrue(app.staticTexts["4 站 · 单程通行"].firstMatch.exists)
        attachScreenshot("Four completed intervals – saved ticket before punching")
        // Long-press the physical ticket's title, not the alternative action
        // button. This exercises the actual on-ticket long-press gesture.
        let physicalTicketTitle = app.staticTexts[task].firstMatch
        XCTAssertTrue(physicalTicketTitle.isHittable)
        physicalTicketTitle.press(forDuration: 1.1)
        XCTAssertTrue(app.staticTexts["punchedStamp"].waitForExistence(timeout: 5))
        attachScreenshot("Four-segment ticket mechanically punched by long press")
        tap("ticketDone")
        tap("tabTickets")
        XCTAssertTrue(ticketRows.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(ticketRows.count, 1)
        attachScreenshot("Completed four-segment journey preserved as one ticket")
    }

    func testRealTimeBoardingCanBeSkipped() throws {
        launch(language: "en", locale: "en_US", scale: 1)
        startJourney(task: "Board without waiting", service: "shuttle", skipBoarding: true)
        waitForPhase("focusing")
        attachScreenshot("Real-time boarding skipped by user")
        tap("cancelJourney")
        tap("cancelConfirm")
        XCTAssertTrue(app.buttons["departButton"].waitForExistence(timeout: 5))
    }

    private var ticketRows: XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "ticketRow_"))
    }

    private func launch(language: String, locale: String, scale: Double) {
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-store", "--time-scale", String(scale),
                               "-AppleLanguages", "(\(language))", "-AppleLocale", locale]
        app.launch()
        XCTAssertTrue(app.textFields["destinationField"].waitForExistence(timeout: 10))
        attachScreenshot("Initial \(language) station")
    }

    private func startJourney(task: String, service: String, skipBoarding: Bool = false) {
        let serviceButton = app.buttons["service_\(service)"]
        for _ in 0..<3 where !serviceButton.isHittable { app.swipeUp() }
        XCTAssertTrue(serviceButton.waitForExistence(timeout: 3))
        attachServiceDiagnostics(serviceButton, stage: "Before service selection")
        serviceButton.tap()
        attachServiceDiagnostics(serviceButton, stage: "After service selection tap")
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "selected == true"), object: serviceButton)
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 3), .completed,
                       "The requested service must become selected after one card tap; do not depart with a remembered service instead.")
        let destination = app.textFields["destinationField"]
        for _ in 0..<3 where !destination.isHittable { app.swipeDown() }
        destination.tap()
        destination.typeText(task)
        if app.keyboards.firstMatch.exists {
            destination.typeText("\n")
            let keyboardHidden = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.keyboards.firstMatch)
            XCTAssertEqual(XCTWaiter.wait(for: [keyboardHidden], timeout: 5), .completed,
                           "Return must submit the task and dismiss the keyboard before departure.")
        }
        attachServiceDiagnostics(serviceButton, stage: "Before departure after typing")
        XCTAssertTrue(serviceButton.isSelected, "Typing the task or dismissing the keyboard must preserve the chosen service.")
        tap("departButton")
        // Accelerated boarding can expire between an accessibility lookup and
        // its queued tap. Exercise automatic departure in accelerated flows;
        // the dedicated real-time boarding test covers the explicit skip action.
        if skipBoarding { tap("skipBoarding") }
        waitForPhase("focusing")
        XCTAssertTrue(app.staticTexts["focusTimer"].exists || app.staticTexts["focusTimer"].waitForExistence(timeout: 5))
    }

    private func punchCompletedTicket() {
        XCTAssertTrue(app.buttons["ticketPunch"].waitForExistence(timeout: 30), "A finished interval should save and present an unpunched ticket.")
        attachScreenshot("Freshly issued ticket before punching")
        // This is the accessible alternative Button, whose action is a tap.
        // The four-segment test separately exercises long-pressing the ticket.
        let punchAction = app.buttons["ticketPunch"]
        XCTAssertTrue(punchAction.isHittable)
        punchAction.tap()
        XCTAssertTrue(app.staticTexts["punchedStamp"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["ticketDone"].waitForExistence(timeout: 5), "Punching should replace the action with the keep-ticket action.")
        attachScreenshot("Ticket punched and stamped")
    }

    private func tap(_ identifier: String, timeout: TimeInterval = 5) {
        let labels: [String: [String]] = [
            "tabStation": ["车站", "Station"],
            "tabAtlas": ["路网", "Atlas"],
            "tabTickets": ["票夹", "Tickets"]
        ]
        let element: XCUIElement
        if let tabLabels = labels[identifier], !app.buttons[identifier].exists {
            // Native TabView items expose their localized labels; identifiers on
            // the tab's content root do not propagate to UITabBarButton.
            element = app.tabBars.buttons.matching(NSPredicate(format: "label IN %@", tabLabels)).firstMatch
        } else {
            element = app.buttons.matching(identifier: identifier).firstMatch
        }
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Missing action: \(identifier)")
        element.tap()
    }

    private func waitForPhase(_ phase: String, timeout: TimeInterval = 5) {
        let status = app.staticTexts["phaseStatus"]
        XCTAssertTrue(status.exists || status.waitForExistence(timeout: timeout))
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", phase), object: status)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: timeout), .completed, "Expected journey phase \(phase), got \(String(describing: status.value))")
    }

    private func selectExport(_ identifier: String) {
        let choices = app.buttons.matching(identifier: identifier)
        XCTAssertTrue(choices.firstMatch.waitForExistence(timeout: 5))
        // The observed system confirmation dialog exposes a wrapper Button and
        // its actionable leaf with the same identifier. Activate the leaf once.
        let choice = choices.element(boundBy: choices.count - 1)
        XCTAssertTrue(choice.isHittable)
        let menuEvidence = XCTAttachment(string: "Selected leaf: \(choice.frame)\n\(app.debugDescription)")
        menuEvidence.name = "Export menu before single activation"
        menuEvidence.lifetime = .keepAlways
        add(menuEvidence)
        choice.tap()
        let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: choices.firstMatch)
        XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 5), .completed,
                       "The export menu did not dismiss after its leaf action. Capture this state; do not blindly retry the tap.")
    }

    private func assertShareSheet(filenameSuffix: String) {
        // These selectors come from the captured native UIKit accessibility tree.
        // Verify a real PNG preview plus native image actions, not just any sheet.
        let sheet = app.otherElements["ActivityListView"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 8))
        let header = app.navigationBars["UIActivityContentView"]
        XCTAssertTrue(header.waitForExistence(timeout: 8))
        // The captured large-screen AX tree exposes the initial raw filename in
        // BottomCaption (including .png); LinkPresentation later asynchronously
        // splits it into TopCaption plus a PNG metadata caption. Validate the
        // same filename/type semantics through either observed presentation.
        let filename = header.descendants(matching: .any).matching(NSPredicate(
            format: "label BEGINSWITH %@ AND (label ENDSWITH %@ OR label ENDSWITH %@)",
            "MetroFocus-", filenameSuffix, filenameSuffix + ".png"
        )).firstMatch
        XCTAssertTrue(filename.waitForExistence(timeout: 10), "The native preview must name the requested MetroFocus export.")
        let pngEvidence = header.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] %@", "PNG")).firstMatch
        XCTAssertTrue(pngEvidence.waitForExistence(timeout: 10), "The native preview must identify PNG either by its file extension or image-format metadata.")
        XCTAssertTrue(header.images.firstMatch.exists, "The native sheet should render an image thumbnail.")
        let imageAction = app.cells.matching(NSPredicate(format: "label IN %@", ["Copy", "拷贝", "复制", "Save Image", "保存图像", "存储图像", "储存图像"])).firstMatch
        XCTAssertTrue(imageAction.waitForExistence(timeout: 5), "Native copy or save-image actions must be available for the exported PNG.")
    }

    private func attachServiceDiagnostics(_ service: XCUIElement, stage: String) {
        // Keep the actual hit target and selection snapshot with the failed run.
        // This distinguishes a card hit-test failure from later draft changes.
        let details = """
        Stage: \(stage)
        Target: \(service.identifier)
        Label: \(service.label)
        Frame: \(service.frame)
        Hittable: \(service.isHittable)
        Selected: \(service.isSelected)

        \(app.debugDescription)
        """
        let attachment = XCTAttachment(string: details)
        attachment.name = stage
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func attachScreenshot(_ label: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = label
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
