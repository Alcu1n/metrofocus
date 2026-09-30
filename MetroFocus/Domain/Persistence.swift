import Foundation
import SwiftData

@Model
final class JourneySession {
    #Index<JourneySession>([\.startedAt])
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var lineRawValue: String
    var task: String
    var phaseRawValue: String
    var focusSeconds: Double
    var stateData: Data

    var line: TransitLine { TransitLine(rawValue: lineRawValue) ?? .writing }
    var phase: JourneyPhase { JourneyPhase(rawValue: phaseRawValue) ?? .cancelled }

    init(state: JourneyState) throws {
        id = state.id
        startedAt = state.startedAt
        lineRawValue = state.plan.line.rawValue
        task = state.plan.task
        phaseRawValue = state.phase.rawValue
        focusSeconds = state.focusedSeconds
        stateData = try JSONEncoder().encode(state)
    }

    func update(from state: JourneyState, endedAt: Date? = nil) throws {
        let encoded = try JSONEncoder().encode(state)
        stateData = encoded
        phaseRawValue = state.phase.rawValue
        focusSeconds = state.focusedSeconds
        self.endedAt = endedAt
    }

    func decodedState() throws -> JourneyState { try JSONDecoder().decode(JourneyState.self, from: stateData) }
}

@Model
final class Ticket {
    #Index<Ticket>([\.completedAt])
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var journeyID: UUID
    var task: String
    var lineRawValue: String
    var kindRawValue: String
    var startedAt: Date
    var completedAt: Date
    var focusSeconds: Double
    var milestones: [String]
    var segmentCount: Int
    var punchedAt: Date?

    var line: TransitLine { TransitLine(rawValue: lineRawValue) ?? .writing }
    var kind: ServiceKind { ServiceKind(rawValue: kindRawValue) ?? .shuttle }

    init(state: JourneyState, completedAt: Date) {
        id = state.id
        journeyID = state.id
        task = state.plan.task
        lineRawValue = state.plan.line.rawValue
        kindRawValue = state.plan.kind.rawValue
        startedAt = state.startedAt
        self.completedAt = completedAt
        focusSeconds = state.focusedSeconds
        milestones = state.plan.milestones
        segmentCount = state.plan.segmentCount
    }
}

enum MetroFocusSchema: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [JourneySession.self, Ticket.self] }
}

enum MetroFocusMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [MetroFocusSchema.self] }
    static var stages: [MigrationStage] { [] }
}

enum MetroFocusStore {
    static func makeContainer(inMemory: Bool = false, url: URL? = nil) throws -> ModelContainer {
        // SwiftData does not consistently create Application Support before its
        // first SQLite open. Create only the directory; never replace store files.
        if !inMemory {
            if let url {
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            } else {
                _ = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            }
        }
        let schema = Schema(versionedSchema: MetroFocusSchema.self)
        let configuration: ModelConfiguration
        if let url, !inMemory {
            configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        } else {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none)
        }
        return try ModelContainer(for: schema, migrationPlan: MetroFocusMigrationPlan.self, configurations: [configuration])
    }
}
