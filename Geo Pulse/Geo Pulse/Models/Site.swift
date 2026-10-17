import Foundation
import CoreLocation

struct Site: Identifiable, Hashable {
    let id: UUID
    var name: String
    var subtitle: String
    var address: String
    var latitude: Double
    var longitude: Double
    var geofenceRadius: Double
    var status: SiteStatus
    var weather: WeatherSnapshot?
    var tasks: [FieldTask]
    var isInsideGeofence: Bool

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(
        id: UUID = UUID(),
        name: String,
        subtitle: String = "",
        address: String = "",
        latitude: Double,
        longitude: Double,
        geofenceRadius: Double = 200,
        status: SiteStatus = .operational,
        weather: WeatherSnapshot? = nil,
        tasks: [FieldTask] = [],
        isInsideGeofence: Bool = false
    ) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.geofenceRadius = geofenceRadius
        self.status = status
        self.weather = weather
        self.tasks = tasks
        self.isInsideGeofence = isInsideGeofence
    }
}

enum SiteStatus: String, Codable {
    case operational
    case attention
    case offline

    var displayText: String {
        switch self {
        case .operational: return "Operational"
        case .attention: return "Attention"
        case .offline: return "Offline"
        }
    }

    var tone: BadgeTone {
        switch self {
        case .operational: return .success
        case .attention: return .warning
        case .offline: return .neutral
        }
    }
}

struct WeatherSnapshot: Hashable, Codable {
    var temperatureF: Int
    var windMph: Int
    var windDirection: String
    var condition: String
    var severeWarning: String?
}
