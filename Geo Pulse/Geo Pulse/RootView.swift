import SwiftUI

enum AppTab: Hashable {
    case home, map, inspect, settings
}

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedTab: AppTab = .home

    private var isWide: Bool { horizontalSizeClass == .regular }

    var body: some View {
        ZStack {
            if !appState.isAuthenticated {
                LoginView()
            } else if isWide {
                IPadRootView()
            } else {
                mainTabs
            }

            if appState.showFallAlert {
                FallAlertView(
                    onCancel: { appState.cancelFallAlert() },
                    onEscalate: { appState.escalateFallAlert() }
                )
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .alert("Operation failed", isPresented: Binding(get: { appState.errorMessage != nil }, set: { if !$0 { appState.errorMessage = nil } })) {
            Button("OK") { appState.errorMessage = nil }
        } message: { Text(appState.errorMessage ?? "") }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: appState.showFallAlert)
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
        .frame(minHeight: 44)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    RootView().environmentObject({
        let state = AppState()
        state.signIn()
        return state
    }())
}
