import SwiftUI

/// 控制 Tab 切换的环境键
struct SelectedTabKey: EnvironmentKey {
    static let defaultValue: Binding<Int> = .constant(0)
}

extension EnvironmentValues {
    var selectedTab: Binding<Int> {
        get { self[SelectedTabKey.self] }
        set { self[SelectedTabKey.self] = newValue }
    }
}

extension View {
    /// 二级页面隐藏系统 TabBar
    func hideTabBar() -> some View {
        toolbarVisibility(.hidden, for: .tabBar)
    }
}

/// 主 Tab 导航（系统 TabView）
struct MainTabView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("仪表盘", systemImage: "chart.bar.fill", value: 0) {
                HomeView()
            }
            Tab("活动", systemImage: "figure.outdoor.cycle", value: 1) {
                ActivitiesView()
            }
            Tab("训练", systemImage: "calendar", value: 2) {
                TrainingView()
            }
            Tab("设置", systemImage: "gearshape.fill", value: 3) {
                SettingsView()
            }
        }
        .environment(\.selectedTab, $selectedTab)
    }
}
