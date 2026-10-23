import Foundation
import CoreLocation

/// Pure selection logic extracted from `LocationService` so it can be unit-tested
/// without a `CLLocationManager`. Given an origin and a list of sites, returns
/// the N nearest (capped at the iOS 20-region limit).
///
/// If no origin is supplied, falls back to insertion order and still enforces
/// the cap — matching production behaviour when the first fix hasn't arrived.
enum GeofenceSelector {

    static let maxMonitoredRegions = 20

    static func pickNearest(_ sites: [Site], to origin: CLLocation?, limit: Int = maxMonitoredRegions) -> [Site] {
        let cap = max(0, min(limit, maxMonitoredRegions))
        guard cap > 0 else { return [] }
        guard let origin else { return Array(sites.prefix(cap)) }
        return sites
            .sorted { lhs, rhs in
                let a = CLLocation(latitude: lhs.latitude, longitude: lhs.longitude).distance(from: origin)
                let b = CLLocation(latitude: rhs.latitude, longitude: rhs.longitude).distance(from: origin)
                return a < b
            }
            .prefix(cap)
            .map { $0 }
    }
}
