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

    lazy var locationService = LocationService()
    lazy var notificationService = providedNotifications ?? NotificationService()
    private let providedNotifications: NotificationService?
    lazy var motionService = MotionService()
    let syncRepository: any SyncRepository
    private let store: any InspectionStore
    private let now: () -> Date
    @Published var errorMessage: String?
    @Published var selectedTask: FieldTask?
    @Published var selectedSiteId: UUID?
    @Published var syncMessage = "Records are saved on this device. Remote sync is not configured."


    private var cancellables: Set<AnyCancellable> = []
    private var entryObserver: NSObjectProtocol?
    private var exitObserver: NSObjectProtocol?
    private var fallObserver: NSObjectProtocol?
    private var feedTask: Task<Void, Never>?
    private var statusTask: Task<Void, Never>?

    init(store: (any InspectionStore)? = nil,
         syncRepository: (any SyncRepository)? = nil,
         sites: [Site]? = nil,
         notificationService: NotificationService? = nil,
         now: @escaping () -> Date = Date.init,
         observeEvents: Bool = true) {
        let shouldSeedDemoHistory = (store == nil)
        self.providedNotifications = notificationService
        self.store = store ?? CoreDataStack.shared
        self.syncRepository = syncRepository ?? MockSyncRepository()
        self.now = now
        self.currentUser = SampleData.currentUser
        self.sites = sites ?? SampleData.sites
        self.isAuthenticated = false
        self.isLoneWorkerMonitoringOn = true
        self.geofenceAlertsOn = true
        self.severeWeatherAlertsOn = true
        self.lastSyncDate = Date().addingTimeInterval(-240)
        self.loneWorkerTimerMinutesRemaining = 38

        self.inspectionHistory = []
        do {
            var loaded = try self.store.fetchAllInspections()
            if loaded.isEmpty && shouldSeedDemoHistory {
                for sample in SampleData.historyInspections {
                    try? self.store.saveInspection(sample)
                }
                loaded = (try? self.store.fetchAllInspections()) ?? SampleData.historyInspections
            }
            self.inspectionHistory = loaded
        }
        catch { self.errorMessage = "Could not load inspections: \(error.localizedDescription)" }
        for inspection in inspectionHistory.reversed() { updateTask(for: inspection) }
        if observeEvents {
            observeGeofenceEvents()
            observeFallEvents()
            startSyncFeed()
        }
    }

    deinit {
        if let entryObserver { NotificationCenter.default.removeObserver(entryObserver) }
        if let exitObserver { NotificationCenter.default.removeObserver(exitObserver) }
        if let fallObserver { NotificationCenter.default.removeObserver(fallObserver) }
        feedTask?.cancel()
        statusTask?.cancel()
    }

    var activeSite: Site? {
        sites.first(where: { $0.isInsideGeofence }) ?? sites.first(where: { $0.id == selectedSiteId })
    }

    var todayTasks: [FieldTask] {
        activeSite?.tasks ?? sites.flatMap(\.tasks)
    }

    func signIn() {
        isAuthenticated = true
        Task { await bootstrapSensors() }
    }

    func signOut() {
        isAuthenticated = false
        showFallAlert = false
        locationService.stopAllMonitoring()
        locationService.stopUpdating()
        motionService.stopMonitoring()
    }

    func syncNow() {
        syncMessage = "Remote sync is not configured. Your records remain saved locally."
    }

    func simulateFall() {
        motionService.simulateFall()
    }

    func cancelFallAlert() {
        showFallAlert = false
        motionService.acknowledgeFall()
    }

    func escalateFallAlert() {
        guard showFallAlert else { return }
        showFallAlert = false
        motionService.acknowledgeFall()
        let incident = Inspection(taskId: UUID(), siteId: activeSite?.id,
            siteName: activeSite?.name ?? currentUser.currentSiteName,
            inspectorName: currentUser.displayName, completedAt: now(),
            resultSummary: "Possible fall recorded locally. Contact emergency services if needed.",
            statusTag: "Safety incident")
        do {
            try recordInspectionCompleted(incident)
            notificationService.scheduleFallDetectionAlert()
        } catch { errorMessage = "Could not save safety incident: \(error.localizedDescription)" }
    }

    func recordInspectionCompleted(_ inspection: Inspection) throws {
        try store.saveInspection(inspection)
        inspectionHistory.removeAll { $0.id == inspection.id }
        inspectionHistory.insert(inspection, at: 0)
        updateTask(for: inspection)
        Task { await syncRepository.publish(inspection: inspection) }
    }

    private func updateTask(for inspection: Inspection) {
        for siteIndex in sites.indices {
            if let taskIndex = sites[siteIndex].tasks.firstIndex(where: { $0.id == inspection.taskId }) {
                sites[siteIndex].tasks[taskIndex].status = inspection.statusTag == "Remediation" ? .flagged : .completed
            }
        }
    }

    func completeInspection(from draft: InspectionDraft, certifies: Bool) throws -> Inspection {
        guard certifies else { throw InspectionValidationError.certificationRequired }
        guard draft.isComplete else { throw InspectionValidationError.incompleteCheckpoints }
        // Reusing a draft cannot create a second record, even after a retry.
        if let existing = inspectionHistory.first(where: { $0.id == draft.id }) { return existing }
        let date = now()
        let flagged = draft.hazardTag != nil || draft.hasFlaggedCheckpoint
        let inspection = Inspection(
            id: draft.id, taskId: draft.task.id, siteId: draft.task.siteId,
            siteName: sites.first(where: { $0.id == draft.task.siteId })?.name ?? draft.task.siteName,
            inspectorName: currentUser.displayName, completedAt: date,
            durationMinutes: max(1, Int(date.timeIntervalSince(draft.startedAt) / 60)),
            resultSummary: flagged ? "Inspection completed with findings requiring review." : "Recorded checkpoints passed.",
            passedCount: draft.passedCount, totalCount: draft.checkpoints.count,
            statusTag: flagged ? "Conditional" : "Verified",
            hazardTag: draft.hazardTag, hazardConfidence: draft.hazardConfidence,
            voiceNote: draft.voiceNote, photoName: draft.photoName, syncState: .savedLocally)
        try recordInspectionCompleted(inspection)
        return inspection
    }

    func bootstrapSensors() async {
        await notificationService.requestAuthorization()
        guard isAuthenticated else { return }

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
                notificationService.scheduleGeofenceEntry(for: "\(site.name) · \(warning)", pendingTasks: site.tasks.filter { $0.status != .completed }.count)
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
        let feed = syncRepository.activityFeed()
        syncStatus = syncRepository.connectionStatus
        feedTask = Task { [weak self] in
            for await event in feed {
                guard let self else { return }
                self.activityFeed.insert(event, at: 0)
                if self.activityFeed.count > 40 { self.activityFeed.removeLast() }
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
            Task { @MainActor [weak self] in self?.handleEntry(siteId: siteId) }
        }

        exitObserver = NotificationCenter.default.addObserver(
            forName: .geofenceDidExit,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let siteId = note.userInfo?["siteId"] as? UUID else { return }
            Task { @MainActor [weak self] in self?.handleExit(siteId: siteId) }
        }
    }

    private func observeFallEvents() {
        fallObserver = NotificationCenter.default.addObserver(
            forName: .possibleFallDetected,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard self.isAuthenticated, self.isLoneWorkerMonitoringOn else { return }
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
            notificationService.scheduleGeofenceEntry(for: site.name, pendingTasks: site.tasks.filter { $0.status != .completed }.count)
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
