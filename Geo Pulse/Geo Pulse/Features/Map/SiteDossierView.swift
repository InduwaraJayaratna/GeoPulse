import SwiftUI

struct SiteDossierView: View {
    let site: Site
    private var summary: String {
        "\(site.name)\n\(site.address)\nStatus: \(site.status.displayText)\nGeofence radius: \(Int(site.geofenceRadius)) m\nAssigned tasks: \(site.tasks.count)"
    }
    var body: some View {
        List {
            Section("Site") {
                Text(site.name).font(.headline)
                Text(site.subtitle)
                Text(site.address)
                Text("Status: \(site.status.displayText)")
            }
            Section("Geofence") {
                Text("Radius: \(Int(site.geofenceRadius)) m")
                Text(site.isInsideGeofence ? "Inside geofence" : "Outside geofence")
                Text("Coordinates: \(site.latitude), \(site.longitude)")
            }
            Section("Assigned tasks") {
                ForEach(site.tasks) { task in
                    NavigationLink(task.title) { InspectView(task: task) }
                }
            }
            Section {
                ShareLink("Share site summary", item: summary)
                Text("Facility documents and emergency contacts have not been configured.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.navigationTitle("Site Dossier")
    }
}
