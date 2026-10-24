import Foundation
import UserNotifications
import Combine

@MainActor
final class NotificationService: ObservableObject {
    @Published private(set) var isAuthorized = false
    @Published private(set) var errorMessage: String?
    private let authorize: () async throws -> Bool
    private let schedule: (UNNotificationRequest) async throws -> Void

    init(authorize: (() async throws -> Bool)? = nil,
         schedule: ((UNNotificationRequest) async throws -> Void)? = nil) {
        self.authorize = authorize ?? {
            try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        }
        self.schedule = schedule ?? { try await UNUserNotificationCenter.current().add($0) }
    }

    func requestAuthorization() async {
        do {
            isAuthorized = try await authorize()
            errorMessage = isAuthorized ? nil : "Notifications are disabled. Enable them in Settings to receive local alerts."
        } catch { isAuthorized = false; errorMessage = error.localizedDescription }
    }

    @discardableResult
    func scheduleGeofenceEntry(for siteName: String, pendingTasks: Int) -> Task<Void, Never> {
        let count = max(0, pendingTasks)
        let body = count == 0 ? "No tasks scheduled for this site right now."
            : "\(count) task\(count == 1 ? "" : "s") waiting. Open GeoPulse to inspect."
        return submit(id: "geofence.enter.\(siteName)", title: "Arrived at \(siteName)", body: body)
    }

    @discardableResult
    func scheduleGeofenceExit(for siteName: String) -> Task<Void, Never> {
        submit(id: "geofence.exit.\(siteName)", title: "Left \(siteName)", body: "Inspection records are saved on this device.")
    }

    @discardableResult
    func scheduleFallDetectionAlert() -> Task<Void, Never> {
        submit(id: "fallDetection.alert", title: "Possible fall recorded",
               body: "Recorded locally. Emergency dispatch is not connected. Contact emergency services if needed.")
    }

    @discardableResult
    func scheduleRecheckReminder(taskTitle: String, at date: Date) -> Task<Void, Never> {
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return submit(id: "recheck.\(UUID())", title: "Recheck: \(taskTitle)",
            body: "Scheduled follow-up for an inspection finding.",
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
    }

    private func submit(id: String, title: String, body: String, trigger: UNNotificationTrigger? = nil) -> Task<Void, Never> {
        let content = UNMutableNotificationContent()
        content.title = title; content.body = body; content.sound = .default
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        return Task {
            do { try await schedule(request); errorMessage = nil }
            catch { errorMessage = "Could not schedule notification: \(error.localizedDescription)" }
        }
    }
}
