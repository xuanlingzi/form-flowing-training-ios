import SwiftUI
import Charts

/// 本场负荷与历史对比：读 /api/trends/activity/{id}。
/// history 只含这场之前的数据，所以“新高”判断对历史活动同样成立。
/// 没有指标（老数据未回填、无逐秒记录、404）时整块不显示。
struct ActivityMetricsSection: View {
    let activityId: Int
    @State private var data: ActivityMetricsResponse?

    private struct CurveRow {
        let key: String
        let duration: String
        let current: Double
        let best42: Double?
        let best365: Double?
    }

    private struct MetricTile: Identifiable {
        let label: String
        let value: String
        var valueColor: Color = .primary
        var sub: String? = nil
        var pill: (String, Color)? = nil
        var id: String { label }
    }

    var body: some View {
        // 空数据时放零高度占位：内容为空的 Group 不会触发 .task
        VStack(spacing: 0) {
            if let data {
                content(data)
            } else {
                Color.clear.frame(height: 0)
            }
        }
        .task(id: activityId) {
            let path = "/trends/activity/\(activityId)"
            if data == nil, let cached = await APIService.shared.cached(path, as: ActivityMetricsResponse.self) {
                data = cached
            }
            // 404 = 这场没有指标；其他错误也静默，不影响详情页其余部分
            if let fresh = try? await APIService.shared.getActivityMetrics(id: activityId) {
                data = fresh
            }
        }
    }

    @ViewBuilder
    private func content(_ data: ActivityMetricsResponse) -> some View {
        let m = data.metrics
        let pmc = data.history.pmc
        let priorPower = data.history.powerCurve ?? []
        let prior = Dictionary(priorPower.map { ($0.key, $0) }, uniquingKeysWith: { a, _ in a })
        let curve: [CurveRow] = ActivityMetrics.powerKeys.compactMap { key, label in
            guard let v = m.powerBests[key] else { return nil }
            return CurveRow(key: key, duration: label, current: v,
                            best42: prior[key]?.best42d, best365: prior[key]?.best365d)
        }
        let hasPriorPower = !priorPower.isEmpty
        let yearBests = curve.filter { r in
            if let b = r.best365 { return r.current > b }
            return hasPriorPower
        }
        let yearKeys = Set(yearBests.map(\.key))
        let sixWeekBests = curve.filter { r in
            !yearKeys.contains(r.key) && r.best42 != nil && r.current > r.best42!
        }

        let priorRun = Dictionary((data.history.runBests ?? []).map { ($0.key, $0) }, uniquingKeysWith: { a, _ in a })
        let runs: [(label: String, current: Double, prior: Double?)] = ActivityMetrics.runKeys.compactMap { key, label in
            guard let v = m.runBests[key] else { return nil }
            return (label, v, priorRun[key]?.best365dS)
        }

        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(tiles(m, pmc: pmc)) { t in tileView(t) }
                }

                if !curve.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("功率曲线：本场 vs 此前最好")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        PowerCurveChart(
                            durations: curve.map(\.duration),
                            rows: curve.flatMap { r -> [(String, String, Double)] in
                                var out: [(String, String, Double)] = []
                                if let b = r.best365 { out.append((r.duration, "此前一年最好", b)) }
                                if let b = r.best42 { out.append((r.duration, "此前 42 天最好", b)) }
                                out.append((r.duration, "本场", r.current))
                                return out
                            },
                            styles: [
                                ("此前一年最好", Color.secondary, true),
                                ("此前 42 天最好", Color.orange, false),
                                ("本场", Color.purple, false),
                            ],
                            height: 200
                        )
                        if !yearBests.isEmpty {
                            recordRow("年度新高", .green, yearBests)
                        }
                        if !sixWeekBests.isEmpty {
                            recordRow("近 42 天新高", .blue, sixWeekBests)
                        }
                    }
                }

                if !runs.isEmpty {
                    Grid(alignment: .trailing, horizontalSpacing: 12, verticalSpacing: 6) {
                        GridRow {
                            Text("距离").gridColumnAlignment(.leading)
                            Text("本场最快")
                            Text("此前一年最好")
                        }
                        .foregroundStyle(.secondary)
                        ForEach(runs, id: \.label) { r in
                            Divider()
                            GridRow {
                                Text(r.label)
                                HStack(spacing: 4) {
                                    if let p = r.prior, r.current < p {
                                        PillBadge(text: "年度新高", color: .green)
                                    }
                                    Text(TrendFormat.runTime(r.current))
                                }
                                Text(TrendFormat.runTime(r.prior))
                            }
                            .monospacedDigit()
                        }
                    }
                    .font(.caption)
                }
            }
            .padding(.top, 4)
        } label: {
            TrendCardTitle(
                title: "本场负荷与历史对比", icon: "chart.xyaxis.line", color: .purple,
                info: "负荷：有功率按 TSS 计算，跑步和无功率活动按心率估算。\nIF = NP / FTP；EF = NP（跑步为速度）/ 平均心率，越高越好。\n心率漂移只对 40 分钟以上的稳态训练有意义，低于 5% 说明有氧耐力扎实。\n“出发时状态”和“新高”只与这场之前的记录比较。"
            )
        }
    }

    private func tiles(_ m: ActivityMetrics, pmc: TrendsPMC?) -> [MetricTile] {
        var out: [MetricTile] = []
        let source: String = switch m.loadSource {
        case "power": "按功率 TSS"
        case "hr": "按心率估算"
        default: "缺少阈值"
        }
        out.append(MetricTile(label: "训练负荷", value: m.loadTss.map { "\(Int($0.rounded()))" } ?? "-", sub: source))
        if let ifv = m.intensityFactor {
            var sub: String?
            if let np = m.np, let ftp = m.ftpUsed {
                sub = "NP \(Int(np.rounded()))W / FTP \(Int(ftp.rounded()))W"
            }
            out.append(MetricTile(label: "强度 IF", value: String(format: "%.2f", ifv), sub: sub))
        }
        if let ef = m.ef {
            out.append(MetricTile(label: "有氧效率 EF", value: String(format: "%.2f", ef)))
        }
        if let dec = m.decouplingPct {
            out.append(MetricTile(label: "心率漂移", value: String(format: "%.1f%%", dec),
                                  valueColor: dec > 5 ? .orange : .primary,
                                  sub: dec > 5 ? "后半程掉得多" : "稳定"))
        }
        if let work = m.workKj {
            out.append(MetricTile(label: "做功", value: "\(Int(work.rounded())) kJ"))
        }
        if let tsb = pmc?.tsb {
            let form = TrendFormat.formState(tsb)
            out.append(MetricTile(label: "出发时状态",
                                  value: "\(tsb > 0 ? "+" : "")\(TrendFormat.num(tsb))",
                                  sub: "CTL \(TrendFormat.num(pmc?.ctl)) · ATL \(TrendFormat.num(pmc?.atl))",
                                  pill: (form.label, form.color)))
        }
        return out
    }

    private func tileView(_ t: MetricTile) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(t.label).font(.caption2).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Text(t.value)
                    .font(.headline)
                    .fontDesign(.rounded)
                    .monospacedDigit()
                    .foregroundStyle(t.valueColor)
                if let pill = t.pill {
                    PillBadge(text: pill.0, color: pill.1)
                }
            }
            if let sub = t.sub {
                Text(sub).font(.caption2).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
    }

    private func recordRow(_ title: String, _ color: Color, _ rows: [CurveRow]) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            PillBadge(text: title, color: color)
            Text(rows.map { "\($0.duration) \(Int($0.current.rounded()))W" }.joined(separator: "　"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
