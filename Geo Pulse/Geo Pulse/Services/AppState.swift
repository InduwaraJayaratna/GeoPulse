import Foundation
import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var currentUser: UserProfile
    @Published var sites: [Site]
    @Published var inspectionHistory: [Inspection]
    @Published var isAuthenticated: Bool
    @Published var isLoneWorkerMonitoringOn: Bool
    @Published var geofenceAlertsOn: Bool
    @Published var severeWeatherAlertsOn: Bool
    @Published var lastSyncDate: Date
    @Published var loneWorkerTimerMinutesRemaining: Int

    init() {
        self.currentUser = SampleData.currentUser
        self.sites = SampleData.sites
        self.inspectionHistory = SampleData.historyInspections
        self.isAuthenticated = false
        self.isLoneWorkerMonitoringOn = true
        self.geofenceAlertsOn = true
        self.severeWeatherAlertsOn = true
        self.lastSyncDate = Date().addingTimeInterval(-240)
        self.loneWorkerTimerMinutesRemaining = 38
    }

    var activeSite: Site? {
        sites.first(where: { $0.isInsideGeofence })
    }

    var todayTasks: [FieldTask] {
        activeSite?.tasks ?? []
    }

    func signIn() {
        isAuthenticated = true
    }

    func signOut() {
        isAuthenticated = false
    }

    func syncNow() {
        lastSyncDate = Date()
    }
}
