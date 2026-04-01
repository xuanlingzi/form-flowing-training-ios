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
    @State private var page = 1
    @State private var appear = false
    @State private var scrollOffset: CGFloat = 0
    
    private var collapseProgress: CGFloat {
        min(max(scrollOffset / 60, 0), 1)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    if loading && activities.isEmpty {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("加载活动列表...")
                                .font(.caption).foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 100)
                    } else if activities.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "figure.run.circle")
                                .font(.system(size: 56))
                                .foregroundStyle(.linearGradient(colors: [.teal, .green], startPoint: .topLeading, endPoint: .bottomTrailing))
                            Text("暂无活动数据")
                                .font(.headline).foregroundColor(.secondary)
                            Text("上传 FIT 文件或连接 Garmin 同步数据")
                                .font(.caption).foregroundColor(Color(UIColor.tertiaryLabel))
                        }
                        .padding(.top, 100)
                    } else {
                        LazyVStack(spacing: 14) {
                            ForEach(Array(activities.enumerated()), id: \.element.id) { idx, act in
                                NavigationLink(destination: ActivityDetailView(activityId: act.activityId)) {
                                    ActivityCard(activity: act, onDeepAnalysis: {
                                        triggerDeepAnalysis(activityId: act.activityId)
                                    })
                                }
                                .buttonStyle(.plain)
                                .opacity(appear ? 1 : 0)
                                .offset(y: appear ? 0 : 20)
                                .animation(.easeOut(duration: 0.4).delay(Double(min(idx, 8)) * 0.05), value: appear)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        
                        // 分页
                        paginationBar
                    }
                }
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: ScrollOffsetKey.self,
                            value: -geo.frame(in: .named("activitiesScroll")).origin.y
                        )
                    }
                )
            }
            .coordinateSpace(name: "activitiesScroll")
            .onPreferenceChange(ScrollOffsetKey.self) { value in
                scrollOffset = value
            }
            .safeAreaInset(edge: .top) {
                activitiesHeader
            }
            .background(Color(UIColor.systemGroupedBackground))
            .toolbar(.hidden, for: .navigationBar)
            .refreshable {
                page = 1
                await loadActivities()
            }
            .task {
                await loadActivities()
                withAnimation { appear = true }
            }
        }
    }
    
    private var activitiesHeader: some View {
        let titleSize: CGFloat = 30 - 10 * collapseProgress
        
        return HStack(alignment: .bottom) {
            Text("运动日志")
                .font(.system(size: titleSize, weight: .bold))
            Spacer()
            NavigationLink(destination: UploadView()) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.linearGradient(colors: [.teal, .green], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12 - 4 * collapseProgress)
        .padding(.bottom, 12 - 4 * collapseProgress)
        .background(
            Color(UIColor.systemBackground)
                .shadow(.drop(color: .black.opacity(0.06 * collapseProgress), radius: 4, y: 2))
        )
        .animation(.interactiveSpring(response: 0.3), value: collapseProgress)
    }
    
    // MARK: - Pagination
    
    var paginationBar: some View {
        HStack(spacing: 12) {
            Button(action: {
                page = max(1, page - 1)
                Task { await loadActivities() }
            }) {
                Image(systemName: "chevron.left")
                    .font(.caption.weight(.semibold))
                    .frame(width: 32, height: 32)
                    .background(Color.white).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(UIColor.systemGray4), lineWidth: 1))
            }
            .disabled(page <= 1)
            .opacity(page <= 1 ? 0.4 : 1)
            
            Text("第 \(page) 页")
                .font(.system(size: 13, weight: .medium))
            
            Button(action: {
                page += 1
                Task { await loadActivities() }
            }) {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .frame(width: 32, height: 32)
                    .background(Color.white).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(UIColor.systemGray4), lineWidth: 1))
            }
            .disabled(activities.count < 20)
            .opacity(activities.count < 20 ? 0.4 : 1)
        }
        .padding(.vertical, 12)
    }
    
    private func loadActivities() async {
        loading = true
        do {
            let items = try await APIService.shared.getActivities(page: page)
            await MainActor.run {
                activities = items
                loading = false
            }
        } catch {
            await MainActor.run { loading = false }
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
        VStack(spacing: 0) {
            // 顶部：运动类型 + 活动名
            HStack(spacing: 12) {
                Text(sportConfig.icon)
                    .font(.title2)
                    .frame(width: 48, height: 48)
                    .background(sportConfig.color.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(activity.activityName ?? "未命名活动")
                            .font(.system(size: 15, weight: .semibold))
                            .lineLimit(1).foregroundColor(.primary)
                        
                        if activity.analysisStatus == "processing" || activity.analysisStatus == "pending" {
                            HStack(spacing: 3) {
                                ProgressView().scaleEffect(0.5)
                                Text("分析中").font(.system(size: 9, weight: .semibold))
                            }
                            .foregroundColor(.purple)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.purple.opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }
                    
                    HStack(spacing: 6) {
                        Text(dateText).font(.system(size: 12)).foregroundColor(.secondary)
                        Text("·").foregroundColor(Color(UIColor.quaternaryLabel))
                        Text(sportConfig.label)
                            .font(.system(size: 11, weight: .medium)).foregroundColor(sportConfig.color)
                    }
                }
                
                Spacer()
                
                if let tier = activity.analysisTier {
                    PillBadge(text: tier == "pro" ? "PRO" : "FAST", color: tier == "pro" ? .purple : .teal)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(Color(UIColor.quaternaryLabel))
            }
            .padding(16)
            
            Divider().padding(.horizontal, 16)
            
            // 核心指标
            HStack(spacing: 0) {
                StatPill(value: distanceText, unit: "km", label: "距离", icon: "arrow.left.and.right")
                StatPill(value: durationText, label: "时间", icon: "clock")
                if let hr = activity.avgHeartRate {
                    StatPill(value: "\(hr)", unit: "bpm", label: "心率", icon: "heart.fill")
                }
                if let pwr = activity.avgPower {
                    StatPill(value: "\(pwr)", unit: "W", label: "功率", icon: "bolt.fill")
                }
                if let cal = activity.totalCalories, activity.avgPower == nil {
                    StatPill(value: "\(cal)", unit: "kcal", label: "热量", icon: "flame.fill")
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 12)
            
            // AI 分析摘要
            if let summary = analysisSummary {
                Divider().padding(.horizontal, 16)
                
                VStack(alignment: .leading, spacing: 8) {
                    // 结论
                    if let conclusion = summary.conclusion, !conclusion.isEmpty {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "brain")
                                .font(.system(size: 11)).foregroundColor(.purple)
                            Text(conclusion)
                                .font(.system(size: 12)).foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                    
                    // 标签
                    let strengths = summary.strengths?.prefix(3) ?? []
                    let improvements = summary.improvements?.prefix(2) ?? []
                    
                    if !strengths.isEmpty || !improvements.isEmpty {
                        FlowLayout(spacing: 4) {
                            ForEach(Array(strengths.enumerated()), id: \.offset) { _, s in
                                HStack(alignment: .top, spacing: 3) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 8)).foregroundColor(.green)
                                        .padding(.top, 2)
                                    Text(s).font(.system(size: 9, weight: .medium))
                                        .foregroundColor(Color(red: 0.02, green: 0.47, blue: 0.34))
                                        .multilineTextAlignment(.leading)
                                        .lineLimit(3)
                                }
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.green.opacity(0.1))
                                .clipShape(Capsule())
                            }
                            
                            ForEach(Array(improvements.enumerated()), id: \.offset) { _, s in
                                HStack(alignment: .top, spacing: 3) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 8)).foregroundColor(.orange)
                                        .padding(.top, 2)
                                    Text(s).font(.system(size: 9, weight: .medium))
                                        .foregroundColor(Color(red: 0.71, green: 0.33, blue: 0.04))
                                        .multilineTextAlignment(.leading)
                                        .lineLimit(3)
                                }
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.orange.opacity(0.1))
                                .clipShape(Capsule())
                            }
                            
                            // 深度分析按钮
                            if activity.analysisTier == "fast" {
                                Button(action: {
                                    onDeepAnalysis?()
                                }) {
                                    HStack(spacing: 3) {
                                        Text("🔬").font(.system(size: 8))
                                        Text("深度分析").font(.system(size: 9, weight: .semibold)).foregroundColor(.purple)
                                    }
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Color.purple.opacity(0.1))
                                    .overlay(Capsule().stroke(Color.purple.opacity(0.3), lineWidth: 0.5))
                                    .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
            }
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
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
    var icon: String? = nil
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                if let unit = unit {
                    Text(unit)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - StatItem (for compatibility)

struct StatItem: View {
    let value: String
    var unit: String? = nil
    let label: String
    var body: some View {
        StatPill(value: value, unit: unit, label: label)
    }
}
