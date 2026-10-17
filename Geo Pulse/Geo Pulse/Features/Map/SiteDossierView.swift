import SwiftUI

struct SiteDossierView: View {
    @Environment(\.dismiss) private var dismiss
    let site: Site

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                overviewCard
                perimeterCard
                infrastructureCard
                contactsCard
                documentationCard
                PrimaryButton(title: "Download Facility Dossier", icon: "arrow.down.circle") {}
                Spacer(minLength: 24)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Site Dossier")
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

    private var overviewCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    LabelCaps(text: "Sector Overview")
                    Spacer()
                    StatusBadge(text: site.status.displayText, tone: site.status.tone, showsDot: true)
                }
                Text("Riverside Sector 4")
                    .font(AppTypography.title())
                Text(site.subtitle.isEmpty ? "Primary Refining Facility" : site.subtitle)
                    .font(AppTypography.body())
                    .foregroundStyle(AppColors.textSecondary)
                HStack(spacing: 4) {
                    Image(systemName: "mappin")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                    Text(site.address.isEmpty ? "Baton Rouge, Louisiana" : site.address)
                        .font(AppTypography.caption())
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
    }

    private var perimeterCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    LabelCaps(text: "Perimeter & Geofence")
                    Spacer()
                    Image(systemName: "grid")
                        .foregroundStyle(AppColors.textSecondary)
                }
                HStack(spacing: 12) {
                    boundaryTile(title: "Outer Boundary", value: "500m radius")
                    boundaryTile(title: "Inner Exclusion Zone", value: "120m")
                }
                HStack(spacing: 10) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(AppColors.accentWarning)
                    Text("Secondary fence clearance requires Sector 4 dispatch badge confirmation.")
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

    private func boundaryTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(AppTypography.caption())
                .foregroundStyle(AppColors.textSecondary)
            Text(value)
                .font(AppTypography.titleSmall())
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surfaceAlt)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var infrastructureCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    LabelCaps(text: "Critical Infrastructure")
                    Spacer()
                    Text("3 Active Units")
                        .font(AppTypography.caption())
                        .foregroundStyle(AppColors.textTertiary)
                }
                unitRow(name: "Cryogenic Feeder (Line 4)", status: "142 PSI · Normal pressure", tone: .success, badge: "Nominal")
                unitRow(name: "Turbine Generator Gen-2", status: "Standby backup · Ready", tone: .neutral, badge: "Standby")
                unitRow(name: "Chemical Scrubbing Unit B", status: "Filter at 84% health", tone: .warning, badge: "Service Soon")
            }
        }
    }

    private func unitRow(name: String, status: String, tone: BadgeTone, badge: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle().fill(tone.foreground).frame(width: 8, height: 8).padding(.top, 6)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(AppTypography.bodyBold())
                Text(status)
                    .font(AppTypography.caption())
                    .foregroundStyle(AppColors.textSecondary)
            }
            Spacer()
            StatusBadge(text: badge, tone: tone)
        }
        .padding(12)
        .background(AppColors.surfaceAlt)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var contactsCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                LabelCaps(text: "Key Emergency Contacts")
                contactRow(name: "Markus Vance", subtitle: "Site Commander · On Station", icon: "phone.fill")
                contactRow(name: "Harris Health Care", subtitle: "Nearest Emergency Facility (12 mi)", icon: "mappin.and.ellipse")
            }
        }
    }

    private func contactRow(name: String, subtitle: String, icon: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(AppTypography.bodyBold())
                Text(subtitle)
                    .font(AppTypography.caption())
                    .foregroundStyle(AppColors.textSecondary)
            }
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(AppColors.primarySoft).frame(width: 36, height: 36)
                Image(systemName: icon).foregroundStyle(AppColors.primary)
            }
        }
        .padding(12)
        .background(AppColors.surfaceAlt)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var documentationCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 10) {
                LabelCaps(text: "Facility Documentation")
                documentRow(title: "Sector 4 Piping Diagram (PDF)", subtitle: "Rev. 2024-C · 4.2 MB", icon: "doc.text")
                documentRow(title: "Emergency Shutdown SOP", subtitle: "Standard Protocol · Tier 1", icon: "shield.lefthalf.filled")
            }
        }
    }

    private func documentRow(title: String, subtitle: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon).foregroundStyle(AppColors.textSecondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTypography.bodyBold())
                Text(subtitle)
                    .font(AppTypography.caption())
                    .foregroundStyle(AppColors.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(AppColors.textTertiary)
        }
        .padding(12)
        .background(AppColors.surfaceAlt)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        SiteDossierView(site: SampleData.sites[0])
    }
}
