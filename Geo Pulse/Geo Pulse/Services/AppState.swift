import Foundation
import SwiftUI
import Combine
import CoreLocation

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

    let locationService = LocationService()
    let notificationService = NotificationService()

    private var cancellables: Set<AnyCancellable> = []
    private var entryObserver: NSObjectProtocol?
    private var exitObserver: NSObjectProtocol?

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

        observeGeofenceEvents()
    }

    deinit {
        if let entryObserver { NotificationCenter.default.removeObserver(entryObserver) }
        if let exitObserver { NotificationCenter.default.removeObserver(exitObserver) }
    }

    var activeSite: Site? {
        sites.first(where: { $0.isInsideGeofence })
    }

    var todayTasks: [FieldTask] {
        activeSite?.tasks ?? []
    }

    func signIn() {
        isAuthenticated = true
        Task { await bootstrapSensors() }
    }

    func signOut() {
        isAuthenticated = false
        locationService.stopAllMonitoring()
        locationService.stopUpdating()
    }

    func syncNow() {
        lastSyncDate = Date()
    }

    func bootstrapSensors() async {
        await notificationService.requestAuthorization()

        switch locationService.authorizationStatus {
        case .notDetermined:
            locationService.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            locationService.requestAlwaysAuthorization()
        case .authorizedAlways:
            locationService.enableBackgroundUpdates(true)
        default:
            break
        }

        locationService.startUpdating()
        locationService.monitorSites(sites)
    }

    private func observeGeofenceEvents() {
        entryObserver = NotificationCenter.default.addObserver(
            forName: .geofenceDidEnter,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let siteId = note.userInfo?["siteId"] as? UUID else { return }
            Task { @MainActor in self?.handleEntry(siteId: siteId) }
        }

        exitObserver = NotificationCenter.default.addObserver(
            forName: .geofenceDidExit,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let siteId = note.userInfo?["siteId"] as? UUID else { return }
            Task { @MainActor in self?.handleExit(siteId: siteId) }
        }
    }

    private func handleEntry(siteId: UUID) {
        guard let index = sites.firstIndex(where: { $0.id == siteId }) else { return }
        guard !sites[index].isInsideGeofence else { return }
        sites[index].isInsideGeofence = true
        let site = sites[index]
        currentUser.currentSiteName = site.name

        if geofenceAlertsOn {
            notificationService.scheduleGeofenceEntry(for: site.name, pendingTasks: site.tasks.count)
        }
    }

    private func handleExit(siteId: UUID) {
        guard let index = sites.firstIndex(where: { $0.id == siteId }) else { return }
        guard sites[index].isInsideGeofence else { return }
        sites[index].isInsideGeofence = false

        if geofenceAlertsOn {
            notificationService.scheduleGeofenceExit(for: sites[index].name)
        }
    }
}
