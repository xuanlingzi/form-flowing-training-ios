import SwiftUI

// MARK: - Constants

private let sportConfig: [String: (icon: String, color: Color, label: String)] = [
    "cycling": ("🚴", .teal, "骑行"),
    "running": ("🏃", .orange, "跑步"),
    "swimming": ("🏊", .blue, "游泳"),
    "rest": ("😴", .gray, "休息"),
    "strength": ("🏋️", .purple, "力量"),
]

private let trainingGoals: [(key: String, icon: String, label: String, desc: String)] = [
    ("ftp_improvement", "⚡", "提升 FTP", "Sweet Spot + 阈值训练为核心"),
    ("aerobic_endurance", "💚", "有氧耐力", "Z2 基础建设，提升有氧引擎"),
    ("vo2max_development", "🔴", "VO₂max 提升", "高强度间歇，突破有氧天花板"),
    ("sprint_power", "💥", "冲刺能力", "无氧 + 神经肌肉爆发训练"),
    ("triathlon", "🏆", "铁三训练", "游骑跑综合能力均衡发展"),
    ("general_fitness", "🎯", "综合提升", "均衡发展各项能力"),
]

private let sportOptions: [(key: String, icon: String, label: String)] = [
    ("cycling", "🚴", "骑行"),
    ("running", "🏃", "跑步"),
    ("swimming", "🏊", "游泳"),
    ("strength", "🏋️", "力量"),
]

private let tssPresets: [(key: String, label: String, tss: String, desc: String, hours: String)] = [
    ("light", "轻量", "200-300", "入门/恢复期", "4-6h"),
    ("moderate", "中等", "300-450", "稳步提升", "6-8h"),
    ("heavy", "高量", "450-600", "进阶冲刺", "8-12h"),
    ("race", "赛季", "600+", "赛前备战", "12h+"),
]

private let weekdayKeys: [(key: Int, label: String, full: String)] = [
    (1, "一", "周一"), (2, "二", "周二"), (3, "三", "周三"),
    (4, "四", "周四"), (5, "五", "周五"), (6, "六", "周六"), (7, "日", "周日"),
]

/// 将 goal_kind key 转换为用户可读的中文标签
private func goalKindLabel(_ key: String?) -> String {
    guard let key else { return "未设置" }
    if let match = trainingGoals.first(where: { $0.key == key }) {
        return "\(match.icon) \(match.label)"
    }
    return key
}

/// 将计划 description（可能是原始 JSON 字典）格式化为可读文本
private func formatPlanDescription(_ plan: TrainingPlan) -> String? {
    // 如果是目标驱动计划，生成结构化描述
    if plan.mode == "goal_driven" {
        var lines: [String] = []
        lines.append("🎯 目标驱动滚动计划")
        if let goalKind = plan.goalKind {
            let label = trainingGoals.first(where: { $0.key == goalKind })?.label ?? goalKind
            lines.append("训练目标：\(label)")
        }
        if let targetDate = plan.targetDate {
            lines.append("目标日期：\(targetDate)")
        }
        if let microCycle = plan.microCycleDays {
            lines.append("微周期：\(microCycle) 天")
        }
        return lines.joined(separator: "\n")
    }
    
    guard let desc = plan.description else { return nil }
    
    // 如果 description 看起来是原始字典格式（包含 key: value 模式），尝试格式化
    if desc.contains("current_ftp:") || desc.contains("target_ftp:") ||
       desc.contains("sports:") || desc.contains("train_days:") {
        // 原始格式，尝试提取关键信息
        var lines: [String] = []
        if let goalKind = plan.goalKind ?? extractValue(from: desc, key: "目标") {
            let label = trainingGoals.first(where: { $0.key == goalKind })?.label ?? goalKind
            lines.append("训练目标：\(label)")
        }
        // 提取 FTP 信息
        if let currentFtp = extractValue(from: desc, key: "current_ftp") {
            lines.append("当前 FTP：\(currentFtp)W")
        }
        if let targetFtp = extractValue(from: desc, key: "target_ftp") {
            lines.append("目标 FTP：\(targetFtp)W")
        }
        if !lines.isEmpty {
            return lines.joined(separator: "\n")
        }
    }
    
    return desc
}

private func extractValue(from text: String, key: String) -> String? {
    let pattern = "\(key):\\s*([^;\\]]+)"
    guard let range = text.range(of: pattern, options: .regularExpression) else { return nil }
    let match = String(text[range])
    let value = match.split(separator: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
    return value.isEmpty ? nil : value
}

struct GeneratePlanForm {
    var goal = "ftp_improvement"
    var sports: Set<String> = ["cycling"]
    var multiSportDay = false
    var trainDays: Set<Int> = [2, 3, 4, 5, 6, 7]
    var lsdDays: Set<Int> = [7]
    var tssLevel = "moderate"
    var weeks = 4.0
    var startDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    var goalDetail: [String: String] = [:]
    var extraRequirements = ""
    // Goal-driven mode
    var mode: String = "fixed"  // "fixed" | "goal_driven"
    var targetDate: Date? = nil
    var microCycleDays: Int = 7
}

// MARK: - Main View

struct TrainingView: View {
    @State private var plans: [TrainingPlan] = []
    @State private var selectedPlan: TrainingPlan?
    @State private var workouts: [Workout] = []
    @State private var workoutsByPlan: [Int: [Workout]] = [:]
    @State private var workoutPlanMetaByWorkoutId: [Int: (title: String, intro: String?)] = [:]
    @State private var loading = true
    /// 最近一次从服务端成功加载的时间，用于切回 tab 时跳过重复请求
    @State private var lastLoadedAt: Date?
    private static let reloadInterval: TimeInterval = 60
    @State private var currentMonth = Date()
    @State private var selectedDate: String?
    @State private var showDeleteAlert = false
    @State private var planToDelete: TrainingPlan?
    @State private var planToRegenerate: TrainingPlan?
    @State private var showPlanDetailsSheet = false
    @State private var showCalendarSheet = false
    @State private var showPlanRegenerateSheet = false
    @State private var swipeDirection: TransitionDirection = .forward
    
    enum TransitionDirection {
        case forward, backward
    }
    
    // 调整排期
    @State private var adjustingSchedule = false
    @State private var workoutToCancel: Workout?
    @State private var workoutToPostpone: Workout?
    @State private var workoutToMove: Workout?
    @State private var moveTargetDate = Date()
    
    // AI 生成
    @State private var showGenSheet = false
    @State private var genForm = GeneratePlanForm()
    @State private var generating = false
    @State private var pollingTask: Task<Void, Never>?
    
    // 目标驱动计划
    @State private var showProgressSheet = false
    @State private var progressData: PlanProgressResponse?
    @State private var loadingProgress = false
    @State private var showExtendAlert = false
    @State private var showReviewAlert = false
    @State private var planBlocks: [Int: [TrainingPlanBlock]] = [:]
    
    // 每日训练建议
    @State private var dailyCheck: DailyCheckItem? = nil
    @State private var dailyCheckExpanded = false
    
    private let calendar = Calendar.current
    
    var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: currentMonth)
    }
    
    var selectedDateTitle: String {
        guard let dateStr = selectedDate, let date = dateFromString(dateStr) else {
            return monthTitle
        }

        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: date)
        let dayOffset = calendar.dateComponents([.day], from: today, to: target).day ?? 0

        let shortFormatter = DateFormatter()
        shortFormatter.locale = Locale(identifier: "zh_CN")
        shortFormatter.dateFormat = "M月d日"

        switch dayOffset {
        case -1:
            return "昨天 · \(shortFormatter.string(from: date))"
        case 0:
            return "今天 · \(shortFormatter.string(from: date))"
        case 1:
            return "明天 · \(shortFormatter.string(from: date))"
        default:
            let fullFormatter = DateFormatter()
            fullFormatter.locale = Locale(identifier: "zh_CN")
            fullFormatter.dateFormat = "yyyy年M月d日"
            return fullFormatter.string(from: date)
        }
    }
    
    var shortDateTitle: String {
        guard let dateStr = selectedDate, let date = dateFromString(dateStr) else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }
    
    var selectedDateWorkouts: [Workout] {
        guard let date = selectedDate else { return [] }
        return visibleWorkouts.filter { $0.workoutDate == date }
    }
    
    var visibleWorkouts: [Workout] {
        guard let planId = selectedPlan?.trainingPlanId else { return workouts }
        return workoutsByPlan[planId] ?? []
    }
    
    var sheetPlan: TrainingPlan? {
        selectedPlan ?? plans.first(where: { $0.status == "active" }) ?? plans.first
    }

    var shouldShowBottomDeletePlanButton: Bool {
        !(plans.count > 1 && plans.contains(where: isAIGeneratedPlan))
    }
    
    private var goalDrivenPlan: TrainingPlan? {
        guard let plan = selectedPlan ?? plans.first(where: { $0.status == "active" }),
              plan.mode == "goal_driven" else { return nil }
        return plan
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if loading {
                        ProgressView("加载训练数据...")
                            .padding(.top, 100)
                    } else if generating {
                        ProgressView("AI 正在为您生成训练计划...")
                            .padding(.top, 60)
                    } else if adjustingSchedule {
                        ProgressView("正在调整排期并同步至佳明...")
                            .padding(.top, 60)
                    } else {
                        // 日期切换器
                        HStack {
                            Button(action: prevDay) {
                                Label("前一天", systemImage: "chevron.left")
                                    .labelStyle(.iconOnly)
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.circle)

                            Spacer()

                            Button {
                                showCalendarSheet = true
                            } label: {
                                Label(selectedDateTitle, systemImage: "calendar")
                                    .font(.headline)
                            }

                            Spacer()

                            Button(action: nextDay) {
                                Label("后一天", systemImage: "chevron.right")
                                    .labelStyle(.iconOnly)
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.circle)
                        }

                        // 1. 直切主题：当日训练卡片流
                        ZStack {
                            if !selectedDateWorkouts.isEmpty {
                                VStack(alignment: .leading, spacing: 14) {
                                    ForEach(Array(selectedDateWorkouts.enumerated()), id: \.element.id) { idx, workout in
                                        let planMeta = workoutPlanMetaByWorkoutId[workout.trainingPlanWorkoutId]
                                        WorkoutCardView(
                                            workout: workout,
                                            initiallyExpanded: plans.count == 1 && selectedDateWorkouts.count == 1 && idx == 0,
                                            planTitle: planMeta?.title,
                                            planIntro: planMeta?.intro,
                                            onCancelSchedule: { workoutToCancel = workout },
                                            onPostpone: { workoutToPostpone = workout },
                                            onMoveTo: {
                                                if let d = dateFromString(workout.workoutDate ?? todayStr()) {
                                                    moveTargetDate = d
                                                }
                                                workoutToMove = workout
                                            }
                                        )
                                    }
                                }
                                .transition(.push(from: swipeDirection == .forward ? .trailing : .leading))
                                .id(selectedDate ?? "")
                            } else {
                                ContentUnavailableView("今日暂无训练安排", systemImage: "cup.and.saucer")
                                    .transition(.push(from: swipeDirection == .forward ? .trailing : .leading))
                                    .id(selectedDate ?? "")
                            }
                        }
                        .animation(.easeInOut(duration: 0.3), value: selectedDate)

                        // 4. 底部操作面板（随内容滚动）
                        bottomActions
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .backgroundStyle(Color(.secondarySystemGroupedBackground))
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("训练课程")
            .toolbar {
                if !plans.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            if let plan = goalDrivenPlan {
                                Section {
                                    Button("进度", systemImage: "chart.line.uptrend.xyaxis") {
                                        loadProgress(planId: plan.trainingPlanId)
                                    }
                                    Button("续期", systemImage: "calendar.badge.plus") {
                                        showExtendAlert = true
                                    }
                                    Button("复盘", systemImage: "checklist") {
                                        showReviewAlert = true
                                    }
                                }
                            }
                            Button("计划详情", systemImage: "list.bullet.rectangle") {
                                showPlanDetailsSheet = true
                            }
                        } label: {
                            Label("更多", systemImage: "ellipsis")
                        }
                    }
                }
            }
            .refreshable { await loadData() }
            .simultaneousGesture(
                DragGesture(minimumDistance: 40)
                    .onEnded { value in
                         if abs(value.translation.width) > abs(value.translation.height) {
                             if value.translation.width < -40 {
                                 nextDay() // Swipe Left
                             } else if value.translation.width > 40 {
                                 prevDay() // Swipe Right
                             }
                         }
                    }
            )
            .task {
                // 系统 TabView 每次切回本 tab 都会重跑 .task：刚加载过就不再请求，下拉刷新不受影响
                if let last = lastLoadedAt, Date().timeIntervalSince(last) < Self.reloadInterval {
                    selectedDate = todayStr()
                    return
                }
                async let dailyCheckLoad: Void = loadDailyCheck()
                await loadData()
                await dailyCheckLoad
                selectedDate = todayStr()
            }
            .sheet(isPresented: $showGenSheet) {
                GeneratePlanSheet(
                    initialForm: genForm,
                    generating: $generating,
                    onGenerate: generatePlan
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showCalendarSheet) {
                NavigationStack {
                    ScrollView {
                        WorkoutCalendarView(
                            workoutDates: workoutDates,
                            selectedDate: selectedDate
                        ) { d in
                            if let curr = selectedDate, let currDate = dateFromString(curr), let newDate = dateFromString(d) {
                                swipeDirection = newDate > currDate ? .forward : .backward
                            }
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                                selectedDate = d
                                showCalendarSheet = false
                            }
                        }
                        .padding(.horizontal)
                    }
                    .navigationTitle("训练日历")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("关闭") { showCalendarSheet = false }
                        }
                    }
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showPlanDetailsSheet) {
                NavigationStack {
                    List {
                        if plans.count > 1 {
                            Section("训练计划") {
                                planSelectionRow(
                                    title: "全部计划",
                                    isSelected: selectedPlan == nil,
                                    action: {
                                        selectedPlan = nil
                                    }
                                )

                                ForEach(plans) { item in
                                    planSelectionRow(
                                        title: (item.mode == "goal_driven" ? "🎯 " : "") + item.planName,
                                        isSelected: selectedPlan?.trainingPlanId == item.trainingPlanId,
                                        action: {
                                            selectedPlan = item
                                            if let startDate = item.startDate, let d = dateFromString(startDate) {
                                                currentMonth = d
                                            }
                                        }
                                    )
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button("删除", systemImage: "trash", role: .destructive) {
                                            planToDelete = item
                                            showDeleteAlert = true
                                        }
                                    }
                                }
                            }
                        }

                        if let detailPlan = selectedPlan ?? (plans.count == 1 ? sheetPlan : nil) {
                            Section(detailPlan.planName) {
                                if let weeks = detailPlan.durationWeeks {
                                    LabeledContent {
                                        Text("\(weeks) 周")
                                    } label: {
                                        Label("周期", systemImage: "calendar.badge.clock")
                                    }
                                }

                                if let desc = formatPlanDescription(detailPlan) {
                                    Text(desc)
                                        .font(.subheadline)
                                }
                            }
                        }

                        if let plan = sheetPlan {
                            Section {
                                Button("将近期训练推至佳明日历", systemImage: "arrow.up.circle") {
                                    pushToGarmin(plan)
                                }

                                Button("重新生成计划", systemImage: "sparkles") {
                                    planToRegenerate = plan
                                }

                                if shouldShowBottomDeletePlanButton {
                                    Button("删除计划", systemImage: "trash", role: .destructive) {
                                        planToDelete = plan
                                        showDeleteAlert = true
                                    }
                                }
                            }
                        }
                    }
                    .navigationTitle("计划详情")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("关闭") { showPlanDetailsSheet = false }
                        }
                    }
                    .alert("重新生成计划", isPresented: Binding(
                        get: { planToRegenerate != nil },
                        set: { if !$0 { planToRegenerate = nil } }
                    )) {
                        Button("继续", role: .destructive) {
                            planToRegenerate = nil
                            DispatchQueue.main.async {
                                showPlanRegenerateSheet = true
                            }
                        }
                        Button("取消", role: .cancel) {
                            planToRegenerate = nil
                        }
                    } message: {
                        Text("当前训练计划「\(planToRegenerate?.planName ?? "")」尚未结束。\n\n重新生成将删除该计划及其所有课程，包括已推送到 Garmin 的训练。确定要继续吗？")
                    }
                    .sheet(isPresented: $showPlanRegenerateSheet) {
                        GeneratePlanSheet(
                            initialForm: genForm,
                            generating: $generating,
                            onGenerate: generatePlan
                        )
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                    }
                }
                .presentationDetents([.fraction(0.72), .large])
                .presentationDragIndicator(.visible)
            }
            .alert("删除训练计划", isPresented: $showDeleteAlert) {
                Button("删除", role: .destructive) {
                    if let plan = planToDelete {
                        deletePlan(plan)
                    }
                    planToDelete = nil
                }
                Button("取消", role: .cancel) { planToDelete = nil }
            } message: {
                Text("确定要删除该训练计划吗？此操作不可恢复。")
            }
            .alert("删除排期", isPresented: Binding(
                get: { workoutToCancel != nil },
                set: { if !$0 { workoutToCancel = nil } }
            )) {
                Button("删除本次", role: .destructive) {
                    if let w = workoutToCancel { cancelSchedule(workout: w) }
                    workoutToCancel = nil
                }
                Button("取消", role: .cancel) { workoutToCancel = nil }
            } message: {
                Text("确定要删除本次排期吗？这不会影响原有训练课程定义，但会从佳明日历中撤下。")
            }
            .alert("顺延一日", isPresented: Binding(
                get: { workoutToPostpone != nil },
                set: { if !$0 { workoutToPostpone = nil } }
            )) {
                Button("确定") {
                    if let w = workoutToPostpone { postponeWorkout(workout: w) }
                    workoutToPostpone = nil
                }
                Button("取消", role: .cancel) { workoutToPostpone = nil }
            } message: {
                Text("这会将该排期及计划内所有后续课程统一向后顺延 1 天，并在佳明日历上同步修改。确定执行吗？")
            }
            .sheet(isPresented: Binding(
                get: { workoutToMove != nil },
                set: { if !$0 { workoutToMove = nil } }
            )) {
                if let wk = workoutToMove {
                    NavigationStack {
                        Form {
                            // 当前课程信息
                            Section {
                                LabeledContent {
                                    Text(wk.workoutDate ?? "未知")
                                } label: {
                                    Text("\((sportConfig[wk.sport ?? ""] ?? ("🏃", .gray, "活动")).icon) \(wk.workoutName ?? "训练课程")")
                                    Text("当前日期")
                                }
                            } footer: {
                                if wk.garminScheduleId != nil {
                                    Label("该课程已同步到 Garmin，移动后将同时更新 Garmin 日历", systemImage: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.orange)
                                }
                            }

                            // 日期选择
                            Section("选择目标日期") {
                                DatePicker(
                                    "目标日期",
                                    selection: $moveTargetDate,
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.graphical)
                            }
                        }
                        .navigationTitle("移动训练课程")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("取消") { workoutToMove = nil }
                            }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("移动") {
                                    let wkToMove = wk
                                    workoutToMove = nil
                                    rescheduleWorkout(workout: wkToMove, to: moveTargetDate)
                                }
                            }
                        }
                    }
                    .presentationDetents([.large])
                }
            }
            .sheet(isPresented: $showProgressSheet) {
                GoalPlanProgressSheet(
                    progressData: progressData,
                    loading: loadingProgress
                )
                .presentationDetents([.fraction(0.75), .large])
                .presentationDragIndicator(.visible)
            }
            .alert("续期 — 生成下一周期", isPresented: $showExtendAlert) {
                Button("确定") {
                    if let plan = selectedPlan ?? plans.first(where: { $0.mode == "goal_driven" }) {
                        extendBlock(plan)
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("将根据当前进度和训练反馈，自动生成下一个训练周期的课程。")
            }
            .alert("复盘当前周期", isPresented: $showReviewAlert) {
                Button("开始复盘") {
                    if let plan = selectedPlan ?? plans.first(where: { $0.mode == "goal_driven" }) {
                        reviewCurrentPlan(plan)
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("AI 将对当前周期的训练执行情况进行分析，更新进度评估。")
            }
        }
    }

    // MARK: - 底部操作

    @ViewBuilder
    private var bottomActions: some View {
        if plans.isEmpty {
            Button {
                showGenSheet = true
            } label: {
                Label("AI 生成计划", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private func planSelectionRow(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            LabeledContent {
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                        .accessibilityLabel("已选中")
                }
            } label: {
                Text(title)
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
            }
        }
    }

    var workoutDates: Set<String> {
        Set(visibleWorkouts.compactMap { $0.workoutDate })
    }
    
    // MARK: - Calendar Helpers
    
    private func todayStr() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private func isAIGeneratedPlan(_ plan: TrainingPlan) -> Bool {
        let source = plan.source?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        return source.contains("ai")
    }
    
    private func prevDay() {
        guard let current = selectedDate, let date = dateFromString(current) else { return }
        if let prev = calendar.date(byAdding: .day, value: -1, to: date) {
            swipeDirection = .backward
            let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
            withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                selectedDate = f.string(from: prev)
                if !calendar.isDate(prev, equalTo: currentMonth, toGranularity: .month) {
                    currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: prev)) ?? currentMonth
                }
            }
        }
    }
    
    private func nextDay() {
        guard let current = selectedDate, let date = dateFromString(current) else { return }
        if let next = calendar.date(byAdding: .day, value: 1, to: date) {
            swipeDirection = .forward
            let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
            withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                selectedDate = f.string(from: next)
                if !calendar.isDate(next, equalTo: currentMonth, toGranularity: .month) {
                    currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: next)) ?? currentMonth
                }
            }
        }
    }
    
    // MARK: - Data
    
    private func loadData() async {
        // 1. 首次进入先用本地缓存立即出内容；有内容时后台刷新不再整页转圈
        if lastLoadedAt == nil {
            let hasCache = await loadFromCache()
            if !hasCache { loading = true }
        }
        
        // 2. 列表与全部计划详情一次请求取齐（原先 1+N 个请求）
        do {
            async let statusReq = try? APIService.shared.getPlanStatus()
            async let bundleReq = APIService.shared.getTrainingPlanBundle()
            let (statusOpt, bundle) = await (statusReq, try bundleReq)
            
            applyPlans(bundle.plans, details: bundle.details)
            lastLoadedAt = Date()
            
            if statusOpt?.isGenerating == true {
                let currentPlanId = bundle.plans.first(where: { $0.status == "active" })?.trainingPlanId
                    ?? bundle.plans.first?.trainingPlanId
                generating = true
                startPolling(oldPlanId: currentPlanId)
            }
        } catch {
            loading = false
        }
    }
    
    /// 从本地缓存恢复，返回是否命中
    private func loadFromCache() async -> Bool {
        if let bundle = await APIService.shared.cached("/training/plan/details", as: TrainingPlanBundleResponse.self) {
            applyPlans(bundle.plans, details: bundle.details)
            return true
        }
        // 兼容升级前按计划逐个缓存的数据
        guard let plansRes = await APIService.shared.cached("/training/plan", as: TrainingPlanListResponse.self) else { return false }
        var details: [TrainingPlanDetailResponse] = []
        for plan in plansRes.plans {
            if let detail = await APIService.shared.cached("/training/plan/\(plan.trainingPlanId)", as: TrainingPlanDetailResponse.self) {
                details.append(detail)
            }
        }
        applyPlans(plansRes.plans, details: details)
        return true
    }
    
    private func applyPlans(_ fetchedPlans: [TrainingPlan], details: [TrainingPlanDetailResponse]) {
        plans = fetchedPlans
        if let current = selectedPlan,
           !fetchedPlans.contains(where: { $0.trainingPlanId == current.trainingPlanId }) {
            selectedPlan = nil
        }
        
        let planById = Dictionary(fetchedPlans.map { ($0.trainingPlanId, $0) }, uniquingKeysWith: { a, _ in a })
        var allWorkouts: [Workout] = []
        var groupedWorkouts: [Int: [Workout]] = [:]
        var planMetaByWorkoutId: [Int: (title: String, intro: String?)] = [:]
        for detail in details {
            let planId = detail.plan.trainingPlanId
            guard let plan = planById[planId] else { continue }
            allWorkouts.append(contentsOf: detail.workouts)
            groupedWorkouts[planId] = detail.workouts
            for workout in detail.workouts {
                planMetaByWorkoutId[workout.trainingPlanWorkoutId] = (
                    title: plan.planName,
                    intro: plan.description
                )
            }
        }
        workouts = allWorkouts
        workoutsByPlan = groupedWorkouts
        workoutPlanMetaByWorkoutId = planMetaByWorkoutId
        // 导航到最新计划的起始月
        if let firstPlan = fetchedPlans.first,
           let startDate = firstPlan.startDate,
           let date = dateFromString(startDate) {
            currentMonth = date
        }
        loading = false
    }
    
    private func dateFromString(_ s: String) -> Date? {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.date(from: s)
    }
    
    private func deletePlan(_ plan: TrainingPlan) {
        Task {
            let wasShowingPlanDetails = await MainActor.run { showPlanDetailsSheet }
            let fallbackSelectedPlanId = await MainActor.run { () -> Int? in
                let deletingCurrentSelection = selectedPlan?.trainingPlanId == plan.trainingPlanId
                guard deletingCurrentSelection else {
                    return selectedPlan?.trainingPlanId
                }

                let remainingPlans = plans.filter { $0.trainingPlanId != plan.trainingPlanId }
                return remainingPlans.first(where: { $0.status == "active" })?.trainingPlanId
                    ?? remainingPlans.first?.trainingPlanId
            }

            try? await APIService.shared.deletePlan(planId: plan.trainingPlanId)
            await loadData()
            await MainActor.run {
                if let fallbackSelectedPlanId {
                    selectedPlan = plans.first(where: { $0.trainingPlanId == fallbackSelectedPlanId })
                } else if selectedPlan?.trainingPlanId == plan.trainingPlanId {
                    selectedPlan = nil
                }

                if wasShowingPlanDetails {
                    showPlanDetailsSheet = true
                }
            }
        }
    }
    
    private func pushToGarmin(_ plan: TrainingPlan) {
        Task {
            do {
                try await APIService.shared.pushPlanToGarmin(planId: plan.trainingPlanId)
            } catch {}
        }
    }
    
    private func generatePlan(_ form: GeneratePlanForm) {
        generating = true
        genForm = form
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        let startDate = f.string(from: form.startDate)
        
        var goal: [String: Any] = [
            "goal_type": form.goal,
            "sports": Array(form.sports),
        ]
        goal.merge(buildTrainingGoalDetails(from: form)) { _, new in new }
        
        if form.mode == "goal_driven" {
            // Goal-driven plan flow
            var req: [String: Any] = [
                "goal_kind": form.goal,
                "start_date": startDate,
                "micro_cycle_days": form.microCycleDays,
            ]
            if let targetDate = form.targetDate {
                req["target_date"] = f.string(from: targetDate)
            }
            req["goal_metrics"] = buildTrainingGoalDetails(from: form)
            req["extra_requirements"] = buildExtraRequirements(from: form)
            
            let oldPlanId = selectedPlan?.trainingPlanId
            
            Task {
                if let oldId = oldPlanId {
                    try? await APIService.shared.deletePlan(planId: oldId)
                    await MainActor.run {
                        self.selectedPlan = nil
                        self.workouts = []
                        self.workoutsByPlan = [:]
                        self.workoutPlanMetaByWorkoutId = [:]
                        self.plans.removeAll { $0.trainingPlanId == oldId }
                    }
                }
                
                do {
                    try await APIService.shared.saveTrainingGoal(goal: goal)
                    _ = try await APIService.shared.startGoalPlan(req: req)
                    await MainActor.run {
                        showGenSheet = false
                        showPlanRegenerateSheet = false
                    }
                    startPolling(oldPlanId: oldPlanId)
                } catch {
                    await MainActor.run { generating = false }
                }
            }
        } else {
            // Fixed plan flow (existing)
            var req: [String: Any] = [
                "duration_weeks": Int(form.weeks),
                "start_date": startDate,
                "training_goal": form.goal
            ]
            req["extra_requirements"] = buildExtraRequirements(from: form)
            
            let oldPlanId = selectedPlan?.trainingPlanId
            
            Task {
                if let oldId = oldPlanId {
                    try? await APIService.shared.deletePlan(planId: oldId)
                    await MainActor.run {
                        self.selectedPlan = nil
                        self.workouts = []
                        self.workoutsByPlan = [:]
                        self.workoutPlanMetaByWorkoutId = [:]
                        self.plans.removeAll { $0.trainingPlanId == oldId }
                    }
                }
                
                do {
                    try await APIService.shared.saveTrainingGoal(goal: goal)
                    try await APIService.shared.generateTrainingPlan(req: req)
                    await MainActor.run {
                        showGenSheet = false
                        showPlanRegenerateSheet = false
                    }
                    startPolling(oldPlanId: oldPlanId)
                } catch {
                    await MainActor.run { generating = false }
                }
            }
        }
    }

    private func buildTrainingGoalDetails(from form: GeneratePlanForm) -> [String: Any] {
        let gd = form.goalDetail
        var req: [String: Any] = [:]

        func intValue(_ key: String) -> Int? {
            guard let raw = gd[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !raw.isEmpty,
                  let value = Int(raw) else { return nil }
            return value
        }

        func stringValue(_ key: String) -> String? {
            guard let raw = gd[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !raw.isEmpty else { return nil }
            return raw
        }

        if form.goal == "ftp_improvement" || form.goal == "general_fitness" {
            if let value = intValue("currentFtp") { req["current_ftp"] = value }
            if let value = intValue("targetFtp") { req["target_ftp"] = value }
            if let value = stringValue("focusArea") { req["focus_area"] = value }
        } else if form.goal == "aerobic_endurance" {
            if let value = intValue("targetZ2Duration") { req["target_z2_duration"] = value }
            if let value = stringValue("targetWeeklyHours") { req["target_weekly_hours"] = value }
        } else if form.goal == "vo2max_development" {
            if let value = intValue("currentVo2") { req["current_vo2"] = value }
            if let value = intValue("targetVo2") { req["target_vo2"] = value }
        } else if form.goal == "sprint_power" {
            if let value = intValue("targetSprintPower") { req["target_sprint_power"] = value }
            if let value = intValue("sprintDuration") { req["sprint_duration"] = value }
        } else if form.goal == "triathlon" {
            if let value = stringValue("targetFinishTime") { req["target_finish_time"] = value }
            if let value = stringValue("raceDistance") { req["race_distance"] = value }
        }

        return req
    }

    private func buildExtraRequirements(from form: GeneratePlanForm) -> String {
        let selectedSports = sportOptions
            .filter { form.sports.contains($0.key) }
            .map(\.label)
            .joined(separator: "、")
        let trainingDays = weekdayKeys
            .filter { form.trainDays.contains($0.key) }
            .map(\.full)
            .joined(separator: "、")
        let lsdDays = weekdayKeys
            .filter { form.lsdDays.contains($0.key) && form.trainDays.contains($0.key) }
            .map(\.full)
            .joined(separator: "、")
        let restDays = weekdayKeys
            .filter { !form.trainDays.contains($0.key) }
            .map(\.full)
            .joined(separator: "、")
        let goalLabel = trainingGoals.first(where: { $0.key == form.goal })?.label ?? form.goal
        let tssPreset = tssPresets.first(where: { $0.key == form.tssLevel })
        let extra = form.extraRequirements.trimmingCharacters(in: .whitespacesAndNewlines)

        var lines = [
            "## 运动项目",
            selectedSports.isEmpty ? "未设置" : selectedSports
        ]

        if form.sports.count > 1 {
            if form.multiSportDay {
                lines.append("- 同一天可以安排多种运动项目的训练")
                lines.append("- 每种运动都作为独立的训练课程安排在同一天")
            } else {
                lines.append("- 每天只安排一项运动，多个项目在不同日期轮流交替")
                lines.append("- 合理分配各项目的训练天数")
            }
        }

        lines.append("")
        lines.append("## 每周训练安排")
        lines.append("- 训练目标：\(goalLabel)")
        lines.append("- 可训练日：\(trainingDays.isEmpty ? "未设置" : trainingDays)（共 \(form.trainDays.count) 天）")
        lines.append("- 休息日：\(restDays.isEmpty ? "无" : restDays)")

        if form.sports.contains("cycling") {
            lines.append("- 长距离骑行日（LSD）：\(lsdDays.isEmpty ? "无" : lsdDays)，LSD 日可安排 2-4 小时长骑")
        }

        lines.append("- 非 LSD 日单次训练时长控制在 60-90 分钟")
        lines.append("")
        lines.append("## 训练负荷")
        lines.append("- 目标周 TSS：\(tssPreset?.tss ?? form.tssLevel)")
        lines.append("- 预计每周训练时长：\(tssPreset?.hours ?? "--")")
        lines.append("- 计划周期：\(Int(form.weeks)) 周")

        if !extra.isEmpty {
            lines.append("")
            lines.append("## 其他要求")
            lines.append(extra)
        }

        return lines.joined(separator: "\n")
    }
    
    private func startPolling(oldPlanId: Int?) {
        pollingTask?.cancel()
        pollingTask = Task {
            var checks = 0
            while checks < 60 && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard !Task.isCancelled else { break }
                
                do {
                    let res = try await APIService.shared.getTrainingPlans()
                    let newPlans = res.plans
                    if let latest = newPlans.first, latest.trainingPlanId != oldPlanId {
                        await MainActor.run { 
                            self.plans = newPlans
                            if let current = self.selectedPlan,
                               !newPlans.contains(where: { $0.trainingPlanId == current.trainingPlanId }) {
                                self.selectedPlan = nil
                            }
                        }
                        let detail = try await APIService.shared.getPlanDetail(planId: latest.trainingPlanId)
                        await MainActor.run {
                            self.workouts = detail.workouts
                            self.workoutsByPlan = [latest.trainingPlanId: detail.workouts]
                            var planMetaByWorkoutId: [Int: (title: String, intro: String?)] = [:]
                            for workout in detail.workouts {
                                planMetaByWorkoutId[workout.trainingPlanWorkoutId] = (
                                    title: latest.planName,
                                    intro: latest.description
                                )
                            }
                            self.workoutPlanMetaByWorkoutId = planMetaByWorkoutId
                            if let startDate = latest.startDate, let d = self.dateFromString(startDate) {
                                self.currentMonth = d
                            }
                            self.generating = false
                        }
                        break
                    }
                } catch { }
                checks += 1
            }
            if !Task.isCancelled {
                await MainActor.run { self.generating = false }
            }
        }
    }
    
    // MARK: - Goal-Driven Plan Actions
    
    // MARK: - Daily Check
    
    private func loadDailyCheck() async {
        do {
            let resp = try await APIService.shared.getDailyCheckToday()
            await MainActor.run {
                // 优先显示未响应的晨检，其次晚检
                if let m = resp.morning, m.status == "done", m.userResponse == nil {
                    dailyCheck = m
                } else if let e = resp.evening, e.status == "done", e.userResponse == nil {
                    dailyCheck = e
                } else {
                    dailyCheck = nil
                }
            }
        } catch {
            // 静默
        }
    }
    
    private func respondDailyCheck(_ response: String) {
        guard let check = dailyCheck else { return }
        Task {
            try? await APIService.shared.respondDailyCheck(
                id: check.dailyCheckId, response: response)
            await MainActor.run { dailyCheck = nil }
        }
    }
    
    private func applyDailyCheck() {
        guard let check = dailyCheck else { return }
        Task {
            try? await APIService.shared.applyDailyCheck(id: check.dailyCheckId)
            await MainActor.run { dailyCheck = nil }
            await loadData()
        }
    }
    
    private func loadProgress(planId: Int) {
        loadingProgress = true
        showProgressSheet = true
        Task {
            do {
                let resp = try await APIService.shared.getPlanProgress(planId: planId)
                await MainActor.run {
                    progressData = resp
                    loadingProgress = false
                }
            } catch {
                await MainActor.run { loadingProgress = false }
            }
        }
    }
    
    private func extendBlock(_ plan: TrainingPlan) {
        generating = true
        Task {
            do {
                _ = try await APIService.shared.extendBlock(planId: plan.trainingPlanId)
                startPolling(oldPlanId: nil)
            } catch {
                await MainActor.run { generating = false }
            }
        }
    }
    
    private func reviewCurrentPlan(_ plan: TrainingPlan) {
        generating = true
        Task {
            do {
                _ = try await APIService.shared.reviewPlan(planId: plan.trainingPlanId)
                await loadData()
                await MainActor.run { generating = false }
            } catch {
                await MainActor.run { generating = false }
            }
        }
    }
    
    // MARK: - Handlers
    
    private func cancelSchedule(workout: Workout) {
        let id = workout.trainingPlanWorkoutId
        adjustingSchedule = true
        Task {
            do {
                try await APIService.shared.cancelWorkoutSchedule(workoutId: id)
                await loadData() // refresh
            } catch {
                // Handle error implicitly
            }
            await MainActor.run { adjustingSchedule = false }
        }
    }
    
    private func postponeWorkout(workout: Workout) {
        let id = workout.trainingPlanWorkoutId
        adjustingSchedule = true
        Task {
            do {
                try await APIService.shared.postponeWorkout(workoutId: id)
                await loadData() // refresh
            } catch {
            }
            await MainActor.run { adjustingSchedule = false }
        }
    }
    
    private func rescheduleWorkout(workout: Workout, to targetDate: Date) {
        let id = workout.trainingPlanWorkoutId
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let newDate = f.string(from: targetDate)
        
        // 如果日期没变则不操作
        if newDate == workout.workoutDate { return }
        
        adjustingSchedule = true
        Task {
            do {
                try await APIService.shared.rescheduleWorkout(workoutId: id, newDate: newDate)
                await loadData()
                await MainActor.run {
                    // 切换到目标日期查看
                    selectedDate = newDate
                    if let d = dateFromString(newDate) {
                        currentMonth = d
                    }
                }
            } catch {
                // Handle error implicitly
            }
            await MainActor.run { adjustingSchedule = false }
        }
    }
}

// MARK: - Workout Card

struct WorkoutCardView: View {
    let workout: Workout
    var initiallyExpanded: Bool = false
    var planTitle: String? = nil
    var planIntro: String? = nil
    var onCancelSchedule: (() -> Void)? = nil
    var onPostpone: (() -> Void)? = nil
    var onMoveTo: (() -> Void)? = nil
    @State private var expanded = false
    
    var config: (icon: String, color: Color, label: String) {
        sportConfig[workout.sport ?? ""] ?? ("🏃", .gray, workout.sport ?? "活动")
    }
    
    private var displayPlanTitle: String {
        let title = planTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let title, !title.isEmpty {
            return title
        }
        return "训练计划"
    }
    
    private var displayPlanIntro: String {
        guard let desc = planIntro?
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !desc.isEmpty else {
            return "暂无训练计划简介"
        }
        return desc
    }
    
    var body: some View {
        GroupBox {
            DisclosureGroup(isExpanded: $expanded) {
                VStack(alignment: .leading, spacing: 10) {
                    // 描述
                    if let desc = workout.description, !desc.isEmpty {
                        MarkdownTextView(markdown: desc)
                    }

                    // 步骤
                    if let steps = workout.steps, !steps.isEmpty {
                        Text("训练步骤").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        ForEach(Array(steps.enumerated()), id: \.offset) { _, step in
                            StepCardView(step: step)
                        }
                    }

                    if onCancelSchedule != nil || onPostpone != nil || onMoveTo != nil {
                        HStack(spacing: 10) {
                            if let cancel = onCancelSchedule {
                                Button("删除", systemImage: "trash", role: .destructive, action: cancel)
                            }
                            if let postpone = onPostpone {
                                Button("顺延其后", systemImage: "clock", action: postpone)
                            }
                            if let moveTo = onMoveTo {
                                Button("移动至", systemImage: "arrow.right.circle", action: moveTo)
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(workout.workoutName ?? "未命名")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.primary)
                        if !summaryText.isEmpty {
                            Text(summaryText)
                                .font(.caption)
                                .foregroundStyle(Color.secondary)
                        }
                    }
                } icon: {
                    Text(config.icon)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text(displayPlanTitle)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text(displayPlanIntro)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear { expanded = initiallyExpanded }
    }

    private var summaryText: String {
        var parts: [String] = []
        if let dur = workout.durationMin { parts.append("\(dur)min") }
        if let tss = workout.tssEstimate { parts.append("TSS \(tss)") }
        if let km = workout.distanceKm { parts.append("\(String(format: "%.1f", km))km") }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Step Card

private let stepColors: [String: Color] = [
    "warmup": .green, "warm_up": .green,
    "interval": .red, "active": .red,
    "recovery": .blue, "rest": .blue,
    "cooldown": .green, "cool_down": .green,
]

private let stepLabels: [String: String] = [
    "warmup": "热身", "warm_up": "热身",
    "interval": "训练", "active": "训练",
    "recovery": "恢复", "rest": "恢复",
    "cooldown": "缓和", "cool_down": "缓和",
]

private let strengthCategoryLabels: [String: String] = [
    "SQUAT": "深蹲类", "LUNGE": "弓步/分腿蹲", "DEADLIFT": "硬拉",
    "HIP_RAISE": "髋桥/臀冲", "HIP_SWING": "髋部摆动",
    "CALF_RAISE": "提踵", "LEG_CURL": "腿弯举",
    "HYPEREXTENSION": "背伸", "BENCH_PRESS": "卧推",
    "PUSH_UP": "俯卧撑", "SHOULDER_PRESS": "肩部推举",
    "PULL_UP": "引体/下拉", "ROW": "划船",
    "LATERAL_RAISE": "侧平举", "FLYE": "飞鸟",
    "SHRUG": "耸肩", "CURL": "二头弯举",
    "TRICEPS_EXTENSION": "三头臂屈伸", "PLANK": "平板支撑",
    "CRUNCH": "卷腹", "SIT_UP": "仰卧起坐",
    "LEG_RAISE": "举腿", "CORE": "核心稳定",
    "HIP_STABILITY": "髋稳定", "PLYO": "爆发力",
    "TOTAL_BODY": "全身复合", "OLYMPIC_LIFT": "举重",
    "CARRY": "负重行走", "WARM_UP": "热身/拉伸",
    "BANDED_EXERCISES": "弹力带", "SUSPENSION": "悬挂训练",
    "BATTLE_ROPE": "战绳",
]

struct StepCardView: View {
    let step: WorkoutStep
    
    var color: Color { stepColors[step.type] ?? .gray }
    var label: String { stepLabels[step.type] ?? step.type }
    
    /// 是否为力量训练步骤
    private var isStrength: Bool {
        step.type == "active" &&
        (step.exerciseName != nil || step.exerciseCategory != nil || step.reps != nil || step.weightValue != nil || step.isTimed == true)
    }
    
    /// 是否为紧凑型休息（无功率/心率/踏频目标）
    private var isCompactRest: Bool {
        (step.type == "rest" || step.type == "recovery") &&
        step.powerLow == nil && step.powerHigh == nil &&
        step.hrLow == nil && step.hrHigh == nil &&
        step.cadenceLow == nil && step.cadenceHigh == nil
    }
    
    var body: some View {
        if step.type == "repeat", let subs = step.steps, !subs.isEmpty {
            // 重复组
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text("↻").foregroundColor(.secondary)
                    Text("\(step.count ?? 1) 次").font(.caption.weight(.semibold))
                }
                .padding(.horizontal, 10).padding(.vertical, 4)
                
                ForEach(Array(subs.enumerated()), id: \.offset) { _, sub in
                    StepCardView(step: sub)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(6)
            .background(Color(UIColor.systemGray6))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(UIColor.systemGray4), lineWidth: 0.5))
        } else if isStrength {
            strengthStepView
        } else if isCompactRest {
            compactRestView
        } else {
            enduranceStepView
        }
    }
    
    // MARK: - 力量训练步骤
    private var strengthStepView: some View {
        let name = step.displayName ?? step.description ?? step.exerciseName ?? "力量动作"
        let categoryLabel = step.exerciseCategory.flatMap { strengthCategoryLabels[$0] }
        let isTimed = step.isTimed ?? (step.durationSec != nil && step.reps == nil)
        
        return HStack(spacing: 0) {
            Rectangle().fill(Color.purple).frame(width: 3)
            
            VStack(alignment: .leading, spacing: 6) {
                // 动作名称行
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(name)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                    if let cat = categoryLabel {
                        Text(cat)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                
                // 三栏指标
                HStack(spacing: 16) {
                    if isTimed {
                        // 计时型：单组时长
                        VStack(alignment: .leading, spacing: 1) {
                            Text(step.durationSec.map { formatSeconds($0) } ?? "-")
                                .font(.system(size: 14, weight: .bold))
                            Text("单组时长").font(.system(size: 9)).foregroundColor(.secondary)
                        }
                    } else {
                        // 次数型：每组次数
                        VStack(alignment: .leading, spacing: 1) {
                            Text(step.reps.map { "\($0) 次" } ?? "-")
                                .font(.system(size: 14, weight: .bold))
                            Text("每组次数").font(.system(size: 9)).foregroundColor(.secondary)
                        }
                    }
                    
                    // 负重
                    VStack(alignment: .leading, spacing: 1) {
                        if let w = step.weightValue, w > 0 {
                            Text("\(String(format: w.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", w)) kg")
                                .font(.system(size: 14, weight: .bold))
                        } else {
                            Text("自重")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                        Text("负重").font(.system(size: 9)).foregroundColor(.secondary)
                    }
                    
                    // 次数型的补充时长
                    if !isTimed {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(step.durationSec.map { formatSeconds($0) } ?? "-")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(step.durationSec != nil ? .primary : Color(UIColor.systemGray3))
                            Text("单组时长").font(.system(size: 9)).foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(UIColor.systemGray4), lineWidth: 0.5))
    }
    
    // MARK: - 紧凑型休息
    private var compactRestView: some View {
        HStack(spacing: 0) {
            Rectangle().fill(Color.blue).frame(width: 3)
            
            HStack {
                Text(step.description ?? "休息")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                Spacer()
                Text(step.durationSec.map { formatSeconds($0) } ?? "-")
                    .font(.system(size: 14, weight: .bold))
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(UIColor.systemGray4), lineWidth: 0.5))
    }
    
    // MARK: - 耐力训练步骤（骑行/跑步/游泳）
    private var enduranceStepView: some View {
        HStack(spacing: 0) {
            Rectangle().fill(color).frame(width: 3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(step.description ?? label)
                    .font(.caption).foregroundColor(.secondary)
                
                HStack(spacing: 16) {
                    // 时长
                    VStack(alignment: .leading, spacing: 1) {
                        Text(step.durationSec.map { formatSeconds($0) } ?? "-")
                            .font(.system(size: 14, weight: .bold))
                        Text("时长").font(.system(size: 9)).foregroundColor(.secondary)
                    }
                    
                    // 功率
                    VStack(alignment: .leading, spacing: 1) {
                        if let lo = step.powerLow, let hi = step.powerHigh {
                            Text("\(lo)-\(hi) W").font(.system(size: 14, weight: .bold))
                        } else {
                            Text("-").font(.system(size: 14, weight: .bold))
                        }
                        Text("功率").font(.system(size: 9)).foregroundColor(.secondary)
                    }
                    
                    // 踏频/心率
                    VStack(alignment: .leading, spacing: 1) {
                        if let lo = step.cadenceLow, let hi = step.cadenceHigh {
                            Text("\(lo)-\(hi) rpm").font(.system(size: 14, weight: .bold))
                        } else if let lo = step.hrLow, let hi = step.hrHigh {
                            Text("\(lo)-\(hi) bpm").font(.system(size: 14, weight: .bold))
                        } else {
                            Text("-").font(.system(size: 14, weight: .bold))
                        }
                        Text("踏频/HR").font(.system(size: 9)).foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(UIColor.systemGray4), lineWidth: 0.5))
    }
    
    private func formatSeconds(_ sec: Int) -> String {
        let m = sec / 60; let s = sec % 60
        return s > 0 ? "\(m):\(String(format: "%02d", s))" : "\(m):00"
    }
}

// MARK: - Generate Plan Sheet

struct GeneratePlanSheet: View {
    @Binding var generating: Bool
    let onGenerate: (GeneratePlanForm) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var form: GeneratePlanForm
    @FocusState private var focusedField: String?

    init(
        initialForm: GeneratePlanForm,
        generating: Binding<Bool>,
        onGenerate: @escaping (GeneratePlanForm) -> Void
    ) {
        self._generating = generating
        self.onGenerate = onGenerate
        self._form = State(initialValue: initialForm)
    }
    
    private func sportBinding(_ key: String) -> Binding<Bool> {
        Binding(
            get: { form.sports.contains(key) },
            set: { isOn in
                if isOn {
                    form.sports.insert(key)
                } else if form.sports.count > 1 {
                    form.sports.remove(key)
                }
                if !form.sports.contains("cycling") {
                    form.lsdDays = []
                } else if form.lsdDays.isEmpty, let fallback = form.trainDays.max() {
                    form.lsdDays = [fallback]
                }
                if form.sports.count <= 1 {
                    form.multiSportDay = false
                }
            }
        )
    }

    private func trainDayBinding(_ key: Int) -> Binding<Bool> {
        Binding(
            get: { form.trainDays.contains(key) },
            set: { isOn in
                if isOn {
                    form.trainDays.insert(key)
                } else if form.trainDays.count > 1 {
                    form.trainDays.remove(key)
                }
                form.lsdDays = form.lsdDays.intersection(form.trainDays)
                if form.lsdDays.isEmpty, form.sports.contains("cycling"), let fallback = form.trainDays.max() {
                    form.lsdDays = [fallback]
                }
            }
        )
    }

    private func lsdDayBinding(_ key: Int) -> Binding<Bool> {
        Binding(
            get: { form.lsdDays.contains(key) },
            set: { isOn in
                if isOn {
                    form.lsdDays.insert(key)
                } else {
                    form.lsdDays.remove(key)
                }
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                // 计划模式
                Section {
                    Picker("计划模式", selection: $form.mode) {
                        Text("固定周期").tag("fixed")
                        Text("目标驱动").tag("goal_driven")
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("计划模式")
                } footer: {
                    if form.mode == "goal_driven" {
                        Text("目标驱动模式：AI 按周期滚动生成课程，持续追踪进度并自动调整")
                    }
                }

                // 运动类型
                Section {
                    ForEach(sportOptions, id: \.key) { option in
                        Toggle("\(option.icon) \(option.label)", isOn: sportBinding(option.key))
                    }
                    if form.sports.count > 1 {
                        Toggle("同一天可安排多种运动", isOn: $form.multiSportDay)
                    }
                } header: {
                    Text("运动类型")
                } footer: {
                    if form.sports.count > 1 && !form.multiSportDay {
                        Text("未开启时，每天只安排一项运动，多项目轮流交替")
                    }
                }

                // 训练目标
                Section {
                    Picker("训练目标", selection: $form.goal) {
                        ForEach(trainingGoals, id: \.key) { goal in
                            Text("\(goal.icon) \(goal.label)").tag(goal.key)
                        }
                    }
                    .onChange(of: form.goal) { _, newGoal in
                        if newGoal == "triathlon" {
                            form.sports = ["cycling", "running", "swimming"]
                        }
                    }
                } footer: {
                    if let goal = trainingGoals.first(where: { $0.key == form.goal }) {
                        Text(goal.desc)
                    }
                }

                goalDetailSection

                // 训练日
                Section("训练日") {
                    HStack {
                        ForEach(weekdayKeys, id: \.key) { wk in
                            Toggle(wk.label, isOn: trainDayBinding(wk.key))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .toggleStyle(.button)
                    .buttonBorderShape(.circle)
                }

                if form.sports.contains("cycling") {
                    Section {
                        HStack {
                            ForEach(weekdayKeys.filter { form.trainDays.contains($0.key) }, id: \.key) { wk in
                                Toggle(wk.label, isOn: lsdDayBinding(wk.key))
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .toggleStyle(.button)
                        .buttonBorderShape(.circle)
                        .tint(.orange)
                    } header: {
                        Text("长距离骑行日（LSD）")
                    } footer: {
                        Text("LSD 日可安排 2-4 小时长骑")
                    }
                }

                Section {
                    DatePicker(
                        "起始日期",
                        selection: $form.startDate,
                        in: Date()...,
                        displayedComponents: .date
                    )

                    if form.mode == "goal_driven" {
                        // 目标驱动：目标日期 + 微周期天数
                        DatePicker(
                            "目标日期",
                            selection: Binding(
                                get: { form.targetDate ?? Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date() },
                                set: { form.targetDate = $0 }
                            ),
                            in: Date()...,
                            displayedComponents: .date
                        )

                        Picker("微周期天数", selection: $form.microCycleDays) {
                            Text("5 天").tag(5)
                            Text("7 天").tag(7)
                            Text("10 天").tag(10)
                            Text("14 天").tag(14)
                        }
                    } else {
                        // 固定模式：周训练量 + 周数
                        Picker("周训练量", selection: $form.tssLevel) {
                            ForEach(tssPresets, id: \.key) { preset in
                                Text("\(preset.label) · TSS \(preset.tss) · \(preset.hours)").tag(preset.key)
                            }
                        }

                        Stepper("计划周数：\(Int(form.weeks)) 周", value: $form.weeks, in: 1...12, step: 1)
                    }
                } header: {
                    Text("周期与负荷")
                } footer: {
                    if form.mode == "goal_driven" {
                        Text("AI 将根据目标日期规划整体周期，每个微周期结束后可复盘并续期")
                    } else if let preset = tssPresets.first(where: { $0.key == form.tssLevel }) {
                        Text(preset.desc)
                    }
                }
                .environment(\.locale, Locale(identifier: "zh_CN"))
                .environment(\.calendar, Calendar(identifier: .gregorian))

                Section("其他要求") {
                    TextField(
                        "其他要求",
                        text: $form.extraRequirements,
                        prompt: Text("例如：本周有比赛需要减量、最近膝盖不适避免爬坡..."),
                        axis: .vertical
                    )
                    .lineLimit(3...8)
                    .focused($focusedField, equals: "extraRequirements")
                }

                // 生成按钮
                Section {
                    Button {
                        focusedField = nil
                        onGenerate(form)
                    } label: {
                        HStack {
                            if generating {
                                ProgressView()
                            } else {
                                Image(systemName: "sparkles")
                            }
                            Text(generating ? "生成中..." : "生成训练计划")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(generating)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("AI 生成训练计划")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var goalDetailSection: some View {
        switch form.goal {
        case "ftp_improvement":
            detailSection(title: "FTP 目标设定", footnote: "专业建议：3 周计划 FTP 提升 3-5% 为合理目标") {
                detailField(title: "当前 FTP (W)", key: "currentFtp", keyboard: .numberPad)
                detailField(title: "目标 FTP (W)", key: "targetFtp", keyboard: .numberPad)
            }
        case "aerobic_endurance":
            detailSection(title: "有氧耐力目标", footnote: "专业建议：逐步将 Z2 时长从 60 分钟递增到目标值") {
                detailField(title: "目标单次 Z2 时长", key: "targetZ2Duration", placeholder: "如 120", keyboard: .numberPad)
                detailField(title: "目标周训练量 (小时)", key: "targetWeeklyHours", placeholder: "如 8", keyboard: .numbersAndPunctuation)
            }
        case "vo2max_development":
            detailSection(title: "VO₂max 目标", footnote: "专业建议：高强度间歇是提升 VO₂max 的有效手段") {
                detailField(title: "当前 VO₂max", key: "currentVo2", placeholder: "如 45", keyboard: .numberPad)
                detailField(title: "目标 VO₂max", key: "targetVo2", placeholder: "如 50", keyboard: .numberPad)
            }
        case "sprint_power":
            detailSection(title: "冲刺能力目标", footnote: "专业建议：以 5-30 秒全力冲刺为核心，配合充足恢复") {
                detailField(title: "目标冲刺功率 (W)", key: "targetSprintPower", placeholder: "如 800", keyboard: .numberPad)
                detailField(title: "冲刺持续时间 (秒)", key: "sprintDuration", placeholder: "如 15", keyboard: .numberPad)
            }
        case "triathlon":
            detailSection(title: "铁三目标", footnote: nil) {
                Picker("参赛距离", selection: detailBinding("raceDistance")) {
                    Text("请选择").tag("")
                    Text("冲刺赛（S）").tag("sprint")
                    Text("标准赛（O）").tag("olympic")
                    Text("半程（70.3）").tag("half")
                    Text("全程（140.6）").tag("full")
                }
                detailField(title: "目标完赛时间", key: "targetFinishTime", placeholder: "如 3小时30分", keyboard: .default)
            }
        case "general_fitness":
            detailSection(title: "综合提升", footnote: nil) {
                detailField(title: "当前 FTP (W)", key: "currentFtp", keyboard: .numberPad)
                detailField(title: "重点方向", key: "focusArea", placeholder: "如 爬坡、耐力", keyboard: .default)
            }
        default:
            EmptyView()
        }
    }

    private func detailBinding(_ key: String) -> Binding<String> {
        Binding(
            get: { form.goalDetail[key] ?? "" },
            set: { form.goalDetail[key] = $0 }
        )
    }

    private func detailField(title: String, key: String, placeholder: String? = nil, keyboard: UIKeyboardType) -> some View {
        LabeledContent(title) {
            TextField(placeholder ?? "未填写", text: detailBinding(key))
                .keyboardType(keyboard)
                .multilineTextAlignment(.trailing)
                .focused($focusedField, equals: key)
        }
    }

    private func detailSection<Content: View>(title: String, footnote: String?, @ViewBuilder content: () -> Content) -> some View {
        Section {
            content()
        } header: {
            Text(title)
        } footer: {
            if let footnote {
                Text(footnote)
            }
        }
    }
}

// MARK: - Goal Plan Progress Sheet

struct GoalPlanProgressSheet: View {
    let progressData: PlanProgressResponse?
    let loading: Bool
    
    @Environment(\.dismiss) private var dismiss
    
    private let assessmentLabels: [String: (label: String, color: Color)] = [
        "on_track": ("按计划进行", .green),
        "ahead": ("超前进度", .teal),
        "behind": ("落后进度", .orange),
        "infeasible": ("需调整目标", .red),
    ]
    
    private let blockStatusColors: [String: Color] = [
        "active": .teal,
        "completed": .green,
        "planned": .gray,
        "skipped": .orange,
    ]
    private let blockStatusLabels: [String: String] = [
        "active": "进行中",
        "completed": "已完成",
        "planned": "待开始",
        "skipped": "已跳过",
    ]

    var body: some View {
        NavigationStack {
            List {
                if !loading, let data = progressData {
                    // 目标信息
                    Section("训练目标") {
                        if let goalKind = data.goalKind {
                            LabeledContent("目标", value: goalKindLabel(goalKind))
                        }
                        if let targetDate = data.targetDate {
                            LabeledContent("目标日期", value: targetDate)
                        }
                    }

                    // 进度评估
                    if let progress = data.progressState {
                        Section("进度评估") {
                            if let assessment = progress.targetAssessment,
                               let info = assessmentLabels[assessment] {
                                LabeledContent("评估") {
                                    Text(info.label)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(info.color)
                                }
                            }

                            if let summary = progress.summary {
                                Text(summary)
                                    .font(.subheadline)
                            }

                            if let focus = progress.nextFocus {
                                Label("下一步重点：\(focus)", systemImage: "arrow.forward.circle.fill")
                                    .font(.footnote)
                            }
                        }
                    }

                    // 统计
                    if let stats = data.stats {
                        Section("统计概览") {
                            LabeledContent("已完成周期", value: "\(stats.completedBlocks ?? 0)/\(stats.totalBlocks ?? 0)")
                            LabeledContent("总课程数", value: "\(stats.totalWorkouts ?? 0)")
                            LabeledContent("已推送", value: "\(stats.pushedWorkouts ?? 0)")
                        }
                    }

                    // 当前活跃 Block
                    if let block = data.activeBlock {
                        Section("当前周期 · Block \(block.blockIndex + 1)") {
                            if let theme = block.theme {
                                Text(theme).font(.subheadline.weight(.semibold))
                            }
                            if let focus = block.focus {
                                Text(focus).font(.footnote).foregroundStyle(.secondary)
                            }
                            if let start = block.blockStartDate, let end = block.blockEndDate {
                                LabeledContent("起止日期", value: "\(start) ~ \(end)")
                            }
                        }
                    }

                    // Block 时间线
                    if let blocks = data.blocks, !blocks.isEmpty {
                        Section("周期时间线") {
                            ForEach(blocks) { block in
                                blockTimelineRow(block: block)
                            }
                        }
                    }

                    // 下次复盘
                    if let nextReview = data.nextReviewAt {
                        Section {
                            Label("下次复盘：\(nextReview)", systemImage: "clock.badge.checkmark")
                                .font(.footnote)
                        }
                    }
                }
            }
            .overlay {
                if loading {
                    ProgressView("加载进度数据...")
                } else if progressData == nil {
                    ContentUnavailableView("暂无进度数据", systemImage: "chart.line.uptrend.xyaxis")
                }
            }
            .navigationTitle("训练进度")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private func blockTimelineRow(block: TrainingPlanBlock) -> some View {
        let status = block.status ?? "planned"
        let color = blockStatusColors[status] ?? .gray

        return LabeledContent {
            Text(blockStatusLabels[status] ?? status)
                .foregroundStyle(color)
        } label: {
            Label {
                Text(block.theme.map { "Block \(block.blockIndex + 1) · \($0)" } ?? "Block \(block.blockIndex + 1)")
                if let start = block.blockStartDate, let end = block.blockEndDate {
                    Text("\(start) ~ \(end)")
                }
            } icon: {
                Image(systemName: status == "completed" ? "checkmark.circle.fill" : status == "active" ? "circle.inset.filled" : "circle")
                    .foregroundStyle(color)
            }
        }
    }
}

// MARK: - Workout Calendar (UICalendarView)

/// 系统日历控件，有训练的日期显示标记点
struct WorkoutCalendarView: UIViewRepresentable {
    let workoutDates: Set<String>
    let selectedDate: String?
    let onSelect: (String) -> Void

    private static var gregorian: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        return cal
    }

    static func key(for components: DateComponents) -> String? {
        guard let y = components.year, let m = components.month, let d = components.day else { return nil }
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    static func components(for key: String) -> DateComponents? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return DateComponents(calendar: gregorian, year: parts[0], month: parts[1], day: parts[2])
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UICalendarView {
        let view = UICalendarView()
        view.calendar = Self.gregorian
        view.locale = Locale(identifier: "zh_CN")
        view.delegate = context.coordinator

        let selection = UICalendarSelectionSingleDate(delegate: context.coordinator)
        if let selectedDate, let comps = Self.components(for: selectedDate) {
            selection.setSelected(comps, animated: false)
            view.visibleDateComponents = comps
        }
        view.selectionBehavior = selection
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }

    func updateUIView(_ uiView: UICalendarView, context: Context) {
        let coordinator = context.coordinator
        let changed = coordinator.parent.workoutDates.symmetricDifference(workoutDates)
        coordinator.parent = self
        if !changed.isEmpty {
            uiView.reloadDecorations(forDateComponents: changed.compactMap(Self.components(for:)), animated: true)
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UICalendarView, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite, width > 0 else { return nil }
        let fitted = uiView.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        return CGSize(width: width, height: fitted.height)
    }

    @MainActor
    final class Coordinator: NSObject, UICalendarViewDelegate, UICalendarSelectionSingleDateDelegate {
        var parent: WorkoutCalendarView

        init(parent: WorkoutCalendarView) {
            self.parent = parent
        }

        func calendarView(_ calendarView: UICalendarView, decorationFor dateComponents: DateComponents) -> UICalendarView.Decoration? {
            guard let key = WorkoutCalendarView.key(for: dateComponents),
                  parent.workoutDates.contains(key) else { return nil }
            return .default(color: .tintColor, size: .large)
        }

        func dateSelection(_ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
            guard let dateComponents, let key = WorkoutCalendarView.key(for: dateComponents) else { return }
            parent.onSelect(key)
        }
    }
}
