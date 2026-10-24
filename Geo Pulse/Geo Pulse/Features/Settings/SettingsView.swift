import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showHistory: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(title: "Settings")
            ScrollView {
                VStack(spacing: 16) {
                    profileCard
                    loneWorkerCard
                    notificationsCard
                    if let message = appState.notificationService.errorMessage {
                        Text(message).foregroundStyle(.red)
                    }
                    syncCard
                    historyEntry
                    Button("Sign out") { appState.signOut() }.frame(minHeight: 44)
                    footer
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .sheet(isPresented: $showHistory) {
            NavigationStack {
                HistoryView()
            }
        }
    }

    private var profileCard: some View {
        CardContainer {
            VStack(spacing: 14) {
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [AppColors.primary, AppColors.primaryDeep], startPoint: .top, endPoint: .bottom))
                            .frame(width: 56, height: 56)
                        Text(initials(for: appState.currentUser.displayName))
                            .font(AppTypography.titleSmall())
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(appState.currentUser.displayName)
                            .font(AppTypography.title())
                        Text("\(appState.currentUser.role) · ID \(appState.currentUser.inspectorId)")
                            .font(AppTypography.caption())
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    Spacer()
                    StatusBadge(text: appState.currentUser.isActive ? "Active" : "Offline", tone: appState.currentUser.isActive ? .success : .neutral)
                }
                HStack {
                    HStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8).fill(AppColors.surface).frame(width: 32, height: 32)
                            Image(systemName: "building.2.fill")
                                .foregroundStyle(AppColors.primary)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("CURRENT SITE")
                                .font(AppTypography.label())
                                .foregroundStyle(AppColors.textTertiary)
                            Text(appState.currentUser.currentSiteName)
                                .font(AppTypography.bodyBold())
                        }
                    }
                    Spacer()
                    Menu("Switch site") {
                        ForEach(appState.sites) { site in
                            Button(site.name) {
                                appState.selectedSiteId = site.id
                                appState.currentUser.currentSiteName = site.name
                            }
                        }
                    }.frame(minHeight: 44)

                }
                .padding(12)
                .background(AppColors.surfaceAlt)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ")
        return parts.prefix(2).compactMap { $0.first }.map { String($0) }.joined()
    }

    private var loneWorkerCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10).fill(AppColors.accentWarningSoft).frame(width: 42, height: 42)
                        Image(systemName: "person.text.rectangle")
                            .foregroundStyle(AppColors.accentWarning)
                    }
                    Text("Lone-worker monitoring")
                        .font(AppTypography.titleSmall())
                    Spacer()
                    Toggle("Lone-worker monitoring", isOn: $appState.isLoneWorkerMonitoringOn)
                        .labelsHidden()
                        .tint(AppColors.primary)
                }
                Text("Detects possible falls while the app is active. Incidents are recorded locally; emergency dispatch is not connected.")
                    .font(AppTypography.caption())
                    .foregroundStyle(AppColors.textSecondary)
                HStack {
                    HStack(spacing: 6) {
                        Circle().fill(AppColors.accentSuccess).frame(width: 8, height: 8)
                        Text(appState.isLoneWorkerMonitoringOn ? "Monitoring enabled" : "Monitoring off")
                            .font(AppTypography.captionBold())
                    }
                    Spacer()
                    Text("Device motion")
                        .font(AppTypography.captionBold())
                        .foregroundStyle(AppColors.textSecondary)
                }
                .padding(12)
                .background(AppColors.surfaceAlt)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Button {
                    appState.simulateFall()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "waveform.path.ecg")
                        Text("Simulate fall event")
                            .font(AppTypography.captionBold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(AppColors.accentWarning)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AppColors.accentWarning, lineWidth: 1)
                    )
                }
            }
        }
    }

    private var notificationsCard: some View {
        CardContainer {
            VStack(spacing: 14) {
                HStack {
                    LabelCaps(text: "Field Notifications")
                    Spacer()
                    Text("Audible + Haptic")
                        .font(AppTypography.captionBold())
                        .foregroundStyle(AppColors.primary)
                }
                settingsToggleRow(
                    title: "Geofence alerts",
                    subtitle: "Notify upon entering or leaving a site",
                    isOn: $appState.geofenceAlertsOn
                )
                Divider()
                settingsToggleRow(
                    title: "Severe weather alerts",
                    subtitle: "High wind, storm, or extreme heat warnings",
                    isOn: $appState.severeWeatherAlertsOn
                )
            }
        }
    }

    private func settingsToggleRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTypography.bodyBold())
                Text(subtitle)
                    .font(AppTypography.caption())
                    .foregroundStyle(AppColors.textSecondary)
            }
            Spacer()
            Toggle(title, isOn: isOn)
                .labelsHidden()
                .tint(AppColors.primary)
        }
    }

    private var syncCard: some View {
        CardContainer {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(AppColors.surfaceAlt).frame(width: 42, height: 42)
                    Image(systemName: "icloud")
                        .foregroundStyle(AppColors.textSecondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Field Data Sync")
                        .font(AppTypography.bodyBold())
                    Text(appState.syncMessage)
                        .font(AppTypography.caption())
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer()
                Button {
                    appState.syncNow()
                } label: {
                    Text("Check sync status")
                        .font(AppTypography.captionBold())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .foregroundStyle(AppColors.primary)
                        .background(AppColors.primarySoft)
                        .clipShape(Capsule())
                }
            }
        }
    }

    private var historyEntry: some View {
        CardContainer {
            Button {
                showHistory = true
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10).fill(AppColors.primarySoft).frame(width: 42, height: 42)
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundStyle(AppColors.primary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Inspection History")
                            .font(AppTypography.bodyBold())
                            .foregroundStyle(AppColors.textPrimary)
                        Text("Past inspections and logged hazards")
                            .font(AppTypography.caption())
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(AppColors.textTertiary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func relativeTime(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private var footer: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Circle().fill(AppColors.accentSuccess).frame(width: 8, height: 8)
                Text("Records stored on this device")
                    .font(AppTypography.caption())
                    .foregroundStyle(AppColors.textSecondary)
            }
            Text("GeoPulse 2.4")
                .font(AppTypography.caption())
                .foregroundStyle(AppColors.textTertiary)
        }
        .padding(.top, 8)
    }
}

#Preview {
    SettingsView().environmentObject(AppState())
}
