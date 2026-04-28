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
}

// MARK: - Main View

struct TrainingView: View {
    @State private var plans: [TrainingPlan] = []
    @State private var selectedPlan: TrainingPlan?
    @State private var workouts: [Workout] = []
    @State private var workoutsByPlan: [Int: [Workout]] = [:]
    @State private var workoutPlanMetaByWorkoutId: [Int: (title: String, intro: String?)] = [:]
    @State private var loading = true
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
    @State private var scrollOffset: CGFloat = 0
    
    private var collapseProgress: CGFloat {
        min(max(scrollOffset / 60, 0), 1)
    }
    
    private let calendar = Calendar.current
    private let weekdayLabels = ["一", "二", "三", "四", "五", "六", "日"]
    
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
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 顶部标题栏（Apple Music 风格：静态大标题 + 右侧操作）
                HStack(alignment: .center) {
                    Text("训练课程")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer(minLength: 16)
                    
                    if !plans.isEmpty {
                        Button(action: { showPlanDetailsSheet = true }) {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 22))
                                .foregroundColor(.primary)
                                .frame(width: 32, height: 32)
                        }
                    }
                }
                .padding(.horizontal)
                .frame(height: 44)
                .background(Color(UIColor.systemBackground))
                
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 16) {
                        if loading {
                            VStack(spacing: 12) {
                                ProgressView()
                                Text("加载训练数据...")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 100)
                        } else if generating {
                            VStack(spacing: 12) {
                                ProgressView()
                                Text("AI 正在为您生成训练计划...").font(.subheadline).foregroundColor(.secondary)
                            }
                            .padding(.top, 60)
                    } else if adjustingSchedule {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("正在调整排期并同步至佳明...").font(.subheadline).foregroundColor(.secondary)
                        }
                        .padding(.top, 60)
                    } else {
                        // 日期切换器
                        HStack {
                            Button(action: prevDay) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .padding(.vertical, 8)
                                    .padding(.trailing, 16)
                            }
                            
                            Spacer()
                            
                            Button(action: { showCalendarSheet = true }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 15))
                                    Text(selectedDateTitle)
                                }
                                .font(.headline)
                                .foregroundColor(.primary)
                            }
                            
                            Spacer()
                            
                            Button(action: nextDay) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .padding(.vertical, 8)
                                    .padding(.leading, 16)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom)
                        
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
                                .padding(.horizontal)
                                .transition(.push(from: swipeDirection == .forward ? .trailing : .leading))
                                .id(selectedDate ?? "")
                            } else {
                                VStack(spacing: 12) {
                                    Image(systemName: "cup.and.saucer")
                                        .font(.title)
                                    Text("今日暂无训练安排")
                                        .font(.subheadline)
                                }
                                .foregroundColor(Color(UIColor.tertiaryLabel))
                                .frame(maxWidth: .infinity, minHeight: 140)
                                .transition(.push(from: swipeDirection == .forward ? .trailing : .leading))
                                .id(selectedDate ?? "")
                            }
                        }
                        .animation(.easeInOut(duration: 0.3), value: selectedDate)
                        
                        // 4. 底部操作面板（随内容滚动）
                        bottomActions
                    }
                }
                .padding(.vertical)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: ScrollOffsetKey.self,
                            value: -geo.frame(in: .named("trainingScroll")).origin.y
                        )
                    }
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .coordinateSpace(name: "trainingScroll")
            .onPreferenceChange(ScrollOffsetKey.self) { value in
                scrollOffset = value
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
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
                await loadData()
                selectedDate = todayStr()
            }
            .sheet(isPresented: $showGenSheet) {
                GeneratePlanSheet(
                    initialForm: genForm,
                    generating: $generating,
                    onGenerate: generatePlan
                )
                .presentationDetents([.fraction(0.8), .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showCalendarSheet) {
                NavigationView {
                    ScrollView {
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                Button(action: prevMonth) {
                                    Image(systemName: "chevron.left")
                                        .font(.headline.weight(.semibold))
                                        .foregroundColor(.primary)
                                        .frame(width: 32, height: 32)
                                }
                                .buttonStyle(.plain)

                                Spacer()

                                Text(monthTitle)
                                    .font(.title3.weight(.semibold))
                                    .foregroundColor(.primary)

                                Spacer()

                                Button(action: nextMonth) {
                                    Image(systemName: "chevron.right")
                                        .font(.headline.weight(.semibold))
                                        .foregroundColor(.primary)
                                        .frame(width: 32, height: 32)
                                }
                                .buttonStyle(.plain)
                            }

                            calendarView
                        }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(20)
                            .padding()
                    }
                    .background(Color(UIColor.systemGroupedBackground))
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
                NavigationView {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if plans.count > 1 {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("训练计划")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.secondary)

                                    VStack(spacing: 10) {
                                        planSelectionRow(
                                            title: "全部计划",
                                            isSelected: selectedPlan == nil,
                                            action: {
                                                selectedPlan = nil
                                            }
                                        )

                                        ForEach(plans) { item in
                                            planSelectionRow(
                                                title: item.planName,
                                                isSelected: selectedPlan?.trainingPlanId == item.trainingPlanId,
                                                action: {
                                                    selectedPlan = item
                                                    if let startDate = item.startDate, let d = dateFromString(startDate) {
                                                        currentMonth = d
                                                    }
                                                },
                                                deleteAction: {
                                                    planToDelete = item
                                                    showDeleteAlert = true
                                                }
                                            )
                                        }
                                    }
                                    .padding(12)
                                    .background(Color(UIColor.secondarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                }
                            }
                            
                            if let detailPlan = selectedPlan ?? (plans.count == 1 ? sheetPlan : nil) {
                                Divider()

                                Text(detailPlan.planName)
                                    .font(.title2.weight(.bold))

                                if let weeks = detailPlan.durationWeeks {
                                    HStack {
                                        Image(systemName: "calendar.badge.clock")
                                        Text("\(weeks) 周周期")
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                }

                                Divider()

                                if let desc = detailPlan.description {
                                    Text(desc)
                                        .font(.system(size: 15))
                                        .foregroundColor(.primary)
                                        .lineSpacing(4)
                                }
                            }

                            if let plan = sheetPlan {
                                VStack(spacing: 12) {
                                    Button(action: {
                                        pushToGarmin(plan)
                                    }) {
                                        HStack {
                                            Image(systemName: "arrow.up.circle")
                                            Text("将近期训练推至佳明日历")
                                        }
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(Color.teal)
                                        .cornerRadius(12)
                                    }
                                    
                                    Button(action: {
                                        planToRegenerate = plan
                                    }) {
                                        HStack {
                                            Image(systemName: "sparkles")
                                            Text("重新生成计划")
                                        }
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing))
                                        .cornerRadius(12)
                                    }
                                    
                                    if shouldShowBottomDeletePlanButton {
                                        Button(action: {
                                            planToDelete = plan
                                            showDeleteAlert = true
                                        }) {
                                            HStack {
                                                Image(systemName: "trash")
                                                Text("删除计划")
                                            }
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.red)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 14)
                                            .background(Color.red.opacity(0.1))
                                            .cornerRadius(12)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(20)
                        .padding(.bottom, 28)
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
                        .presentationDetents([.fraction(0.8), .large])
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
                    NavigationView {
                        VStack(spacing: 20) {
                            // 当前课程信息
                            VStack(spacing: 6) {
                                let cfg = sportConfig[wk.sport ?? ""] ?? ("🏃", .gray, "活动")
                                HStack(spacing: 8) {
                                    Text(cfg.icon).font(.title2)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(wk.workoutName ?? "训练课程")
                                            .font(.headline)
                                        Text("当前日期: \(wk.workoutDate ?? "未知")")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding()
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(12)
                                
                                if wk.garminScheduleId != nil {
                                    HStack(spacing: 4) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.orange)
                                            .font(.caption)
                                        Text("该课程已同步到 Garmin，移动后将同时更新 Garmin 日历")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            
                            // 日期选择
                            VStack(alignment: .leading, spacing: 8) {
                                Text("选择目标日期")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                                
                                DatePicker(
                                    "目标日期",
                                    selection: $moveTargetDate,
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.graphical)
                                .tint(.teal)
                                .padding(.horizontal)
                            }
                            
                            Spacer()
                            
                            // 确认按钮
                            Button(action: {
                                let wkToMove = wk
                                workoutToMove = nil
                                rescheduleWorkout(workout: wkToMove, to: moveTargetDate)
                            }) {
                                HStack {
                                    Image(systemName: "arrow.right.circle.fill")
                                    let f = DateFormatter()
                                    let _ = f.dateFormat = "M月d日"
                                    Text("移动到 \(f.string(from: moveTargetDate))")
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.teal)
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                            .padding(.bottom)
                        }
                        .navigationTitle("移动训练课程")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("取消") { workoutToMove = nil }
                            }
                        }
                    }
                    .presentationDetents([.large])
                }
            }
            }
        }
    }
    
    // Note: old trainingHeader removed
    
    // MARK: - 底部悬浮按钮
    
    private var bottomActions: some View {
        Group {
            if plans.isEmpty {
                HStack(spacing: 12) {
                    Button(action: { showGenSheet = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                            Text("AI 生成计划")
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical)
            }
        }
    }
    
    // MARK: - Calendar

    var calendarView: some View {
        VStack(spacing: 4) {
            HStack {
                ForEach(weekdayLabels, id: \.self) { d in
                    Text(d).font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            let days = generateCalendarDays()
            ForEach(0..<(days.count / 7 + (days.count % 7 > 0 ? 1 : 0)), id: \.self) { week in
                HStack(spacing: 2) {
                    ForEach(0..<7, id: \.self) { day in
                        let idx = week * 7 + day
                        if idx < days.count, let d = days[idx] {
                            let hasWorkout = workoutDates.contains(d)
                            let isToday = d == todayStr()
                            let isSelected = d == selectedDate
                            let dayWorkouts = visibleWorkouts.filter { $0.workoutDate == d }
                            
                            Button(action: { 
                                if let curr = selectedDate, let currDate = dateFromString(curr), let newDate = dateFromString(d) {
                                    swipeDirection = newDate > currDate ? .forward : .backward
                                }
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                                    selectedDate = d 
                                    showCalendarSheet = false
                                }
                            }) {
                                VStack(spacing: 2) {
                                    Text(dayNumber(d))
                                        .font(.system(size: 12, weight: isToday ? .bold : .regular))
                                        .foregroundColor(isSelected ? .white : isToday ? .teal : .primary)
                                    
                                    // 运动类型小图标
                                    if hasWorkout {
                                        HStack(spacing: 1) {
                                            let sports = Set(dayWorkouts.compactMap { $0.sport })
                                            ForEach(Array(sports.prefix(2)), id: \.self) { sport in
                                                Text(sportConfig[sport]?.icon ?? "🏃")
                                                    .font(.system(size: 7))
                                            }
                                        }
                                    } else {
                                        Text(" ").font(.system(size: 7))
                                    }
                                }
                                .frame(maxWidth: .infinity, minHeight: 42)
                                .background(
                                    isSelected ? Color.teal :
                                    isToday ? Color.teal.opacity(0.15) :
                                    hasWorkout ? Color.teal.opacity(0.06) : Color.clear
                                )
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Text("").frame(maxWidth: .infinity, minHeight: 42)
                        }
                    }
                }
            }
        }
        .padding(12).background(.white).cornerRadius(14)
    }

    @ViewBuilder
    private func planSelectionRow(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void,
        deleteAction: (() -> Void)? = nil
    ) -> some View {
        HStack(spacing: 10) {
            Button(action: action) {
                HStack(spacing: 12) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.teal)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isSelected ? Color.teal.opacity(0.12) : Color(UIColor.systemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isSelected ? Color.teal.opacity(0.35) : Color.clear, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            if let deleteAction {
                Button(role: .destructive, action: deleteAction) {
                    Image(systemName: "trash")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.red)
                        .frame(width: 40, height: 40)
                        .background(Color.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    var workoutDates: Set<String> {
        Set(visibleWorkouts.compactMap { $0.workoutDate })
    }
    
    // MARK: - Calendar Helpers
    
    private func generateCalendarDays() -> [String?] {
        let comps = calendar.dateComponents([.year, .month], from: currentMonth)
        guard let firstDay = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: firstDay) else { return [] }
        
        let weekday = calendar.component(.weekday, from: firstDay)
        let offset = (weekday + 5) % 7
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        var days: [String?] = Array(repeating: nil, count: offset)
        for d in range {
            let date = calendar.date(byAdding: .day, value: d - 1, to: firstDay)!
            days.append(formatter.string(from: date))
        }
        return days
    }
    
    private func dayNumber(_ dateStr: String) -> String {
        if let day = Int(dateStr.suffix(2)) {
            return String(day)
        }
        return String(dateStr.suffix(2))
    }
    
    private func todayStr() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private func isAIGeneratedPlan(_ plan: TrainingPlan) -> Bool {
        let source = plan.source?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        return source.contains("ai")
    }
    
    private func prevMonth() {
        currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
    }
    
    private func nextMonth() {
        currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
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
        // 1. 先从本地缓存加载，立即显示
        await loadFromCache()
        
        // 2. 后台请求更新
        loading = true
        do {
            async let statusReq = try? APIService.shared.getPlanStatus()
            async let plansReq = try APIService.shared.getTrainingPlans()
            let (statusOpt, plansRes) = await (statusReq, try plansReq)
            
            let fetchedPlans = plansRes.plans
            var currentPlanId: Int?
            
            await MainActor.run {
                self.plans = fetchedPlans
                if let current = self.selectedPlan,
                   !fetchedPlans.contains(where: { $0.trainingPlanId == current.trainingPlanId }) {
                    self.selectedPlan = nil
                }
                currentPlanId = fetchedPlans.first(where: { $0.status == "active" })?.trainingPlanId
                    ?? fetchedPlans.first?.trainingPlanId
            }
            
            // 并发加载所有计划的课程（而非串行循环）
            if !fetchedPlans.isEmpty {
                // 为每个 plan 创建独立 Task 并发请求 detail
                let tasks = fetchedPlans.map { plan in
                    Task { () -> (Int, [Workout])? in
                        guard let detail = try? await APIService.shared.getPlanDetail(planId: plan.trainingPlanId) else { return nil }
                        return (plan.trainingPlanId, detail.workouts)
                    }
                }
                
                // 收集所有结果
                var allWorkouts: [Workout] = []
                var groupedWorkouts: [Int: [Workout]] = [:]
                var planMetaByWorkoutId: [Int: (title: String, intro: String?)] = [:]
                
                for task in tasks {
                    if let (planId, workoutsForPlan) = await task.value {
                        allWorkouts.append(contentsOf: workoutsForPlan)
                        groupedWorkouts[planId] = workoutsForPlan
                        if let plan = fetchedPlans.first(where: { $0.trainingPlanId == planId }) {
                            for workout in workoutsForPlan {
                                planMetaByWorkoutId[workout.trainingPlanWorkoutId] = (
                                    title: plan.planName,
                                    intro: plan.description
                                )
                            }
                        }
                    }
                }
                
                await MainActor.run {
                    self.workouts = allWorkouts
                    self.workoutsByPlan = groupedWorkouts
                    self.workoutPlanMetaByWorkoutId = planMetaByWorkoutId
                    // 导航到最新计划的起始月（仅首次加载时）
                    if let firstPlan = fetchedPlans.first,
                       let startDate = firstPlan.startDate,
                       let date = dateFromString(startDate) {
                        self.currentMonth = date
                    }
                    self.loading = false
                }
            } else {
                await MainActor.run {
                    self.workouts = []
                    self.workoutsByPlan = [:]
                    self.workoutPlanMetaByWorkoutId = [:]
                    self.loading = false
                }
            }
            
            if statusOpt?.isGenerating == true {
                await MainActor.run { generating = true }
                startPolling(oldPlanId: currentPlanId)
            }
        } catch {
            await MainActor.run { loading = false }
        }
    }
    
    private func loadFromCache() async {
        // 加载 plans
        guard let plansRes = await APIService.shared.cached("/training/plan", as: TrainingPlanListResponse.self) else { return }
        let fetchedPlans = plansRes.plans
        
        await MainActor.run {
            self.plans = fetchedPlans
            if let current = self.selectedPlan,
               !fetchedPlans.contains(where: { $0.trainingPlanId == current.trainingPlanId }) {
                self.selectedPlan = nil
            }
        }
        
        if !fetchedPlans.isEmpty {
            var allWorkouts: [Workout] = []
            var groupedWorkouts: [Int: [Workout]] = [:]
            var planMetaByWorkoutId: [Int: (title: String, intro: String?)] = [:]
            
            for plan in fetchedPlans {
                if let detail = await APIService.shared.cached("/training/plan/\(plan.trainingPlanId)", as: TrainingPlanDetailResponse.self) {
                    allWorkouts.append(contentsOf: detail.workouts)
                    groupedWorkouts[plan.trainingPlanId] = detail.workouts
                    for workout in detail.workouts {
                        planMetaByWorkoutId[workout.trainingPlanWorkoutId] = (
                            title: plan.planName,
                            intro: plan.description
                        )
                    }
                }
            }
            
            await MainActor.run {
                self.workouts = allWorkouts
                self.workoutsByPlan = groupedWorkouts
                self.workoutPlanMetaByWorkoutId = planMetaByWorkoutId
                if let firstPlan = fetchedPlans.first,
                   let startDate = firstPlan.startDate,
                   let date = dateFromString(startDate) {
                    self.currentMonth = date
                }
                self.loading = false
            }
        } else {
            await MainActor.run {
                self.loading = false
            }
        }
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
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button(action: { withAnimation(.spring(response: 0.3)) { expanded.toggle() } }) {
                HStack(spacing: 10) {
                    Text(config.icon).font(.title3)
                        .frame(width: 40, height: 40)
                        .background(config.color.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text(workout.workoutName ?? "未命名")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                        HStack(spacing: 8) {
                            if let dur = workout.durationMin {
                                Label("\(dur)min", systemImage: "clock")
                                    .font(.caption2).foregroundColor(.secondary)
                            }
                            if let tss = workout.tssEstimate {
                                Text("TSS \(tss)")
                                    .font(.caption2).foregroundColor(.secondary)
                            }
                            if let km = workout.distanceKm {
                                Text("\(String(format: "%.1f", km))km")
                                    .font(.caption2).foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            .padding(14)
            
            if expanded {
                Divider().padding(.horizontal, 14)
                
                VStack(alignment: .leading, spacing: 10) {
                    // 描述
                    if let desc = workout.description, !desc.isEmpty {
                        MarkdownTextView(markdown: desc)
                            .padding(10)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(10)
                    }
                    
                    // 步骤
                    if let steps = workout.steps, !steps.isEmpty {
                        Text("训练步骤").font(.caption.weight(.semibold)).foregroundColor(.secondary)
                        ForEach(Array(steps.enumerated()), id: \.offset) { _, step in
                            StepCardView(step: step)
                        }
                    }
                    
                    if onCancelSchedule != nil || onPostpone != nil || onMoveTo != nil {
                        Divider().padding(.top, 6).padding(.bottom, 6)
                        HStack(spacing: 20) {
                            if let cancel = onCancelSchedule {
                                Button(action: cancel) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "trash")
                                        Text("删除")
                                    }
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.red)
                                }
                            }
                            if let postpone = onPostpone {
                                Button(action: postpone) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "clock") 
                                        Text("顺延其后")
                                    }
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.orange)
                                }
                            }
                            if let moveTo = onMoveTo {
                                Button(action: moveTo) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.right.circle")
                                        Text("移动至")
                                    }
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.teal)
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 4)
                        .padding(.bottom, 4)
                    }
                }
                .padding(14)
            }
            
            Divider().padding(.horizontal, 14)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(displayPlanTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(displayPlanIntro)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 12)
        }
        .background(Color.white)
        .cornerRadius(16)
        .onAppear { expanded = initiallyExpanded }
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

struct StepCardView: View {
    let step: WorkoutStep
    
    var color: Color { stepColors[step.type] ?? .gray }
    var label: String { stepLabels[step.type] ?? step.type }
    
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
        } else {
            // 单步骤
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
            .background(.white)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(UIColor.systemGray4), lineWidth: 0.5))
        }
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
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 运动类型
                    VStack(alignment: .leading, spacing: 8) {
                        Text("运动类型").font(.headline)
                        HStack(spacing: 10) {
                            ForEach(sportOptions, id: \.key) { option in
                                Button(action: {
                                    if form.sports.contains(option.key) {
                                        if form.sports.count > 1 { form.sports.remove(option.key) }
                                    } else { form.sports.insert(option.key) }
                                    if !form.sports.contains("cycling") {
                                        form.lsdDays = []
                                    } else if form.lsdDays.isEmpty, let fallback = form.trainDays.max() {
                                        form.lsdDays = [fallback]
                                    }
                                    if form.sports.count <= 1 {
                                        form.multiSportDay = false
                                    }
                                }) {
                                    VStack(spacing: 4) {
                                        Text(option.icon).font(.title2)
                                        Text(option.label).font(.caption.weight(.medium))
                                    }
                                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                                    .background(form.sports.contains(option.key) ? Color.teal.opacity(0.15) : Color(UIColor.systemGray6))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(form.sports.contains(option.key) ? Color.teal : Color.clear, lineWidth: 2)
                                    )
                                }
                                .foregroundColor(.primary)
                            }
                        }

                        if form.sports.count > 1 {
                            Toggle("同一天可安排多种运动的训练课程", isOn: $form.multiSportDay)
                                .font(.subheadline)
                                .tint(.teal)
                            if !form.multiSportDay {
                                Text("未开启时，每天只安排一项运动，多项目轮流交替")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // 训练目标
                    VStack(alignment: .leading, spacing: 8) {
                        Text("训练目标").font(.headline)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(trainingGoals, id: \.key) { goal in
                                Button(action: {
                                    form.goal = goal.key
                                    if goal.key == "triathlon" {
                                        form.sports = ["cycling", "running", "swimming"]
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Text(goal.icon)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(goal.label).font(.caption.weight(.semibold))
                                            Text(goal.desc).font(.system(size: 9)).foregroundColor(.secondary)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(10)
                                    .background(form.goal == goal.key ? Color.purple.opacity(0.12) : Color(UIColor.systemGray6))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(form.goal == goal.key ? Color.purple : Color.clear, lineWidth: 2)
                                    )
                                }
                                .foregroundColor(.primary)
                            }
                        }
                    }

                    goalDetailSection
                    
                    // 训练日
                    VStack(alignment: .leading, spacing: 8) {
                        Text("训练日").font(.headline)
                        HStack(spacing: 6) {
                            ForEach(weekdayKeys, id: \.key) { wk in
                                Button(action: {
                                    if form.trainDays.contains(wk.key) {
                                        if form.trainDays.count > 1 { form.trainDays.remove(wk.key) }
                                    } else { form.trainDays.insert(wk.key) }
                                    form.lsdDays = form.lsdDays.intersection(form.trainDays)
                                    if form.lsdDays.isEmpty, form.sports.contains("cycling"), let fallback = form.trainDays.max() {
                                        form.lsdDays = [fallback]
                                    }
                                }) {
                                    Text(wk.label)
                                        .font(.system(size: 13, weight: .medium))
                                        .frame(width: 36, height: 36)
                                        .background(form.trainDays.contains(wk.key) ? Color.teal : Color(UIColor.systemGray5))
                                        .foregroundColor(form.trainDays.contains(wk.key) ? .white : .primary)
                                        .clipShape(Circle())
                                }
                            }
                        }
                    }

                    if form.sports.contains("cycling") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("长距离骑行日（LSD）").font(.headline)
                            HStack(spacing: 6) {
                                ForEach(weekdayKeys.filter { form.trainDays.contains($0.key) }, id: \.key) { wk in
                                    Button(action: {
                                        if form.lsdDays.contains(wk.key) {
                                            form.lsdDays.remove(wk.key)
                                        } else {
                                            form.lsdDays.insert(wk.key)
                                        }
                                    }) {
                                        Text(wk.label)
                                            .font(.system(size: 13, weight: .medium))
                                            .frame(width: 36, height: 36)
                                            .background(form.lsdDays.contains(wk.key) ? Color.orange : Color(UIColor.systemGray5))
                                            .foregroundColor(form.lsdDays.contains(wk.key) ? .white : .primary)
                                            .clipShape(Circle())
                                    }
                                }
                            }
                            Text("LSD 日可安排 2-4 小时长骑")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("起始日期").font(.headline)
                        DatePicker(
                            "起始日期",
                            selection: $form.startDate,
                            in: Date()...,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "zh_CN"))
                        .environment(\.calendar, Calendar(identifier: .gregorian))
                    }
                    
                    // TSS 预设
                    VStack(alignment: .leading, spacing: 8) {
                        Text("周训练量").font(.headline)
                        HStack(spacing: 8) {
                            ForEach(tssPresets, id: \.key) { preset in
                                Button(action: { form.tssLevel = preset.key }) {
                                    VStack(spacing: 2) {
                                        Text(preset.label).font(.caption.weight(.semibold))
                                        Text(preset.tss).font(.system(size: 9, weight: .bold)).foregroundColor(.teal)
                                        Text(preset.hours).font(.system(size: 8)).foregroundColor(.secondary)
                                        Text(preset.desc).font(.system(size: 8)).foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                                    .background(form.tssLevel == preset.key ? Color.teal.opacity(0.15) : Color(UIColor.systemGray6))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(form.tssLevel == preset.key ? Color.teal : Color.clear, lineWidth: 2)
                                    )
                                }
                                .foregroundColor(.primary)
                            }
                        }
                    }

                    // 周数
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("计划周数").font(.headline)
                            Spacer()
                            Text("\(Int(form.weeks)) 周").font(.subheadline.weight(.bold)).foregroundColor(.teal)
                        }
                        Slider(value: $form.weeks, in: 1...12, step: 1).tint(.teal)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("其他要求").font(.headline)
                        TextEditor(text: $form.extraRequirements)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 96)
                            .padding(10)
                            .background(Color(UIColor.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color(UIColor.systemGray5), lineWidth: 1)
                            )
                            .overlay(alignment: .topLeading) {
                                if form.extraRequirements.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text("例如：本周有比赛需要减量、最近膝盖不适避免爬坡...")
                                        .font(.subheadline)
                                        .foregroundColor(Color(UIColor.placeholderText))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 18)
                                        .allowsHitTesting(false)
                                }
                            }
                    }
                    
                    // 生成按钮
                    Button(action: {
                        focusedField = nil
                        onGenerate(form)
                    }) {
                        HStack {
                            if generating {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "sparkles")
                            }
                            Text(generating ? "生成中..." : "生成训练计划")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(
                            LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing)
                        )
                        .foregroundColor(.white).cornerRadius(14)
                    }
                    .disabled(generating)
                }
                .padding()
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
            detailCard(title: "FTP 目标设定", icon: "⚡", footnote: "专业建议：3 周计划 FTP 提升 3-5% 为合理目标") {
                HStack(spacing: 12) {
                    detailField(title: "当前 FTP (W)", key: "currentFtp", keyboard: .numberPad)
                    detailField(title: "目标 FTP (W)", key: "targetFtp", keyboard: .numberPad)
                }
            }
        case "aerobic_endurance":
            detailCard(title: "有氧耐力目标", icon: "💚", footnote: "专业建议：逐步将 Z2 时长从 60 分钟递增到目标值") {
                HStack(spacing: 12) {
                    detailField(title: "目标单次 Z2 时长", key: "targetZ2Duration", placeholder: "如 120", keyboard: .numberPad)
                    detailField(title: "目标周训练量 (小时)", key: "targetWeeklyHours", placeholder: "如 8", keyboard: .numbersAndPunctuation)
                }
            }
        case "vo2max_development":
            detailCard(title: "VO₂max 目标", icon: "🔴", footnote: "专业建议：高强度间歇是提升 VO₂max 的有效手段") {
                HStack(spacing: 12) {
                    detailField(title: "当前 VO₂max", key: "currentVo2", placeholder: "如 45", keyboard: .numberPad)
                    detailField(title: "目标 VO₂max", key: "targetVo2", placeholder: "如 50", keyboard: .numberPad)
                }
            }
        case "sprint_power":
            detailCard(title: "冲刺能力目标", icon: "💥", footnote: "专业建议：以 5-30 秒全力冲刺为核心，配合充足恢复") {
                HStack(spacing: 12) {
                    detailField(title: "目标冲刺功率 (W)", key: "targetSprintPower", placeholder: "如 800", keyboard: .numberPad)
                    detailField(title: "冲刺持续时间 (秒)", key: "sprintDuration", placeholder: "如 15", keyboard: .numberPad)
                }
            }
        case "triathlon":
            detailCard(title: "铁三目标", icon: "🏆", footnote: nil) {
                VStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("参赛距离").font(.caption).foregroundColor(.secondary)
                        Picker("参赛距离", selection: detailBinding("raceDistance")) {
                            Text("请选择").tag("")
                            Text("冲刺赛（S）").tag("sprint")
                            Text("标准赛（O）").tag("olympic")
                            Text("半程（70.3）").tag("half")
                            Text("全程（140.6）").tag("full")
                        }
                        .pickerStyle(.menu)
                    }
                    detailField(title: "目标完赛时间", key: "targetFinishTime", placeholder: "如 3小时30分", keyboard: .default)
                }
            }
        case "general_fitness":
            detailCard(title: "综合提升", icon: "🎯", footnote: nil) {
                HStack(spacing: 12) {
                    detailField(title: "当前 FTP (W)", key: "currentFtp", keyboard: .numberPad)
                    detailField(title: "重点方向", key: "focusArea", placeholder: "如 爬坡、耐力", keyboard: .default)
                }
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
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            TextField(placeholder ?? title, text: detailBinding(key))
                .textFieldStyle(.roundedBorder)
                .keyboardType(keyboard)
                .focused($focusedField, equals: key)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func detailCard<Content: View>(title: String, icon: String, footnote: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(icon) \(title)")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)
            content()
            if let footnote {
                Text(footnote)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color(UIColor.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
