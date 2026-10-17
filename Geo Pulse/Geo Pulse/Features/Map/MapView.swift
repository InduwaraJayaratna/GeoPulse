import SwiftUI
import MapKit

struct MapView: View {
    @EnvironmentObject private var appState: AppState
    @Binding var selectedTab: AppTab

    @State private var cameraPosition: MapCameraPosition
    @State private var selectedSite: Site?
    @State private var showDossier: Bool = false
    @State private var showOpenInspection: Bool = false

    init(selectedTab: Binding<AppTab>) {
        self._selectedTab = selectedTab
        let riverside = SampleData.sites.first { $0.isInsideGeofence } ?? SampleData.sites[0]
        self._cameraPosition = State(initialValue: .region(MKCoordinateRegion(
            center: riverside.coordinate,
            latitudinalMeters: 2500,
            longitudinalMeters: 2500
        )))
        self._selectedSite = State(initialValue: riverside)
    }

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(title: "Map")
            ScrollView {
                VStack(spacing: 16) {
                    mapView
                    if let site = selectedSite {
                        siteStatusCard(site: site)
                    }
                    radiusRow
                    HStack(spacing: 12) {
                        PrimaryButton(title: "Open Site Inspection", icon: "checkmark.seal") {
                            showOpenInspection = true
                        }
                        PrimaryButton(title: "Dossier", icon: "book", tone: .outlined) {
                            showDossier = true
                        }
                    }
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .sheet(isPresented: $showDossier) {
            if let site = selectedSite {
                NavigationStack {
                    SiteDossierView(site: site)
                }
            }
        }
        .sheet(isPresented: $showOpenInspection) {
            if let site = selectedSite {
                NavigationStack {
                    OpenInspectionView(site: site)
                }
            }
        }
    }

    private var mapView: some View {
        ZStack(alignment: .topLeading) {
            Map(position: $cameraPosition) {
                ForEach(appState.sites) { site in
                    Annotation(site.name, coordinate: site.coordinate) {
                        Button {
                            selectedSite = site
                        } label: {
                            VStack(spacing: 4) {
                                ZStack {
                                    Circle()
                                        .fill(markerColor(for: site))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: markerIcon(for: site))
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                                Text(site.name.components(separatedBy: " ").first ?? "")
                                    .font(AppTypography.label())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.white)
                                    .clipShape(Capsule())
                                    .foregroundStyle(AppColors.textPrimary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    if site.isInsideGeofence {
                        MapCircle(center: site.coordinate, radius: site.geofenceRadius)
                            .foregroundStyle(AppColors.primary.opacity(0.15))
                            .stroke(AppColors.primary, lineWidth: 2)
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat))
            .frame(height: 340)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            HStack {
                HStack(spacing: 6) {
                    Circle().fill(AppColors.accentSuccess).frame(width: 8, height: 8)
                    Text("Live Field Sync")
                        .font(AppTypography.captionBold())
                        .foregroundStyle(AppColors.textPrimary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.white)
                .clipShape(Capsule())
                Spacer()
                VStack(spacing: 10) {
                    circleButton(icon: "location.fill")
                    circleButton(icon: "square.3.layers.3d")
                }
            }
            .padding(14)
        }
    }

    private func markerColor(for site: Site) -> Color {
        switch site.status {
        case .operational: return AppColors.primary
        case .attention: return AppColors.accentWarning
        case .offline: return AppColors.textTertiary
        }
    }

    private func markerIcon(for site: Site) -> String {
        switch site.status {
        case .attention: return "exclamationmark"
        default: return "mappin"
        }
    }

    private func circleButton(icon: String) -> some View {
        ZStack {
            Circle().fill(.white).frame(width: 36, height: 36)
            Image(systemName: icon)
                .foregroundStyle(AppColors.primary)
        }
    }

    private func siteStatusCard(site: Site) -> some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(site.name)
                        .font(AppTypography.titleSmall())
                        .foregroundStyle(AppColors.textPrimary)
                    Spacer()
                    ZStack {
                        Circle().fill(AppColors.surfaceAlt).frame(width: 30, height: 30)
                        Image(systemName: "gearshape")
                            .foregroundStyle(AppColors.textSecondary)
                            .font(.caption)
                    }
                }
                HStack(spacing: 6) {
                    Circle()
                        .fill(site.isInsideGeofence ? AppColors.accentSuccess : AppColors.textTertiary)
                        .frame(width: 8, height: 8)
                    Text(site.isInsideGeofence ? "Inside geofence" : "Outside geofence")
                        .font(AppTypography.caption())
                        .foregroundStyle(AppColors.textSecondary)
                }
                if let weather = site.weather {
                    HStack(spacing: 8) {
                        Image(systemName: "wind")
                            .foregroundStyle(AppColors.textSecondary)
                        Text("\(weather.temperatureF)°F · Wind \(weather.windMph) mph \(weather.windDirection)")
                            .font(AppTypography.caption())
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                if !site.tasks.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(AppColors.accentWarning)
                        Text("\(site.tasks.count) tasks scheduled today (\(site.tasks.filter { $0.priority != .normal }.count) attention needed)")
                            .font(AppTypography.caption())
                            .foregroundStyle(AppColors.textPrimary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.surfaceAlt)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                PrimaryButton(title: "View \(site.tasks.count) Tasks", icon: "arrow.right") {
                    showOpenInspection = true
                }
            }
        }
    }

    private var radiusRow: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "slider.horizontal.3")
                Text("Map Radius: 2.5 miles")
            }
            .font(AppTypography.caption())
            .foregroundStyle(AppColors.textSecondary)
            Spacer()
            Text("\(appState.sites.count) Active Sites")
                .font(AppTypography.captionBold())
                .foregroundStyle(AppColors.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppColors.surfaceAlt)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    MapView(selectedTab: .constant(.map)).environmentObject(AppState())
}
