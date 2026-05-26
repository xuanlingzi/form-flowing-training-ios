import SwiftUI

struct HomeView: View {
    @EnvironmentObject var auth: AuthManager
    @Environment(\.selectedTab) var selectedTab
    @State private var garminStatus: GarminUserStatus?
    @State private var recentActivities: [ActivityListItem] = []
    @State private var loading = true
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
    
    @State private var scrollOffset: CGFloat = 0
    
    // 折叠进度 0=展开 1=完全折叠
    private var collapseProgress: CGFloat {
        min(max(scrollOffset / 60, 0), 1)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    if loading {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("加载中...").font(.caption).foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity).padding(.top, 80)
                    } else if let s = garminStatus {
                        // 每日训练建议卡片
                        if let check = dailyCheck {
                            dailyCheckHomeCard(check: check)
                                .padding(.horizontal)
                        }
                        
                        // 8 个状态卡片
                        VStack(spacing: 14) {
                            // Row 1: 训练状态 + 心率
                            EqualHeightHStack(spacing: 12) {
                                trainingStatusCard(s)
                                heartRateCard(s)
                            }
                            // Row 2: 身体电量 + 健康
                            EqualHeightHStack(spacing: 12) {
                                bodyBatteryCard(s)
                                healthCard(s)
                            }
                            // 训练负荷（全宽）
                            trainingLoadCard(s)
                            // Row 3: 今日活动 + 睡眠
                            EqualHeightHStack(spacing: 12) {
                                todayActivityCard(s)
                                sleepCard(s)
                            }
                            // HRV（全宽）
                            hrvCard(s)
                        }
                        .padding(.horizontal)
                        .opacity(appear ? 1 : 0)
                        .offset(y: appear ? 0 : 15)
                        .animation(.easeOut(duration: 0.5).delay(0.1), value: appear)
                        .animation(.easeInOut(duration: 0.35), value: recentActivities.count)
                        
                        // AI 分析
                        if !recentActivities.isEmpty {
                            analysisSection
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                                .opacity(appear ? 1 : 0)
                                .offset(y: appear ? 0 : 15)
                                .animation(.easeOut(duration: 0.5).delay(0.2), value: appear)
                        }
                    }
                }
                .padding(.bottom)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: ScrollOffsetKey.self,
                            value: -geo.frame(in: .named("scroll")).origin.y
                        )
                    }
                )
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetKey.self) { value in
                scrollOffset = value
            }
            .safeAreaInset(edge: .top) {
                collapsibleHeader
            }
            .background(Color(UIColor.systemGroupedBackground))
            .toolbar(.hidden, for: .navigationBar)
            .refreshable {
                // 下拉同时触发 Garmin 同步
                try? await APIService.shared.refreshGarmin()
                await loadData()
            }
            .task {
                await loadData()
            }
        }
    }
    
    // MARK: - 可折叠头部
    
    var collapsibleHeader: some View {
        let nameSize: CGFloat = 20
        let greetingSize: CGFloat = 11

        return HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(greeting)
                        .font(.system(size: greetingSize))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Text(auth.username)
                        .font(.system(size: nameSize, weight: .bold))
                        .lineLimit(1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    if let device = garminStatus?.primaryDevice {
                        Text(device)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    if let syncTime = garminStatus?.garminSyncedAt {
                        Text("同步 " + String(syncTime.suffix(8).prefix(5)))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
        }
        .padding(.horizontal)
        .frame(height: 44)
        .background(Color(UIColor.systemBackground))
    }
    
    // MARK: - Card 1: 训练状态
    
    @ViewBuilder
    func trainingStatusCard(_ s: GarminUserStatus) -> some View {
        let _ = s.vo2MaxCycling ?? s.vo2MaxRunning ?? 0
        let acwr = GarminLocalization.acwrStatus(s.acwrStatus)
        
        StatusCardView(icon: "figure.run", iconColor: .emerald, title: "训练状态", borderColor: .emerald) {
            VStack(alignment: .leading, spacing: 6) {
                Text(GarminLocalization.trainingStatus(s.trainingStatus))
                    .font(.system(size: 17, weight: .bold))
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(s.acwrRatio.map { String(format: "%.1f", $0) } ?? "-")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(.emerald)
                    Text("ACWR").font(.system(size: 10)).foregroundColor(.secondary)
                }
                Text(acwr.text)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(acwrColor(s.acwrStatus))
            }
        }
    }
    
    // MARK: - Card 2: 心率
    
    @ViewBuilder
    func heartRateCard(_ s: GarminUserStatus) -> some View {
        StatusCardView(icon: "heart.fill", iconColor: .pink, title: "心率", borderColor: .pink) {
            VStack(spacing: 6) {
                metricRow("静息心率", "\(s.hrRest ?? 0)", "bpm")
                metricRow("LTHR", "\(s.hrLthr ?? 0)", "")
                metricRow("今日最高", "\(s.hrMaxToday ?? 0)", "")
                metricRow("7日均", "\(s.hr7dAvgRest ?? 0)", "")
            }
        }
    }
    
    // MARK: - Card 3: 身体电量
    
    @ViewBuilder
    func bodyBatteryCard(_ s: GarminUserStatus) -> some View {
        let bbPct = Double(s.bodyBatteryLatest ?? 0) / 100.0
        StatusCardView(icon: "battery.75percent", iconColor: .orange, title: "身体电量", borderColor: .orange) {
            HStack(spacing: 12) {
                // 圆环
                ZStack {
                    Circle().stroke(Color(UIColor.systemGray5), lineWidth: 6)
                    Circle().trim(from: 0, to: bbPct)
                        .stroke(
                            bbPct > 0.5 ? Color.green : bbPct > 0.25 ? Color.orange : Color.red,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.8), value: bbPct)
                    Text("\(s.bodyBatteryLatest ?? 0)")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                }
                .frame(width: 56, height: 56)
                
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("压力").font(.system(size: 12)).foregroundColor(.secondary)
                        Spacer()
                        Text("\(s.stressAvg ?? 0)").font(.system(size: 13, weight: .semibold))
                    }
                    HStack {
                        Text("最高").font(.system(size: 12)).foregroundColor(.secondary)
                        Spacer()
                        Text("\(s.bodyBatteryHigh ?? 0)").font(.system(size: 13, weight: .semibold))
                    }
                    HStack {
                        Text("最低").font(.system(size: 12)).foregroundColor(.secondary)
                        Spacer()
                        Text("\(s.bodyBatteryLow ?? 0)").font(.system(size: 13, weight: .semibold))
                    }
                }
            }
        }
    }
    
    // MARK: - Card 4: 健康
    
    @ViewBuilder
    func healthCard(_ s: GarminUserStatus) -> some View {
        StatusCardView(icon: "wind", iconColor: .blue, title: "健康", borderColor: .blue) {
            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("血氧").font(.system(size: 12)).foregroundColor(.secondary)
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text("\(s.spo2Avg ?? s.spo2Latest ?? 0)")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundColor(.blue)
                        Text("%").font(.system(size: 11)).foregroundColor(.secondary)
                    }
                }
                metricRow("呼吸率", s.respirationAvgWaking.map { String(format: "%.1f", $0) } ?? "-", "")
                metricRow("VO₂Max", s.vo2MaxCycling.map { String(format: "%.0f", $0) } ?? "-",
                          s.fitnessAge.map { "age \($0)" } ?? "")
            }
        }
    }
    
    // MARK: - Card 5: 训练负荷（全宽）
    
    @ViewBuilder
    func trainingLoadCard(_ s: GarminUserStatus) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill").font(.system(size: 13)).foregroundColor(.teal)
                    Text("训练负荷").font(.system(size: 14, weight: .semibold))
                }
                Spacer()
                HStack(spacing: 12) {
                    HStack(spacing: 3) {
                        Text("急性").font(.system(size: 10)).foregroundColor(.secondary)
                        Text(s.acuteLoad.map { String(format: "%.0f", $0) } ?? "-")
                            .font(.system(size: 10, weight: .bold)).foregroundColor(.teal)
                    }
                    HStack(spacing: 3) {
                        Text("慢性").font(.system(size: 10)).foregroundColor(.secondary)
                        Text(s.chronicLoad.map { String(format: "%.0f", $0) } ?? "-")
                            .font(.system(size: 10, weight: .bold)).foregroundColor(.green)
                    }
                }
            }
            
            // 三行进度条
            let loads: [(String, Double, Double, Double, Color)] = [
                ("低强度有氧", s.loadAerobicLow ?? 0, s.loadAerobicLowTargetMin ?? 0, s.loadAerobicLowTargetMax ?? 0, .teal),
                ("高强度有氧", s.loadAerobicHigh ?? 0, s.loadAerobicHighTargetMin ?? 0, s.loadAerobicHighTargetMax ?? 0, Color(red: 0.05, green: 0.58, blue: 0.53)),
                ("无氧", s.loadAnaerobic ?? 0, s.loadAnaerobicTargetMin ?? 0, s.loadAnaerobicTargetMax ?? 0, .orange),
            ]
            
            ForEach(loads, id: \.0) { item in
                let (name, value, tMin, tMax, color) = item
                let maxScale = max(value, tMax) * 1.15
                let valuePct = maxScale > 0 ? min(value / maxScale, 1.0) : 0
                let inRange = value >= tMin && value <= tMax
                
                VStack(spacing: 3) {
                    HStack {
                        HStack(spacing: 4) {
                            Text(name).font(.system(size: 11)).foregroundColor(.secondary)
                            if tMin > 0 {
                                Text("\(Int(tMin))~\(Int(tMax))")
                                    .font(.system(size: 9)).foregroundColor(Color(UIColor.tertiaryLabel))
                            }
                        }
                        Spacer()
                        Text("\(Int(value))")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(inRange ? .green : value < tMin ? .orange : .red)
                    }
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            // Background
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(UIColor.systemGray5))
                            // Value bar
                            RoundedRectangle(cornerRadius: 4)
                                .fill(color)
                                .frame(width: geo.size.width * valuePct)
                                .animation(.easeOut(duration: 0.7), value: valuePct)
                            // Target range markers
                            if tMin > 0 && maxScale > 0 {
                                let tMinPct = tMin / maxScale
                                let tMaxPct = tMax / maxScale
                                Rectangle().fill(Color.gray.opacity(0.15))
                                    .frame(width: geo.size.width * (tMaxPct - tMinPct))
                                    .offset(x: geo.size.width * tMinPct)
                                Rectangle().fill(Color.gray.opacity(0.5))
                                    .frame(width: 1.5).offset(x: geo.size.width * tMinPct)
                                Rectangle().fill(Color.gray.opacity(0.5))
                                    .frame(width: 1.5).offset(x: geo.size.width * tMaxPct)
                            }
                        }
                    }
                    .frame(height: 10)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            
            // 反馈信息
            let feedback = GarminLocalization.trainingLoadFeedback(s.trainingLoadFeedback)
            if !feedback.isEmpty {
                HStack(spacing: 6) {
                    Text("⚠").font(.system(size: 11))
                    Text(feedback).font(.system(size: 11)).foregroundColor(.orange)
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(16)
        .background(.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }
    
    // MARK: - Card 6: 今日活动
    
    @ViewBuilder
    func todayActivityCard(_ s: GarminUserStatus) -> some View {
        StatusCardView(icon: "figure.walk", iconColor: .teal, title: "今日活动", borderColor: .teal) {
            VStack(spacing: 6) {
                metricRow("步数", s.steps.map { formatNumber($0) } ?? "-", "")
                metricRow("活动卡路里", "\(s.caloriesActive ?? 0)", "kcal")
                metricRow("距离", s.distanceM.map { String(format: "%.1f", $0 / 1000) } ?? "-", "km")
                metricRow("强度分钟", "\(s.intensityMinutesWeek ?? 0)", "min")
            }
        }
    }
    
    // MARK: - Card 7: 睡眠
    
    @ViewBuilder
    func sleepCard(_ s: GarminUserStatus) -> some View {
        let scorePct = Double(s.sleepScore ?? 0) / 100.0
        let totalSec = s.sleepSeconds ?? 0
        
        StatusCardView(icon: "moon.zzz.fill", iconColor: .indigo, title: "睡眠", borderColor: .indigo) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    // 评分圆环
                    ZStack {
                        Circle().stroke(Color(UIColor.systemGray5), lineWidth: 4)
                        Circle().trim(from: 0, to: scorePct)
                            .stroke(
                                scorePct > 0.7 ? Color.green : scorePct > 0.4 ? Color.orange : Color.red,
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .animation(.easeOut(duration: 0.8), value: scorePct)
                        Text("\(s.sleepScore ?? 0)")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                    }
                    .frame(width: 40, height: 40)
                    
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 3) {
                            Text("质量").font(.system(size: 11)).foregroundColor(.secondary)
                            Text(GarminLocalization.sleepQuality(s.sleepQuality))
                                .font(.system(size: 12, weight: .semibold))
                        }
                        HStack(spacing: 3) {
                            Text("时长").font(.system(size: 11)).foregroundColor(.secondary)
                            Text(totalSec > 0 ? "\(totalSec / 3600)h\((totalSec % 3600) / 60)m" : "--")
                                .font(.system(size: 12, weight: .semibold))
                        }
                    }
                }
                
                // 阶段条
                if totalSec > 0 {
                    let stages: [(Int, Color, String)] = [
                        (s.sleepDeepSeconds ?? 0, Color(red: 0.26, green: 0.22, blue: 0.79), "深睡"),
                        (s.sleepLightSeconds ?? 0, Color(red: 0.51, green: 0.55, blue: 0.97), "浅睡"),
                        (s.sleepRemSeconds ?? 0, Color(red: 0.75, green: 0.52, blue: 0.99), "REM"),
                        (s.sleepAwakeSeconds ?? 0, Color(UIColor.systemGray4), "清醒"),
                    ]
                    
                    HStack(spacing: 1) {
                        ForEach(stages, id: \.2) { sec, color, _ in
                            let pct = Double(sec) / Double(totalSec)
                            if pct > 0 {
                                RoundedRectangle(cornerRadius: 2).fill(color)
                                    .frame(width: nil).layoutPriority(pct)
                            }
                        }
                    }
                    .frame(height: 8)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    
                    HStack(spacing: 0) {
                        ForEach(stages, id: \.2) { _, color, label in
                            HStack(spacing: 2) {
                                Circle().fill(color).frame(width: 5, height: 5)
                                Text(label).font(.system(size: 8)).foregroundColor(.secondary)
                            }.frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Card 8: HRV（全宽）
    
    @ViewBuilder
    func hrvCard(_ s: GarminUserStatus) -> some View {
        if s.hrvLastNight != nil {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.purple)
                        .frame(width: 26, height: 26)
                        .background(Color.purple.opacity(0.12))
                        .clipShape(Circle())
                    Text("HRV").font(.system(size: 13, weight: .semibold)).foregroundColor(.secondary)
                }
                
                HStack(alignment: .top, spacing: 0) {
                    // 左侧：大数字 + 状态
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text("\(s.hrvLastNight ?? 0)")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundColor(.purple)
                            Text("rMSSD").font(.system(size: 10)).foregroundColor(.secondary)
                        }
                        Text(GarminLocalization.hrvStatus(s.hrvStatus))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(hrvStatusColor(s.hrvStatus))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // 右侧：详细指标行
                    VStack(spacing: 8) {
                        HRVMetricRow(label: "7日均值", value: "\(s.hrvWeeklyAvg ?? 0)")
                        HRVMetricRow(label: "5分峰值", value: "\(s.hrv5minHigh ?? 0)")
                        if let lo = s.hrvBaselineLow, let hi = s.hrvBaselineHigh {
                            HRVMetricRow(label: "基线范围", value: "\(lo) ~ \(hi)")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(16)
            .background(.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        }
    }
    
    // MARK: - AI 分析
    
    var analysisSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.linearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                Text("最近 AI 分析").font(.system(size: 17, weight: .semibold))
            }
            .padding(.horizontal)
            
            ForEach(recentActivities) { act in
                NavigationLink(destination: ActivityDetailView(activityId: act.id)) {
                    VStack(alignment: .leading, spacing: 10) {
                        // 活动标题行
                        HStack(spacing: 10) {
                            Text(sportIcon(act.sport))
                                .font(.system(size: 20))
                                .frame(width: 36, height: 36)
                                .background(sportColor(act.sport).opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(act.activityName ?? "活动")
                                    .font(.system(size: 14, weight: .semibold)).foregroundColor(.primary)
                                    .lineLimit(1)
                                HStack(spacing: 4) {
                                    Text(act.startTimeLocal ?? "").font(.system(size: 11)).foregroundColor(.secondary)
                                    Text("·").foregroundColor(.secondary)
                                    Text(sportLabel(act.sport)).font(.system(size: 11)).foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                        }
                        
                        // 活动指标
                        HStack(spacing: 12) {
                            if let d = act.distance {
                                MiniStat(value: String(format: "%.1f", d / 1000), unit: "km", label: "距离")
                            }
                            if let t = act.duration {
                                let h = Int(t) / 3600; let m = (Int(t) % 3600) / 60
                                MiniStat(value: h > 0 ? "\(h)h\(m)m" : "\(m)m", unit: "", label: "时间")
                            }
                            if let hr = act.avgHeartRate {
                                MiniStat(value: "\(hr)", unit: "bpm", label: "心率")
                            }
                            if let p = act.avgPower {
                                MiniStat(value: "\(p)", unit: "W", label: "功率")
                            }
                        }
                        
                        // AI 摘要
                        if let summaryJson = act.analysisSummary,
                           let data = summaryJson.data(using: .utf8),
                           let summary = try? JSONDecoder().decode(AnalysisSummary.self, from: data) {
                            
                            if let conclusion = summary.conclusion, !conclusion.isEmpty {
                                HStack(alignment: .top, spacing: 6) {
                                    Image(systemName: "sparkle")
                                        .font(.system(size: 10))
                                        .foregroundColor(.orange)
                                        .padding(.top, 2)
                                    Text(conclusion)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                        .lineSpacing(2)
                                }
                            }
                            
                            // 标签
                            let tags = (summary.strengths ?? []).map { ("✓", $0, Color.green) }
                                + (summary.improvements ?? []).map { ("⚠", $0, Color.orange) }
                            if !tags.isEmpty {
                                FlowLayout(spacing: 6) {
                                    ForEach(Array(tags.enumerated()), id: \.offset) { _, tag in
                                        HStack(alignment: .top, spacing: 3) {
                                            Text(tag.0).font(.system(size: 9)).padding(.top, 2)
                                            Text(tag.1)
                                                .font(.system(size: 10, weight: .medium))
                                                .multilineTextAlignment(.leading)
                                                .lineLimit(3)
                                        }
                                        .padding(.horizontal, 8).padding(.vertical, 4)
                                        .background(tag.2.opacity(0.1))
                                        .foregroundColor(tag.2)
                                        .cornerRadius(8)
                                    }
                                }
                            }
                        }
                    }
                    .padding(14)
                    .background(.white)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
                }
            }
            .padding(.horizontal)
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
    
    @ViewBuilder
    func metricRow(_ label: String, _ value: String, _ unit: String) -> some View {
        HStack {
            Text(label).font(.system(size: 12)).foregroundColor(.secondary)
            Spacer()
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value).font(.system(size: 14, weight: .semibold))
                if !unit.isEmpty {
                    Text(unit).font(.system(size: 10)).foregroundColor(.secondary)
                }
            }
        }
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
        // 1. 先从本地缓存加载，立即显示
        await loadFromCache()
        
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
    
    @ViewBuilder
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
        
        if dailyCheckCollapsed {
            // 收缩为一行，点击可展开
            Button(action: { withAnimation { dailyCheckCollapsed = false } }) {
                HStack(spacing: 8) {
                    Text(check.checkType == "morning" ? "🌅" : "🌙")
                    Text(info.text)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(info.color)
                    Spacer()
                    Text("点击查看")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.teal.opacity(0.04))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.teal.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        } else {
            // 展开状态
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(check.checkType == "morning" ? "🌅 晨检建议" : "🌙 晚检建议")
                        .font(.system(size: 14, weight: .bold))
                    Spacer()
                    Text(info.text)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(info.color)
                        .cornerRadius(6)
                }
                
                if let rec = check.recommendation {
                    let lines = rec.split(separator: "\n", omittingEmptySubsequences: false)
                    let body = lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(body.isEmpty ? rec : body)
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                            .lineLimit(dailyCheckExpanded ? nil : 4)
                        
                        Button(action: { withAnimation { dailyCheckExpanded.toggle() } }) {
                            Text(dailyCheckExpanded ? "收起" : "展开全部")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.teal)
                        }
                    }
                }
                
                HStack(spacing: 10) {
                    if let adjustments = check.adjustments, !adjustments.isEmpty {
                        Button(action: { applyDailyCheckAndGoTraining() }) {
                            Text("执行调整")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.purple)
                                .cornerRadius(8)
                        }
                    }
                    Button(action: { respondAndCollapse("accepted") }) {
                        Text("知道了")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.teal)
                            .cornerRadius(8)
                    }
                    Button(action: { respondAndCollapse("ignored") }) {
                        Text("忽略")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(UIColor.systemGray5))
                            .cornerRadius(8)
                    }
                }
            }
            .padding(14)
            .background(Color.teal.opacity(0.06))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.teal.opacity(0.3), lineWidth: 1)
            )
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
    let borderColor: Color
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(iconColor)
                    .frame(width: 24, height: 24)
                    .background(iconColor.opacity(0.12))
                    .clipShape(Circle())
                Text(title).font(.system(size: 12, weight: .medium)).foregroundColor(.secondary)
            }
            content()
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .background(.white)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(UIColor.systemGray5), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }
}

// MARK: - Mini Metric Cell

struct MiniMetricCell: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(10)
    }
}

// MARK: - HRV Metric Row

struct HRVMetricRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
        }
    }
}

// MARK: - Mini Stat

struct MiniStat: View {
    let value: String
    let unit: String
    let label: String
    
    var body: some View {
        VStack(spacing: 2) {
            HStack(alignment: .lastTextBaseline, spacing: 1) {
                Text(value).font(.system(size: 13, weight: .bold, design: .rounded))
                if !unit.isEmpty {
                    Text(unit).font(.system(size: 9)).foregroundColor(.secondary)
                }
            }
            Text(label).font(.system(size: 9)).foregroundColor(.secondary)
        }
    }
}

struct EqualHeightHStack: Layout {
    var spacing: CGFloat = 12
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        let maxHeight = subviews.map { $0.sizeThatFits(.init(width: (width - spacing * CGFloat(subviews.count - 1)) / CGFloat(subviews.count), height: nil)).height }.max() ?? 0
        return CGSize(width: width, height: maxHeight)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let count = CGFloat(subviews.count)
        let childWidth = (bounds.width - spacing * (count - 1)) / count
        var x = bounds.minX
        for subview in subviews {
            subview.place(at: CGPoint(x: x, y: bounds.minY), proposal: .init(width: childWidth, height: bounds.height))
            x += childWidth + spacing
        }
    }
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
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.12))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
}

// MARK: - Simple Badge (used across views)

struct Badge: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(8)
    }
}

// MARK: - Scroll Offset Key

struct ScrollOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
