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

private let tssPresets: [(key: String, label: String, tss: String, desc: String)] = [
    ("light", "轻量", "200-300", "入门/恢复期"),
    ("moderate", "中等", "300-450", "稳步提升"),
    ("heavy", "高量", "450-600", "进阶冲刺"),
    ("race", "赛季", "600+", "赛前备战"),
]

private let weekdayKeys: [(key: Int, label: String, full: String)] = [
    (1, "一", "周一"), (2, "二", "周二"), (3, "三", "周三"),
    (4, "四", "周四"), (5, "五", "周五"), (6, "六", "周六"), (7, "日", "周日"),
]

// MARK: - Main View

struct TrainingView: View {
    @State private var plans: [TrainingPlan] = []
    @State private var selectedPlan: TrainingPlan?
    @State private var workouts: [Workout] = []
    @State private var loading = true
    @State private var currentMonth = Date()
    @State private var selectedDate: String?
    @State private var showDeleteAlert = false
    @State private var showPlanDetailsSheet = false
    @State private var showCalendarSheet = false
    @State private var swipeDirection: TransitionDirection = .forward
    
    enum TransitionDirection {
        case forward, backward
    }
    
    // 调整排期
    @State private var adjustingSchedule = false
    @State private var workoutToCancel: Workout?
    @State private var workoutToPostpone: Workout?
    
    // AI 生成
    @State private var showGenSheet = false
    @State private var genGoal = "ftp_improvement"
    @State private var genSports: Set<String> = ["cycling"]
    @State private var genTrainDays: Set<Int> = [2, 3, 4, 5, 6, 7]
    @State private var genTssLevel = "moderate"
    @State private var genWeeks = 4.0
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
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日"
        return formatter.string(from: date)
    }
    
    var shortDateTitle: String {
        guard let dateStr = selectedDate, let date = dateFromString(dateStr) else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }
    
    var selectedDateWorkouts: [Workout] {
        guard let date = selectedDate else { return [] }
        return workouts.filter { $0.workoutDate == date }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 顶部仪表盘栏 (替代系统 NavigationBar 防止截断)
                HStack(alignment: .center) {
                    if let plan = selectedPlan {
                        Text(plan.planName)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    } else {
                        Text("近期无计划")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    
                    Spacer(minLength: 16)
                    
                    if selectedPlan != nil {
                        Button(action: { showPlanDetailsSheet = true }) {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 22))
                                .foregroundColor(.primary)
                                .frame(width: 32, height: 32)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 12)
                .background(Color(UIColor.systemGroupedBackground))
                
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
                        .padding(.horizontal, 20)
                        .padding(.bottom, 4)
                        
                        // 1. 直切主题：当日训练卡片流
                        ZStack {
                            if !selectedDateWorkouts.isEmpty {
                                VStack(alignment: .leading, spacing: 14) {
                                    ForEach(Array(selectedDateWorkouts.enumerated()), id: \.element.id) { idx, workout in
                                        WorkoutCardView(
                                            workout: workout, 
                                            initiallyExpanded: idx == 0,
                                            onCancelSchedule: { workoutToCancel = workout },
                                            onPostpone: { workoutToPostpone = workout }
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
                    genGoal: $genGoal,
                    genSports: $genSports,
                    genTrainDays: $genTrainDays,
                    genTssLevel: $genTssLevel,
                    genWeeks: $genWeeks,
                    generating: $generating,
                    onGenerate: generatePlan
                )
            }
            .sheet(isPresented: $showCalendarSheet) {
                NavigationView {
                    ScrollView {
                        calendarView
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
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showPlanDetailsSheet) {
                if let plan = selectedPlan {
                    NavigationView {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                Text(plan.planName)
                                    .font(.title2.weight(.bold))
                                
                                if let weeks = plan.durationWeeks {
                                    HStack {
                                        Image(systemName: "calendar.badge.clock")
                                        Text("\(weeks) 周周期")
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                }
                                
                                Divider()
                                
                                if let desc = plan.description {
                                    Text(desc)
                                        .font(.system(size: 15))
                                        .foregroundColor(.primary)
                                        .lineSpacing(4)
                                }
                                
                                Spacer(minLength: 32)
                                
                                VStack(spacing: 12) {
                                    Button(action: {
                                        showPlanDetailsSheet = false
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                            pushToGarmin()
                                        }
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
                                        showPlanDetailsSheet = false
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                            showGenSheet = true
                                        }
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
                                    
                                    Button(action: {
                                        showPlanDetailsSheet = false
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                            showDeleteAlert = true
                                        }
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
                            .padding(20)
                        }
                        .navigationTitle("计划详情")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("关闭") { showPlanDetailsSheet = false }
                            }
                        }
                    }
                    .presentationDetents([.medium, .large])
                }
            }
            .alert("删除训练计划", isPresented: $showDeleteAlert) {
                Button("删除", role: .destructive) { deletePlan() }
                Button("取消", role: .cancel) {}
            } message: {
                Text("确定要删除当前训练计划吗？此操作不可恢复。")
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
            }
        }
    }
    
    // Note: old trainingHeader removed
    
    // MARK: - 底部悬浮按钮
    
    private var bottomActions: some View {
        Group {
            if selectedPlan == nil {
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
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 30)
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
                            let dayWorkouts = workouts.filter { $0.workoutDate == d }
                            
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
    
    var workoutDates: Set<String> {
        Set(workouts.compactMap { $0.workoutDate })
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
        loading = true
        do {
            async let statusReq = try? APIService.shared.getPlanStatus()
            async let plansReq = try APIService.shared.getTrainingPlans()
            let (statusOpt, plansRes) = await (statusReq, try plansReq)
            
            let fetchedPlans = plansRes.plans
            var currentPlanId: Int?
            
            await MainActor.run {
                self.plans = fetchedPlans
                if let active = fetchedPlans.first(where: { $0.status == "active" }) ?? fetchedPlans.first {
                    self.selectedPlan = active
                    currentPlanId = active.trainingPlanId
                } else {
                    self.selectedPlan = nil
                }
            }
            if let planId = currentPlanId {
                let detail = try await APIService.shared.getPlanDetail(planId: planId)
                await MainActor.run {
                    self.workouts = detail.workouts
                    if let startDate = self.selectedPlan?.startDate,
                       let date = dateFromString(startDate) {
                        self.currentMonth = date
                    }
                    self.loading = false
                }
            } else {
                await MainActor.run {
                    self.workouts = []
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
    
    private func dateFromString(_ s: String) -> Date? {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.date(from: s)
    }
    
    private func deletePlan() {
        guard let plan = selectedPlan else { return }
        Task {
            try? await APIService.shared.deletePlan(planId: plan.trainingPlanId)
            await MainActor.run {
                selectedPlan = nil; workouts = []
            }
            await loadData()
        }
    }
    
    private func pushToGarmin() {
        guard let plan = selectedPlan else { return }
        Task {
            do {
                try await APIService.shared.pushPlanToGarmin(planId: plan.trainingPlanId)
            } catch {}
        }
    }
    
    private func generatePlan() {
        generating = true
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        
        let goal: [String: Any] = [
            "goal_type": genGoal,
            "sports": Array(genSports),
            "train_days": Array(genTrainDays),
            "tss_level": genTssLevel,
            "weeks": Int(genWeeks),
            "start_date": f.string(from: tomorrow),
        ]
        
        let req: [String: Any] = [
            "duration_weeks": Int(genWeeks),
            "start_date": f.string(from: tomorrow)
        ]
        
        let oldPlanId = selectedPlan?.trainingPlanId
        
        Task {
            if let oldId = oldPlanId {
                try? await APIService.shared.deletePlan(planId: oldId)
                await MainActor.run {
                    self.selectedPlan = nil
                    self.workouts = []
                    self.plans.removeAll { $0.trainingPlanId == oldId }
                }
            }
            
            do {
                try await APIService.shared.saveTrainingGoal(goal: goal)
                try await APIService.shared.generateTrainingPlan(req: req)
                await MainActor.run { showGenSheet = false }
                startPolling(oldPlanId: oldPlanId)
            } catch {
                await MainActor.run { generating = false }
            }
        }
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
                            self.selectedPlan = latest
                        }
                        let detail = try await APIService.shared.getPlanDetail(planId: latest.trainingPlanId)
                        await MainActor.run {
                            self.workouts = detail.workouts
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
}

// MARK: - Workout Card

struct WorkoutCardView: View {
    let workout: Workout
    var initiallyExpanded: Bool = false
    var onCancelSchedule: (() -> Void)? = nil
    var onPostpone: (() -> Void)? = nil
    @State private var expanded = false
    
    var config: (icon: String, color: Color, label: String) {
        sportConfig[workout.sport ?? ""] ?? ("🏃", .gray, workout.sport ?? "活动")
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
                    
                    if onCancelSchedule != nil || onPostpone != nil {
                        Divider().padding(.top, 6).padding(.bottom, 6)
                        HStack(spacing: 24) {
                            if let cancel = onCancelSchedule {
                                Button(action: cancel) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "trash")
                                        Text("删除本次排期")
                                    }
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.red)
                                }
                            }
                            if let postpone = onPostpone {
                                Button(action: postpone) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "clock") 
                                        Text("顺延其后所有")
                                    }
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.orange)
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
    @Binding var genGoal: String
    @Binding var genSports: Set<String>
    @Binding var genTrainDays: Set<Int>
    @Binding var genTssLevel: String
    @Binding var genWeeks: Double
    @Binding var generating: Bool
    let onGenerate: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 运动类型
                    VStack(alignment: .leading, spacing: 8) {
                        Text("运动类型").font(.headline)
                        HStack(spacing: 10) {
                            ForEach([("cycling", "🚴", "骑行"), ("running", "🏃", "跑步"), ("swimming", "🏊", "游泳"), ("strength", "🏋️", "力量")], id: \.0) { key, icon, label in
                                Button(action: {
                                    if genSports.contains(key) {
                                        if genSports.count > 1 { genSports.remove(key) }
                                    } else { genSports.insert(key) }
                                }) {
                                    VStack(spacing: 4) {
                                        Text(icon).font(.title2)
                                        Text(label).font(.caption.weight(.medium))
                                    }
                                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                                    .background(genSports.contains(key) ? Color.teal.opacity(0.15) : Color(UIColor.systemGray6))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(genSports.contains(key) ? Color.teal : Color.clear, lineWidth: 2)
                                    )
                                }
                                .foregroundColor(.primary)
                            }
                        }
                    }
                    
                    // 训练目标
                    VStack(alignment: .leading, spacing: 8) {
                        Text("训练目标").font(.headline)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(trainingGoals, id: \.key) { goal in
                                Button(action: { genGoal = goal.key }) {
                                    HStack(spacing: 6) {
                                        Text(goal.icon)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(goal.label).font(.caption.weight(.semibold))
                                            Text(goal.desc).font(.system(size: 9)).foregroundColor(.secondary)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(10)
                                    .background(genGoal == goal.key ? Color.purple.opacity(0.12) : Color(UIColor.systemGray6))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(genGoal == goal.key ? Color.purple : Color.clear, lineWidth: 2)
                                    )
                                }
                                .foregroundColor(.primary)
                            }
                        }
                    }
                    
                    // 训练日
                    VStack(alignment: .leading, spacing: 8) {
                        Text("训练日").font(.headline)
                        HStack(spacing: 6) {
                            ForEach(weekdayKeys, id: \.key) { wk in
                                Button(action: {
                                    if genTrainDays.contains(wk.key) {
                                        if genTrainDays.count > 1 { genTrainDays.remove(wk.key) }
                                    } else { genTrainDays.insert(wk.key) }
                                }) {
                                    Text(wk.label)
                                        .font(.system(size: 13, weight: .medium))
                                        .frame(width: 36, height: 36)
                                        .background(genTrainDays.contains(wk.key) ? Color.teal : Color(UIColor.systemGray5))
                                        .foregroundColor(genTrainDays.contains(wk.key) ? .white : .primary)
                                        .clipShape(Circle())
                                }
                            }
                        }
                    }
                    
                    // TSS 预设
                    VStack(alignment: .leading, spacing: 8) {
                        Text("周训练量").font(.headline)
                        HStack(spacing: 8) {
                            ForEach(tssPresets, id: \.key) { preset in
                                Button(action: { genTssLevel = preset.key }) {
                                    VStack(spacing: 2) {
                                        Text(preset.label).font(.caption.weight(.semibold))
                                        Text(preset.tss).font(.system(size: 9, weight: .bold)).foregroundColor(.teal)
                                        Text(preset.desc).font(.system(size: 8)).foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                                    .background(genTssLevel == preset.key ? Color.teal.opacity(0.15) : Color(UIColor.systemGray6))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(genTssLevel == preset.key ? Color.teal : Color.clear, lineWidth: 2)
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
                            Text("\(Int(genWeeks)) 周").font(.subheadline.weight(.bold)).foregroundColor(.teal)
                        }
                        Slider(value: $genWeeks, in: 1...12, step: 1).tint(.teal)
                    }
                    
                    // 生成按钮
                    Button(action: onGenerate) {
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
            .navigationTitle("AI 生成训练计划")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}
