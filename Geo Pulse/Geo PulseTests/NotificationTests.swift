import Testing
import Foundation
import UserNotifications
@testable import Geo_Pulse

@MainActor
@Suite("Notification scheduling")
struct NotificationTests {
    @Test(arguments: [0, 1, 3])
    func entryCounts(count: Int) async throws {
        var recorded: UNNotificationRequest?
        let service = NotificationService(authorize: { true }, schedule: { recorded = $0 })
        await service.scheduleGeofenceEntry(for: "Site", pendingTasks: count).value
        let request = try #require(recorded)
        #expect(request.identifier == "geofence.enter.Site")
        #expect(request.content.title == "Arrived at Site")
        if count == 0 { #expect(request.content.body.contains("No tasks")) }
        else { #expect(request.content.body.contains(count == 1 ? "1 task waiting" : "3 tasks waiting")) }
        #expect(request.trigger == nil)
    }

    @Test func permissionDenialIsVisible() async {
        let service = NotificationService(authorize: { false }, schedule: { _ in })
        await service.requestAuthorization()
        #expect(!service.isAuthorized)
        #expect(service.errorMessage != nil)
    }

    @Test func scheduleFailureIsVisible() async {
        let service = NotificationService(schedule: { _ in throw CocoaError(.featureUnsupported) })
        await service.scheduleFallDetectionAlert().value
        #expect(service.errorMessage != nil)
    }

    @Test func reminderHasRequestedDateAndDoesNotRepeat() async throws {
        var recorded: UNNotificationRequest?
        let service = NotificationService(schedule: { recorded = $0 })
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        await service.scheduleRecheckReminder(taskTitle: "Seal", at: date).value
        let trigger = try #require(recorded?.trigger as? UNCalendarNotificationTrigger)
        #expect(!trigger.repeats)
        #expect(trigger.dateComponents == Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date))
        #expect(recorded?.content.title == "Recheck: Seal")
    }
}
