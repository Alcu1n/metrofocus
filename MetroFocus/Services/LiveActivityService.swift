import ActivityKit
import Foundation

/// Serializes asynchronous updates; a slower old update cannot overwrite a newer one.
@MainActor
final class LiveActivityService {
    private var tail: Task<Void, Never>?
    private var revision = 0
    func sync(_ snapshot: SystemJourneySnapshot) {
        if snapshot.isTerminal { end(); return }
        enqueue(snapshot)
    }
    func end() { enqueue(nil) }
    private func enqueue(_ snapshot: SystemJourneySnapshot?) {
        revision += 1
        let requestRevision = revision
        let previous = tail
        tail = Task { [weak self] in
            await previous?.value
            guard let self, requestRevision == self.revision else { return }
            await self.apply(snapshot)
        }
    }
    private func apply(_ snapshot: SystemJourneySnapshot?) async {
        guard let snapshot else {
            for activity in Activity<TransitActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = TransitActivityAttributes.ContentState(station: snapshot.station, phase: snapshot.phase, segmentIndex: snapshot.segmentIndex, segmentCount: snapshot.segmentCount, startedAt: snapshot.phaseStartedAt, deadline: snapshot.deadline)
        let content = ActivityContent(state: state, staleDate: snapshot.deadline)
        let activities = Activity<TransitActivityAttributes>.activities
        for old in activities where old.attributes.journeyID != snapshot.id {
            await old.end(nil, dismissalPolicy: .immediate)
        }
        if let existing = Activity<TransitActivityAttributes>.activities.first(where: { $0.attributes.journeyID == snapshot.id }) {
            await existing.update(content)
        } else {
            _ = try? Activity.request(attributes: TransitActivityAttributes(journeyID: snapshot.id, task: snapshot.task, line: snapshot.line), content: content, pushType: nil)
        }
    }
}
