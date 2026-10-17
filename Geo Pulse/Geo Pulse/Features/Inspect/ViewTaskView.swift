import SwiftUI

struct ViewTaskView: View {
    @Environment(\.dismiss) private var dismiss
    let task: FieldTask
    @State private var severity: HazardSeverity = .high

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                associatedTaskCard
                photoCard
                severityCard
                protocolCard
                notesCard
                inventoryCard
                PrimaryButton(title: "Submit Remediation Ticket", icon: "checkmark.seal") {
                    dismiss()
                }
                Spacer(minLength: 24)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Remediation Ticket")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var associatedTaskCard: some View {
        CardContainer(padding: 14) {
            HStack {
                Image(systemName: "link")
                    .foregroundStyle(AppColors.textSecondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("ASSOCIATED TASK")
                        .font(AppTypography.label())
                        .foregroundStyle(AppColors.textTertiary)
                    Text("Valve B-4 Leak Test")
                        .font(AppTypography.bodyBold())
                }
                Spacer()
                HStack(spacing: 6) {
                    Circle().fill(AppColors.accentSuccess).frame(width: 6, height: 6)
                    Text("Station 04")
                        .font(AppTypography.captionBold())
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AppColors.accentSuccessSoft)
                .clipShape(Capsule())
                .foregroundStyle(AppColors.accentSuccess)
            }
        }
    }

    private var photoCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    LabelCaps(text: "Inspection Photo")
                    Spacer()
                    Text("Captured 14:22")
                        .font(AppTypography.caption())
                        .foregroundStyle(AppColors.textTertiary)
                }
                ZStack {
                    LinearGradient(colors: [AppColors.surfaceAlt, Color(red: 0.65, green: 0.60, blue: 0.55)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    Image(systemName: "wrench.adjustable")
                        .font(.system(size: 44))
                        .foregroundStyle(.white.opacity(0.8))
                }
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                    Text("Surface corrosion on lower flange bolts")
                        .font(AppTypography.caption())
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
    }

    private var severityCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    LabelCaps(text: "Severity Level")
                    Spacer()
                    Text("Action required within 48h")
                        .font(AppTypography.captionBold())
                        .foregroundStyle(AppColors.accentWarning)
                }
                HStack(spacing: 8) {
                    ForEach(HazardSeverity.allCases, id: \.self) { level in
                        Button { severity = level } label: {
                            Text(level.displayText)
                                .font(AppTypography.captionBold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .foregroundStyle(severity == level ? level.tone.foreground : AppColors.textSecondary)
                                .background(severity == level ? level.tone.background : AppColors.surfaceAlt)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
            }
        }
    }

    private var protocolCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 10) {
                LabelCaps(text: "Assigned Protocol")
                HStack {
                    ZStack {
                        Circle().fill(AppColors.primarySoft).frame(width: 36, height: 36)
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .foregroundStyle(AppColors.primary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ultrasonic thickness test & flange resealing")
                            .font(AppTypography.bodyBold())
                        Text("SOP-MECH-442 Rev B")
                            .font(AppTypography.caption())
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.left.and.right")
                        .foregroundStyle(AppColors.textTertiary)
                }
                .padding(12)
                .background(AppColors.surfaceAlt)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var notesCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    LabelCaps(text: "Inspector Notes")
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "mic.fill")
                        Text("Voice note")
                    }
                    .font(AppTypography.captionBold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .foregroundStyle(AppColors.textPrimary)
                    .background(AppColors.surfaceAlt)
                    .clipShape(Capsule())
                }
                Text("Localized oxidation found on flange bolts. Recommend ultrasonic test before repressurizing.")
                    .font(AppTypography.body())
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.surfaceAlt)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var inventoryCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    LabelCaps(text: "Required Inventory")
                    Spacer()
                    Text("2 items assigned")
                        .font(AppTypography.caption())
                        .foregroundStyle(AppColors.textTertiary)
                }
                inventoryRow(name: "Flange Gasket 4-inch", detail: "Class 300 Spiral Wound · Van #2")
                inventoryRow(name: "Grade B7 Stud Bolts (x8)", detail: "5/8\" x 3-1/2 Zinc Plated · Van #2")
            }
        }
    }

    private func inventoryRow(name: String, detail: String) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 6)
                .fill(AppColors.primary)
                .frame(width: 20, height: 20)
                .overlay(Image(systemName: "checkmark").foregroundStyle(.white).font(.caption2))
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(AppTypography.bodyBold())
                Text(detail)
                    .font(AppTypography.caption())
                    .foregroundStyle(AppColors.textSecondary)
            }
            Spacer()
            StatusBadge(text: "In Stock", tone: .success)
        }
        .padding(12)
        .background(AppColors.surfaceAlt)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        ViewTaskView(task: SampleData.tasks[0])
    }
}
