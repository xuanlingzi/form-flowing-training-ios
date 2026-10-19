import SwiftUI
import Charts

// MARK: - 通用解读（趋势页、活动详情共用，口径与 Web 端 lib/trends.ts 一致）

enum TrendFormat {
    /// TSB 区间解读（Coggan / TrainingPeaks 常用划分）
    static func formState(_ tsb: Double) -> (label: String, color: Color, hint: String) {
        if tsb < -30 { return ("过度疲劳", .red, "疲劳累积过深，建议安排恢复") }
        if tsb < -10 { return ("有效训练", .green, "正在积累体能，注意睡眠和恢复") }
        if tsb < 5 { return ("维持", .gray, "负荷与体能持平，训练刺激有限") }
        if tsb < 25 { return ("新鲜", .blue, "状态好，适合比赛或测试") }
        return ("训练不足", .orange, "休息偏多，体能在流失")
    }

    /// 秒 → m:ss 或 h:mm:ss
    static func runTime(_ sec: Double?) -> String {
        guard let sec, sec > 0 else { return "-" }
        let s = Int(sec.rounded())
        let h = s / 3600, m = (s % 3600) / 60, r = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, r) : String(format: "%d:%02d", m, r)
    }

    /// 数值显示：整数不带小数，否则保留 1 位
    static func num(_ v: Double?, digits: Int = 1) -> String {
        guard let v else { return "-" }
        if v == v.rounded() { return String(format: "%.0f", v) }
        return String(format: "%.\(digits)f", v)
    }

    static func pctChange(_ cur: Double?, _ prev: Double?) -> Double? {
        guard let cur, let prev, cur != 0, prev != 0 else { return nil }
        return ((cur - prev) / prev * 1000).rounded() / 10
    }

    static let dayParser: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static let zoneColors: [Color] = [
        Color(red: 0.23, green: 0.51, blue: 0.96),
        Color(red: 0.13, green: 0.77, blue: 0.37),
        Color(red: 0.92, green: 0.70, blue: 0.03),
        Color(red: 0.98, green: 0.45, blue: 0.09),
        Color(red: 0.94, green: 0.27, blue: 0.27),
    ]
}

/// 涨跌幅小标签：正绿负红
struct DeltaText: View {
    let value: Double?
    var unit = "%"

    var body: some View {
        if let value, value != 0 {
            Text("\(value > 0 ? "+" : "")\(TrendFormat.num(value))\(unit)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(value > 0 ? .green : .red)
        }
    }
}

// MARK: - 训练趋势页

/// 跨活动训练趋势：体能/疲劳/状态（PMC）、每周训练量、功率曲线、有氧效率、
/// 抗疲劳和跑步成绩。数据来自 /api/trends。
struct TrendsView: View {
    @State private var data: TrendsResponse?
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if loading && data == nil {
                    ProgressView("加载中...")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                } else if let data {
                    if (data.activityCount365d ?? 0) == 0 {
                        ContentUnavailableView(
                            "暂无可分析的活动",
                            systemImage: "chart.line.uptrend.xyaxis",
                            description: Text("趋势基于每场活动的逐秒数据计算。同步或上传带心率、功率的活动后，这里会显示体能变化、功率曲线等跨活动分析。")
                        )
                        .padding(.top, 40)
                    } else {
                        content(data)
                    }
                } else {
                    ContentUnavailableView {
                        Label("加载失败", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error ?? "训练趋势加载失败，请稍后重试")
                    } actions: {
                        Button("重试") { Task { await loadData() } }
                    }
                    .padding(.top, 40)
                }
            }
            .padding()
            .backgroundStyle(Color(.secondarySystemGroupedBackground))
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("训练趋势")
        .navigationBarTitleDisplayMode(.inline)
        .hideTabBar()
        .refreshable { await loadData() }
        .task { await loadData() }
    }

    @ViewBuilder
    private func content(_ data: TrendsResponse) -> some View {
        statsGrid(data)
        if let series = data.pmc?.series, !series.isEmpty {
            PMCCard(series: series)
        }
        if let weekly = data.weekly, weekly.contains(where: { ($0.count ?? 0) > 0 }) {
            WeeklyCard(weekly: weekly)
        }
        if let curve = data.powerCurve, !curve.isEmpty {
            PowerCurveCard(curve: curve)
        }
        AerobicCard(data: data)
        RunCard(data: data)

        Text("统计近一年 \(data.activityCount365d ?? 0) 场有逐秒数据的活动，截至 \(String((data.asOf ?? "").prefix(16)))。数据每 10 分钟刷新。")
            .font(.caption2)
            .foregroundStyle(.secondary)
    }

    // MARK: 顶部指标

    private func statsGrid(_ data: TrendsResponse) -> some View {
        let pmc = data.pmc
        let ctlDelta: Double? = {
            guard let c = pmc?.ctl, let p = pmc?.ctl28dAgo else { return nil }
            return ((c - p) * 10).rounded() / 10
        }()
        let ramp = pmc?.ctlRampPerWeek
        let form = pmc?.tsb.map(TrendFormat.formState)
        let eftp = data.eftp90d
        let ftp = data.ftpSetting
        let eftpGap = TrendFormat.pctChange(eftp, ftp)
        let eftpHint: String? = {
            guard let g = eftpGap else { return nil }
            if g >= 3 { return "高于设置的 FTP，可以考虑重新测试" }
            if g <= -10 { return "近期缺少长时间高强度骑行，可能低估" }
            return nil
        }()

        return Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                StatusCardView(icon: "chart.line.uptrend.xyaxis", iconColor: .blue, title: "体能 CTL") {
                    VStack(alignment: .leading, spacing: 4) {
                        bigValue(TrendFormat.num(pmc?.ctl), color: .blue)
                        HStack(spacing: 4) {
                            Text("4 周前 \(TrendFormat.num(pmc?.ctl28dAgo))")
                            DeltaText(value: ctlDelta, unit: "")
                        }
                        .font(.caption).foregroundStyle(.secondary)
                        if let ramp, ramp > 8 {
                            PillBadge(text: "增长过快", color: .orange)
                        }
                    }
                }
                StatusCardView(icon: "flame.fill", iconColor: .pink, title: "疲劳 ATL") {
                    VStack(alignment: .leading, spacing: 4) {
                        bigValue(TrendFormat.num(pmc?.atl), color: .pink)
                        if let ramp {
                            Text("CTL 周增长 \(TrendFormat.num(ramp))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            GridRow {
                StatusCardView(icon: "gauge.with.needle", iconColor: .green, title: "状态 TSB") {
                    VStack(alignment: .leading, spacing: 4) {
                        bigValue(TrendFormat.num(pmc?.tsb), color: .green)
                        if let form {
                            PillBadge(text: form.label, color: form.color)
                            Text(form.hint)
                                .font(.caption2).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                StatusCardView(icon: "bolt.fill", iconColor: .purple, title: "eFTP（近 90 天）") {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .lastTextBaseline, spacing: 2) {
                            bigValue(TrendFormat.num(eftp, digits: 0), color: .purple)
                            if eftp != nil { Text("W").font(.caption2).foregroundStyle(.secondary) }
                        }
                        if let ftp {
                            HStack(spacing: 4) {
                                Text("设置 FTP \(TrendFormat.num(ftp, digits: 0))W")
                                DeltaText(value: eftpGap)
                            }
                            .font(.caption).foregroundStyle(.secondary)
                        }
                        if let eftpHint {
                            Text(eftpHint)
                                .font(.caption2).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    private func bigValue(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.title.weight(.bold))
            .fontDesign(.rounded)
            .foregroundStyle(color)
    }

    // MARK: 加载

    private func loadData() async {
        if data == nil, let cached = await APIService.shared.cached("/trends", as: TrendsResponse.self) {
            data = cached
            loading = false
        }
        do {
            let fresh = try await APIService.shared.getTrends()
            withAnimation { data = fresh }
            error = nil
        } catch {
            if data == nil { self.error = error.localizedDescription }
        }
        loading = false
    }
}

// MARK: - 卡片标题

struct TrendCardTitle: View {
    let title: String
    let icon: String
    let color: Color
    var info: String? = nil
    @State private var showInfo = false

    var body: some View {
        HStack(spacing: 6) {
            Label {
                Text(title)
            } icon: {
                Image(systemName: icon).foregroundStyle(color)
            }
            if let info {
                Button { showInfo.toggle() } label: {
                    Image(systemName: "info.circle").font(.caption).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showInfo) {
                    Text(info)
                        .font(.footnote)
                        .padding()
                        .frame(idealWidth: 300)
                        .fixedSize(horizontal: false, vertical: true)
                        .presentationCompactAdaptation(.popover)
                }
            }
        }
    }
}

// MARK: - PMC

private struct PMCCard: View {
    let series: [PMCPoint]
    @State private var range = 90

    private struct Row: Identifiable {
        let id = UUID()
        let date: Date
        let name: String
        let value: Double
    }

    var body: some View {
        let points = series.suffix(range).compactMap { p -> (Date, PMCPoint)? in
            guard let d = TrendFormat.dayParser.date(from: p.date) else { return nil }
            return (d, p)
        }
        let lines: [Row] = points.flatMap { d, p -> [Row] in
            var r: [Row] = []
            if let v = p.ctl { r.append(Row(date: d, name: "CTL 体能", value: v)) }
            if let v = p.atl { r.append(Row(date: d, name: "ATL 疲劳", value: v)) }
            return r
        }

        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Picker("范围", selection: $range) {
                    Text("6 周").tag(42)
                    Text("3 个月").tag(90)
                    Text("6 个月").tag(180)
                }
                .pickerStyle(.segmented)

                Chart {
                    ForEach(points, id: \.1.date) { d, p in
                        if let tsb = p.tsb {
                            AreaMark(x: .value("日期", d, unit: .day), y: .value("值", tsb))
                                .foregroundStyle(Color.green.opacity(0.18))
                            LineMark(x: .value("日期", d, unit: .day), y: .value("值", tsb),
                                     series: .value("指标", "TSB 状态"))
                                .foregroundStyle(by: .value("指标", "TSB 状态"))
                                .lineStyle(StrokeStyle(lineWidth: 1.2))
                        }
                    }
                    ForEach(lines) { r in
                        LineMark(x: .value("日期", r.date, unit: .day), y: .value("值", r.value),
                                 series: .value("指标", r.name))
                            .foregroundStyle(by: .value("指标", r.name))
                            .lineStyle(StrokeStyle(lineWidth: r.name.hasPrefix("CTL") ? 2 : 1.5))
                    }
                    RuleMark(y: .value("零", 0))
                        .foregroundStyle(Color.secondary.opacity(0.3))
                }
                .chartForegroundStyleScale([
                    "CTL 体能": Color.blue,
                    "ATL 疲劳": Color.pink,
                    "TSB 状态": Color.green,
                ])
                .chartLegend(position: .bottom)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) {
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.defaultDigits).day())
                    }
                }
                .frame(height: 220)

                Text("当日负荷").font(.caption).foregroundStyle(.secondary)
                Chart {
                    ForEach(points, id: \.1.date) { d, p in
                        BarMark(x: .value("日期", d, unit: .day), y: .value("TSS", p.tss ?? 0))
                            .foregroundStyle(Color.secondary.opacity(0.5))
                    }
                }
                .chartXAxis(.hidden)
                .frame(height: 60)
            }
        } label: {
            TrendCardTitle(
                title: "体能 / 疲劳 / 状态", icon: "chart.line.uptrend.xyaxis", color: .blue,
                info: "CTL 体能：近 42 天负荷的指数加权平均，代表长期训练积累。\nATL 疲劳：近 7 天的指数加权平均。\nTSB 状态 = 前一天的 CTL - ATL，即当天出发时的新鲜度。\n柱子是每天的训练负荷（有功率按 TSS，没有按心率估算）。"
            )
        }
    }
}

// MARK: - 每周训练量

private struct WeeklyCard: View {
    let weekly: [TrendsWeek]
    @State private var basis: String

    init(weekly: [TrendsWeek]) {
        self.weekly = weekly
        _basis = State(initialValue: Self.hasPower(weekly) ? "power" : "hr")
    }

    private static func hasPower(_ weekly: [TrendsWeek]) -> Bool {
        weekly.contains { ($0.powerZonesS ?? []).contains { $0 > 0 } }
    }

    private struct Seg: Identifiable {
        let id = UUID()
        let week: String
        let zone: String
        let hours: Double
    }

    private static let zoneNames = ["Z1", "Z2", "Z3", "Z4", "Z5", "未分区"]

    /// "2026-10-13" → "10/13"
    private static func weekLabel(_ weekStart: String) -> String {
        let parts = weekStart.split(separator: "-").compactMap { Int($0) }
        return parts.count == 3 ? "\(parts[1])/\(parts[2])" : weekStart
    }

    /// 周数多时隔一个显示横轴标签，避免挤成省略号
    private var axisWeeks: [String] {
        let labels = weekly.map { Self.weekLabel($0.weekStart) }
        guard labels.count > 6 else { return labels }
        return labels.enumerated().filter { ($0.offset - labels.count + 1) % 2 == 0 }.map(\.element)
    }

    private var segments: [Seg] {
        weekly.flatMap { w -> [Seg] in
            let label = Self.weekLabel(w.weekStart)
            let zones = (basis == "power" ? w.powerZonesS : w.hrZonesS) ?? []
            let zoneHours = zones.prefix(5).map { ($0 / 3600 * 10).rounded() / 10 }
            var segs = zoneHours.enumerated().map { Seg(week: label, zone: "Z\($0.offset + 1)", hours: $0.element) }
            // 没有对应传感器数据的时长单独一段，保证柱高等于总时长
            let other = max(0, (((w.hours ?? 0) - zoneHours.reduce(0, +)) * 10).rounded() / 10)
            segs.append(Seg(week: label, zone: "未分区", hours: other))
            return segs
        }
    }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                if Self.hasPower(weekly) {
                    Picker("区间", selection: $basis) {
                        Text("功率区间").tag("power")
                        Text("心率区间").tag("hr")
                    }
                    .pickerStyle(.segmented)
                }

                Chart(segments) { s in
                    BarMark(x: .value("周", s.week), y: .value("小时", s.hours))
                        .foregroundStyle(by: .value("区间", s.zone))
                }
                .chartForegroundStyleScale(domain: Self.zoneNames,
                                           range: TrendFormat.zoneColors + [Color.secondary.opacity(0.35)])
                .chartXAxis {
                    AxisMarks(values: axisWeeks) { _ in
                        AxisValueLabel()
                    }
                }
                .chartYAxis {
                    AxisMarks { v in
                        AxisGridLine()
                        AxisValueLabel { if let h = v.as(Double.self) { Text("\(TrendFormat.num(h))h") } }
                    }
                }
                .chartLegend(position: .bottom)
                .frame(height: 200)

                Text("每周训练负荷（TSS）").font(.caption).foregroundStyle(.secondary)
                Chart(weekly) { w in
                    LineMark(x: .value("周", Self.weekLabel(w.weekStart)), y: .value("TSS", w.tss ?? 0))
                        .foregroundStyle(Color.primary.opacity(0.7))
                        .symbol(.circle)
                        .symbolSize(16)
                }
                .chartXAxis(.hidden)
                .frame(height: 70)
            }
        } label: {
            TrendCardTitle(
                title: "每周训练量", icon: "timer", color: .teal,
                info: "柱高是每周训练时长，按区间着色；灰色是没有对应功率或心率数据的时长。\n下方折线是每周训练负荷（TSS）。"
            )
        }
    }
}

// MARK: - 功率曲线

private struct PowerCurveCard: View {
    let curve: [PowerCurvePoint]

    private struct Row: Identifiable {
        let id = UUID()
        let duration: String
        let name: String
        let watts: Double
    }

    var body: some View {
        let rows = curve.flatMap { c -> [Row] in
            [("近 1 年", c.best365d), ("前 42 天", c.bestPrev42d), ("近 42 天", c.best42d)]
                .compactMap { name, v in v.map { Row(duration: c.duration, name: name, watts: $0) } }
        }
        let prs = curve.filter { c in
            guard let b42 = c.best42d else { return false }
            return b42 >= (c.best365d ?? 0)
        }

        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                PowerCurveChart(
                    durations: curve.map(\.duration),
                    rows: rows.map { ($0.duration, $0.name, $0.watts) },
                    styles: [
                        ("近 1 年", Color.secondary, true),
                        ("前 42 天", Color.orange, false),
                        ("近 42 天", Color.purple, false),
                    ]
                )
                if !prs.isEmpty {
                    Text("近 42 天刷新年度最好").font(.caption).foregroundStyle(.secondary)
                    FlowPills(items: prs.map { "\($0.duration) \(TrendFormat.num($0.best42d, digits: 0))W" }, color: .green)
                }
            }
        } label: {
            TrendCardTitle(
                title: "功率曲线（骑行）", icon: "bolt.fill", color: .purple,
                info: "各时长的最大平均功率。对比近 42 天、再往前 42 天和近一年的最好成绩，可以看出短时爆发和长时耐力分别在变好还是变差。"
            )
        }
    }
}

/// 功率曲线图（对数纵轴，横轴为时长标签）；趋势页与活动详情共用
struct PowerCurveChart: View {
    let durations: [String]
    /// (时长, 系列名, 瓦数)
    let rows: [(String, String, Double)]
    /// (系列名, 颜色, 是否虚线)，顺序即图例顺序
    let styles: [(String, Color, Bool)]
    var height: CGFloat = 220

    private static let ticks: [Double] = [100, 150, 200, 300, 400, 600, 800, 1000, 1500, 2000]

    var body: some View {
        let indexed = rows.enumerated().map { (i: $0.offset, d: $0.element.0, s: $0.element.1, w: $0.element.2) }
        let dashed = Set(styles.filter(\.2).map(\.0))
        let lo = (rows.map(\.2).min() ?? 100) * 0.9
        let hi = (rows.map(\.2).max() ?? 1000) * 1.1

        Chart(indexed, id: \.i) { r in
            LineMark(x: .value("时长", r.d), y: .value("功率", r.w), series: .value("系列", r.s))
                .foregroundStyle(by: .value("系列", r.s))
                .lineStyle(StrokeStyle(lineWidth: dashed.contains(r.s) ? 1.2 : 2,
                                       dash: dashed.contains(r.s) ? [4, 3] : []))
            if !dashed.contains(r.s) {
                PointMark(x: .value("时长", r.d), y: .value("功率", r.w))
                    .foregroundStyle(by: .value("系列", r.s))
                    .symbolSize(18)
            }
        }
        .chartForegroundStyleScale(domain: styles.map(\.0), range: styles.map(\.1))
        .chartXScale(domain: durations)
        .chartYScale(domain: max(lo, 1)...hi, type: .log)
        .chartYAxis {
            // 对数轴自动刻度太稀，给一组常用瓦数
            AxisMarks(values: Self.ticks.filter { $0 >= lo && $0 <= hi }) { v in
                AxisGridLine()
                AxisValueLabel { if let w = v.as(Double.self) { Text("\(Int(w))W") } }
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel().font(.system(size: 9))
            }
        }
        .chartLegend(position: .bottom)
        .frame(height: height)
    }
}

/// 自动换行的胶囊标签
struct FlowPills: View {
    let items: [String]
    let color: Color

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), alignment: .leading)], alignment: .leading, spacing: 6) {
            ForEach(items, id: \.self) { PillBadge(text: $0, color: color) }
        }
    }
}

// MARK: - 有氧效率与抗疲劳

private struct PeriodTable: View {
    let periods: [AerobicPeriod]
    var showDecoupling = false

    var body: some View {
        Grid(alignment: .trailing, horizontalSpacing: 12, verticalSpacing: 6) {
            GridRow {
                Text("时间段").gridColumnAlignment(.leading)
                Text("场次")
                Text("EF 中位数")
                if showDecoupling { Text("心率漂移") }
            }
            .foregroundStyle(.secondary)
            ForEach(periods) { p in
                Divider()
                GridRow {
                    Text(p.label)
                    Text("\(p.sessions ?? 0)").monospacedDigit()
                    Text(p.efMedian.map { TrendFormat.num($0, digits: 2) } ?? "-").monospacedDigit()
                    if showDecoupling {
                        Text(p.decouplingMedian.map { "\(TrendFormat.num($0))%" } ?? "-")
                            .monospacedDigit()
                            .foregroundStyle((p.decouplingMedian ?? 0) > 5 ? .orange : .primary)
                    }
                }
            }
        }
        .font(.caption)
    }
}

private struct AerobicCard: View {
    let data: TrendsResponse

    var body: some View {
        let periods = data.aerobic?.periods ?? []
        let hasAerobic = periods.contains { ($0.sessions ?? 0) > 0 }
        let fresh = data.fatigue?.freshP5m90d
        let fatigueRows: [(String, FatigueBest)] = [
            ("累计做功 1000kJ 后", data.fatigue?.p5mAfter1000kj),
            ("累计做功 2000kJ 后", data.fatigue?.p5mAfter2000kj),
        ].compactMap { label, v in
            guard let v, v.best90d != nil else { return nil }
            return (label, v)
        }

        if hasAerobic || !fatigueRows.isEmpty {
            GroupBox {
                VStack(alignment: .leading, spacing: 14) {
                    if hasAerobic {
                        PeriodTable(periods: periods, showDecoupling: true)
                    }
                    if !fatigueRows.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("近 90 天最佳 5 分钟功率").font(.caption).foregroundStyle(.secondary)
                            if let fresh {
                                LabeledContent("精力充沛时") {
                                    Text("\(TrendFormat.num(fresh, digits: 0)) W").fontWeight(.semibold)
                                }
                            }
                            ForEach(fatigueRows, id: \.0) { label, v in
                                LabeledContent(label) {
                                    HStack(spacing: 4) {
                                        Text("\(TrendFormat.num(v.best90d, digits: 0)) W").fontWeight(.semibold)
                                        if let fresh, fresh > 0, let b = v.best90d {
                                            Text("· \(Int((b / fresh * 100).rounded()))%")
                                                .foregroundStyle(.secondary)
                                        }
                                        DeltaText(value: TrendFormat.pctChange(v.best90d, v.bestPrev90d))
                                    }
                                }
                            }
                        }
                        .font(.caption)
                        .monospacedDigit()
                    }
                }
            } label: {
                TrendCardTitle(
                    title: "有氧效率与抗疲劳（骑行）", icon: "heart.fill", color: .green,
                    info: "只统计 60 分钟以上、强度不高（IF < 0.85）的稳态骑行。\nEF = NP / 平均心率，同样心率下功率越高越好。\n心率漂移是后半程相对前半程的功率心率比下降，低于 5% 说明有氧耐力扎实。\n抗疲劳：骑到一定做功量之后还能输出的最好 5 分钟功率。"
                )
            }
        }
    }
}

// MARK: - 跑步

private struct RunCard: View {
    let data: TrendsResponse

    var body: some View {
        let bests = data.runBests ?? []
        let runEf = data.runEf ?? []
        let hasEf = runEf.contains { ($0.sessions ?? 0) > 0 }

        if !bests.isEmpty || hasEf {
            GroupBox {
                VStack(alignment: .leading, spacing: 14) {
                    if !bests.isEmpty {
                        Grid(alignment: .trailing, horizontalSpacing: 12, verticalSpacing: 6) {
                            GridRow {
                                Text("距离").gridColumnAlignment(.leading)
                                Text("近 90 天")
                                Text("近 1 年")
                            }
                            .foregroundStyle(.secondary)
                            ForEach(bests) { b in
                                Divider()
                                GridRow {
                                    Text(b.distance)
                                    HStack(spacing: 4) {
                                        if let b90 = b.best90dS, let b365 = b.best365dS, b90 <= b365 {
                                            PillBadge(text: "年度最好", color: .green)
                                        }
                                        Text(TrendFormat.runTime(b.best90dS))
                                    }
                                    Text(TrendFormat.runTime(b.best365dS))
                                }
                                .monospacedDigit()
                            }
                        }
                        .font(.caption)
                    }
                    if hasEf {
                        PeriodTable(periods: runEf)
                    }
                }
            } label: {
                TrendCardTitle(
                    title: "跑步", icon: "figure.run", color: .orange,
                    info: "最佳成绩取活动中任意连续路段完成该距离的最短用时。\n跑步 EF = 平均速度（米/分）/ 平均心率，只统计 40 分钟以上的跑步。"
                )
            }
        }
    }
}
