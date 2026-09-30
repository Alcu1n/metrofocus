import Foundation

/// Value-only boundary between the journey engine and optional system integrations.
struct SystemJourneySnapshot: Equatable, Sendable {
    var id: UUID
    var task: String
    var line: String
    var station: String
    var phase: String
    var segmentIndex: Int
    var segmentCount: Int
    var phaseStartedAt: Date?
    var deadline: Date?
    var focusSeconds: TimeInterval
    var restSeconds: TimeInterval
    var hasNextSegment: Bool { segmentIndex + 1 < segmentCount }
    var isTerminal: Bool { phase == "completed" || phase == "cancelled" }
}
