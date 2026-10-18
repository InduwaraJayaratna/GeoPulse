import Foundation
import CoreLocation
import Combine

@MainActor
final class LocationService: NSObject, ObservableObject {
    static let maxMonitoredRegions = 20

    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var currentLocation: CLLocation?
    @Published private(set) var monitoredSiteIds: Set<UUID> = []
    @Published private(set) var enteredSiteIds: Set<UUID> = []

    private let manager = CLLocationManager()

    override init() {
        self.authorizationStatus = CLLocationManager().authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 25
    }

    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func requestAlwaysAuthorization() {
        manager.requestAlwaysAuthorization()
    }

    func startUpdating() {
        guard authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse else { return }
        manager.startUpdatingLocation()
    }

    func stopUpdating() {
        manager.stopUpdatingLocation()
    }

    func enableBackgroundUpdates(_ enabled: Bool) {
        guard authorizationStatus == .authorizedAlways else { return }
        manager.allowsBackgroundLocationUpdates = enabled
        manager.pausesLocationUpdatesAutomatically = !enabled
    }

    func monitorSites(_ sites: [Site]) {
        guard authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse else { return }

        stopAllMonitoring()

        let origin = currentLocation
        let nearest = sites.sorted { lhs, rhs in
            guard let origin else { return false }
            let a = CLLocation(latitude: lhs.latitude, longitude: lhs.longitude).distance(from: origin)
            let b = CLLocation(latitude: rhs.latitude, longitude: rhs.longitude).distance(from: origin)
            return a < b
        }.prefix(Self.maxMonitoredRegions)

        for site in nearest {
            let region = CLCircularRegion(
                center: site.coordinate,
                radius: site.geofenceRadius,
                identifier: site.id.uuidString
            )
            region.notifyOnEntry = true
            region.notifyOnExit = true
            manager.startMonitoring(for: region)
            monitoredSiteIds.insert(site.id)
            manager.requestState(for: region)
        }
    }

    func stopAllMonitoring() {
        for region in manager.monitoredRegions {
            manager.stopMonitoring(for: region)
        }
        monitoredSiteIds.removeAll()
        enteredSiteIds.removeAll()
    }

    private func handleState(_ state: CLRegionState, for region: CLRegion) {
        guard let circular = region as? CLCircularRegion,
              let siteId = UUID(uuidString: circular.identifier) else { return }
        switch state {
        case .inside:
            if enteredSiteIds.insert(siteId).inserted {
                NotificationCenter.default.post(name: .geofenceDidEnter, object: nil, userInfo: ["siteId": siteId])
            }
        case .outside:
            if enteredSiteIds.remove(siteId) != nil {
                NotificationCenter.default.post(name: .geofenceDidExit, object: nil, userInfo: ["siteId": siteId])
            }
        case .unknown:
            break
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            if status == .authorizedWhenInUse {
                self.requestAlwaysAuthorization()
            }
            if status == .authorizedAlways || status == .authorizedWhenInUse {
                self.startUpdating()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        Task { @MainActor in
            self.currentLocation = latest
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let circular = region as? CLCircularRegion,
              let siteId = UUID(uuidString: circular.identifier) else { return }
        Task { @MainActor in
            if self.enteredSiteIds.insert(siteId).inserted {
                NotificationCenter.default.post(name: .geofenceDidEnter, object: nil, userInfo: ["siteId": siteId])
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard let circular = region as? CLCircularRegion,
              let siteId = UUID(uuidString: circular.identifier) else { return }
        Task { @MainActor in
            if self.enteredSiteIds.remove(siteId) != nil {
                NotificationCenter.default.post(name: .geofenceDidExit, object: nil, userInfo: ["siteId": siteId])
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        Task { @MainActor in
            self.handleState(state, for: region)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        // Monitoring can fail if the device goes offline or the region overlaps too many others.
        // We silently drop it — the app will re-register next time monitorSites is called.
    }
}

extension Notification.Name {
    static let geofenceDidEnter = Notification.Name("GeoPulse.geofenceDidEnter")
    static let geofenceDidExit = Notification.Name("GeoPulse.geofenceDidExit")
}
