import SwiftUI

/// 控制 TabBar 可见性的环境键
struct TabBarVisibleKey: EnvironmentKey {
    static let defaultValue: Binding<Bool> = .constant(true)
}

extension EnvironmentValues {
    var tabBarVisible: Binding<Bool> {
        get { self[TabBarVisibleKey.self] }
        set { self[TabBarVisibleKey.self] = newValue }
    }
}

/// 二级页面用来隐藏 TabBar 的 ViewModifier
struct HideTabBarModifier: ViewModifier {
    @Environment(\.tabBarVisible) var tabBarVisible
    
    func body(content: Content) -> some View {
        content
            .onAppear { tabBarVisible.wrappedValue = false }
            .onDisappear { tabBarVisible.wrappedValue = true }
    }
}

extension View {
    func hideTabBar() -> some View {
        modifier(HideTabBarModifier())
    }
}

/// 主 Tab 导航（自定义 TabBar，支持浮起/降落动画）
struct MainTabView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var selectedTab = 0
    @State private var tabBarVisible = true
    
    private let teal = Color(red: 0.051, green: 0.580, blue: 0.533)
    
    private let tabs: [(icon: String, label: String)] = [
        ("chart.bar.fill", "仪表盘"),
        ("figure.outdoor.cycle", "活动"),
        ("calendar", "训练"),
        ("gearshape.fill", "设置"),
    ]
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // 内容区域
            Group {
                switch selectedTab {
                case 0: HomeView()
                case 1: ActivitiesView()
                case 2: TrainingView()
                case 3: SettingsView()
                default: HomeView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, tabBarVisible ? 50 : 0)
            .environment(\.tabBarVisible, $tabBarVisible)
            
            // 自定义 TabBar
            customTabBar
                .offset(y: tabBarVisible ? 0 : 100)
                .opacity(tabBarVisible ? 1 : 0)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: tabBarVisible)
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .ignoresSafeArea(.keyboard)
    }
    
    var customTabBar: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.3)
            HStack(spacing: 0) {
                ForEach(0..<tabs.count, id: \.self) { idx in
                    let tab = tabs[idx]
                    let isSelected = selectedTab == idx
                    
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedTab = idx
                        }
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                                .foregroundColor(isSelected ? teal : .gray)
                                .scaleEffect(isSelected ? 1.05 : 1.0)
                            
                            Text(tab.label)
                                .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                                .foregroundColor(isSelected ? teal : .gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                    }
                }
            }
        }
        .background(.ultraThinMaterial.shadow(.drop(color: .black.opacity(0.06), radius: 4, y: -1)))
        .ignoresSafeArea(edges: .bottom)
    }
}
