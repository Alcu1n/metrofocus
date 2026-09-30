import SwiftUI
import SwiftData
import UserNotifications

@MainActor @Observable
final class AppModel {
    let engine: JourneyEngine
    let draft = JourneyDraft()
    let settings: SensorySettings
    let sensory: SensoryService
    let notifications = LocalNotificationService()
    let liveActivity = LiveActivityService()
    var selectedTab = 0
    var showsJourney = false
    var presentedTicket: Ticket?
    var foreground = true
    private var previousState: JourneyState?
    private var lastPulseBucket = -1
    private var lastApproachID = ""

    init(container: ModelContainer, durationScale: Double = 1) {
        engine = JourneyEngine(modelContainer: container, durationScale: durationScale)
        settings = SensorySettings()
        sensory = SensoryService(settings: settings)
        previousState = engine.state
        if let state = engine.state { showsJourney = state.isActive || (state.phase == .completed && engine.ticket(for: state.id)?.punchedAt == nil) }
        synchronize(allowEffects: false)
    }

    var stationName: String {
        guard let state = engine.state else { return "" }
        let index = state.segmentIndex
        if index < state.plan.milestones.count, !state.plan.milestones[index].isEmpty { return state.plan.milestones[index] }
        if index + 1 == state.plan.segmentCount { return state.plan.task }
        return String(format: L("区间 %d", "Stop %d"), index + 1)
    }

    func startJourney(_ plan: JourneyPlan) {
        engine.start(plan)
        guard engine.state?.isActive == true else { return }
        showsJourney = true
        synchronize()
        requestArrivalAlertsIfNeeded()
    }

    private func requestArrivalAlertsIfNeeded() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") { return }
        #endif
        guard !UserDefaults.standard.bool(forKey: "arrivalPermissionRequested") else { return }
        UserDefaults.standard.set(true, forKey: "arrivalPermissionRequested")
        Task {
            _ = await notifications.requestAuthorization()
            synchronize(allowEffects: false)
        }
    }

    func openJourney(id: UUID) {
        engine.refresh()
        if engine.state?.id == id {
            showsJourney = true
        } else if let ticket = engine.ticket(for: id) {
            presentedTicket = ticket
        }
    }

    func synchronize(allowEffects: Bool = true) {
        guard let state = engine.state else { notifications.cancel(); liveActivity.end(); return }
        // Side effects follow committed state, never a failed write.
        guard engine.errorMessage == nil else { return }
        let snapshot = SystemJourneySnapshot(id: state.id, task: state.plan.task, line: state.plan.line.rawValue,
            station: stationName, phase: state.phase.rawValue, segmentIndex: state.segmentIndex,
            segmentCount: state.plan.segmentCount, phaseStartedAt: state.phaseStartedAt, deadline: state.deadline,
            focusSeconds: Double(state.plan.focusMinutes * 60) * state.durationScale,
            restSeconds: Double(state.plan.restMinutes * 60) * state.durationScale)
        notifications.schedule(snapshot)
        liveActivity.sync(snapshot)
        if state.phase == .focusing { sensory.play() } else { sensory.stop() }
        if allowEffects, foreground, previousState?.phase != state.phase {
            if state.phase == .focusing {
                sensory.effect(.departure); sensory.feedback(.departure)
                sensory.announce(station: stationName)
            } else if state.phase == .resting || state.phase == .completed {
                sensory.effect(.arrival); sensory.feedback(.arrival)
            }
        }
        previousState = state
    }

    func tick() {
        let revision = engine.revision
        engine.refresh()
        if engine.revision != revision { synchronize(allowEffects: foreground) }
        guard foreground, let state = engine.state, state.phase == .focusing else { return }
        let elapsed = state.currentFocusSeconds(at: .now)
        let bucket = Int(elapsed / 300)
        if lastPulseBucket >= 0, bucket > lastPulseBucket { sensory.feedback(.pulse) }
        lastPulseBucket = bucket
        let approachID = state.id.uuidString + "-\(state.segmentIndex)"
        if state.remaining() <= 60, lastApproachID != approachID {
            sensory.feedback(.arrival)
            lastApproachID = approachID
        }
    }

    func reconcileForeground() {
        engine.refresh()
        if let state = engine.state {
            lastPulseBucket = Int(state.currentFocusSeconds(at: .now) / 300)
            if state.remaining() <= 60 { lastApproachID = state.id.uuidString + "-\(state.segmentIndex)" }
        }
        synchronize(allowEffects: false)
    }

    func punch(_ ticket: Ticket) {
        let wasPunched = ticket.punchedAt != nil
        engine.punch(ticketID: ticket.id)
        if !wasPunched, ticket.punchedAt != nil, engine.errorMessage == nil {
            sensory.effect(.punch); sensory.feedback(.punch)
        }
    }
}
