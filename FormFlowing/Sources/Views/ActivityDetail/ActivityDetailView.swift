import SwiftUI
import Charts
import MapKit

struct ActivityDetailView: View {
    let activityId: Int
    @State private var activity: ActivitySummary?
    @State private var laps: [LapData] = []
    @State private var records: [RecordData] = []
    @State private var analysis: AnalysisResult?
    @State private var loading = true
    @State private var analyzing = false
    @State private var appear = false
    @State private var expandedCharts: Set<String> = ["heartRate", "power"]
    @State private var showReanalyzeSheet = false
    @State private var showDeepConfirm = false
    
    var sportConfig: (icon: String, color: Color, label: String) {
        switch activity?.sport {
        case "cycling": return ("🚴", .teal, "骑行")
        case "running": return ("🏃", .orange, "跑步")
        case "swimming": return ("🏊", .blue, "游泳")
        default: return ("🏃", .gray, activity?.sport ?? "活动")
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical, showsIndicators: false) {
                if loading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("加载活动数据...").font(.caption).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity).padding(.top, 120)
                } else if let act = activity {
                    VStack(spacing: 16) {
                        // GPS 轨迹地图
                        if hasGPSData {
                            mapSection
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                        
                        // 顶部 hero card
                        heroCard(act)
                        
                        // 详细指标
                        metricsGrid(act)
                        
                        // 图表
                        if !records.isEmpty {
                            chartsSection
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                        
                        // 分圈
                        if laps.count > 1 {
                            lapsSection
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                        
                        // AI 分析
                        if let analysis = analysis {
                            aiSection(analysis)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                        
                        // 触发分析按钮
                        analyzeButton
                    }
                    .padding(20)
                    .frame(width: geometry.size.width)
                    .clipped()
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 15)
                    .animation(.easeOut(duration: 0.5), value: appear)
                    .animation(.easeInOut(duration: 0.35), value: records.count)
                    .animation(.easeInOut(duration: 0.35), value: laps.count)
                    .animation(.easeInOut(duration: 0.35), value: analysis?.id)
                }
            }
        }
        .background(
            LinearGradient(colors: [sportConfig.color.opacity(0.06), Color(UIColor.systemGroupedBackground)], startPoint: .top, endPoint: .center)
        )
        .navigationTitle(activity?.activityName ?? "活动详情")
        .navigationBarTitleDisplayMode(.inline)
        .hideTabBar()
        .task {
            await loadData()
        }
    }
    
    // MARK: - Hero Card
    
    @ViewBuilder
    func heroCard(_ act: ActivitySummary) -> some View {
        VStack(spacing: 20) {
            HStack(spacing: 14) {
                Text(sportConfig.icon).font(.system(size: 36))
                    .frame(width: 56, height: 56)
                    .background(sportConfig.color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 3) {
                    Text(act.activityName ?? "活动").font(.system(size: 18, weight: .bold))
                    Text("\(act.startTimeLocal ?? "") · \(sportConfig.label)")
                        .font(.system(size: 12)).foregroundColor(.secondary)
                }
                Spacer()
            }
            
            // Hero stats - 使用 Grid 避免溢出
            let metrics = buildHeroMetrics(act)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: min(metrics.count, 4)), spacing: 8) {
                ForEach(metrics, id: \.label) { m in
                    HeroMetric(value: m.value, unit: m.unit, label: m.label, color: m.color)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(.white)
                .shadow(color: sportConfig.color.opacity(0.08), radius: 16, y: 6)
        )
    }
    
    // MARK: - Metrics Grid
    
    @ViewBuilder
    func metricsGrid(_ act: ActivitySummary) -> some View {
        let items = buildMetricItems(act)
        
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text("详细数据").font(.system(size: 16, weight: .semibold))
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(items, id: \.label) { item in
                        VStack(spacing: 4) {
                            HStack(alignment: .lastTextBaseline, spacing: 2) {
                                Text(item.value).font(.system(size: 17, weight: .bold, design: .rounded))
                                Text(item.unit).font(.system(size: 10)).foregroundColor(.secondary)
                            }
                            Text(item.label).font(.system(size: 10, weight: .medium)).foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(12)
                    }
                }
            }
            .padding(18)
            .background(.white)
            .cornerRadius(20)
        }
    }
    
    private func buildMetricItems(_ act: ActivitySummary) -> [MetricDisplayItem] {
        var items: [MetricDisplayItem] = []
        if let v = act.maxSpeed { items.append(MetricDisplayItem(label: "最大速度", value: String(format: "%.1f", v * 3.6), unit: "km/h")) }
        if let v = act.maxHeartRate { items.append(MetricDisplayItem(label: "最大心率", value: "\(v)", unit: "bpm")) }
        if let v = act.avgCadence { items.append(MetricDisplayItem(label: "均踏频", value: "\(v)", unit: "rpm")) }
        if let v = act.avgPower { items.append(MetricDisplayItem(label: "均功率", value: "\(v)", unit: "W")) }
        if let v = act.normalizedPower { items.append(MetricDisplayItem(label: "标准化功率", value: "\(v)", unit: "W")) }
        if let v = act.totalAscent { items.append(MetricDisplayItem(label: "总爬升", value: "\(v)", unit: "m")) }
        if let v = act.totalCalories { items.append(MetricDisplayItem(label: "热量", value: "\(v)", unit: "kcal")) }
        if let v = act.trainingStressScore { items.append(MetricDisplayItem(label: "TSS", value: String(format: "%.0f", v), unit: "")) }
        return items
    }
    
    private func buildHeroMetrics(_ act: ActivitySummary) -> [HeroMetricItem] {
        var items: [HeroMetricItem] = []
        items.append(HeroMetricItem(value: act.totalDistance.map { String(format: "%.1f", $0 / 1000) } ?? "--", unit: "km", label: "距离", color: sportConfig.color))
        items.append(HeroMetricItem(value: formatDuration(act.totalTimerTime ?? act.totalElapsedTime), unit: nil, label: "时间", color: sportConfig.color))
        if let spd = act.avgSpeed {
            items.append(HeroMetricItem(value: String(format: "%.1f", spd * 3.6), unit: "km/h", label: "均速", color: sportConfig.color))
        }
        if let hr = act.avgHeartRate {
            items.append(HeroMetricItem(value: "\(hr)", unit: "bpm", label: "均心率", color: .red))
        }
        return items
    }
    
    // MARK: - Laps Section
    
    var lapsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "flag.checkered").foregroundColor(.orange)
                Text("分圈数据").font(.system(size: 16, weight: .semibold))
                Spacer()
                Text("\(laps.count) 圈").font(.caption).foregroundColor(.secondary)
            }
            
            ForEach(Array(laps.enumerated()), id: \.offset) { idx, lap in
                HStack(spacing: 12) {
                    Text("\(idx + 1)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 22, height: 22)
                        .background(sportConfig.color.opacity(0.8))
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(formatDuration(lap.totalTimerTime))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                        if let d = lap.totalDistance {
                            Text(String(format: "%.2f km", d / 1000))
                                .font(.system(size: 11)).foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer(minLength: 4)
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 8) {
                            if let spd = lap.avgSpeed {
                                HStack(spacing: 2) {
                                    Image(systemName: "speedometer").font(.system(size: 9)).foregroundColor(.cyan)
                                    Text(String(format: "%.1f km/h", spd * 3.6)).font(.system(size: 11, weight: .medium))
                                }
                            }
                            if let cad = lap.avgCadence {
                                HStack(spacing: 2) {
                                    Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 9)).foregroundColor(.blue)
                                    Text("\(cad) rpm").font(.system(size: 11, weight: .medium))
                                }
                            }
                            if let hr = lap.avgHeartRate {
                                HStack(spacing: 2) {
                                    Image(systemName: "heart.fill").font(.system(size: 9)).foregroundColor(.red)
                                    Text("\(hr) bpm").font(.system(size: 11, weight: .medium))
                                }
                            }
                        }
                        
                        HStack(spacing: 12) {
                            if let ap = lap.avgPower {
                                HStack(spacing: 2) {
                                    Text("AP").font(.system(size: 9, weight: .bold)).foregroundColor(.yellow)
                                    Text("\(ap) W").font(.system(size: 11, weight: .medium))
                                }
                            }
                            if let np = lap.normalizedPower {
                                HStack(spacing: 2) {
                                    Text("NP").font(.system(size: 9, weight: .bold)).foregroundColor(.purple)
                                    Text("\(np) W").font(.system(size: 11, weight: .medium))
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
                if idx < laps.count - 1 { Divider() }
            }
        }
        .padding(18)
        .background(.white)
        .cornerRadius(20)
    }
    
    // MARK: - AI Section
    
    @ViewBuilder
    func aiSection(_ analysis: AnalysisResult) -> some View {
        let isPro = analysis.tier == "pro"
        let modelStr = analysis.modelUsed
            .flatMap { modelUsed in
                guard !modelUsed.isEmpty else { return nil }
                return " · " + (modelUsed.components(separatedBy: "/").last ?? modelUsed)
            } ?? ""
        let badgeText = (isPro ? "🔬 深度" : "⚡️ 快速") + modelStr
        
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.linearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                Text("AI 训练分析").font(.system(size: 16, weight: .semibold))
                Spacer()
                Text(badgeText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isPro ? .purple : .secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(isPro ? Color.purple.opacity(0.12) : Color.gray.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(isPro ? Color.purple.opacity(0.25) : Color.gray.opacity(0.2), lineWidth: 1)
                    )
            }
            
            MarkdownTextView(markdown: analysis.resultMd ?? "", baseFontSize: 13)
        }
        .padding(18)
        .background(.white)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(colors: [.purple.opacity(0.2), .pink.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
        )
    }
    
    // MARK: - Analyze Button
    
    private var hasProAnalysis: Bool {
        analysis?.tier == "pro"
    }
    
    private var hasFastOnly: Bool {
        analysis != nil && analysis?.tier == "fast"
    }
    
    var analyzeButton: some View {
        let isReanalyze = hasProAnalysis
        let isDeep = hasFastOnly
        let label = analyzing ? "AI 分析中..." : isReanalyze ? "🔄 重新分析" : isDeep ? "🔬 深度分析" : "启动 AI 分析"
        let colors: [Color] = analyzing ? [.gray]
            : isReanalyze ? [.blue, .indigo]
            : isDeep ? [.red, .orange]
            : [Color(red: 0.05, green: 0.58, blue: 0.53), .green]
        let shadowColor: Color = isReanalyze ? .blue : isDeep ? .red : .teal
        
        return Button(action: {
            if isReanalyze {
                showReanalyzeSheet = true
            } else if isDeep {
                showDeepConfirm = true
            } else {
                doTriggerAnalysis()
            }
        }) {
            HStack(spacing: 10) {
                if analyzing {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: isReanalyze ? "arrow.clockwise" : "sparkles")
                }
                Text(label)
                    .font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
            )
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: shadowColor.opacity(analyzing ? 0 : 0.3), radius: 8, y: 4)
        }
        .disabled(analyzing)
        .alert("深度分析", isPresented: $showDeepConfirm) {
            Button("取消", role: .cancel) {}
            Button("开始") { doTriggerAnalysis() }
        } message: {
            Text("深度分析使用更高级的 AI 模型，分析速度较慢，请耐心等候。\n\n确定要开始深度分析吗？")
        }
        .sheet(isPresented: $showReanalyzeSheet) {
            ReanalyzeSheet {
                showReanalyzeSheet = false
                doTriggerAnalysis(extraPrompt: $0)
            }
            .presentationDetents([.fraction(0.72), .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
        }
    }
    
    // MARK: - GPS Map
    
    private var hasGPSData: Bool {
        records.contains { $0.latitude != nil && $0.longitude != nil }
    }
    
    private var gpsCoordinates: [CLLocationCoordinate2D] {
        records.compactMap { r in
            guard let lat = r.latitude, let lon = r.longitude, lat != 0, lon != 0 else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }
    
    @ViewBuilder
    var mapSection: some View {
        let coords = gpsCoordinates
        if coords.count > 1 {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "map.fill")
                        .foregroundColor(sportConfig.color)
                    Text("GPS 轨迹")
                        .font(.system(size: 15, weight: .semibold))
                }
                
                Map {
                    MapPolyline(coordinates: coords)
                        .stroke(sportConfig.color, lineWidth: 3)
                    
                    // 起点
                    if let first = coords.first {
                        Annotation("起点", coordinate: first) {
                            Circle()
                                .fill(.green)
                                .frame(width: 12, height: 12)
                                .overlay(Circle().stroke(.white, lineWidth: 2))
                        }
                    }
                    // 终点
                    if let last = coords.last {
                        Annotation("终点", coordinate: last) {
                            Circle()
                                .fill(.red)
                                .frame(width: 12, height: 12)
                                .overlay(Circle().stroke(.white, lineWidth: 2))
                        }
                    }
                }
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(16)
            .background(.white)
            .cornerRadius(20)
        }
    }
    
    // MARK: - Charts Section
    
    private var chartConfigs: [(key: String, label: String, unit: String, color: Color)] {
        [
            ("power", "功率", "W", .purple),
            ("heartRate", "心率", "bpm", .red),
            ("speed", "速度", "km/h", .orange),
            ("cadence", "踏频", "rpm", .blue),
            ("altitude", "海拔", "m", .green),
            ("temperature", "温度", "°C", .pink),
        ]
    }
    
    @ViewBuilder
    var chartsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "chart.xyaxis.line")
                    .foregroundColor(.indigo)
                Text("数据图表")
                    .font(.system(size: 15, weight: .semibold))
            }
            
            ForEach(chartConfigs, id: \.key) { config in
                let hasData = records.contains { recordValue(for: config.key, in: $0) != nil }
                if hasData {
                    chartCard(config: config)
                }
            }
        }
        .padding(16)
        .background(.white)
        .cornerRadius(20)
    }
    
    @ViewBuilder
    func chartCard(config: (key: String, label: String, unit: String, color: Color)) -> some View {
        let isExpanded = expandedCharts.contains(config.key)
        let values = records.enumerated().compactMap { (idx, r) -> ChartDataPoint? in
            guard let v = recordValue(for: config.key, in: r) else { return nil }
            return ChartDataPoint(index: idx, value: v)
        }
        let avg = values.isEmpty ? 0 : values.map(\.value).reduce(0, +) / Double(values.count)
        let maxV = values.map(\.value).max() ?? 0
        
        VStack(spacing: 0) {
            // Header - tap to toggle
            Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    if expandedCharts.contains(config.key) {
                        expandedCharts.remove(config.key)
                    } else {
                        expandedCharts.insert(config.key)
                    }
                }
            }) {
                HStack {
                    Circle().fill(config.color).frame(width: 8, height: 8)
                    Text(config.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(config.color)
                    Text("(\(config.unit))")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("均 \(formatChartValue(avg, config.key))").font(.system(size: 11)).foregroundColor(.secondary)
                    Text("峰 \(formatChartValue(maxV, config.key))").font(.system(size: 11)).foregroundColor(.secondary)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            
            // Chart
            if isExpanded && !values.isEmpty {
                Chart(values) { point in
                    AreaMark(
                        x: .value("Index", point.index),
                        y: .value(config.label, point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(colors: [config.color.opacity(0.3), config.color.opacity(0.05)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    
                    LineMark(
                        x: .value("Index", point.index),
                        y: .value(config.label, point.value)
                    )
                    .foregroundStyle(config.color)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            Text("\(value.as(Double.self).map { formatChartValue($0, config.key) } ?? "")")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(height: 120)
                .padding(.bottom, 4)
            }
        }
        
        if config.key != chartConfigs.last?.key {
            Divider()
        }
    }
    
    private func recordValue(for key: String, in record: RecordData) -> Double? {
        switch key {
        case "power": return record.power.map(Double.init)
        case "heartRate": return record.heartRate.map(Double.init)
        case "speed": return record.speed.map { $0 * 3.6 }
        case "cadence": return record.cadence.map(Double.init)
        case "altitude": return record.altitude
        case "temperature": return record.temperature
        default: return nil
        }
    }
    
    private func formatChartValue(_ value: Double, _ key: String) -> String {
        switch key {
        case "speed": return String(format: "%.1f", value)
        case "altitude": return String(format: "%.0f", value)
        case "temperature": return String(format: "%.1f", value)
        default: return "\(Int(value))"
        }
    }
    
    // MARK: - Data
    
    private func loadData() async {
        // 1. 先从本地缓存加载，立即显示
        await loadFromCache()
        
        // 2. 后台请求，拿到最新数据后自动写入缓存并刷新 UI
        async let detailFetch: Void = {
            do {
                let detail = try await APIService.shared.getActivityDetail(id: activityId)
                await MainActor.run {
                    activity = detail
                    loading = false
                    withAnimation { appear = true }
                }
            } catch {
                await MainActor.run { 
                    if activity == nil { loading = false }
                }
            }
        }()
        
        async let lapsFetch: Void = {
            if let data = try? await APIService.shared.getActivityLaps(id: activityId) {
                await MainActor.run { withAnimation { laps = data } }
            }
        }()
        
        async let recordsFetch: Void = {
            if let data = try? await APIService.shared.getActivityRecords(id: activityId) {
                await MainActor.run { withAnimation { records = data } }
            }
        }()
        
        async let analysisFetch: Void = {
            if let res = try? await APIService.shared.getAnalysisByActivity(activityId: activityId) {
                await MainActor.run { withAnimation { analysis = res.records.first } }
            }
        }()
        
        // 等待所有并发任务完成（各自内部已独立更新 UI）
        _ = await (detailFetch, lapsFetch, recordsFetch, analysisFetch)
    }
    
    private func loadFromCache() async {
        if let cached = await APIService.shared.cached("/activity/\(activityId)", as: ActivitySummary.self) {
            await MainActor.run {
                activity = cached
                loading = false
                withAnimation { appear = true }
            }
        }
        if let cached = await APIService.shared.cached("/activity/\(activityId)/laps", as: [LapData].self) {
            await MainActor.run { laps = cached }
        }
        if let cached = await APIService.shared.cached("/activity/\(activityId)/records", as: [RecordData].self) {
            await MainActor.run { records = cached }
        }
        if let cached = await APIService.shared.cached("/analysis/activity/\(activityId)", as: AnalysisByActivityResponse.self) {
            await MainActor.run { analysis = cached.records.first }
        }
    }
    
    private func doTriggerAnalysis(extraPrompt: String? = nil) {
        analyzing = true
        Task {
            do {
                try await APIService.shared.triggerAnalysis(activityId: activityId, extraPrompt: extraPrompt)
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                let res = try? await APIService.shared.getAnalysisByActivity(activityId: activityId)
                await MainActor.run { analysis = res?.records.first; analyzing = false }
            } catch {
                await MainActor.run { analyzing = false }
            }
        }
    }
    
    private func formatDuration(_ seconds: Double?) -> String {
        guard let s = seconds else { return "--" }
        let h = Int(s) / 3600; let m = (Int(s) % 3600) / 60; let sec = Int(s) % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%02d:%02d", m, sec)
    }
}

private struct ReanalyzeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var prompt = ""
    @FocusState private var isEditorFocused: Bool

    let onSubmit: (String?) -> Void

    private var trimmedPrompt: String {
        prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Image(systemName: "waveform.and.magnifyingglass")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 34, height: 34)
                                .background(
                                    LinearGradient(
                                        colors: [.blue, .indigo],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                            Text("重新分析")
                                .font(.title3.weight(.bold))
                                .foregroundColor(.primary)
                        }

                        Text("使用 Pro 模型重新分析本次训练。你可以补充关注点，结果会更聚焦。")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("补充要求")
                                .font(.headline)
                            Spacer()
                            Text("\(prompt.count)/300")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color(UIColor.secondarySystemGroupedBackground))

                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.blue.opacity(isEditorFocused ? 0.25 : 0.1), lineWidth: 1)

                            TextEditor(text: Binding(
                                get: { prompt },
                                set: { prompt = String($0.prefix(300)) }
                            ))
                            .focused($isEditorFocused)
                            .scrollContentBackground(.hidden)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .frame(minHeight: 180)
                            .background(Color.clear)

                            if prompt.isEmpty {
                                Text("例如：请重点分析间歇训练后半程的功率衰减、心率漂移和配速稳定性。")
                                    .font(.subheadline)
                                    .foregroundColor(Color(UIColor.placeholderText))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 18)
                                    .allowsHitTesting(false)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                    Button(action: {
                        dismiss()
                        onSubmit(trimmedPrompt.isEmpty ? nil : trimmedPrompt)
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                            Text("开始分析")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [.blue, .indigo],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(UIColor.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Hero Metric

struct HeroMetricItem: Identifiable {
    let value: String
    let unit: String?
    let label: String
    let color: Color
    var id: String { label }
}

struct HeroMetric: View {
    let value: String
    var unit: String? = nil
    let label: String
    var color: Color = .primary
    
    var body: some View {
        VStack(spacing: 5) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value).font(.system(size: 20, weight: .bold, design: .rounded))
                if let unit = unit {
                    Text(unit).font(.system(size: 10, weight: .medium)).foregroundColor(.secondary)
                }
            }
            Text(label).font(.system(size: 10, weight: .medium)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct DetailRow: View {
    let label: String; let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundColor(.secondary)
            Text(value).font(.subheadline.weight(.semibold))
        }
    }
}

struct ChartDataPoint: Identifiable {
    let index: Int
    let value: Double
    var id: Int { index }
}
