import SwiftUI
import Charts

struct AnalyticsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                summaryCard
                completionCard
                hazardCard
                responseTimeCard
                Spacer(minLength: 24)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .accessibilityLabel("Back")
                        .foregroundStyle(AppColors.textPrimary)
                }
            }
        }
    }

    // MARK: - KPI summary

    private var summaryCard: some View {
        let completion = overallCompletion
        let percent = completion.total == 0 ? "—" : "\(Int((Double(completion.completed) / Double(completion.total)) * 100))%"
        let avg = avgResponseMinutes
        return CardContainer {
            HStack(spacing: 12) {
                statTile(label: "Completion", value: percent, icon: "checkmark.circle.fill", tint: AppColors.accentSuccess)
                statTile(label: "Hazards", value: "\(flaggedCount)", icon: "exclamationmark.triangle.fill", tint: AppColors.accentWarning)
                statTile(label: "Avg time", value: avg == 0 ? "—" : "\(avg) min", icon: "timer", tint: AppColors.primary)
            }
        }
    }

    private func statTile(label: String, value: String, icon: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .font(.title3)
            Text(value)
                .font(AppTypography.titleSmall())
                .foregroundStyle(AppColors.textPrimary)
            Text(label)
                .font(AppTypography.caption())
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Completion rate chart

    private var completionCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                Text("Completion rate by site")
                    .font(AppTypography.bodyBold())
                let data = completionData
                if data.isEmpty {
                    emptyState("No tasks assigned on any site yet.")
                } else {
                    Chart(data) { entry in
                        BarMark(
                            x: .value("Rate", entry.rate),
                            y: .value("Site", entry.siteName)
                        )
                        .foregroundStyle(AppColors.primary)
                        .annotation(position: .trailing) {
                            Text("\(Int((entry.rate * 100).rounded()))%")
                                .font(.caption2)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                    .chartXScale(domain: 0...1)
                    .chartXAxis {
                        AxisMarks(values: [0, 0.25, 0.5, 0.75, 1.0]) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let d = value.as(Double.self) {
                                    Text("\(Int(d * 100))%")
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                    .frame(height: CGFloat(max(140, data.count * 44)))
                }
            }
        }
    }

    // MARK: - Hazard frequency chart

    private var hazardCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                Text("Hazard frequency")
                    .font(AppTypography.bodyBold())
                let data = hazardData
                if data.isEmpty {
                    emptyState("No hazards logged in recent inspections.")
                } else {
                    Chart(data) { entry in
                        BarMark(
                            x: .value("Hazard", entry.label),
                            y: .value("Count", entry.count)
                        )
                        .foregroundStyle(AppColors.accentWarning)
                        .annotation(position: .top) {
                            Text("\(entry.count)")
                                .font(.caption2)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                    .frame(height: 220)
                    .chartXAxis {
                        AxisMarks { value in
                            AxisValueLabel {
                                if let str = value.as(String.self) {
                                    Text(str)
                                        .font(.caption2)
                                        .lineLimit(2)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Response time chart

    private var responseTimeCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                Text("Average response time (last 7 days)")
                    .font(AppTypography.bodyBold())
                let data = responseTimeData
                let hasAny = data.contains(where: { $0.minutes > 0 })
                if !hasAny {
                    emptyState("No completed inspections in the last 7 days.")
                } else {
                    Chart(data) { point in
                        LineMark(
                            x: .value("Day", point.date, unit: .day),
                            y: .value("Minutes", point.minutes)
                        )
                        .foregroundStyle(AppColors.primary)
                        .interpolationMethod(.catmullRom)
                        PointMark(
                            x: .value("Day", point.date, unit: .day),
                            y: .value("Minutes", point.minutes)
                        )
                        .foregroundStyle(AppColors.primary)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                        }
                    }
                    .chartYAxis {
                        AxisMarks { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let m = value.as(Double.self) {
                                    Text("\(Int(m))m")
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                    .frame(height: 200)
                }
            }
        }
    }

    private func emptyState(_ text: String) -> some View {
        Text(text)
            .font(AppTypography.caption())
            .foregroundStyle(AppColors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 24)
    }

    // MARK: - Derived data

    private struct CompletionEntry: Identifiable {
        let id = UUID()
        let siteName: String
        let rate: Double
    }

    private struct HazardEntry: Identifiable {
        let id = UUID()
        let label: String
        let count: Int
    }

    private struct ResponsePoint: Identifiable {
        let id = UUID()
        let date: Date
        let minutes: Double
    }

    private var overallCompletion: (completed: Int, total: Int) {
        let all = appState.sites.flatMap(\.tasks)
        return (all.filter { $0.status == .completed }.count, all.count)
    }

    private var flaggedCount: Int {
        appState.inspectionHistory.filter { $0.hazardTag != nil }.count
    }

    private var avgResponseMinutes: Int {
        let durations = appState.inspectionHistory.map(\.durationMinutes).filter { $0 > 0 }
        guard !durations.isEmpty else { return 0 }
        return Int((Double(durations.reduce(0, +)) / Double(durations.count)).rounded())
    }

    private var completionData: [CompletionEntry] {
        appState.sites.compactMap { site in
            guard !site.tasks.isEmpty else { return nil }
            let done = site.tasks.filter { $0.status == .completed }.count
            return CompletionEntry(
                siteName: shortName(site.name),
                rate: Double(done) / Double(site.tasks.count)
            )
        }
    }

    private var hazardData: [HazardEntry] {
        let tags = appState.inspectionHistory.compactMap(\.hazardTag)
        let counts = Dictionary(grouping: tags, by: { $0 }).mapValues(\.count)
        return counts
            .map { HazardEntry(label: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    private var responseTimeData: [ResponsePoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let days: [Date] = (0..<7)
            .compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
            .reversed()
        return days.map { day in
            let next = calendar.date(byAdding: .day, value: 1, to: day) ?? day
            let items = appState.inspectionHistory.filter {
                $0.completedAt >= day && $0.completedAt < next && $0.durationMinutes > 0
            }
            let avg = items.isEmpty
                ? 0
                : Double(items.map(\.durationMinutes).reduce(0, +)) / Double(items.count)
            return ResponsePoint(date: day, minutes: avg)
        }
    }

    private func shortName(_ full: String) -> String {
        if let paren = full.firstIndex(of: "(") {
            return String(full[..<paren]).trimmingCharacters(in: .whitespaces)
        }
        return full
    }
}

#Preview {
    NavigationStack {
        AnalyticsView().environmentObject(AppState())
    }
}
