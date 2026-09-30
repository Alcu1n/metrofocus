import Foundation
import Observation
import UIKit
import UserNotifications

/// Buffers notification routing until the root view and persisted journey are ready.
@MainActor @Observable
final class NotificationInbox {
    static let shared = NotificationInbox()
    var pendingJourneyID: UUID?
    private init() {}
}

@MainActor
final class AppNotificationDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                           didReceive response: UNNotificationResponse) async {
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier,
              let raw = response.notification.request.content.userInfo["journeyID"] as? String,
              let journeyID = UUID(uuidString: raw) else { return }
        await MainActor.run {
            NotificationInbox.shared.pendingJourneyID = journeyID
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                           willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        // The app supplies its own foreground station chime; never double-play it.
        [.banner]
    }
}
