import SwiftUI

enum AppTab: Hashable {
    case home, map, inspect, settings
}

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab: AppTab = .home

    var body: some View {
        if !appState.isAuthenticated {
            LoginView()
        } else {
            mainTabs
        }
    }

    private var mainTabs: some View {
        VStack(spacing: 0) {
            Group {
                switch selectedTab {
                case .home: HomeView(selectedTab: $selectedTab)
                case .map: MapView(selectedTab: $selectedTab)
                case .inspect: InspectView()
                case .settings: SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            customTabBar
        }
        .background(AppColors.background.ignoresSafeArea())
    }

    private var customTabBar: some View {
        HStack {
            tabItem(tab: .home, label: "Home", baseIcon: "house", fillIcon: "house.fill")
            tabItem(tab: .map, label: "Map", baseIcon: "map", fillIcon: "map.fill")
            tabItem(tab: .inspect, label: "Inspect", baseIcon: "checkmark.square", fillIcon: "checkmark.square.fill")
            tabItem(tab: .settings, label: "Settings", baseIcon: "gearshape", fillIcon: "gearshape.fill")
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(AppColors.surface)
        .overlay(Rectangle().fill(AppColors.divider).frame(height: 1), alignment: .top)
    }

    private func tabItem(tab: AppTab, label: String, baseIcon: String, fillIcon: String) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? fillIcon : baseIcon)
                    .font(.system(size: 20, weight: .medium))
                Text(label)
                    .font(AppTypography.label())
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(isSelected ? AppColors.primary : AppColors.textTertiary)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    RootView().environmentObject({
        let state = AppState()
        state.signIn()
        return state
    }())
}
