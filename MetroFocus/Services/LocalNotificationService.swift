import Foundation
import UserNotifications

@MainActor
final class LocalNotificationService {
    private let center = UNUserNotificationCenter.current()
    private var tail: Task<Void, Never>?
    private var revision = 0
    private let identifiers = ["metrofocus.focus.end", "metrofocus.rest.end"]
    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }
    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }
    func schedule(_ state: SystemJourneySnapshot) { enqueue(state) }
    func cancel() { enqueue(nil) }
    private func enqueue(_ state: SystemJourneySnapshot?) {
        revision += 1
        let requestRevision = revision
        let previous = tail
        tail = Task { [weak self] in
            await previous?.value
            guard let self, requestRevision == self.revision else { return }
            await self.apply(state)
        }
    }
    private func apply(_ state: SystemJourneySnapshot?) async {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        guard let state, !state.isTerminal, let deadline = state.deadline else { return }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
        if state.phase == "focusing" || state.phase == "boarding" {
            let focusEnd = state.phase == "boarding" ? deadline.addingTimeInterval(state.focusSeconds) : deadline
            await add(id: identifiers[0], at: focusEnd, title: state.hasNextSegment ? String(localized: "列车进站，请稍作休息") : String(localized: "已抵达终点"), body: state.hasNextSegment ? String(localized: "这一段专注已完成。下一段由你决定何时出发。") : String(localized: "你的专注车票已就绪，打开 App 打孔收藏。"), journey: state.id)
            if state.hasNextSegment {
                await add(id: identifiers[1], at: focusEnd.addingTimeInterval(state.restSeconds), title: String(localized: "休息结束，下一站等你"), body: String(localized: "打开 App 确认发车，开始下一段专注。"), journey: state.id)
            }
        } else if state.phase == "resting" {
            await add(id: identifiers[1], at: deadline, title: String(localized: "休息结束，下一站等你"), body: String(localized: "打开 App 确认发车，开始下一段专注。"), journey: state.id)
        }
    }
    private func add(id: String, at date: Date, title: String, body: String, journey: UUID) async {
        guard date.timeIntervalSinceNow > 1 else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.threadIdentifier = "metrofocus.journey"
        content.userInfo = ["journeyID": journey.uuidString]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
        try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
