import ActivityKit
import Foundation

struct TransitActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var station: String
        var phase: String
        var segmentIndex: Int
        var segmentCount: Int
        var startedAt: Date?
        var deadline: Date?
    }
    var journeyID: UUID
    var task: String
    var line: String
}
