import SwiftUI
import MapKit

/// iPad-specific root layout.
///
/// Follows the proposal's "iPad — site manager overview" spec:
/// - Sidebar: all sites with status filters and search
/// - Detail: selected site's map, live weather, task list, history, team feed
///
/// Only shown when the horizontal size class is `.regular` (i.e. iPad or iPhone
/// in Max landscape). iPhone portrait still falls through to the 4-tab `RootView`.
struct IPadRootView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedSiteId: UUID?
    @State private var searchText: String = ""
    @State private var statusFilter: StatusFilter = .all

    enum StatusFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case active = "Active"
        case attention = "Attention"
        case offline = "Offline"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationTitle("Sites")
        } content: {
            if let site = selectedSite {
                SiteDetailPane(site: site)
            } else {
                ContentUnavailableView("Select a site", systemImage: "mappin.and.ellipse")
            }
        } detail: {
            activityDetail
        }
        .onAppear {
            if selectedSiteId == nil {
                selectedSiteId = appState.sites.first?.id
            }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selectedSiteId) {
            Section {
                Picker("Status", selection: $statusFilter) {
                    ForEach(StatusFilter.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
            }
            Section {
                NavigationLink("Settings") { SettingsView() }
                NavigationLink("Inspection history") { HistoryView() }
            }
            Section("Job Sites") {
                ForEach(filteredSites) { site in
                    NavigationLink(value: site.id) {
                        siteRow(site)
                    }
                }
            }
        }
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search sites")
    }

    private var filteredSites: [Site] {
        appState.sites.filter { site in
            let matchesStatus: Bool
            switch statusFilter {
            case .all: matchesStatus = true
            case .active: matchesStatus = site.status == .operational
            case .attention: matchesStatus = site.status == .attention
            case .offline: matchesStatus = site.status == .offline
            }
            let matchesSearch = searchText.isEmpty
                || site.name.localizedCaseInsensitiveContains(searchText)
                || site.address.localizedCaseInsensitiveContains(searchText)
            return matchesStatus && matchesSearch
        }
    }

    private var selectedSite: Site? {
        selectedSiteId.flatMap { id in appState.sites.first(where: { $0.id == id }) }
    }

    private func siteRow(_ site: Site) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(colorForStatus(site.status))
                    .frame(width: 8, height: 8)
                Text(site.name)
                    .font(.body.weight(.semibold))
                Spacer()
                if site.isInsideGeofence {
                    Text("ON SITE")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppColors.accentSuccess)
                }
            }
            Text(site.address.isEmpty ? site.subtitle : site.address)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if !site.tasks.isEmpty {
                Text("\(site.tasks.count) task\(site.tasks.count == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(AppColors.primary)
            }
        }
        .padding(.vertical, 4)
    }

    private func colorForStatus(_ status: SiteStatus) -> Color {
        switch status {
        case .operational: return AppColors.accentSuccess
        case .attention: return AppColors.accentWarning
        case .offline: return AppColors.textTertiary
        }
    }

    // MARK: - Activity detail (far right pane)

    private var activityDetail: some View {
        List {
            Section {
                HStack {
                    Circle()
                        .fill(appState.syncStatus == .live ? AppColors.accentSuccess : AppColors.textTertiary)
                        .frame(width: 8, height: 8)
                    Text("Local Feed · \(appState.syncStatus.displayText)")
                        .font(.subheadline.weight(.semibold))
                }
            }
            Section("Live Activity") {
                if appState.activityFeed.isEmpty {
                    Text("Waiting for team events…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(appState.activityFeed.prefix(20)) { event in
                        activityRow(event)
                    }
                }
            }
            Section("Recent Inspections") {
                ForEach(appState.inspectionHistory.prefix(10)) { inspection in
                    historyRow(inspection)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Operations")
    }

    private func activityRow(_ event: ActivityEvent) -> some View {
        HStack(alignment: .top) {
            Image(systemName: iconFor(event.kind))
                .foregroundStyle(toneFor(event.kind))
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.actorName)
                    .font(.subheadline.weight(.semibold))
                Text(event.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(event.siteName) · \(event.occurredAt.formatted(.relative(presentation: .numeric)))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }

    private func historyRow(_ inspection: Inspection) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(inspection.siteName).font(.subheadline.weight(.semibold))
                Spacer()
                Text(inspection.statusTag).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            }
            Text("\(inspection.passedCount)/\(inspection.totalCount) passed · \(inspection.durationMinutes)m")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let hazard = inspection.hazardTag {
                Text("Hazard: \(hazard)")
                    .font(.caption2)
                    .foregroundStyle(AppColors.accentWarning)
            }
        }
    }

    private func iconFor(_ kind: ActivityEvent.Kind) -> String {
        switch kind {
        case .taskAssigned: return "person.badge.plus"
        case .inspectionLogged: return "checkmark.seal.fill"
        case .hazardFlagged: return "exclamationmark.triangle.fill"
        case .fallAlert: return "waveform.path.ecg"
        }
    }

    private func toneFor(_ kind: ActivityEvent.Kind) -> Color {
        switch kind {
        case .taskAssigned: return AppColors.primary
        case .inspectionLogged: return AppColors.accentSuccess
        case .hazardFlagged: return AppColors.accentWarning
        case .fallAlert: return .red
        }
    }
}

// MARK: - Site detail pane

private struct SiteDetailPane: View {
    @EnvironmentObject private var appState: AppState
    let site: Site

    @State private var cameraPosition: MapCameraPosition

    init(site: Site) {
        self.site = site
        _cameraPosition = State(initialValue: .region(MKCoordinateRegion(
            center: site.coordinate,
            latitudinalMeters: 1500,
            longitudinalMeters: 1500
        )))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                mapCard
                weatherCard
                tasksCard
                siteHistoryCard
            }
            .padding(20)
        }
        .onChange(of: site.id) { _, _ in
            cameraPosition = .region(MKCoordinateRegion(center: site.coordinate, latitudinalMeters: 1500, longitudinalMeters: 1500))
        }
        .navigationTitle(site.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var mapCard: some View {
        Map(position: $cameraPosition) {
            Annotation(site.name, coordinate: site.coordinate) {
                ZStack {
                    Circle().fill(AppColors.primary).frame(width: 32, height: 32)
                    Image(systemName: "mappin").foregroundStyle(.white).font(.system(size: 14, weight: .bold))
                }
            }
            MapCircle(center: site.coordinate, radius: site.geofenceRadius)
                .foregroundStyle(AppColors.primary.opacity(0.15))
                .stroke(AppColors.primary, lineWidth: 2)
        }
        .frame(height: 260)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var weatherCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 10) {
                LabelCaps(text: "Live Weather")
                if let weather = site.weather {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(weather.temperatureF)°F")
                                .font(.largeTitle.weight(.bold))
                            Text(weather.condition)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Divider().frame(height: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Wind")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(weather.windMph) mph \(weather.windDirection)")
                                .font(.body.weight(.semibold))
                        }
                        if let warning = weather.severeWarning {
                            Divider().frame(height: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Severe")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(warning)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(AppColors.accentWarning)
                            }
                        }
                    }
                } else {
                    Text("No weather snapshot yet. Refresh after geofence entry.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var tasksCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 10) {
                LabelCaps(text: "Scheduled Tasks")
                if site.tasks.isEmpty {
                    Text("No tasks scheduled for this site right now.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(site.tasks) { task in
                        NavigationLink { InspectView(task: task) } label: { HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.title).font(.body.weight(.semibold))
                                Text(task.subLocation).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            StatusBadge(text: task.priority.displayText, tone: task.priority.tone)
                        }
                        .padding(.vertical, 4) }
                        if task.id != site.tasks.last?.id { Divider() }
                    }
                }
            }
        }
    }

    private var siteHistoryCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 10) {
                LabelCaps(text: "Inspection History")
                let siteRecords = appState.inspectionHistory.filter { $0.siteId == site.id || ($0.siteId == nil && $0.siteName == site.name) }
                if siteRecords.isEmpty {
                    Text("No inspections logged for this site yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(siteRecords.prefix(8)) { inspection in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(inspection.passedCount)/\(inspection.totalCount) passed · \(inspection.durationMinutes)m")
                                    .font(.body.weight(.semibold))
                                Text(inspection.completedAt.formatted(.dateTime.month().day().hour().minute()))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            StatusBadge(text: inspection.statusTag, tone: inspection.statusTag == "Verified" ? .success : .warning)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }
}
