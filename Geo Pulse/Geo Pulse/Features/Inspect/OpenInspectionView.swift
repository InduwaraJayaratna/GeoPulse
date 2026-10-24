import SwiftUI

struct OpenInspectionView: View {
    @Environment(\.dismiss) private var dismiss
    let site: Site
    @State private var filter: TaskFilter = .all

    enum TaskFilter: String, CaseIterable {
        case all = "All"
        case needsAttention = "Needs Attention"
        case completed = "Completed"
    }

    private var filteredTasks: [FieldTask] {
        switch filter {
        case .all: return site.tasks
        case .needsAttention: return site.tasks.filter { $0.priority != .normal }
        case .completed: return site.tasks.filter { $0.status == .completed }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                siteHeaderCard
                filterBar
                ForEach(filteredTasks) { task in
                    taskCard(task)
                    NavigationLink("Log remediation for \(task.title)") { ViewTaskView(task: task) }
                        .frame(minHeight: 44)
                }
                Text("Inspections are saved on this device")
                    .font(AppTypography.caption())
                    .foregroundStyle(AppColors.textTertiary)
                Spacer(minLength: 24)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Open Inspection")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left").accessibilityLabel("Back")
                        .foregroundStyle(AppColors.textPrimary)
                }
            }
        }
    }

    private var siteHeaderCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    HStack(spacing: 6) {
                        Circle().fill(AppColors.accentSuccess).frame(width: 8, height: 8)
                        Text(site.isInsideGeofence ? "Inside geofence" : "Outside geofence")
                            .font(AppTypography.captionBold())
                            .foregroundStyle(AppColors.accentSuccess)
                    }
                    Spacer()
                    if let weather = site.weather {
                        HStack(spacing: 6) {
                            Image(systemName: "wind")
                                .font(.caption)
                                .foregroundStyle(AppColors.textSecondary)
                            Text("\(weather.temperatureF)°F · \(weather.windMph) mph \(weather.windDirection)")
                                .font(AppTypography.caption())
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                }
                Text(site.name)
                    .font(AppTypography.title())
                Text("\(site.tasks.count) tasks scheduled today (\(site.tasks.filter { $0.priority != .normal }.count) requires attention)")
                    .font(AppTypography.caption())
                    .foregroundStyle(AppColors.accentWarning)
                ZStack(alignment: .bottomLeading) {
                    LinearGradient(colors: [AppColors.primary.opacity(0.5), AppColors.primaryDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
                        .frame(height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    HStack {
                        Image(systemName: "scope")
                            .foregroundStyle(.white)
                        Text("Sector 4 Compressor Yard")
                            .font(AppTypography.captionBold())
                            .foregroundStyle(.white)
                    }
                    .padding(12)
                }
            }
        }
    }

    private var filterBar: some View {
        HStack(spacing: 10) {
            ForEach(TaskFilter.allCases, id: \.self) { option in
                let count: Int = {
                    switch option {
                    case .all: return site.tasks.count
                    case .needsAttention: return site.tasks.filter { $0.priority != .normal }.count
                    case .completed: return site.tasks.filter { $0.status == .completed }.count
                    }
                }()
                let isSelected = filter == option
                Button { filter = option } label: {
                    Text("\(option.rawValue) (\(count))")
                        .font(AppTypography.captionBold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .foregroundStyle(isSelected ? AppColors.textPrimary : AppColors.textSecondary)
                        .background(isSelected ? AppColors.surface : Color.clear)
                        .clipShape(Capsule())
                }
            }
            Spacer()
        }
        .padding(4)
        .background(AppColors.surfaceAlt)
        .clipShape(Capsule())
    }

    private func taskCard(_ task: FieldTask) -> some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    if task.priority == .attention {
                        StatusBadge(text: "Attention needed", tone: .warning, showsDot: true)
                    } else {
                        Text(task.dueDescription)
                            .font(AppTypography.caption())
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    Spacer()
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(task.priority == .attention ? AppColors.accentWarningSoft : AppColors.surfaceAlt)
                            .frame(width: 36, height: 36)
                        Image(systemName: taskIcon(task))
                            .foregroundStyle(task.priority == .attention ? AppColors.accentWarning : AppColors.textSecondary)
                    }
                }
                Text(task.title)
                    .font(AppTypography.titleSmall())
                    .foregroundStyle(AppColors.textPrimary)
                Text(task.subLocation)
                    .font(AppTypography.caption())
                    .foregroundStyle(AppColors.textSecondary)
                HStack {
                    if task.priority == .attention {
                        NavigationLink(destination: InspectView(task: task)) {
                            HStack(spacing: 6) {
                                Image(systemName: "play.fill")
                                Text("Start Inspection")
                            }
                            .font(AppTypography.captionBold())
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .foregroundStyle(.white)
                            .background(AppColors.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        Spacer()
                        ZStack {
                            RoundedRectangle(cornerRadius: 10).fill(AppColors.surfaceAlt).frame(width: 36, height: 36)
                            Image(systemName: "info.circle")
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    } else {
                        Text(task.status.displayText)
                            .font(AppTypography.caption())
                            .foregroundStyle(AppColors.textTertiary)
                        Spacer()
                        NavigationLink(destination: InspectView(task: task)) {
                            HStack(spacing: 4) {
                                Text("Open")
                                Image(systemName: "chevron.right")
                            }
                            .font(AppTypography.captionBold())
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .foregroundStyle(AppColors.textPrimary)
                            .background(AppColors.surfaceAlt)
                            .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }

    private func taskIcon(_ task: FieldTask) -> String {
        if task.title.contains("Fuel") { return "fuelpump" }
        if task.title.contains("Structural") { return "building.2" }
        if task.title.contains("Pressure") { return "exclamationmark.triangle.fill" }
        return "wrench.and.screwdriver"
    }
}

#Preview {
    NavigationStack {
        OpenInspectionView(site: SampleData.sites[0])
    }
}
