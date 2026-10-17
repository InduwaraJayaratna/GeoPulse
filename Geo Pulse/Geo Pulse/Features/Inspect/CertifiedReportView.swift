import SwiftUI

struct CertifiedReportView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                verifiedCard
                auditOverview
                measurementsCard
                evidenceCard
                verificationCard
                PrimaryButton(title: "Share PDF Report", icon: "square.and.arrow.up") {}
                PrimaryButton(title: "Return to Home", tone: .outlined) {
                    dismiss()
                }
                Spacer(minLength: 24)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Certified Report")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var verifiedCard: some View {
        CardContainer {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle().fill(AppColors.accentSuccessSoft).frame(width: 44, height: 44)
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(AppColors.accentSuccess)
                        .font(.title3)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Inspection Completed & Verified")
                        .font(AppTypography.titleSmall())
                    Text("Riverside Plant Sector 4 · \(formattedToday())")
                        .font(AppTypography.caption())
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
    }

    private func formattedToday() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: Date())
    }

    private var auditOverview: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    LabelCaps(text: "Audit Overview")
                    Spacer()
                    StatusBadge(text: "Conditional", tone: .warning)
                }
                HStack(spacing: 12) {
                    kpiTile(title: "Site", value: "Riverside Plant (Sector 4)")
                    kpiTile(title: "Inspector", value: "Alex Mercer, PE")
                }
                HStack(spacing: 12) {
                    kpiTile(title: "Duration", value: "42 minutes")
                    kpiTile(title: "Reference", value: "Ticket #4412")
                }
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(AppColors.accentWarning)
                    Text("Passed with conditional remediation scheduled for auxiliary flange seal.")
                        .font(AppTypography.caption())
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.accentWarningSoft)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private func kpiTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(AppTypography.caption())
                .foregroundStyle(AppColors.textSecondary)
            Text(value)
                .font(AppTypography.bodyBold())
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surfaceAlt)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var measurementsCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                LabelCaps(text: "Key Measurements")
                measurementRow(label: "Vibration", value: "42.4 Hz", status: "Nominal", tone: .success)
                measurementRow(label: "Pressure", value: "142 PSI", status: "Safe Range", tone: .success)
                measurementRow(label: "Gas Concentration", value: "0.02 ppm", status: "Safe Level", tone: .success)
            }
        }
    }

    private func measurementRow(label: String, value: String, status: String, tone: BadgeTone) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(AppTypography.caption())
                    .foregroundStyle(AppColors.textSecondary)
                Text(value)
                    .font(AppTypography.titleSmall())
            }
            Spacer()
            HStack(spacing: 6) {
                Circle().fill(tone.foreground).frame(width: 8, height: 8)
                Text(status)
                    .font(AppTypography.captionBold())
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .padding(12)
        .background(AppColors.surfaceAlt)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var evidenceCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 10) {
                LabelCaps(text: "Attached Evidence")
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10).fill(AppColors.surfaceAlt).frame(width: 44, height: 44)
                        Image(systemName: "photo").foregroundStyle(AppColors.textSecondary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Valve B-4 Primary Seal")
                            .font(AppTypography.bodyBold())
                        Text("Valve inspection completed")
                            .font(AppTypography.caption())
                            .foregroundStyle(AppColors.textSecondary)
                        Text("IMG_8829 · 2.4 MB")
                            .font(AppTypography.label())
                            .foregroundStyle(AppColors.textTertiary)
                    }
                    Spacer()
                }
                .padding(12)
                .background(AppColors.surfaceAlt)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(AppColors.surfaceAlt).frame(width: 36, height: 36)
                        Image(systemName: "mic").foregroundStyle(AppColors.textSecondary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Inspector Voice Summary")
                            .font(AppTypography.bodyBold())
                        Text("0:18 duration")
                            .font(AppTypography.caption())
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    Spacer()
                    ZStack {
                        Circle().fill(AppColors.surface).frame(width: 36, height: 36)
                            .overlay(Circle().stroke(AppColors.divider, lineWidth: 1))
                        Image(systemName: "play.fill").foregroundStyle(AppColors.textPrimary).font(.caption)
                    }
                }
                .padding(12)
                .background(AppColors.surfaceAlt)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var verificationCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 10) {
                LabelCaps(text: "Chain of Verification")
                verificationRow(name: "Alex Mercer, PE", role: "Lead Field Auditor", badgeText: "Signed", tone: .success, icon: "shield.lefthalf.filled")
                verificationRow(name: "Markus Vance", role: "Site Commander", badgeText: "Pending Co-Sign", tone: .warning, icon: "clock")
            }
        }
    }

    private func verificationRow(name: String, role: String, badgeText: String, tone: BadgeTone, icon: String) -> some View {
        HStack {
            ZStack {
                Circle().fill(AppColors.primarySoft).frame(width: 36, height: 36)
                Image(systemName: icon).foregroundStyle(AppColors.primary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(AppTypography.bodyBold())
                Text(role)
                    .font(AppTypography.caption())
                    .foregroundStyle(AppColors.textSecondary)
            }
            Spacer()
            StatusBadge(text: badgeText, tone: tone)
        }
        .padding(12)
        .background(AppColors.surfaceAlt)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        CertifiedReportView()
    }
}
