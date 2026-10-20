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
    @Published var isLoneWorkerMonitoringOn: Bool {
        didSet { loneWorkerMonitoringToggled() }
    }
    @Published var geofenceAlertsOn: Bool
    @Published var severeWeatherAlertsOn: Bool
    @Published var lastSyncDate: Date
    @Published var loneWorkerTimerMinutesRemaining: Int
    @Published var showFallAlert: Bool = false
    @Published var activityFeed: [ActivityEvent] = []
    @Published var syncStatus: SyncConnectionStatus = .connecting

    let locationService = LocationService()
    let notificationService = NotificationService()
    let motionService = MotionService()
    let syncRepository: SyncRepository = MockSyncRepository()

    private var cancellables: Set<AnyCancellable> = []
    private var entryObserver: NSObjectProtocol?
    private var exitObserver: NSObjectProtocol?
    private var fallObserver: NSObjectProtocol?
    private var feedTask: Task<Void, Never>?
    private var statusTask: Task<Void, Never>?

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
        observeFallEvents()
        startSyncFeed()
    }

    deinit {
        if let entryObserver { NotificationCenter.default.removeObserver(entryObserver) }
        if let exitObserver { NotificationCenter.default.removeObserver(exitObserver) }
        if let fallObserver { NotificationCenter.default.removeObserver(fallObserver) }
        feedTask?.cancel()
        statusTask?.cancel()
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
        motionService.stopMonitoring()
    }

    func syncNow() {
        lastSyncDate = Date()
    }

    func simulateFall() {
        motionService.simulateFall()
    }

    func cancelFallAlert() {
        showFallAlert = false
        motionService.acknowledgeFall()
    }

    func escalateFallAlert() {
        showFallAlert = false
        motionService.acknowledgeFall()
        notificationService.scheduleFallDetectionAlert()
        let incident = SampleData.safetyIncident(for: activeSite?.name ?? currentUser.currentSiteName)
        inspectionHistory.insert(incident, at: 0)
        activityFeed.insert(
            ActivityEvent(
                kind: .fallAlert,
                actorName: currentUser.displayName,
                siteName: incident.siteName,
                summary: "Possible fall — alert escalated to Markus Vance"
            ),
            at: 0
        )
        Task { await syncRepository.publish(inspection: incident) }
    }

    func recordInspectionCompleted(_ inspection: Inspection) {
        inspectionHistory.insert(inspection, at: 0)
        Task { await syncRepository.publish(inspection: inspection) }
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

        if isLoneWorkerMonitoringOn {
            motionService.startMonitoring()
        }

        await refreshWeatherForAllSites()
    }

    func refreshWeatherForAllSites() async {
        await withTaskGroup(of: (UUID, WeatherSnapshot?).self) { group in
            for site in sites {
                group.addTask {
                    let snapshot = try? await WeatherService.shared.fetchCurrent(for: site.coordinate)
                    return (site.id, snapshot)
                }
            }
            for await (siteId, snapshot) in group {
                if let snapshot, let index = sites.firstIndex(where: { $0.id == siteId }) {
                    sites[index].weather = snapshot
                }
            }
        }
    }

    func refreshWeather(for siteId: UUID) async {
        guard let site = sites.first(where: { $0.id == siteId }) else { return }
        if let snapshot = try? await WeatherService.shared.fetchCurrent(for: site.coordinate),
           let index = sites.firstIndex(where: { $0.id == siteId }) {
            sites[index].weather = snapshot
            if let warning = snapshot.severeWarning, severeWeatherAlertsOn {
                notificationService.scheduleGeofenceEntry(for: "\(site.name) · \(warning)", pendingTasks: site.tasks.count)
            }
        }
    }

    private func loneWorkerMonitoringToggled() {
        guard isAuthenticated else { return }
        if isLoneWorkerMonitoringOn {
            motionService.startMonitoring()
        } else {
            motionService.stopMonitoring()
            showFallAlert = false
        }
    }

    private func startSyncFeed() {
        feedTask = Task { [weak self] in
            guard let self else { return }
            for await event in self.syncRepository.activityFeed() {
                await MainActor.run {
                    self.activityFeed.insert(event, at: 0)
                    if self.activityFeed.count > 40 {
                        self.activityFeed.removeLast(self.activityFeed.count - 40)
                    }
                }
            }
        }

        statusTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await MainActor.run {
                    self.syncStatus = self.syncRepository.connectionStatus
                    if self.syncStatus == .live {
                        self.lastSyncDate = Date()
                    }
                }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
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

    private func observeFallEvents() {
        fallObserver = NotificationCenter.default.addObserver(
            forName: .possibleFallDetected,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                guard self.isLoneWorkerMonitoringOn else { return }
                self.showFallAlert = true
            }
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

        Task { await refreshWeather(for: siteId) }
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
