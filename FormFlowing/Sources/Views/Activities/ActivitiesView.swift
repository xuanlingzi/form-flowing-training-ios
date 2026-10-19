import SwiftUI

// MARK: - Analysis Summary Model

struct AnalysisSummary: Codable {
    let conclusion: String?
    let strengths: [String]?
    let improvements: [String]?
}

struct ActivitiesView: View {
    @State private var activities: [ActivityListItem] = []
    @State private var loading = true
    /// 最近一次加载第一页的时间：系统 TabView 每次切回都会重跑 .task，
    /// 不节流的话每次切回都会把已翻到的列表重置成第一页
    @State private var lastLoadedAt: Date?
    @State private var page = 1
    @State private var hasMore = true
    @State private var loadingMore = false
    @State private var showUploadSheet = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(activities) { act in
                    NavigationLink(destination: ActivityDetailView(activityId: act.activityId)) {
                        ActivityCard(activity: act, onDeepAnalysis: {
                            triggerDeepAnalysis(activityId: act.activityId)
                        })
                    }
                }
                
                // 滑动到底部加载更多
                if !activities.isEmpty {
                    if hasMore {
                        ProgressView()
                            .id(activities.count)
                            .frame(maxWidth: .infinity)
                            .listRowSeparator(.hidden)
                            .onAppear {
                                if !loadingMore && !loading {
                                    page += 1
                                    Task { await loadActivities(isLoadMore: true) }
                                }
                            }
                    } else {
                        Text("没有更多了")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .listRowSeparator(.hidden)
                    }
                }
            }
            .overlay {
                if loading && activities.isEmpty {
                    ProgressView("加载活动列表...")
                } else if activities.isEmpty {
                    ContentUnavailableView(
                        "暂无活动数据",
                        systemImage: "figure.run.circle",
                        description: Text("上传 FIT 文件或连接 Garmin 同步数据")
                    )
                }
            }
            .navigationTitle("运动日志")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showUploadSheet = true
                    } label: {
                        Label("上传活动", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .refreshable {
                await loadActivities(isLoadMore: false)
            }
            .task {
                if let last = lastLoadedAt, Date().timeIntervalSince(last) < 60 { return }
                await loadActivities()
            }
            .sheet(isPresented: $showUploadSheet) {
                NavigationStack {
                    UploadView()
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }
    
    private func loadActivities(isLoadMore: Bool = false) async {
        if !isLoadMore {
            page = 1
            hasMore = true
            lastLoadedAt = Date()
            if activities.isEmpty,
               let cached = await APIService.shared.cached("/activity/list?page=1&page_size=20", as: [ActivityListItem].self) {
                await MainActor.run {
                    activities = cached
                    loading = false
                }
            }
        } else {
            await MainActor.run { loadingMore = true }
        }
        
        do {
            let items = try await APIService.shared.getActivities(page: page)
            await MainActor.run {
                if isLoadMore {
                    activities.append(contentsOf: items)
                    loadingMore = false
                } else {
                    activities = items
                    loading = false
                }
                hasMore = items.count >= 20
            }
        } catch {
            await MainActor.run { 
                if isLoadMore {
                    loadingMore = false
                } else if activities.isEmpty {
                    loading = false
                }
            }
        }
    }
    
    private func triggerDeepAnalysis(activityId: Int) {
        Task {
            try? await APIService.shared.triggerAnalysis(activityId: activityId, tier: "pro")
            await loadActivities()
        }
    }
}

// MARK: - Activity Card

struct ActivityCard: View {
    let activity: ActivityListItem
    var onDeepAnalysis: (() -> Void)? = nil
    
    var sportConfig: (icon: String, color: Color, label: String) {
        switch activity.sport {
        case "cycling": return ("🚴", .teal, "骑行")
        case "running": return ("🏃", .orange, "跑步")
        case "swimming": return ("🏊", .blue, "游泳")
        case "walking": return ("🚶", .green, "步行")
        case "strength_training": return ("🏋️", .purple, "力量")
        case "hiking": return ("🥾", .brown, "徒步")
        default: return ("🏃", .gray, activity.sport ?? "活动")
        }
    }
    
    var distanceText: String {
        guard let d = activity.distance, d > 0 else { return "--" }
        return String(format: "%.1f", d / 1000)
    }
    
    var durationText: String {
        guard let d = activity.duration, d > 0 else { return "--" }
        let h = Int(d) / 3600; let m = (Int(d) % 3600) / 60
        return h > 0 ? "\(h)h\(m)m" : "\(m)min"
    }
    
    var dateText: String {
        guard let s = activity.startTimeLocal else { return "" }
        let parts = s.components(separatedBy: "T")
        if parts.count >= 2 {
            let date = String(parts[0].suffix(5))
            let time = String(parts[1].prefix(5))
            return "\(date) \(time)"
        }
        return String(s.prefix(16))
    }
    
    var analysisSummary: AnalysisSummary? {
        guard let json = activity.analysisSummary, !json.isEmpty,
              let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(AnalysisSummary.self, from: data)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 顶部：运动类型 + 活动名
            HStack(spacing: 12) {
                Text(sportConfig.icon)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(activity.activityName ?? "未命名活动")
                        .font(.headline)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Text(dateText)
                        Text("·")
                        Text(sportConfig.label).foregroundStyle(sportConfig.color)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if activity.analysisStatus == "processing" || activity.analysisStatus == "pending" {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("分析中")
                } else if let tier = activity.analysisTier {
                    let isPro = tier != "fast"
                    PillBadge(text: isPro ? "PRO" : "FAST", color: isPro ? .purple : .teal)
                }
            }
            
            // 核心指标
            HStack(spacing: 0) {
                StatPill(value: distanceText, unit: "km", label: "距离")
                StatPill(value: durationText, label: "时间")
                if let hr = activity.avgHeartRate {
                    StatPill(value: "\(hr)", unit: "bpm", label: "心率")
                }
                if let pwr = activity.avgPower {
                    StatPill(value: "\(pwr)", unit: "W", label: "功率")
                }
                if let cal = activity.totalCalories, activity.avgPower == nil {
                    StatPill(value: "\(cal)", unit: "kcal", label: "热量")
                }
            }
            
            // AI 分析摘要
            if let summary = analysisSummary {
                // 结论
                if let conclusion = summary.conclusion, !conclusion.isEmpty {
                    Label(conclusion, systemImage: "brain")
                        .labelStyle(.titleAndIcon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                // 标签
                let strengths = summary.strengths?.prefix(3) ?? []
                let improvements = summary.improvements?.prefix(2) ?? []
                
                if !strengths.isEmpty || !improvements.isEmpty {
                    FlowLayout(spacing: 4) {
                        ForEach(Array(strengths.enumerated()), id: \.offset) { _, s in
                            SummaryTag(text: s, systemImage: "checkmark.circle.fill", color: .green)
                        }
                        
                        ForEach(Array(improvements.enumerated()), id: \.offset) { _, s in
                            SummaryTag(text: s, systemImage: "exclamationmark.triangle.fill", color: .orange)
                        }
                    }
                }
                
                // 深度分析按钮
                if activity.analysisTier == "fast" {
                    Button {
                        onDeepAnalysis?()
                    } label: {
                        Label("深度分析", systemImage: "sparkle.magnifyingglass")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.purple)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Summary Tag

struct SummaryTag: View {
    let text: String
    let systemImage: String
    let color: Color
    
    var body: some View {
        Label(text, systemImage: systemImage)
            .labelStyle(.titleAndIcon)
            .font(.caption2)
            .foregroundStyle(color)
            .multilineTextAlignment(.leading)
            .lineLimit(3)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
    }
}

// MARK: - Flow Layout (for tags)

struct FlowLayout: Layout {
    var spacing: CGFloat = 4
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, pos) in result.positions.enumerated() {
            let subview = subviews[index]
            subview.place(
                at: CGPoint(x: bounds.minX + pos.x, y: bounds.minY + pos.y),
                proposal: ProposedViewSize(width: proposal.width, height: nil)
            )
        }
    }
    
    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
            if x + size.width > maxWidth && x > 0 {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }
        
        return (positions, CGSize(width: min(maxX, maxWidth), height: y + rowHeight))
    }
}

// MARK: - Stat Pill

struct StatPill: View {
    let value: String
    var unit: String? = nil
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.callout.weight(.bold))
                    .fontDesign(.rounded)
                if let unit = unit {
                    Text(unit)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
