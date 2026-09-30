import Foundation
import Observation
import SwiftData

/// All model access and state changes are synchronous on the main actor.
/// Timer callbacks only ask this engine to reconcile persisted time anchors.
@MainActor @Observable
final class JourneyEngine {
    private(set) var state: JourneyState?
    private(set) var tickets: [Ticket] = []
    private(set) var sessions: [JourneySession] = []
    private(set) var revision = 0
    private(set) var errorMessage: String?

    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let saveContext: (ModelContext) throws -> Void
    @ObservationIgnored private let durationScale: Double
    @ObservationIgnored private var storageReady = false
    @ObservationIgnored private var pendingSave = false
    @ObservationIgnored private var pendingTicket: Ticket?

    init(modelContainer: ModelContainer, now: @escaping () -> Date = Date.init,
         durationScale: Double = 1, save: @escaping (ModelContext) throws -> Void = { try $0.save() }) {
        context = ModelContext(modelContainer)
        context.autosaveEnabled = false
        self.now = now
        saveContext = save
        #if DEBUG
        self.durationScale = durationScale.isFinite && durationScale > 0 ? durationScale : 1
        #else
        self.durationScale = 1
        #endif
        load()
        refresh()
    }

    func start(_ plan: JourneyPlan) {
        guard storageReady, !pendingSave, state?.isActive != true else { return }
        guard plan.isValid else {
            errorMessage = String(localized: "请填写 1–24 字的任务名称，并检查班次设置。")
            return
        }
        let date = now()
        var normalizedPlan = plan
        normalizedPlan.task = plan.task.trimmingCharacters(in: .whitespacesAndNewlines)
        normalizedPlan.milestones = Array(plan.milestones.prefix(plan.segmentCount)).map {
            String($0.trimmingCharacters(in: .whitespacesAndNewlines).prefix(24))
        }
        state = JourneyState(id: UUID(), plan: normalizedPlan, phase: .boarding, segmentIndex: 0,
                             startedAt: date, phaseStartedAt: date,
                             deadline: date.addingTimeInterval(plan.boardingSeconds * durationScale),
                             focusedSeconds: 0, durationScale: durationScale)
        persist()
        refresh()
    }

    func skipBoarding() {
        refresh()
        guard !pendingSave, var current = state, current.phase == .boarding else { return }
        enterFocus(&current, at: now())
        state = current
        persist()
    }

    func pause() {
        refresh()
        guard !pendingSave, var current = state,
              [.boarding, .focusing, .resting].contains(current.phase) else { return }
        let date = now()
        current.focusedSeconds = current.currentFocusSeconds(at: date)
        current.pausedRemaining = current.remaining(at: date)
        current.pausedPhase = current.phase
        current.phase = .paused
        current.phaseStartedAt = nil
        current.deadline = nil
        state = current
        persist()
    }

    func resume() {
        guard storageReady, !pendingSave, var current = state, current.phase == .paused,
              let phase = current.pausedPhase, let remaining = current.pausedRemaining else { return }
        let date = now()
        current.phase = phase
        current.phaseStartedAt = date
        current.deadline = date.addingTimeInterval(remaining * current.durationScale)
        current.pausedPhase = nil
        current.pausedRemaining = nil
        state = current
        persist()
        refresh()
    }

    /// Valid during a rest or after it ends. Repeated taps cannot skip another segment.
    func continueJourney() {
        refresh()
        guard !pendingSave, var current = state,
              current.phase == .resting || current.phase == .awaitingDeparture,
              current.segmentIndex + 1 < current.plan.segmentCount else { return }
        current.segmentIndex += 1
        enterFocus(&current, at: now())
        state = current
        persist()
    }

    func cancelJourney() {
        refresh()
        guard !pendingSave, var current = state, current.isActive else { return }
        let date = now()
        current.focusedSeconds = current.currentFocusSeconds(at: date)
        current.phase = .cancelled
        current.phaseStartedAt = date
        current.deadline = nil
        current.pausedPhase = nil
        current.pausedRemaining = nil
        state = current
        persist()
    }

    /// May catch up boarding, one focus segment, and its rest. Never crosses departure confirmation.
    func refresh() {
        guard storageReady, !pendingSave, var current = state, current.isActive else { return }
        let date = now()
        var changed = false
        while let deadline = current.deadline, date >= deadline {
            switch current.phase {
            case .boarding:
                enterFocus(&current, at: deadline)
            case .focusing:
                current.focusedSeconds = current.currentFocusSeconds(at: deadline)
                current.phaseStartedAt = deadline
                if current.segmentIndex + 1 == current.plan.segmentCount {
                    current.phase = .completed
                    current.deadline = nil
                } else {
                    current.phase = .resting
                    current.deadline = deadline.addingTimeInterval(Double(current.plan.restMinutes * 60) * current.durationScale)
                }
            case .resting:
                current.phase = .awaitingDeparture
                current.phaseStartedAt = deadline
                current.deadline = nil
            default: break
            }
            changed = true
            if current.phase == .completed || current.phase == .awaitingDeparture { break }
            if current.phase != .boarding && current.phase != .focusing && current.phase != .resting { break }
        }
        if changed {
            state = current
            persist()
        }
    }

    func punch(ticketID: UUID) {
        guard storageReady, !pendingSave,
              let ticket = tickets.first(where: { $0.id == ticketID }), ticket.punchedAt == nil else { return }
        ticket.punchedAt = now()
        pendingSave = true
        commit()
    }

    func retrySave() {
        if !storageReady { load(); refresh(); return }
        guard pendingSave else { return }
        commit()
        if !pendingSave { refresh() }
    }

    func ticket(for sessionID: UUID) -> Ticket? { tickets.first { $0.journeyID == sessionID } }

    func totalFocusSeconds(line: TransitLine? = nil) -> Double {
        let date = now()
        return sessions.reduce(0) { total, session in
            guard line == nil || session.line == line else { return total }
            if let state, session.id == state.id {
                return total + state.currentFocusSeconds(at: date)
            }
            return total + session.focusSeconds
        }
    }

    private func enterFocus(_ current: inout JourneyState, at date: Date) {
        current.phase = .focusing
        current.phaseStartedAt = date
        current.deadline = date.addingTimeInterval(Double(current.plan.focusMinutes * 60) * current.durationScale)
        current.pausedPhase = nil
        current.pausedRemaining = nil
    }

    private func load() {
        do {
            let fetchedSessions = try context.fetch(FetchDescriptor<JourneySession>(sortBy: [SortDescriptor(\.startedAt, order: .reverse)]))
            let fetchedTickets = try context.fetch(FetchDescriptor<Ticket>(sortBy: [SortDescriptor(\.completedAt, order: .reverse)]))
            let active = fetchedSessions.filter { $0.phase != .completed && $0.phase != .cancelled }
            guard active.count <= 1 else { throw StoreError.multipleActiveJourneys }
            let recovered = try (active.first ?? fetchedSessions.first)?.decodedState()
            sessions = fetchedSessions
            tickets = fetchedTickets
            state = recovered
            storageReady = true
            errorMessage = nil
        } catch {
            storageReady = false
            errorMessage = String(localized: "无法读取旅程记录。请重试；已有数据不会被清除。")
        }
    }

    private func persist() {
        guard let state else { return }
        do {
            let session: JourneySession
            if let existing = sessions.first(where: { $0.id == state.id }) {
                session = existing
            } else {
                session = try JourneySession(state: state)
                context.insert(session)
                sessions.insert(session, at: 0)
            }
            try session.update(from: state, endedAt: state.isActive ? nil : state.phaseStartedAt)
            if state.phase == .completed, ticket(for: state.id) == nil, pendingTicket == nil {
                let ticket = Ticket(state: state, completedAt: state.phaseStartedAt ?? now())
                context.insert(ticket)
                pendingTicket = ticket
            }
            pendingSave = true
            commit()
        } catch {
            pendingSave = true
            errorMessage = String(localized: "旅程尚未保存。请重试保存，当前进度会保留。")
        }
    }

    private func commit() {
        do {
            try saveContext(context)
            if let pendingTicket {
                tickets.insert(pendingTicket, at: 0)
                self.pendingTicket = nil
            }
            pendingSave = false
            errorMessage = nil
            revision += 1
        } catch {
            errorMessage = String(localized: "旅程尚未保存。请重试保存，当前进度会保留。")
        }
    }

    private enum StoreError: Error { case multipleActiveJourneys }
}
