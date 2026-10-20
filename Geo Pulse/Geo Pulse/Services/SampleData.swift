import Foundation

enum SampleData {
    static let riversideId = UUID()
    static let apexId = UUID()
    static let harborId = UUID()
    static let southReservoirId = UUID()

    static let currentUser = UserProfile(
        displayName: "Alex Mercer",
        role: "Senior Field Inspector",
        inspectorId: "#4829",
        email: "alex.mercer@energy.org",
        currentSiteName: "Riverside Plant",
        isActive: true
    )

    static let riversideWeather = WeatherSnapshot(
        temperatureF: 84,
        windMph: 14,
        windDirection: "NW",
        condition: "Partly Cloudy",
        severeWarning: nil
    )

    static let tasks: [FieldTask] = [
        FieldTask(
            id: UUID(),
            title: "High Pressure Valve B-4 Leak Test",
            siteId: riversideId,
            siteName: "Compressor Station 3",
            subLocation: "Compressor Station 3",
            dueDescription: "Due in 45 min",
            protocolCode: "ASTM-F1166",
            ticketNumber: 4092,
            priority: .attention,
            status: .notStarted,
            scheduledAt: Date().addingTimeInterval(45 * 60)
        ),
        FieldTask(
            id: UUID(),
            title: "Structural Foundation Inspection",
            siteId: riversideId,
            siteName: "Cooling Tower East",
            subLocation: "Cooling Tower East · Routine check · 6 strain gauges",
            dueDescription: "Due at 2:00 PM",
            ticketNumber: 4093,
            status: .notStarted
        ),
        FieldTask(
            id: UUID(),
            title: "Emergency Generator Fuel Audit",
            siteId: riversideId,
            siteName: "Backup Substation",
            subLocation: "Backup Substation · Scheduled · Main Tank #1 & #2",
            dueDescription: "Due at 4:30 PM",
            ticketNumber: 4094,
            status: .notStarted
        )
    ]

    static let sites: [Site] = [
        Site(
            id: riversideId,
            name: "Riverside Plant (Sector 4)",
            subtitle: "Primary Refining Facility",
            address: "Baton Rouge, Louisiana",
            latitude: 30.4515,
            longitude: -91.1871,
            geofenceRadius: 500,
            status: .operational,
            weather: riversideWeather,
            tasks: tasks,
            isInsideGeofence: true
        ),
        Site(
            id: apexId,
            name: "Apex Industrial Complex",
            subtitle: "Secondary Processing",
            address: "Baton Rouge, Louisiana",
            latitude: 30.4580,
            longitude: -91.1945,
            geofenceRadius: 300,
            status: .operational,
            weather: WeatherSnapshot(temperatureF: 82, windMph: 10, windDirection: "N", condition: "Clear"),
            tasks: [],
            isInsideGeofence: false
        ),
        Site(
            id: harborId,
            name: "Harbor Loading Terminal",
            subtitle: "Dock Operations",
            address: "Baton Rouge, Louisiana",
            latitude: 30.4450,
            longitude: -91.1795,
            geofenceRadius: 400,
            status: .attention,
            weather: WeatherSnapshot(temperatureF: 85, windMph: 18, windDirection: "NW", condition: "Windy", severeWarning: "High wind advisory"),
            tasks: [],
            isInsideGeofence: false
        ),
        Site(
            id: southReservoirId,
            name: "South Reservoir",
            subtitle: "Water Containment",
            address: "0.8 mi away",
            latitude: 30.4380,
            longitude: -91.1900,
            geofenceRadius: 250,
            status: .operational,
            weather: nil,
            tasks: [],
            isInsideGeofence: false
        )
    ]

    static let checkpoints: [Checkpoint] = [
        Checkpoint(index: 1, title: "Cryogenic Feeder B-4", subtitle: "Recorded 18 min ago", status: .flagged("Surface Corrosion")),
        Checkpoint(index: 2, title: "Seismic Strain Gauge #12", subtitle: "Deflection nominal", status: .passed),
        Checkpoint(index: 3, title: "Compressor Seal 3", subtitle: "Current Reading 42.4 Hz (normal)", status: .current),
        Checkpoint(index: 4, title: "Emergency Depressurization", subtitle: nil, status: .pending),
        Checkpoint(index: 5, title: "Atmospheric Sensor", subtitle: nil, status: .pending),
        Checkpoint(index: 6, title: "Cathodic Protection", subtitle: nil, status: .pending),
        Checkpoint(index: 7, title: "Containment Berm", subtitle: nil, status: .pending)
    ]

    static let signOffCheckpoints: [Checkpoint] = [
        Checkpoint(index: 1, title: "Cryogenic Feeder Valve B-4", subtitle: "Torque readjusted to spec", status: .remediated),
        Checkpoint(index: 2, title: "Seismic Strain Gauge Baseline", status: .passed),
        Checkpoint(index: 3, title: "Primary Compressor Seal Integrity", status: .passed),
        Checkpoint(index: 4, title: "Emergency Vent Actuator Line", status: .passed),
        Checkpoint(index: 5, title: "Secondary Containment Drainage", status: .passed),
        Checkpoint(index: 6, title: "Auxiliary Power Transfer Switch", status: .passed),
        Checkpoint(index: 7, title: "Telemetry Transmitter Coupling", status: .passed)
    ]

    static let historyInspections: [Inspection] = [
        Inspection(
            taskId: tasks[0].id,
            siteName: "Riverside Plant Sector 4",
            inspectorName: "Alex Mercer, PE",
            completedAt: Date().addingTimeInterval(-3600 * 2),
            durationMinutes: 42,
            resultSummary: "Passed with conditional remediation scheduled for auxiliary flange seal.",
            passedCount: 6,
            totalCount: 7,
            statusTag: "Conditional",
            hazardTag: "Surface corrosion",
            hazardConfidence: 0.94,
            voiceNote: "Pressure reading is 142 PSI. Slight oxidation on flange bolts.",
            syncState: .syncedToTeam
        ),
        Inspection(
            taskId: UUID(),
            siteName: "Harbor Loading Terminal",
            inspectorName: "Alex Mercer, PE",
            completedAt: Date().addingTimeInterval(-3600 * 26),
            durationMinutes: 28,
            resultSummary: "All checkpoints nominal.",
            passedCount: 5,
            totalCount: 5,
            statusTag: "Verified",
            syncState: .syncedToTeam
        ),
        Inspection(
            taskId: UUID(),
            siteName: "Apex Industrial Complex",
            inspectorName: "Alex Mercer, PE",
            completedAt: Date().addingTimeInterval(-3600 * 50),
            durationMinutes: 35,
            resultSummary: "Routine inspection complete.",
            passedCount: 8,
            totalCount: 8,
            statusTag: "Verified",
            syncState: .savedLocally
        )
    ]

    static func safetyIncident(for siteName: String) -> Inspection {
        Inspection(
            taskId: UUID(),
            siteName: siteName,
            inspectorName: "Alex Mercer, PE",
            completedAt: Date(),
            durationMinutes: 0,
            resultSummary: "Possible fall detected — alert sent to dispatch.",
            passedCount: 0,
            totalCount: 0,
            statusTag: "Safety incident",
            syncState: .savedLocally
        )
    }
}
