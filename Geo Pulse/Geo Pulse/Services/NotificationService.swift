import Foundation
import UserNotifications
import Combine

@MainActor
final class NotificationService: ObservableObject {
    @Published var isAuthorized: Bool = false

    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            self.isAuthorized = granted
        } catch {
            self.isAuthorized = false
        }
    }

    func scheduleGeofenceEntry(for siteName: String, pendingTasks: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Arrived at \(siteName)"
        content.body = pendingTasks == 0
            ? "No tasks scheduled for this site right now."
            : "\(pendingTasks) task\(pendingTasks == 1 ? "" : "s") waiting. Tap to inspect."
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(
            identifier: "geofence.enter.\(siteName)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    func scheduleGeofenceExit(for siteName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Left \(siteName)"
        content.body = "Inspection records will sync automatically when you reconnect."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "geofence.exit.\(siteName)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    func scheduleFallDetectionAlert() {
        let content = UNMutableNotificationContent()
        content.title = "Possible fall detected"
        content.body = "Tap I'm OK within 30 seconds to cancel."
        content.sound = .defaultCritical
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(
            identifier: "fallDetection.alert",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    func scheduleRecheckReminder(taskTitle: String, at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Recheck: \(taskTitle)"
        content.body = "Scheduled follow-up for a previously flagged inspection."
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: "recheck.\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }
}
