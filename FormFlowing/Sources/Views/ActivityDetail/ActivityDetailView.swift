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
    // Chat
    @State private var chatMessages: [(role: String, content: String, adjustments: [PlanAdjustment]?)] = []
    @State private var chatInput = ""
    @State private var chatLoading = false
    @State private var chatError: String?
    @State private var pendingAdjustments: [PlanAdjustment]?
    @State private var applyingAdjustments = false
    @State private var adjustmentSuccess: String?
    
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
            ScrollView {
                if loading {
                    ProgressView("加载活动数据...")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 120)
                } else if let act = activity {
                    VStack(spacing: 16) {
                        // GPS 轨迹地图
                        if hasGPSData {
                            mapSection
                        }
                        
                        // 顶部 hero card
                        heroCard(act)
                        
                        // 详细指标
                        metricsGrid(act)
                        
                        // 图表
                        if !records.isEmpty {
                            chartsSection
                        }
                        
                        // 分圈
                        if laps.count > 1 {
                            lapsSection
                        }
                        
                        // AI 分析
                        if let analysis = analysis {
                            aiSection(analysis)
                        }
                        
                        // 触发分析按钮
                        analyzeButton
                    }
                    .padding()
                    .frame(width: geometry.size.width)
                    .backgroundStyle(Color(.secondarySystemGroupedBackground))
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(activity?.activityName ?? "活动详情")
        .navigationBarTitleDisplayMode(.inline)
        .hideTabBar()
        .task {
            await loadData()
        }
    }
    
    // MARK: - Hero Card
    
    func heroCard(_ act: ActivitySummary) -> some View {
        let metrics = buildHeroMetrics(act)
        return GroupBox {
            HStack(spacing: 0) {
                ForEach(metrics) { m in
                    StatPill(value: m.value, unit: m.unit, label: m.label)
                }
            }
            .padding(.top, 4)
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(act.activityName ?? "活动")
                    Text("\(act.startTimeLocal ?? "") · \(sportConfig.label)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Text(sportConfig.icon)
            }
        }
    }
    
    // MARK: - Metrics Grid
    
    @ViewBuilder
    func metricsGrid(_ act: ActivitySummary) -> some View {
        let items = buildMetricItems(act)
        
        if !items.isEmpty {
            GroupBox("详细数据") {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ForEach(items, id: \.label) { item in
                        StatPill(value: item.value, unit: item.unit.isEmpty ? nil : item.unit, label: item.label)
                    }
                }
                .padding(.top, 4)
            }
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
        GroupBox {
            VStack(spacing: 0) {
                ForEach(Array(laps.enumerated()), id: \.offset) { idx, lap in
                    LabeledContent {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(lapPrimaryText(lap))
                            Text(lapPowerText(lap))
                        }
                        .font(.caption)
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(formatDuration(lap.totalTimerTime))
                                    .font(.subheadline.weight(.semibold))
                                    .monospacedDigit()
                                if let d = lap.totalDistance {
                                    Text(String(format: "%.2f km", d / 1000))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } icon: {
                            Image(systemName: idx < 50 ? "\(idx + 1).circle.fill" : "circle.fill")
                                .foregroundStyle(sportConfig.color)
                        }
                    }
                    .padding(.vertical, 8)
                    if idx < laps.count - 1 { Divider() }
                }
            }
        } label: {
            LabeledContent {
                Text("\(laps.count) 圈").font(.caption)
            } label: {
                Label("分圈数据", systemImage: "flag.checkered")
            }
        }
    }
    
    private func lapPrimaryText(_ lap: LapData) -> String {
        var parts: [String] = []
        if let spd = lap.avgSpeed { parts.append(String(format: "%.1f km/h", spd * 3.6)) }
        if let cad = lap.avgCadence { parts.append("\(cad) rpm") }
        if let hr = lap.avgHeartRate { parts.append("\(hr) bpm") }
        return parts.joined(separator: " · ")
    }
    
    private func lapPowerText(_ lap: LapData) -> String {
        var parts: [String] = []
        if let ap = lap.avgPower { parts.append("AP \(ap) W") }
        if let np = lap.normalizedPower { parts.append("NP \(np) W") }
        return parts.joined(separator: " · ")
    }
    
    // MARK: - AI Section
    
    func aiSection(_ analysis: AnalysisResult) -> some View {
        let isPro = analysis.tier != nil && analysis.tier != "fast"
        let modelStr = analysis.modelUsed
            .flatMap { modelUsed in
                guard !modelUsed.isEmpty else { return nil }
                return " · " + (modelUsed.components(separatedBy: "/").last ?? modelUsed)
            } ?? ""
        let badgeText = (isPro ? "深度" : "快速") + modelStr
        
        return GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                MarkdownTextView(markdown: analysis.resultMd ?? "", baseFontSize: 13)
                
                // MARK: - 追问区域
                if analysis.canChat == true {
                    Divider()
                    
                    Label("继续追问", systemImage: "bubble.left.and.bubble.right")
                        .font(.subheadline.weight(.semibold))
                    
                    AnalysisChatView(
                        messages: chatMessages,
                        pendingAdjustments: pendingAdjustments,
                        applyingAdjustments: applyingAdjustments,
                        adjustmentSuccess: adjustmentSuccess,
                        chatError: chatError,
                        chatInput: $chatInput,
                        chatLoading: chatLoading,
                        onSend: { doSendChat(analysisId: analysis.analysisResultId) },
                        onApply: { doApplyAdjustments() }
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
        } label: {
            LabeledContent {
                Text(badgeText)
                    .font(.caption)
                    .foregroundStyle(isPro ? .purple : .secondary)
            } label: {
                Label("AI 训练分析", systemImage: "sparkles")
            }
        }
    }
    
    // MARK: - Analyze Button
    
    private var hasProAnalysis: Bool {
        guard let t = analysis?.tier else { return false }
        return t != "fast"
    }
    
    private var hasFastOnly: Bool {
        analysis != nil && analysis?.tier == "fast"
    }
    
    var analyzeButton: some View {
        let isReanalyze = hasProAnalysis
        let isDeep = hasFastOnly
        let label = analyzing ? "AI 分析中..." : isReanalyze ? "重新分析" : isDeep ? "深度分析" : "启动 AI 分析"
        
        return Button {
            if isReanalyze {
                showReanalyzeSheet = true
            } else if isDeep {
                showDeepConfirm = true
            } else {
                doTriggerAnalysis()
            }
        } label: {
            HStack(spacing: 8) {
                if analyzing {
                    ProgressView()
                } else {
                    Image(systemName: isReanalyze ? "arrow.clockwise" : isDeep ? "sparkle.magnifyingglass" : "sparkles")
                }
                Text(label)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
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
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
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
            GroupBox {
                Map {
                    MapPolyline(coordinates: coords)
                        .stroke(sportConfig.color, lineWidth: 3)
                    
                    // 起点
                    if let first = coords.first {
                        Marker("起点", systemImage: "flag.fill", coordinate: first)
                            .tint(.green)
                    }
                    // 终点
                    if let last = coords.last {
                        Marker("终点", systemImage: "flag.checkered", coordinate: last)
                            .tint(.red)
                    }
                }
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } label: {
                Label("GPS 轨迹", systemImage: "map.fill")
            }
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
    
    var chartsSection: some View {
        GroupBox {
            VStack(spacing: 8) {
                ForEach(chartConfigs, id: \.key) { config in
                    let hasData = records.contains { recordValue(for: config.key, in: $0) != nil }
                    if hasData {
                        chartCard(config: config)
                    }
                }
            }
            .padding(.top, 4)
        } label: {
            Label("数据图表", systemImage: "chart.xyaxis.line")
        }
    }
    
    func chartCard(config: (key: String, label: String, unit: String, color: Color)) -> some View {
        let isExpanded = Binding(
            get: { expandedCharts.contains(config.key) },
            set: { newValue in
                if newValue {
                    expandedCharts.insert(config.key)
                } else {
                    expandedCharts.remove(config.key)
                }
            }
        )
        let values = records.enumerated().compactMap { (idx, r) -> ChartDataPoint? in
            guard let v = recordValue(for: config.key, in: r) else { return nil }
            return ChartDataPoint(index: idx, value: v)
        }
        let avg = values.isEmpty ? 0 : values.map(\.value).reduce(0, +) / Double(values.count)
        let maxV = values.map(\.value).max() ?? 0
        
        return DisclosureGroup(isExpanded: isExpanded) {
            if !values.isEmpty {
                Chart(values) { point in
                    AreaMark(
                        x: .value("Index", point.index),
                        y: .value(config.label, point.value)
                    )
                    .foregroundStyle(config.color.opacity(0.2))
                    
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
                        }
                    }
                }
                .frame(height: 120)
                .padding(.vertical, 4)
            }
        } label: {
            LabeledContent {
                Text("均 \(formatChartValue(avg, config.key)) · 峰 \(formatChartValue(maxV, config.key))")
                    .font(.caption)
            } label: {
                Text("\(config.label) (\(config.unit))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(config.color)
            }
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
                let firstResult = res.records.first
                await MainActor.run { withAnimation { analysis = firstResult } }
                
                // 加载追问对话历史
                if let ar = firstResult, ar.canChat == true {
                    if let hist = try? await APIService.shared.getChatHistory(analysisResultId: ar.analysisResultId) {
                        let msgs: [(role: String, content: String, adjustments: [PlanAdjustment]?)] = hist.messages.map { m in
                            (role: m.role, content: m.content, adjustments: m.adjustments)
                        }
                        if !msgs.isEmpty {
                            await MainActor.run { chatMessages = msgs }
                        }
                    }
                }
            }
        }()
        
        async let statusFetch: Void = {
            if let status = try? await APIService.shared.getAnalysisStatus(activityId: activityId),
               status.analyzing {
                await MainActor.run {
                    analyzing = true
                    pollAnalysisResult()
                }
            }
        }()
        
        // 等待所有并发任务完成（各自内部已独立更新 UI）
        _ = await (detailFetch, lapsFetch, recordsFetch, analysisFetch, statusFetch)
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
                pollAnalysisResult()
            } catch {
                await MainActor.run { analyzing = false }
            }
        }
    }
    
    private func pollAnalysisResult() {
        Task {
            var checks = 0
            while checks < 60 {
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3s
                
                // 检查是否还在分析
                if let status = try? await APIService.shared.getAnalysisStatus(activityId: activityId),
                   !status.analyzing {
                    // 分析完成，获取结果
                    if let res = try? await APIService.shared.getAnalysisByActivity(activityId: activityId) {
                        await MainActor.run {
                            withAnimation { analysis = res.records.first }
                            analyzing = false
                        }
                    } else {
                        await MainActor.run { analyzing = false }
                    }
                    return
                }
                checks += 1
            }
            // 超时
            await MainActor.run { analyzing = false }
        }
    }
    
    private func doSendChat(analysisId: Int) {
        let message = chatInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty, !chatLoading else { return }
        
        chatMessages.append((role: "user", content: message, adjustments: nil))
        chatInput = ""
        chatLoading = true
        chatError = nil
        
        Task {
            do {
                let res = try await APIService.shared.analysisChat(
                    analysisResultId: analysisId,
                    message: message
                )
                await MainActor.run {
                    chatMessages.append((
                        role: "assistant",
                        content: res.reply,
                        adjustments: res.adjustments
                    ))
                    pendingAdjustments = res.adjustments
                    chatLoading = false
                }
            } catch {
                await MainActor.run {
                    chatError = error.localizedDescription
                    chatLoading = false
                }
            }
        }
    }
    
    private func doApplyAdjustments() {
        guard let pending = pendingAdjustments, !pending.isEmpty,
              let analysisId = analysis?.analysisResultId else { return }
        
        applyingAdjustments = true
        adjustmentSuccess = nil
        
        // Convert PlanAdjustment to [[String: Any]] for API
        let adjustmentDicts: [[String: Any]] = pending.map { adj in
            var dict: [String: Any] = ["action": adj.action]
            if let wid = adj.workoutId { dict["workout_id"] = wid }
            if let swid = adj.swapWithWorkoutId { dict["swap_with_workout_id"] = swid }
            if let reason = adj.reason { dict["reason"] = reason }
            return dict
        }
        
        Task {
            do {
                let result = try await APIService.shared.applyAnalysisAdjustments(
                    analysisResultId: analysisId,
                    adjustments: adjustmentDicts
                )
                await MainActor.run {
                    applyingAdjustments = false
                    pendingAdjustments = nil
                    adjustmentSuccess = result.message ?? "已成功应用 \(result.applied) 项调整"
                }
            } catch {
                await MainActor.run {
                    applyingAdjustments = false
                    chatError = error.localizedDescription
                }
            }
        }
    }
    
    private func adjustmentActionLabel(_ action: String) -> String {
        switch action {
        case "modify": return "📝 修改"
        case "skip": return "⏭️ 跳过"
        case "reduce": return "⬇️ 降强度"
        case "swap": return "🔄 交换"
        default: return action
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

    let onSubmit: (String?) -> Void

    private var trimmedPrompt: String {
        prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(
                        "补充要求",
                        text: Binding(
                            get: { prompt },
                            set: { prompt = String($0.prefix(300)) }
                        ),
                        prompt: Text("例如：请重点分析间歇训练后半程的功率衰减、心率漂移和配速稳定性。"),
                        axis: .vertical
                    )
                    .lineLimit(5...12)
                } header: {
                    Text("补充要求")
                } footer: {
                    Text("使用 Pro 模型重新分析本次训练。你可以补充关注点，结果会更聚焦。（\(prompt.count)/300）")
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("重新分析")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("开始分析") {
                        dismiss()
                        onSubmit(trimmedPrompt.isEmpty ? nil : trimmedPrompt)
                    }
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

struct ChartDataPoint: Identifiable {
    let index: Int
    let value: Double
    var id: Int { index }
}

// MARK: - Analysis Chat View (extracted to avoid type-checker timeout)

struct AnalysisChatView: View {
    let messages: [(role: String, content: String, adjustments: [PlanAdjustment]?)]
    let pendingAdjustments: [PlanAdjustment]?
    let applyingAdjustments: Bool
    let adjustmentSuccess: String?
    let chatError: String?
    @Binding var chatInput: String
    let chatLoading: Bool
    let onSend: () -> Void
    let onApply: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 消息列表
            ForEach(Array(messages.enumerated()), id: \.offset) { _, msg in
                ChatBubbleView(
                    role: msg.role,
                    content: msg.content,
                    adjustments: msg.adjustments
                )
            }
            
            // 待应用调整
            if let pending = pendingAdjustments, !pending.isEmpty {
                LabeledContent("共 \(pending.count) 项调整待确认") {
                    Button(applyingAdjustments ? "应用中..." : "确认应用", action: onApply)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .tint(.green)
                        .disabled(applyingAdjustments)
                }
                .font(.footnote)
            }
            
            // 调整成功提示
            if let successMsg = adjustmentSuccess {
                Label(successMsg, systemImage: "checkmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(.green)
            }
            
            // 错误提示
            if let err = chatError {
                Label(err, systemImage: "exclamationmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
            
            // 输入区
            chatInputBar
        }
    }
    
    private var chatInputBar: some View {
        let isEmpty = chatInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return HStack(alignment: .bottom, spacing: 8) {
            TextField("针对这次训练继续提问", text: $chatInput, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
                .disabled(chatLoading)
            
            Button(action: onSend) {
                if chatLoading {
                    ProgressView()
                } else {
                    Image(systemName: "paperplane.fill")
                }
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("发送")
            .disabled(isEmpty || chatLoading)
        }
    }
}

// MARK: - Chat Bubble

private struct ChatBubbleView: View {
    let role: String
    let content: String
    let adjustments: [PlanAdjustment]?
    
    var body: some View {
        HStack {
            if role == "user" { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 6) {
                if role == "assistant" {
                    MarkdownTextView(markdown: content, baseFontSize: 12)
                } else {
                    Text(content).font(.footnote)
                }
                if let adjustments, !adjustments.isEmpty {
                    AdjustmentPreviewView(adjustments: adjustments)
                }
            }
            .padding(10)
            .background(
                role == "user" ? AnyShapeStyle(.tint.opacity(0.15)) : AnyShapeStyle(.fill.tertiary),
                in: RoundedRectangle(cornerRadius: 12)
            )
            if role == "assistant" { Spacer(minLength: 20) }
        }
    }
}

// MARK: - Adjustment Preview

private struct AdjustmentPreviewView: View {
    let adjustments: [PlanAdjustment]
    
    private func actionLabel(_ action: String) -> String {
        switch action {
        case "modify": return "修改"
        case "skip": return "跳过"
        case "reduce": return "降强度"
        case "swap": return "交换"
        default: return action
        }
    }
    
    private func actionIcon(_ action: String) -> String {
        switch action {
        case "modify": return "pencil"
        case "skip": return "forward.end"
        case "reduce": return "arrow.down"
        case "swap": return "arrow.left.arrow.right"
        default: return "bolt"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("AI 建议的计划调整", systemImage: "bolt.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(.orange)
            ForEach(Array(adjustments.enumerated()), id: \.offset) { _, adj in
                Label {
                    Text(adjustmentText(adj))
                        .lineLimit(2)
                } icon: {
                    Image(systemName: actionIcon(adj.action))
                }
                .font(.caption)
            }
        }
    }
    
    private func adjustmentText(_ adj: PlanAdjustment) -> String {
        var text = actionLabel(adj.action)
        if let wid = adj.workoutId { text += " #\(wid)" }
        if let reason = adj.reason { text += " — \(reason)" }
        return text
    }
}
