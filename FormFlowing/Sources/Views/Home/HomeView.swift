import SwiftUI
import Charts

struct HomeView: View {
    @EnvironmentObject var auth: AuthManager
    @Environment(\.selectedTab) var selectedTab
    @State private var garminStatus: GarminUserStatus?
    @State private var recentActivities: [ActivityListItem] = []
    @State private var loading = true
    /// 最近一次加载时间：系统 TabView 每次切回都会重跑 .task，刚加载过就跳过
    @State private var lastLoadedAt: Date?
    @State private var syncing = false
    @State private var appear = false
    
    // 每日训练建议
    @State private var dailyCheck: DailyCheckItem? = nil
    @State private var dailyCheckCollapsed = false
    @State private var dailyCheckExpanded = false
    
    var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 0..<6: return "🌙 深夜好"
        case 6..<12: return "🌅 上午好"
        case 12..<14: return "☀️ 中午好"
        case 14..<18: return "🌤 下午好"
        default: return "🌆 晚上好"
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if loading {
                        ProgressView("加载中...")
                            .frame(maxWidth: .infinity)
                            .padding(.top, 80)
                    } else if let s = garminStatus {
                        // 每日训练建议卡片
                        if let check = dailyCheck {
                            dailyCheckHomeCard(check: check)
                        }
                        
                        // 状态卡片
                        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                            GridRow {
                                trainingStatusCard(s)
                                heartRateCard(s)
                            }
                            GridRow {
                                bodyBatteryCard(s)
                                healthCard(s)
                            }
                            trainingLoadCard(s)
                            GridRow {
                                todayActivityCard(s)
                                sleepCard(s)
                            }
                            if s.hrvLastNight != nil {
                                hrvCard(s)
                            }
                        }
                        
                        // 训练趋势入口
                        trendsEntry
                        
                        // AI 分析
                        if !recentActivities.isEmpty {
                            analysisSection
                        }
                    }
                }
                .padding()
                .backgroundStyle(Color(.secondarySystemGroupedBackground))
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(auth.username)
            .navigationSubtitle(greeting)
            .toolbar {
                if garminStatus?.primaryDevice != nil || garminStatus?.garminSyncedAt != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        VStack(alignment: .trailing, spacing: 0) {
                            if let device = garminStatus?.primaryDevice {
                                Text(device).lineLimit(1)
                            }
                            if let syncTime = garminStatus?.garminSyncedAt {
                                Text("同步 " + String(syncTime.suffix(8).prefix(5)))
                            }
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize()
                    }
                    .sharedBackgroundVisibility(.hidden)
                }
            }
            .refreshable {
                // 下拉同时触发 Garmin 同步
                try? await APIService.shared.refreshGarmin()
                await loadData()
            }
            .task {
                if let last = lastLoadedAt, Date().timeIntervalSince(last) < 60 { return }
                await loadData()
            }
        }
    }
    
    // MARK: - Card 1: 训练状态
    
    func trainingStatusCard(_ s: GarminUserStatus) -> some View {
        let acwr = GarminLocalization.acwrStatus(s.acwrStatus)
        
        return StatusCardView(icon: "figure.run", iconColor: .emerald, title: "训练状态") {
            VStack(alignment: .leading, spacing: 6) {
                Text(GarminLocalization.trainingStatus(s.trainingStatus))
                    .font(.headline)
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(s.acwrRatio.map { String(format: "%.1f", $0) } ?? "-")
                        .font(.title.weight(.bold))
                        .fontDesign(.rounded)
                        .foregroundStyle(Color.emerald)
                    Text("ACWR").font(.caption2).foregroundStyle(.secondary)
                }
                Text(acwr.text)
                    .font(.caption)
                    .foregroundStyle(acwrColor(s.acwrStatus))
            }
        }
    }
    
    // MARK: - Card 2: 心率
    
    func heartRateCard(_ s: GarminUserStatus) -> some View {
        StatusCardView(icon: "heart.fill", iconColor: .pink, title: "心率") {
            VStack(spacing: 6) {
                metricRow("静息心率", "\(s.hrRest ?? 0)", "bpm")
                metricRow("LTHR", "\(s.hrLthr ?? 0)", "")
                metricRow("今日最高", "\(s.hrMaxToday ?? 0)", "")
                metricRow("7日均", "\(s.hr7dAvgRest ?? 0)", "")
            }
        }
    }
    
    // MARK: - Card 3: 身体电量
    
    func bodyBatteryCard(_ s: GarminUserStatus) -> some View {
        let bb = Double(s.bodyBatteryLatest ?? 0)
        return StatusCardView(icon: "battery.75percent", iconColor: .orange, title: "身体电量") {
            HStack(spacing: 12) {
                Gauge(value: min(max(bb, 0), 100), in: 0...100) {
                    Text("身体电量")
                } currentValueLabel: {
                    Text("\(s.bodyBatteryLatest ?? 0)")
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(bb > 50 ? .green : bb > 25 ? .orange : .red)
                
                VStack(spacing: 5) {
                    metricRow("压力", "\(s.stressAvg ?? 0)", "")
                    metricRow("最高", "\(s.bodyBatteryHigh ?? 0)", "")
                    metricRow("最低", "\(s.bodyBatteryLow ?? 0)", "")
                }
            }
        }
    }
    
    // MARK: - Card 4: 健康
    
    func healthCard(_ s: GarminUserStatus) -> some View {
        StatusCardView(icon: "wind", iconColor: .blue, title: "健康") {
            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("血氧").font(.caption).foregroundStyle(.secondary)
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text("\(s.spo2Avg ?? s.spo2Latest ?? 0)")
                            .font(.title2.weight(.bold))
                            .fontDesign(.rounded)
                            .foregroundStyle(.blue)
                        Text("%").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                metricRow("呼吸率", s.respirationAvgWaking.map { String(format: "%.1f", $0) } ?? "-", "")
                metricRow("VO₂Max", s.vo2MaxCycling.map { String(format: "%.0f", $0) } ?? "-",
                          s.fitnessAge.map { "age \($0)" } ?? "")
            }
        }
    }
    
    // MARK: - Card 5: 训练负荷（全宽）
    
    func trainingLoadCard(_ s: GarminUserStatus) -> some View {
        let loads: [(String, Double, Double, Double, Color)] = [
            ("低强度有氧", s.loadAerobicLow ?? 0, s.loadAerobicLowTargetMin ?? 0, s.loadAerobicLowTargetMax ?? 0, .teal),
            ("高强度有氧", s.loadAerobicHigh ?? 0, s.loadAerobicHighTargetMin ?? 0, s.loadAerobicHighTargetMax ?? 0, .emerald),
            ("无氧", s.loadAnaerobic ?? 0, s.loadAnaerobicTargetMin ?? 0, s.loadAnaerobicTargetMax ?? 0, .orange),
        ]
        let feedback = GarminLocalization.trainingLoadFeedback(s.trainingLoadFeedback)
        let acute = s.acuteLoad.map { String(format: "%.0f", $0) } ?? "-"
        let chronic = s.chronicLoad.map { String(format: "%.0f", $0) } ?? "-"
        
        return GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(loads, id: \.0) { item in
                    let (name, value, tMin, tMax, color) = item
                    let total = max(max(value, tMax) * 1.15, 1)
                    let inRange = value >= tMin && value <= tMax
                    
                    ProgressView(value: min(max(value, 0), total), total: total) {
                        LabeledContent {
                            Text("\(Int(value))")
                                .fontWeight(.semibold)
                                .foregroundStyle(inRange ? .green : value < tMin ? .orange : .red)
                        } label: {
                            Text(tMin > 0 ? "\(name)（目标 \(Int(tMin))~\(Int(tMax))）" : name)
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                    }
                    .tint(color)
                }
                
                // 反馈信息
                if !feedback.isEmpty {
                    Label(feedback, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        } label: {
            LabeledContent {
                Text("急性 \(acute) · 慢性 \(chronic)")
                    .font(.caption)
            } label: {
                Label("训练负荷", systemImage: "flame.fill")
            }
        }
    }
    
    // MARK: - 训练趋势入口
    
    var trendsEntry: some View {
        NavigationLink(destination: TrendsView()) {
            GroupBox {
                HStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title3)
                        .foregroundStyle(.blue)
                        .frame(width: 40, height: 40)
                        .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("训练趋势")
                            .font(.subheadline.weight(.semibold))
                        Text("体能 / 疲劳 / 状态、功率曲线、有氧效率等跨活动分析")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Card 6: 今日活动
    
    func todayActivityCard(_ s: GarminUserStatus) -> some View {
        StatusCardView(icon: "figure.walk", iconColor: .teal, title: "今日活动") {
            VStack(spacing: 6) {
                metricRow("步数", s.steps.map { formatNumber($0) } ?? "-", "")
                metricRow("活动卡路里", "\(s.caloriesActive ?? 0)", "kcal")
                metricRow("距离", s.distanceM.map { String(format: "%.1f", $0 / 1000) } ?? "-", "km")
                metricRow("强度分钟", "\(s.intensityMinutesWeek ?? 0)", "min")
            }
        }
    }
    
    // MARK: - Card 7: 睡眠
    
    func sleepCard(_ s: GarminUserStatus) -> some View {
        let score = Double(s.sleepScore ?? 0)
        let totalSec = s.sleepSeconds ?? 0
        let stages: [SleepStage] = [
            SleepStage(name: "深睡", seconds: s.sleepDeepSeconds ?? 0),
            SleepStage(name: "浅睡", seconds: s.sleepLightSeconds ?? 0),
            SleepStage(name: "REM", seconds: s.sleepRemSeconds ?? 0),
            SleepStage(name: "清醒", seconds: s.sleepAwakeSeconds ?? 0),
        ]
        
        return StatusCardView(icon: "moon.zzz.fill", iconColor: .indigo, title: "睡眠") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Gauge(value: min(max(score, 0), 100), in: 0...100) {
                        Text("睡眠评分")
                    } currentValueLabel: {
                        Text("\(s.sleepScore ?? 0)")
                    }
                    .gaugeStyle(.accessoryCircularCapacity)
                    .tint(score > 70 ? .green : score > 40 ? .orange : .red)
                    
                    VStack(spacing: 3) {
                        metricRow("质量", GarminLocalization.sleepQuality(s.sleepQuality), "")
                        metricRow("时长", totalSec > 0 ? "\(totalSec / 3600)h\((totalSec % 3600) / 60)m" : "--", "")
                    }
                }
                
                // 阶段条
                if totalSec > 0 {
                    Chart(stages) { stage in
                        BarMark(x: .value("时长", stage.seconds))
                            .foregroundStyle(by: .value("阶段", stage.name))
                    }
                    .chartForegroundStyleScale([
                        "深睡": Color.indigo,
                        "浅睡": Color.blue,
                        "REM": Color.purple,
                        "清醒": Color.gray,
                    ])
                    .chartXAxis(.hidden)
                    .chartXScale(domain: 0...max(stages.reduce(0) { $0 + $1.seconds }, 1))
                    .frame(height: 44)
                }
            }
        }
    }
    
    // MARK: - Card 8: HRV（全宽）
    
    func hrvCard(_ s: GarminUserStatus) -> some View {
        StatusCardView(icon: "waveform.path.ecg", iconColor: .purple, title: "HRV") {
            HStack(alignment: .top, spacing: 16) {
                // 左侧：大数字 + 状态
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text("\(s.hrvLastNight ?? 0)")
                            .font(.title.weight(.bold))
                            .fontDesign(.rounded)
                            .foregroundStyle(.purple)
                        Text("rMSSD").font(.caption2).foregroundStyle(.secondary)
                    }
                    Text(GarminLocalization.hrvStatus(s.hrvStatus))
                        .font(.caption)
                        .foregroundStyle(hrvStatusColor(s.hrvStatus))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // 右侧：详细指标行
                VStack(spacing: 8) {
                    metricRow("7日均值", "\(s.hrvWeeklyAvg ?? 0)", "")
                    metricRow("5分峰值", "\(s.hrv5minHigh ?? 0)", "")
                    if let lo = s.hrvBaselineLow, let hi = s.hrvBaselineHigh {
                        metricRow("基线范围", "\(lo) ~ \(hi)", "")
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
    
    // MARK: - AI 分析
    
    var analysisSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("最近 AI 分析", systemImage: "sparkles")
                .font(.headline)
            
            ForEach(recentActivities) { act in
                NavigationLink(destination: ActivityDetailView(activityId: act.id)) {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 10) {
                            // 活动指标
                            HStack(spacing: 0) {
                                if let d = act.distance {
                                    StatPill(value: String(format: "%.1f", d / 1000), unit: "km", label: "距离")
                                }
                                if let t = act.duration {
                                    let h = Int(t) / 3600; let m = (Int(t) % 3600) / 60
                                    StatPill(value: h > 0 ? "\(h)h\(m)m" : "\(m)m", label: "时间")
                                }
                                if let hr = act.avgHeartRate {
                                    StatPill(value: "\(hr)", unit: "bpm", label: "心率")
                                }
                                if let p = act.avgPower {
                                    StatPill(value: "\(p)", unit: "W", label: "功率")
                                }
                            }
                            
                            // AI 摘要
                            if let summaryJson = act.analysisSummary,
                               let data = summaryJson.data(using: .utf8),
                               let summary = try? JSONDecoder().decode(AnalysisSummary.self, from: data) {
                                
                                if let conclusion = summary.conclusion, !conclusion.isEmpty {
                                    Label(conclusion, systemImage: "sparkle")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                
                                // 标签
                                let strengths = summary.strengths ?? []
                                let improvements = summary.improvements ?? []
                                if !strengths.isEmpty || !improvements.isEmpty {
                                    FlowLayout(spacing: 6) {
                                        ForEach(Array(strengths.enumerated()), id: \.offset) { _, tag in
                                            SummaryTag(text: tag, systemImage: "checkmark.circle.fill", color: .green)
                                        }
                                        ForEach(Array(improvements.enumerated()), id: \.offset) { _, tag in
                                            SummaryTag(text: tag, systemImage: "exclamationmark.triangle.fill", color: .orange)
                                        }
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } label: {
                        LabeledContent {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        } label: {
                            Text("\(sportIcon(act.sport)) \(act.activityName ?? "活动")")
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            Text("\(act.startTimeLocal ?? "") · \(sportLabel(act.sport))")
                                .font(.caption)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func sportIcon(_ sport: String?) -> String {
        switch sport {
        case "cycling": return "🚴"
        case "running": return "🏃"
        case "swimming": return "🏊"
        default: return "🏃"
        }
    }
    
    private func sportColor(_ sport: String?) -> Color {
        switch sport {
        case "cycling": return .teal
        case "running": return .orange
        case "swimming": return .blue
        default: return .gray
        }
    }
    
    private func sportLabel(_ sport: String?) -> String {
        switch sport {
        case "cycling": return "骑行"
        case "running": return "跑步"
        case "swimming": return "游泳"
        default: return sport ?? "活动"
        }
    }
    
    // MARK: - Helpers
    
    func metricRow(_ label: String, _ value: String, _ unit: String) -> some View {
        LabeledContent {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value).fontWeight(.semibold).foregroundStyle(.primary)
                if !unit.isEmpty {
                    Text(unit).font(.caption2)
                }
            }
        } label: {
            Text(label).foregroundStyle(.secondary)
        }
        .font(.footnote)
    }
    
    private func acwrColor(_ status: String?) -> Color {
        switch status {
        case "OPTIMAL": return .green
        case "HIGH": return .orange
        case "LOW": return .blue
        case "VERY_HIGH": return .red
        default: return .secondary
        }
    }
    
    private func hrvStatusColor(_ status: String?) -> Color {
        switch status {
        case "BALANCED": return .green
        case "UNBALANCED": return .orange
        case "LOW": return .red
        default: return .secondary
        }
    }
    
    private func formatNumber(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }
    
    private func handleRefresh() {
        syncing = true
        Task {
            try? await APIService.shared.refreshGarmin()
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            let res = try? await APIService.shared.getGarminStatus()
            await MainActor.run {
                if let s = res?.status { garminStatus = s }
                syncing = false
            }
        }
    }
    
    private func loadData() async {
        // 1. 首次进入先从本地缓存加载，立即显示
        if lastLoadedAt == nil { await loadFromCache() }
        lastLoadedAt = Date()
        
        // 2. 后台从 API 获取最新数据
        async let statusFetch: Void = {
            if let res = try? await APIService.shared.getGarminStatus() {
                await MainActor.run {
                    garminStatus = res.status
                    loading = false
                    withAnimation { appear = true }
                }
            } else {
                await MainActor.run {
                    if garminStatus == nil { loading = false }
                }
            }
        }()
        
        async let activitiesFetch: Void = {
            if let items = try? await APIService.shared.getActivities(page: 1, pageSize: 10) {
                let filtered = items.filter { $0.analysisSummary != nil }.prefix(3).map { $0 }
                await MainActor.run { withAnimation { recentActivities = filtered } }
            }
        }()
        
        async let dailyCheckFetch: Void = {
            if let resp = try? await APIService.shared.getDailyCheckToday() {
                await MainActor.run {
                    if let m = resp.morning, m.status == "done" {
                        dailyCheck = m
                        dailyCheckCollapsed = m.userResponse != nil
                    } else if let e = resp.evening, e.status == "done" {
                        dailyCheck = e
                        dailyCheckCollapsed = e.userResponse != nil
                    }
                }
            }
        }()
        
        _ = await (statusFetch, activitiesFetch, dailyCheckFetch)
    }
    
    private func loadFromCache() async {
        if let cached = await APIService.shared.cached("/profile/garmin-status", as: GarminStatusResponse.self) {
            await MainActor.run {
                garminStatus = cached.status
                loading = false
                withAnimation { appear = true }
            }
        }
        if let cached = await APIService.shared.cached("/activity/list?page=1&page_size=10", as: [ActivityListItem].self) {
            let filtered = cached.filter { $0.analysisSummary != nil }.prefix(3).map { $0 }
            await MainActor.run { recentActivities = filtered }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年M月d日 EEEE"
        return f.string(from: date)
    }
    
    // MARK: - Daily Check Card
    
    private func dailyCheckHomeCard(check: DailyCheckItem) -> some View {
        let actionLabels: [String: (text: String, color: Color)] = [
            "proceed": ("按计划执行", .green),
            "modify": ("建议调整", .orange),
            "skip": ("建议休息", .red),
            "reschedule": ("建议改期", .blue),
            "no_change": ("保持原计划", .green),
            "on_track": ("执行良好", .green),
        ]
        let info = actionLabels[check.action ?? ""] ?? ("AI 建议", .teal)
        let isExpanded = Binding(
            get: { !dailyCheckCollapsed },
            set: { dailyCheckCollapsed = !$0 }
        )
        
        return GroupBox {
            DisclosureGroup(isExpanded: isExpanded) {
                VStack(alignment: .leading, spacing: 10) {
                    if let rec = check.recommendation {
                        let lines = rec.split(separator: "\n", omittingEmptySubsequences: false)
                        let body = lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                        Text(body.isEmpty ? rec : body)
                            .font(.subheadline)
                            .lineLimit(dailyCheckExpanded ? nil : 4)
                        
                        Button(dailyCheckExpanded ? "收起" : "展开全部") {
                            withAnimation { dailyCheckExpanded.toggle() }
                        }
                        .buttonStyle(.borderless)
                        .font(.footnote)
                    }
                    
                    HStack(spacing: 10) {
                        if let adjustments = check.adjustments, !adjustments.isEmpty {
                            Button("执行调整") { applyDailyCheckAndGoTraining() }
                                .buttonStyle(.borderedProminent)
                        }
                        Button("知道了") { respondAndCollapse("accepted") }
                            .buttonStyle(.bordered)
                        Button("忽略") { respondAndCollapse("ignored") }
                            .buttonStyle(.bordered)
                            .tint(.secondary)
                    }
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
            } label: {
                LabeledContent {
                    Text(info.text)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(info.color)
                } label: {
                    Label(check.checkType == "morning" ? "晨检建议" : "晚检建议",
                          systemImage: check.checkType == "morning" ? "sunrise.fill" : "moon.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primary)
                }
            }
        }
    }
    
    private func respondAndCollapse(_ response: String) {
        guard let check = dailyCheck else { return }
        Task {
            try? await APIService.shared.respondDailyCheck(
                id: check.dailyCheckId, response: response)
            await MainActor.run {
                withAnimation { dailyCheckCollapsed = true }
            }
        }
    }
    
    private func applyDailyCheckAndGoTraining() {
        guard let check = dailyCheck else { return }
        Task {
            try? await APIService.shared.applyDailyCheck(id: check.dailyCheckId)
            await MainActor.run {
                dailyCheck = nil
                // 切换到训练 Tab (index 2)
                withAnimation {
                    selectedTab.wrappedValue = 2
                }
            }
        }
    }
}

// MARK: - Status Card Container

struct StatusCardView<Content: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        GroupBox {
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } label: {
            Label {
                Text(title).foregroundStyle(.secondary)
            } icon: {
                Image(systemName: icon).foregroundStyle(iconColor)
            }
            .font(.subheadline.weight(.medium))
        }
    }
}

// MARK: - Sleep Stage

struct SleepStage: Identifiable {
    let name: String
    let seconds: Int
    var id: String { name }
}

// MARK: - Color Extensions

extension Color {
    static let emerald = Color(red: 0.05, green: 0.65, blue: 0.52)
}

// MARK: - Pill Badge

struct PillBadge: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
            .foregroundStyle(color)
    }
}
