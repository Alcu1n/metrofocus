import Foundation

enum TransitLine: String, Codable, CaseIterable, Identifiable, Sendable {
    case writing, coding, reading, life
    var id: String { rawValue }
    var number: Int {
        switch self { case .writing: 1; case .coding: 2; case .reading: 3; case .life: 4 }
    }
}

enum ServiceKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case shuttle, standard, express, custom
    var id: String { rawValue }
}

struct JourneyPlan: Codable, Equatable, Sendable {
    var task: String
    var line: TransitLine
    var kind: ServiceKind
    var focusMinutes: Int
    var restMinutes: Int
    var segmentCount: Int
    var milestones: [String]
    var boardingSeconds: TimeInterval = 30

    init(task: String, line: TransitLine, kind: ServiceKind, focusMinutes: Int, restMinutes: Int,
         segmentCount: Int, milestones: [String] = [], boardingSeconds: TimeInterval = 30) {
        self.task = task
        self.line = line
        self.kind = kind
        self.focusMinutes = focusMinutes
        self.restMinutes = restMinutes
        self.segmentCount = segmentCount
        self.milestones = milestones
        self.boardingSeconds = boardingSeconds
    }

    static func preset(_ kind: ServiceKind, task: String, line: TransitLine) -> Self {
        switch kind {
        case .shuttle: Self(task: task, line: line, kind: kind, focusMinutes: 15, restMinutes: 0, segmentCount: 1)
        case .standard: Self(task: task, line: line, kind: kind, focusMinutes: 25, restMinutes: 5, segmentCount: 4)
        case .express: Self(task: task, line: line, kind: kind, focusMinutes: 50, restMinutes: 10, segmentCount: 2)
        case .custom: Self(task: task, line: line, kind: kind, focusMinutes: 25, restMinutes: 5, segmentCount: 2)
        }
    }

    var totalFocusMinutes: Int { focusMinutes * segmentCount }
    var finalRelaxationMinutes: Int {
        switch kind { case .shuttle: 3; case .standard: 15; case .express: 10; case .custom: restMinutes }
    }

    var isValid: Bool {
        let name = task.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 24, (5...120).contains(focusMinutes),
              (1...8).contains(segmentCount), boardingSeconds.isFinite,
              (0...300).contains(boardingSeconds) else { return false }
        return (1...30).contains(restMinutes) || (kind == .shuttle && restMinutes == 0 && segmentCount == 1)
    }
}

enum JourneyPhase: String, Codable, Sendable {
    case boarding, focusing, paused, resting, awaitingDeparture, completed, cancelled
}

struct JourneyState: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var plan: JourneyPlan
    var phase: JourneyPhase
    var segmentIndex: Int
    var startedAt: Date
    var phaseStartedAt: Date?
    var deadline: Date?
    /// Settled focus time, excluding the currently running anchor.
    var focusedSeconds: TimeInterval
    var pausedPhase: JourneyPhase?
    var pausedRemaining: TimeInterval?
    var durationScale: Double

    var isActive: Bool { phase != .completed && phase != .cancelled }
    var phaseDuration: TimeInterval {
        switch phase == .paused ? pausedPhase ?? .focusing : phase {
        case .boarding: plan.boardingSeconds
        case .focusing: TimeInterval(plan.focusMinutes * 60)
        case .resting: TimeInterval(plan.restMinutes * 60)
        default: 0
        }
    }

    func remaining(at date: Date = .now) -> TimeInterval {
        if phase == .paused { return max(0, pausedRemaining ?? 0) }
        guard let deadline else { return 0 }
        return max(0, min(phaseDuration, deadline.timeIntervalSince(date) / durationScale))
    }

    func progress(at date: Date = .now) -> Double {
        guard phaseDuration > 0 else { return phase == .completed || phase == .awaitingDeparture ? 1 : 0 }
        return min(1, max(0, 1 - remaining(at: date) / phaseDuration))
    }

    func currentFocusSeconds(at date: Date) -> TimeInterval {
        guard phase == .focusing, let phaseStartedAt, let deadline else { return focusedSeconds }
        return focusedSeconds + max(0, min(date, deadline).timeIntervalSince(phaseStartedAt) / durationScale)
    }

    /// Extra waiting at a platform is deliberately excluded from this lower bound.
    func earliestArrival(at date: Date) -> Date? {
        guard isActive else { return nil }
        let subsequentSegments = max(0, plan.segmentCount - segmentIndex - 1)
        let segment = TimeInterval(plan.focusMinutes * 60)
        let rest = TimeInterval(plan.restMinutes * 60)
        let effectivePhase = phase == .paused ? pausedPhase ?? .focusing : phase
        let seconds: TimeInterval
        switch effectivePhase {
        case .boarding: seconds = remaining(at: date) + Double(plan.segmentCount) * segment + Double(plan.segmentCount - 1) * rest
        case .focusing: seconds = remaining(at: date) + Double(subsequentSegments) * (segment + rest)
        case .resting: seconds = remaining(at: date) + Double(subsequentSegments) * segment + Double(max(0, subsequentSegments - 1)) * rest
        case .awaitingDeparture: seconds = Double(subsequentSegments) * segment + Double(max(0, subsequentSegments - 1)) * rest
        default: return nil
        }
        return date.addingTimeInterval(seconds * durationScale)
    }
}
