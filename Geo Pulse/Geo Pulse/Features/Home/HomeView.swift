import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @Binding var selectedTab: AppTab
    @State private var showNotifications: Bool = false

    private var currentSite: Site? { appState.activeSite }
    private var todayTasks: [FieldTask] { appState.todayTasks }
    private var attentionCount: Int { todayTasks.filter { $0.priority != .normal }.count }
    private var completedCount: Int { todayTasks.filter { $0.status == .completed }.count }

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(title: "Home", trailing: AnyView(
                Button { showNotifications.toggle() } label: {
                    ZStack {
                        Circle()
                            .fill(AppColors.surfaceAlt)
                            .frame(width: 36, height: 36)
                        Image(systemName: "bell").accessibilityLabel("Local activity")
                            .foregroundStyle(AppColors.textPrimary)
                    }
                }
            ))
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    greeting
                    facilityHeroCard
                    scheduleProgressCard
                    priorityActionItems
                    nearbyPerimeter
                    liveActivityFeed
                    unscheduledFindingCard
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .sheet(isPresented: $showNotifications) {
            NavigationStack {
                List(appState.activityFeed) { event in
                    VStack(alignment: .leading) { Text(event.siteName).font(.headline); Text(event.summary) }
                }.navigationTitle("Local Activity")
            }
        }
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Welcome, \(appState.currentUser.displayName.components(separatedBy: " ").first ?? "Alex")")
                .font(AppTypography.largeTitle())
                .foregroundStyle(AppColors.textPrimary)
            HStack(spacing: 6) {
                Circle()
                    .fill(AppColors.accentSuccess)
                    .frame(width: 8, height: 8)
                Text("Selected site: \(currentSite?.name ?? "All sites")")
                    .font(AppTypography.caption())
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(AppColors.surfaceAlt)
            .clipShape(Capsule())
        }
    }

    private var facilityHeroCard: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [AppColors.primaryDeep, AppColors.primary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 170)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            VStack(alignment: .leading, spacing: 8) {
                Text("FACILITY STATUS")
                    .font(AppTypography.label())
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.75))
                HStack {
                    Text("Riverside Main Plant · Online")
                        .font(AppTypography.titleSmall())
                        .foregroundStyle(.white)
                    Spacer()
                    Text("Normal flow")
                        .font(AppTypography.captionBold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.15))
                        .clipShape(Capsule())
                        .foregroundStyle(.white)
                }
            }
            .padding(18)
        }
    }

    private var scheduleProgressCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        LabelCaps(text: "Today's Schedule")
                        Text("\(todayTasks.count) tasks assigned today")
                            .font(AppTypography.title())
                            .foregroundStyle(AppColors.textPrimary)
                    }
                    Spacer()
                    if attentionCount > 0 {
                        StatusBadge(text: "\(attentionCount) needs attention", tone: .warning, showsDot: true)
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    GeometryReader { geo in
                        let completedWidth = geo.size.width * CGFloat(completedCount) / CGFloat(max(todayTasks.count, 1))
                        let attentionWidth = geo.size.width * CGFloat(attentionCount) / CGFloat(max(todayTasks.count, 1))
                        ZStack(alignment: .leading) {
                            Capsule().fill(AppColors.surfaceAlt).frame(height: 8)
                            HStack(spacing: 0) {
                                Capsule().fill(AppColors.primary).frame(width: max(16, completedWidth), height: 8)
                                Capsule().fill(AppColors.accentWarning).frame(width: max(32, attentionWidth), height: 8)
                            }
                        }
                    }
                    .frame(height: 8)
                    HStack {
                        Text("\(completedCount) completed")
                            .font(AppTypography.caption())
                            .foregroundStyle(AppColors.textSecondary)
                        Spacer()
                        Text("\(todayTasks.count - completedCount) pending · \(attentionCount) urgent")
                            .font(AppTypography.caption())
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
        }
    }

    private var priorityActionItems: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Priority Action Items", trailing: "Tap to inspect")
            if let urgent = todayTasks.first(where: { $0.priority == .attention || $0.priority == .urgent }) {
                urgentTaskCard(urgent)
            }
            ForEach(todayTasks.filter { $0.priority == .normal }) { task in
                Button {
                    appState.selectedTask = task
                    selectedTab = .inspect
                } label: { basicTaskRow(task) }.buttonStyle(.plain)
            }
        }
    }

    private func urgentTaskCard(_ task: FieldTask) -> some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    StatusBadge(text: task.priority.displayText, tone: task.priority.tone)
                    Spacer()
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(AppColors.accentWarningSoft)
                            .frame(width: 38, height: 38)
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(AppColors.accentWarning)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(AppTypography.titleSmall())
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(2)
                    Text("\(task.subLocation) · \(task.dueDescription)")
                        .font(AppTypography.caption())
                        .foregroundStyle(AppColors.textSecondary)
                }
                HStack(spacing: 10) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                        Text("Critical window")
                    }
                    .font(AppTypography.captionBold())
                    .foregroundStyle(AppColors.accentWarning)
                    Spacer()
                    Button {
                        appState.selectedTask = task
                        selectedTab = .inspect
                    } label: {
                        HStack(spacing: 6) {
                            Text("Start Inspection")
                            Image(systemName: "arrow.right")
                        }
                        .font(AppTypography.captionBold())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .foregroundStyle(.white)
                        .background(AppColors.primary)
                        .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private func basicTaskRow(_ task: FieldTask) -> some View {
        CardContainer(padding: 14) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppColors.surfaceAlt)
                        .frame(width: 38, height: 38)
                    Image(systemName: iconFor(task))
                        .foregroundStyle(AppColors.textSecondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(AppTypography.bodyBold())
                        .foregroundStyle(AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(task.siteName) · \(task.dueDescription)")
                        .font(AppTypography.caption())
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppColors.textTertiary)
            }
        }
    }

    private func iconFor(_ task: FieldTask) -> String {
        if task.title.contains("Fuel") { return "fuelpump" }
        if task.title.contains("Structural") { return "building.2" }
        return "wrench.and.screwdriver"
    }

    private var nearbyPerimeter: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Nearby Perimeter Sectors")
            CardContainer {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundStyle(AppColors.textSecondary)
                            Text("South Reservoir")
                                .font(AppTypography.bodyBold())
                        }
                        Spacer()
                        StatusBadge(text: "0.8 mi away", tone: .neutral)
                    }
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppColors.accentSuccess)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("All clear for today")
                                .font(AppTypography.bodyBold())
                            Text("No tasks scheduled for this sector today")
                                .font(AppTypography.caption())
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                    .padding(10)
                    .background(AppColors.accentSuccessSoft.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }

    private var liveActivityFeed: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionHeader(title: "Local Activity")
                Spacer()
                HStack(spacing: 4) {
                    Circle()
                        .fill(appState.syncStatus == .live ? AppColors.accentSuccess : AppColors.textTertiary)
                        .frame(width: 6, height: 6)
                    Text(appState.syncStatus.displayText)
                        .font(AppTypography.label())
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            CardContainer {
                if appState.activityFeed.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .foregroundStyle(AppColors.textTertiary)
                        Text("No local activity yet.")
                            .font(AppTypography.caption())
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .padding(.vertical, 6)
                } else {
                    VStack(spacing: 10) {
                        ForEach(appState.activityFeed.prefix(4)) { event in
                            activityRow(event)
                            if event.id != appState.activityFeed.prefix(4).last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }

    private func activityRow(_ event: ActivityEvent) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(activityTone(event.kind).opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: activityIcon(event.kind))
                    .foregroundStyle(activityTone(event.kind))
                    .font(.system(size: 13, weight: .semibold))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(event.actorName)
                    .font(AppTypography.captionBold())
                    .foregroundStyle(AppColors.textPrimary)
                Text(event.summary)
                    .font(AppTypography.caption())
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(2)
                Text("\(event.siteName) · \(relativeTime(event.occurredAt))")
                    .font(AppTypography.label())
                    .foregroundStyle(AppColors.textTertiary)
            }
            Spacer(minLength: 0)
        }
    }

    private func activityIcon(_ kind: ActivityEvent.Kind) -> String {
        switch kind {
        case .taskAssigned: return "person.badge.plus"
        case .inspectionLogged: return "checkmark.seal.fill"
        case .hazardFlagged: return "exclamationmark.triangle.fill"
        case .fallAlert: return "waveform.path.ecg"
        }
    }

    private func activityTone(_ kind: ActivityEvent.Kind) -> Color {
        switch kind {
        case .taskAssigned: return AppColors.primary
        case .inspectionLogged: return AppColors.accentSuccess
        case .hazardFlagged: return AppColors.accentWarning
        case .fallAlert: return .red
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private var unscheduledFindingCard: some View {
        CardContainer {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(AppColors.primary).frame(width: 36, height: 36)
                    Image(systemName: "plus.square.on.square")
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Unscheduled Finding?")
                        .font(AppTypography.bodyBold())
                    Text("Log an on-site hazard or spot tag")
                        .font(AppTypography.caption())
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer()
                Button {
                    selectedTab = .inspect
                } label: {
                    Text("Log")
                        .font(AppTypography.captionBold())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .foregroundStyle(AppColors.textPrimary)
                        .background(AppColors.surface)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(AppColors.divider, lineWidth: 1))
                }
            }
        }
    }
}

#Preview {
    HomeView(selectedTab: .constant(.home)).environmentObject(AppState())
}
