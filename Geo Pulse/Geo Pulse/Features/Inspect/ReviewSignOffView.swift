import SwiftUI

struct ReviewSignOffView: View {
    @Environment(\.dismiss) private var dismiss
    let task: FieldTask
    @State private var certifies: Bool = true
    @State private var showCertifiedReport: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                reviewCard
                checkpointsCard
                signOffCard
                PrimaryButton(title: "Sign and Submit Inspection", icon: "signature") {
                    showCertifiedReport = true
                }
                PrimaryButton(title: "Export Draft Report", icon: "square.and.arrow.down", tone: .outlined) {}
                Spacer(minLength: 24)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Review & Sign Off")
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
        .sheet(isPresented: $showCertifiedReport) {
            NavigationStack {
                CertifiedReportView()
            }
        }
    }

    private var reviewCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    LabelCaps(text: "Inspection Review")
                    Spacer()
                    StatusBadge(text: "Pending Sign-Off", tone: .warning, showsDot: true)
                }
                Text("Riverside Plant · Sector 4")
                    .font(AppTypography.title())
                HStack(spacing: 12) {
                    kpiTile(title: "Lead Inspector", value: "Alex Mercer, PE")
                    kpiTile(title: "Result Summary", value: "6 of 7 Passed")
                }
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(AppColors.accentWarning)
                    Text("1 item flagged during initial walkthrough has been remediated.")
                        .font(AppTypography.caption())
                        .foregroundStyle(AppColors.textPrimary)
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

    private var checkpointsCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    LabelCaps(text: "Checkpoint Verification")
                    Spacer()
                    Text("7 Items")
                        .font(AppTypography.caption())
                        .foregroundStyle(AppColors.textTertiary)
                }
                ForEach(SampleData.signOffCheckpoints) { checkpoint in
                    checkpointRow(checkpoint)
                }
            }
        }
    }

    private func checkpointRow(_ checkpoint: Checkpoint) -> some View {
        HStack(spacing: 10) {
            switch checkpoint.status {
            case .passed:
                ZStack {
                    Circle().fill(AppColors.accentSuccessSoft).frame(width: 24, height: 24)
                    Image(systemName: "checkmark").font(.caption).foregroundStyle(AppColors.accentSuccess)
                }
            case .remediated:
                ZStack {
                    Circle().fill(AppColors.accentWarningSoft).frame(width: 24, height: 24)
                    Image(systemName: "wrench.adjustable").font(.caption).foregroundStyle(AppColors.accentWarning)
                }
            default:
                Circle().fill(AppColors.surfaceAlt).frame(width: 24, height: 24)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(checkpoint.title)
                    .font(AppTypography.bodyBold())
                    .lineLimit(1)
                if let subtitle = checkpoint.subtitle {
                    Text(subtitle)
                        .font(AppTypography.caption())
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            StatusBadge(text: checkpoint.status.displayText, tone: checkpoint.status.tone)
        }
        .padding(.vertical, 6)
    }

    private var signOffCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    LabelCaps(text: "Sign-Off Authorization")
                    Spacer()
                    Text("Today at 10:48 AM")
                        .font(AppTypography.caption())
                        .foregroundStyle(AppColors.textTertiary)
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Digital Signature")
                        .font(AppTypography.caption())
                        .foregroundStyle(AppColors.textSecondary)
                    Path { path in
                        path.move(to: CGPoint(x: 10, y: 40))
                        path.addCurve(to: CGPoint(x: 90, y: 30), control1: CGPoint(x: 40, y: 10), control2: CGPoint(x: 60, y: 50))
                        path.addCurve(to: CGPoint(x: 200, y: 45), control1: CGPoint(x: 120, y: 10), control2: CGPoint(x: 150, y: 60))
                        path.addCurve(to: CGPoint(x: 300, y: 30), control1: CGPoint(x: 240, y: 20), control2: CGPoint(x: 270, y: 50))
                    }
                    .stroke(AppColors.primary, lineWidth: 2)
                    .frame(height: 60)
                    Divider()
                    Text("Alex Mercer, PE · Lic #84920")
                        .font(AppTypography.caption())
                        .foregroundStyle(AppColors.textSecondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.surfaceAlt)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                HStack(alignment: .top, spacing: 10) {
                    Button {
                        certifies.toggle()
                    } label: {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(certifies ? AppColors.primary : Color.clear)
                            .frame(width: 20, height: 20)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppColors.divider))
                            .overlay(certifies ? Image(systemName: "checkmark").foregroundStyle(.white).font(.caption2) : nil)
                    }
                    Text("I certify that all inspection records reflect accurate site conditions and that remediation steps comply with plant safety requirements.")
                        .font(AppTypography.caption())
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ReviewSignOffView(task: SampleData.tasks[0])
    }
}
