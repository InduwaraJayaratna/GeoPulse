import Foundation
import CoreLocation
import Combine

@MainActor
final class LocationService: NSObject, ObservableObject {
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var currentLocation: CLLocation?
    @Published var monitoredRegions: Set<CLCircularRegion> = []

    private let manager = CLLocationManager()

    override init() {
        self.authorizationStatus = CLLocationManager().authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.allowsBackgroundLocationUpdates = false
    }

    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func requestAlwaysAuthorization() {
        manager.requestAlwaysAuthorization()
    }

    func startUpdating() {
        manager.startUpdatingLocation()
    }

    func stopUpdating() {
        manager.stopUpdatingLocation()
    }

    func monitor(site: Site) {
        let region = CLCircularRegion(
            center: site.coordinate,
            radius: site.geofenceRadius,
            identifier: site.id.uuidString
        )
        region.notifyOnEntry = true
        region.notifyOnExit = true
        manager.startMonitoring(for: region)
        monitoredRegions.insert(region)
    }

    func stopMonitoring(site: Site) {
        for region in monitoredRegions where region.identifier == site.id.uuidString {
            manager.stopMonitoring(for: region)
            monitoredRegions.remove(region)
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            self.authorizationStatus = status
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            self.currentLocation = locations.last
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let circular = region as? CLCircularRegion else { return }
        NotificationCenter.default.post(
            name: .geofenceDidEnter,
            object: nil,
            userInfo: ["regionId": circular.identifier]
        )
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard let circular = region as? CLCircularRegion else { return }
        NotificationCenter.default.post(
            name: .geofenceDidExit,
            object: nil,
            userInfo: ["regionId": circular.identifier]
        )
    }
}

extension Notification.Name {
    static let geofenceDidEnter = Notification.Name("GeoPulse.geofenceDidEnter")
    static let geofenceDidExit = Notification.Name("GeoPulse.geofenceDidExit")
}
