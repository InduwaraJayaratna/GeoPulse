import SwiftUI

struct HistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                summaryCard
                ForEach(appState.inspectionHistory) { inspection in
                    inspectionCard(inspection)
                }
                Spacer(minLength: 24)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(AppColors.textPrimary)
                }
            }
        }
    }

    private var summaryCard: some View {
        CardContainer {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(AppColors.primarySoft).frame(width: 48, height: 48)
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundStyle(AppColors.primary)
                        .font(.title3)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Inspection History")
                        .font(AppTypography.titleSmall())
                    Text("\(appState.inspectionHistory.count) records · synced from Firestore")
                        .font(AppTypography.caption())
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer()
            }
        }
    }

    private func inspectionCard(_ inspection: Inspection) -> some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(inspection.siteName)
                        .font(AppTypography.bodyBold())
                    Spacer()
                    StatusBadge(text: inspection.statusTag, tone: inspection.statusTag == "Verified" ? .success : .warning)
                }
                Text("\(inspection.passedCount) of \(inspection.totalCount) passed · \(inspection.durationMinutes) min")
                    .font(AppTypography.caption())
                    .foregroundStyle(AppColors.textSecondary)
                if let hazard = inspection.hazardTag, let confidence = inspection.hazardConfidence {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(AppColors.accentWarning)
                            .font(.caption)
                        Text("\(hazard) · \(Int(confidence * 100))%")
                            .font(AppTypography.caption())
                            .foregroundStyle(AppColors.accentWarning)
                    }
                }
                if let note = inspection.voiceNote {
                    Text("\"\(note)\"")
                        .font(AppTypography.caption())
                        .foregroundStyle(AppColors.textPrimary)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.surfaceAlt)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                HStack {
                    Text(relativeTime(inspection.completedAt))
                        .font(AppTypography.caption())
                        .foregroundStyle(AppColors.textTertiary)
                    Spacer()
                    StatusBadge(text: inspection.syncState.displayText, tone: inspection.syncState.tone)
                }
            }
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    NavigationStack {
        HistoryView().environmentObject(AppState())
    }
}
