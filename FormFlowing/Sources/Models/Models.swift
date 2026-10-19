import Foundation

// MARK: - Auth

struct LoginResponse: Codable, Sendable {
    let accessToken: String
    let refreshToken: String?
    let tokenType: String?
    let username: String?
    let tier: String?
    let tierExpiresAt: String?
}

// MARK: - Account

struct AccountInfo: Codable, Sendable {
    let accountId: Int?
    let username: String?
    let cnUsername: String?
    let globalUsername: String?
    let syncFrequency: Int?
    let enabled: Bool?
    let lastSyncTime: String?
    let syncCnGlobal: Bool?
    let syncToStrava: Bool?
    let stravaConnected: Bool?
    let igpsportConfigured: Bool?
    let igpsportUsername: String?
    let intervalsConfigured: Bool?
    let intervalsUserId: String?
}

// MARK: - Platform Status

struct PlatformStatus: Codable, Identifiable, Sendable {
    var id: String { platform }
    let platform: String
    let configured: Bool
    let connected: Bool
    let message: String
}

struct AccountStatusResponse: Codable, Sendable {
    let platforms: [PlatformStatus]
}

// MARK: - iGPSport Config

struct IGPSportConfigResponse: Codable, Sendable {
    let configured: Bool
    let username: String?
    let connected: Bool
    let message: String?
}

// MARK: - Intervals.icu Config

struct IntervalsConfigResponse: Codable, Sendable {
    let configured: Bool
    let userId: String?
    let connected: Bool
    let athleteName: String?
    let message: String?
}

// MARK: - Profile

struct ProfileResponse: Codable, Sendable {
    let profile: UserProfile?
}

struct UserProfile: Codable, Sendable {
    var weightKg: Double?
    var heightCm: Double?
    var birthDate: String?
    var gender: String?
    var ftpWatts: Int?
    var hrMax: Int?
    var hrRest: Int?
    var vo2Max: Double?
    var trainingPhase: String?
    var weeklyTssTarget: Int?
    var goalFtp: Int?
    var goalDesc: String?
    var extraNotes: String?
    var garminSyncedAt: String?
    var updatedAt: String?
    
    init(weightKg: Double? = nil, heightCm: Double? = nil, birthDate: String? = nil,
         gender: String? = nil, ftpWatts: Int? = nil, hrMax: Int? = nil,
         hrRest: Int? = nil, vo2Max: Double? = nil, trainingPhase: String? = nil,
         weeklyTssTarget: Int? = nil, goalFtp: Int? = nil, goalDesc: String? = nil,
         extraNotes: String? = nil, garminSyncedAt: String? = nil, updatedAt: String? = nil) {
        self.weightKg = weightKg; self.heightCm = heightCm; self.birthDate = birthDate
        self.gender = gender; self.ftpWatts = ftpWatts; self.hrMax = hrMax
        self.hrRest = hrRest; self.vo2Max = vo2Max; self.trainingPhase = trainingPhase
        self.weeklyTssTarget = weeklyTssTarget; self.goalFtp = goalFtp
        self.goalDesc = goalDesc; self.extraNotes = extraNotes
        self.garminSyncedAt = garminSyncedAt; self.updatedAt = updatedAt
    }
}

struct GarminStatusResponse: Codable, Sendable {
    let status: GarminUserStatus?
}

struct GarminUserStatus: Codable, Sendable {
    let calendarDate: String?
    let weightKg: Double?
    let heightCm: Double?
    let birthDate: String?
    let gender: String?
    let hrRest: Int?
    let hrMaxToday: Int?
    let hr7dAvgRest: Int?
    let hrLthr: Int?
    let vo2MaxRunning: Double?
    let vo2MaxCycling: Double?
    let fitnessAge: Int?
    let trainingStatus: String?
    let trainingStatusDesc: String?
    let acuteLoad: Double?
    let chronicLoad: Double?
    let acwrRatio: Double?
    let acwrStatus: String?
    // 训练负荷三分类
    let loadAerobicLow: Double?
    let loadAerobicHigh: Double?
    let loadAnaerobic: Double?
    let loadAerobicLowTargetMin: Double?
    let loadAerobicLowTargetMax: Double?
    let loadAerobicHighTargetMin: Double?
    let loadAerobicHighTargetMax: Double?
    let loadAnaerobicTargetMin: Double?
    let loadAnaerobicTargetMax: Double?
    let trainingLoadFeedback: String?
    // SpO2
    let spo2Avg: Int?
    let spo2Lowest: Int?
    let spo2Latest: Int?
    // 身体电量 & 压力
    let bodyBatteryLatest: Int?
    let bodyBatteryHigh: Int?
    let bodyBatteryLow: Int?
    let stressAvg: Int?
    let stressMax: Int?
    // 呼吸
    let respirationAvgWaking: Double?
    // 今日活动
    let steps: Int?
    let distanceM: Double?
    let caloriesTotal: Int?
    let caloriesActive: Int?
    let intensityMinutesWeek: Int?
    // 睡眠
    let sleepSeconds: Int?
    let sleepScore: Int?
    let sleepQuality: String?
    let sleepDeepSeconds: Int?
    let sleepLightSeconds: Int?
    let sleepRemSeconds: Int?
    let sleepAwakeSeconds: Int?
    // HRV
    let hrvLastNight: Int?
    let hrvWeeklyAvg: Int?
    let hrv5minHigh: Int?
    let hrvStatus: String?
    let hrvBaselineLow: Int?
    let hrvBaselineHigh: Int?
    // 体脂
    let bodyFatPct: Double?
    let primaryDevice: String?
    let garminSyncedAt: String?
}

// MARK: - Activities

struct ActivityListItem: Codable, Identifiable, Sendable {
    var id: Int { activityId }
    let activityId: Int
    let activityName: String?
    let activityType: String?
    let sport: String?
    let startTimeLocal: String?
    let duration: Double?
    let distance: Double?
    let totalAscent: Int?
    let avgHeartRate: Int?
    let avgPower: Int?
    let avgSpeed: Double?
    let totalCalories: Int?
    let region: String?
    let analysisSummary: String?
    let analysisTier: String?
    let analysisStatus: String?
}

struct ActivitySummary: Codable, Identifiable, Sendable {
    var id: Int { activityId }
    let activityId: Int
    let garminActivityId: Int?
    let region: String?
    let activityName: String?
    let activityType: String?
    let startTimeLocal: String?
    let sport: String?
    let subSport: String?
    let totalElapsedTime: Double?
    let totalTimerTime: Double?
    let totalDistance: Double?
    let totalAscent: Int?
    let totalDescent: Int?
    let avgHeartRate: Int?
    let maxHeartRate: Int?
    let avgPower: Int?
    let maxPower: Int?
    let normalizedPower: Int?
    let thresholdPower: Int?
    let intensityFactor: Double?
    let trainingStressScore: Double?
    let avgCadence: Int?
    let maxCadence: Int?
    let avgSpeed: Double?
    let maxSpeed: Double?
    let totalCalories: Int?
    let totalTrainingEffect: Double?
    let totalAnaerobicTrainingEffect: Double?
    let numLaps: Int?
}

struct LapData: Codable, Identifiable, Sendable {
    var id: Int { lapIndex }
    let lapIndex: Int
    let startTime: String?
    let totalElapsedTime: Double?
    let totalTimerTime: Double?
    let totalDistance: Double?
    let totalAscent: Int?
    let totalDescent: Int?
    let avgHeartRate: Int?
    let maxHeartRate: Int?
    let avgPower: Int?
    let maxPower: Int?
    let normalizedPower: Int?
    let avgCadence: Int?
    let avgSpeed: Double?
    let maxSpeed: Double?
    let totalCalories: Int?
}

struct RecordData: Codable, Sendable {
    let timestamp: String?
    let heartRate: Int?
    let power: Int?
    let cadence: Int?
    let speed: Double?
    let altitude: Double?
    let distance: Double?
    let latitude: Double?
    let longitude: Double?
    let temperature: Double?
}

// MARK: - Analysis

struct AnalysisResult: Codable, Identifiable, Sendable {
    var id: Int { analysisResultId }
    let analysisResultId: Int
    let activityId: Int
    let triggerType: String?
    let tier: String?
    let modelUsed: String?
    let resultMd: String?
    let memoryDelta: String?
    let canChat: Bool?
    let createdAt: String?
    let activityName: String?
    let activityDate: String?
    let totalDistance: Double?
    let totalTimerTime: Double?
    let avgHeartRate: Int?
    let avgPower: Int?
}

struct AnalysisHistoryResponse: Codable, Sendable {
    let total: Int
    let page: Int
    let size: Int
    let records: [AnalysisResult]
}

struct AnalysisByActivityResponse: Codable, Sendable {
    let records: [AnalysisResult]
}

struct AnalysisStatusResponse: Codable, Sendable {
    let analyzing: Bool
    let queueId: Int?
    let status: String?
}

// MARK: - Analysis Chat & Plan Adjustment

struct PlanAdjustment: Codable, Sendable {
    let action: String  // modify / skip / reduce / swap
    let workoutId: Int?
    let swapWithWorkoutId: Int?
    let reason: String?
    let changes: [String: AnyCodableValue]?
}

struct AdjustmentDetail: Codable, Sendable {
    let workoutId: Int?
    let action: String?
    let status: String?
    let message: String?
}

struct AdjustmentResult: Codable, Sendable {
    let applied: Int
    let skipped: Int
    let details: [AdjustmentDetail]?
    let message: String?
}

struct AnalysisChatResponse: Codable, Sendable {
    let analysisResultId: Int
    let reply: String
    let adjustments: [PlanAdjustment]?
    let adjustmentApplied: AdjustmentResult?
    let canChat: Bool?
}

struct ChatHistoryMessage: Codable, Sendable {
    let role: String
    let content: String
    let adjustments: [PlanAdjustment]?
    let createdAt: String?
}

struct ChatHistoryResponse: Codable, Sendable {
    let analysisResultId: Int
    let messages: [ChatHistoryMessage]
}

// MARK: - Training Plan

struct TrainingPlanStatusResponse: Codable, Sendable {
    let isGenerating: Bool
}

struct TrainingPlan: Codable, Identifiable, Sendable {
    var id: Int { trainingPlanId }
    let trainingPlanId: Int
    let planName: String
    let source: String?
    let description: String?
    let phase: String?
    let startDate: String?
    let endDate: String?
    let status: String?
    let durationWeeks: Int?
    let createdAt: String?
    // Goal-driven plan fields
    let mode: String?  // "fixed" | "goal_driven"
    let goalKind: String?
    let goalMetrics: [String: AnyCodableValue]?
    let targetDate: String?
    let microCycleDays: Int?
    let currentBlockIndex: Int?
    let nextReviewAt: String?
    let progressState: PlanProgressState?
}

struct TrainingPlanListResponse: Codable, Sendable {
    let plans: [TrainingPlan]
}

struct TrainingPlanDetailResponse: Codable, Sendable {
    let plan: TrainingPlan
    let blocks: [TrainingPlanBlock]?
    let workouts: [Workout]
}

/// GET /training/plan/details：计划列表 + 每个计划的详情
struct TrainingPlanBundleResponse: Codable, Sendable {
    let plans: [TrainingPlan]
    let details: [TrainingPlanDetailResponse]
}

struct Workout: Codable, Identifiable, Sendable {
    var id: Int { trainingPlanWorkoutId }
    let trainingPlanWorkoutId: Int
    let trainingPlanBlockId: Int?
    let workoutDate: String?
    let workoutName: String?
    let sport: String?
    let description: String?
    let tssEstimate: Int?
    let durationMin: Int?
    let distanceKm: Double?
    let garminWorkoutId: Int?
    let garminScheduleId: Int?
    let pushStatus: String?
    let steps: [WorkoutStep]?
}

struct WorkoutStep: Codable, Sendable {
    let type: String
    let durationSec: Int?
    let distanceM: Double?
    let powerLow: Int?
    let powerHigh: Int?
    let hrLow: Int?
    let hrHigh: Int?
    let cadenceLow: Int?
    let cadenceHigh: Int?
    let description: String?
    let count: Int?
    let steps: [WorkoutStep]?
    // 力量训练专用字段
    let exerciseName: String?
    let exerciseCategory: String?
    let weightValue: Double?
    let reps: Int?
    let displayName: String?  // 后端注入的中文动作名
    let isTimed: Bool?  // 计时型动作标记
    // 游泳/跑步配速
    let paceLowSec: Int?
    let paceHighSec: Int?
    let strokeType: String?
    let drillType: String?
    let equipmentType: String?
}

struct MemoryItem: Codable, Identifiable, Sendable {
    var id: String { type }
    let type: String
    let label: String?
    let content: String?
    let version: Int?
    let editable: Bool?
    let resettable: Bool?
    let template: String?
    let updatedAt: String?
}

struct MemoryListResponse: Codable, Sendable {
    let memories: [MemoryItem]
}

// MARK: - Goal-Driven Plan

struct PlanProgressState: Codable, Sendable {
    let assessedAt: String?
    let summary: String?
    let metrics: [String: AnyCodableValue]?
    let targetAssessment: String?  // on_track | ahead | behind | infeasible
    let nextFocus: String?
}

struct TrainingPlanBlock: Codable, Identifiable, Sendable {
    var id: Int { trainingPlanBlockId ?? blockIndex }
    let trainingPlanBlockId: Int?
    let blockIndex: Int
    let blockStartDate: String?
    let blockEndDate: String?
    let status: String?  // planned | active | completed | skipped
    let theme: String?
    let focus: String?
    let rationale: String?
    let reviewSummary: String?
    let reviewedAt: String?
}

struct GoalPlanResponse: Codable, Sendable {
    let message: String
    let trainingPlanId: Int
    let queueId: Int
}

struct ExtendBlockResponse: Codable, Sendable {
    let message: String
    let queueId: Int?
    let nextBlockIndex: Int?
    let nextBlockStart: String?
    let nextBlockEnd: String?
    let planStatus: String?
}

struct ReviewPlanResponse: Codable, Sendable {
    let message: String
    let queueId: Int
}

struct PlanProgressResponse: Codable, Sendable {
    let trainingPlanId: Int
    let planName: String
    let goalKind: String?
    let goalMetrics: [String: AnyCodableValue]?
    let targetDate: String?
    let status: String?
    let currentBlockIndex: Int?
    let nextReviewAt: String?
    let progressState: PlanProgressState?
    let stats: PlanStats?
    let activeBlock: TrainingPlanBlock?
    let blocks: [TrainingPlanBlock]?
}

struct PlanStats: Codable, Sendable {
    let totalBlocks: Int?
    let completedBlocks: Int?
    let activeBlockIndex: Int?
    let totalWorkouts: Int?
    let pushedWorkouts: Int?
}

// MARK: - Daily Check

struct DailyCheckItem: Codable, Sendable {
    let dailyCheckId: Int
    let checkType: String  // morning / evening
    let checkDate: String
    let bodyBattery: Int?
    let hrvLastNight: Double?
    let sleepScore: Int?
    let stressAvg: Int?
    let recommendation: String?
    let action: String?  // proceed / modify / skip / reschedule / no_change
    let adjustments: [DailyCheckAdjustment]?
    let userResponse: String?
    let status: String
}

struct DailyCheckAdjustment: Codable, Sendable {
    let action: String
    let workoutId: Int?
    let swapWithWorkoutId: Int?
    let reason: String?
}

struct DailyCheckTodayResponse: Codable, Sendable {
    let morning: DailyCheckItem?
    let evening: DailyCheckItem?
}

// MARK: - Training Goal

struct TrainingGoalResponse: Codable, Sendable {
    let content: String?
    let updatedAt: String?
}

// MARK: - Upload

struct UploadResponse: Codable, Sendable {
    let message: String?
    let activityId: Int?
}

// MARK: - Display Helpers

struct MetricDisplayItem {
    let label: String
    let value: String
    let unit: String
}

// MARK: - Subscription

struct SubscriptionStatusResponse: Codable, Sendable {
    let tier: String
    let status: String
    let startedAt: String?
    let expiresAt: String?
    let autoRenew: Bool?
    let limits: [String: AnyCodableValue]?
}

struct UsageQuotaItem: Codable, Sendable {
    let quotaType: String
    let period: String
    let periodKey: String
    let usedCount: Int
    let maxCount: Int
    let remaining: Int
}

struct UsageResponse: Codable, Sendable {
    let tier: String
    let period: String
    let quotas: [UsageQuotaItem]
}

/// 用于解析 limits 中的混合类型值（bool / int / string）
enum AnyCodableValue: Codable, Sendable {
    case int(Int)
    case bool(Bool)
    case string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(Bool.self) { self = .bool(v); return }
        if let v = try? container.decode(Int.self) { self = .int(v); return }
        if let v = try? container.decode(String.self) { self = .string(v); return }
        self = .string("")
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .int(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        case .string(let v): try container.encode(v)
        }
    }

    var intValue: Int? {
        if case .int(let v) = self { return v }
        return nil
    }

    var boolValue: Bool? {
        if case .bool(let v) = self { return v }
        return nil
    }
}


// MARK: - Training Trends（/trends）
//
// 注意：convertFromSnakeCase 会把数字后的字母转大写（best_42d → best42D），
// 所以含数字的字段都显式写 CodingKeys。数值字段一律 Double?，后端可能给 null。

struct TrendsResponse: Codable, Sendable {
    let asOf: String?
    let activityCount365d: Int?
    let pmc: TrendsPMC?
    let weekly: [TrendsWeek]?
    let powerCurve: [PowerCurvePoint]?
    let eftp90d: Double?
    let ftpSetting: Double?
    let aerobic: TrendsAerobic?
    let fatigue: TrendsFatigue?
    let runBests: [RunBest]?
    let runEf: [AerobicPeriod]?

    enum CodingKeys: String, CodingKey {
        case asOf, pmc, weekly, powerCurve, ftpSetting, aerobic, fatigue, runBests, runEf
        case activityCount365d = "activityCount365D"
        case eftp90d = "eftp90D"
    }
}

/// PMC 汇总；没有数据时后端返回 {}，所以全部可选
struct TrendsPMC: Codable, Sendable {
    let ctl: Double?
    let atl: Double?
    let tsb: Double?
    let ctl28dAgo: Double?
    let ctlRampPerWeek: Double?
    let series: [PMCPoint]?

    enum CodingKeys: String, CodingKey {
        case ctl, atl, tsb, ctlRampPerWeek, series
        case ctl28dAgo = "ctl28DAgo"
    }
}

struct PMCPoint: Codable, Sendable, Identifiable {
    var id: String { date }
    let date: String
    let tss: Double?
    let ctl: Double?
    let atl: Double?
    let tsb: Double?
}

struct TrendsWeek: Codable, Sendable, Identifiable {
    var id: String { weekStart }
    let weekStart: String
    let count: Int?
    let hours: Double?
    let tss: Double?
    let powerZonesS: [Double]?
    let hrZonesS: [Double]?
}

struct PowerCurvePoint: Codable, Sendable, Identifiable {
    var id: String { key }
    let duration: String
    let key: String
    let best42d: Double?
    let best42dDate: String?
    let bestPrev42d: Double?
    let best365d: Double?
    let best365dDate: String?

    enum CodingKeys: String, CodingKey {
        case duration, key
        case best42d = "best42D"
        case best42dDate = "best42DDate"
        case bestPrev42d = "bestPrev42D"
        case best365d = "best365D"
        case best365dDate = "best365DDate"
    }
}

struct AerobicPeriod: Codable, Sendable, Identifiable {
    var id: String { label }
    let label: String
    let sessions: Int?
    let efMedian: Double?
    let decouplingMedian: Double?
}

struct TrendsAerobic: Codable, Sendable {
    let periods: [AerobicPeriod]?
    let recent: [AerobicSession]?
}

/// recent 里的单场稳态骑行，只取用得到的字段
struct AerobicSession: Codable, Sendable {
    let date: String?
    let ef: Double?
    let decouplingPct: Double?
}

struct FatigueBest: Codable, Sendable {
    let best90d: Double?
    let bestPrev90d: Double?

    enum CodingKeys: String, CodingKey {
        case best90d = "best90D"
        case bestPrev90d = "bestPrev90D"
    }
}

struct TrendsFatigue: Codable, Sendable {
    let p5mAfter1000kj: FatigueBest?
    let p5mAfter2000kj: FatigueBest?
    let freshP5m90d: Double?

    enum CodingKeys: String, CodingKey {
        case p5mAfter1000kj = "p5mAfter1000Kj"
        case p5mAfter2000kj = "p5mAfter2000Kj"
        case freshP5m90d = "freshP5M90D"
    }
}

struct RunBest: Codable, Sendable, Identifiable {
    var id: String { key }
    let distance: String
    let key: String
    let best90dS: Double?
    let best90dDate: String?
    let best365dS: Double?
    let best365dDate: String?

    enum CodingKeys: String, CodingKey {
        case distance, key
        case best90dS = "best90DS"
        case best90dDate = "best90DDate"
        case best365dS = "best365DS"
        case best365dDate = "best365DDate"
    }
}

// MARK: - 单场活动指标（/trends/activity/{id}）

struct ActivityMetricsResponse: Codable, Sendable {
    let metrics: ActivityMetrics
    let history: ActivityMetricsHistory
}

/// history 只含这场活动开始之前的数据
struct ActivityMetricsHistory: Codable, Sendable {
    let pmc: TrendsPMC?
    let powerCurve: [PowerCurvePoint]?
    let runBests: [RunBest]?
    let eftp90d: Double?

    enum CodingKeys: String, CodingKey {
        case pmc, powerCurve, runBests
        case eftp90d = "eftp90D"
    }
}

/// activity_metrics 表的一行。数值宽松解析（数字或数字字符串都接受），
/// 后端以后新增列也不影响解码。
struct ActivityMetrics: Codable, Sendable {
    let loadTss: Double?
    let loadSource: String?
    let intensityFactor: Double?
    let np: Double?
    let ftpUsed: Double?
    let ef: Double?
    let decouplingPct: Double?
    let workKj: Double?
    /// 功率曲线：key（p5s…p60m）→ 瓦数
    let powerBests: [String: Double]
    /// 跑步最快用时：key（run_1k_s…run_hm_s）→ 秒
    let runBests: [String: Double]

    static let powerKeys: [(key: String, label: String)] = [
        ("p5s", "5s"), ("p15s", "15s"), ("p30s", "30s"), ("p1m", "1min"),
        ("p3m", "3min"), ("p5m", "5min"), ("p8m", "8min"), ("p10m", "10min"),
        ("p20m", "20min"), ("p30m", "30min"), ("p60m", "60min"),
    ]
    static let runKeys: [(key: String, label: String)] = [
        ("run_1k_s", "1km"), ("run_5k_s", "5km"), ("run_10k_s", "10km"), ("run_hm_s", "半马"),
    ]

    /// 用 snake_case 原名定位字段：convertFromSnakeCase 已把 key 转成驼峰
    private struct RawKey: CodingKey {
        let stringValue: String
        init(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { nil }
        init?(intValue: Int) { nil }

        /// 与 JSONDecoder.convertFromSnakeCase 相同的转换
        init(snake: String) {
            let parts = snake.split(separator: "_").map(String.init)
            stringValue = ([parts[0]] + parts.dropFirst().map { $0.capitalized }).joined()
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: RawKey.self)
        func num(_ snake: String) -> Double? {
            let k = RawKey(snake: snake)
            if let v = try? c.decode(Double.self, forKey: k) { return v }
            if let s = try? c.decode(String.self, forKey: k) { return Double(s) }
            return nil
        }
        loadTss = num("load_tss")
        loadSource = try? c.decode(String.self, forKey: RawKey(snake: "load_source"))
        intensityFactor = num("intensity_factor")
        np = num("np")
        ftpUsed = num("ftp_used")
        ef = num("ef")
        decouplingPct = num("decoupling_pct")
        workKj = num("work_kj")
        var power: [String: Double] = [:]
        for (key, _) in Self.powerKeys { if let v = num(key) { power[key] = v } }
        powerBests = power
        var run: [String: Double] = [:]
        for (key, _) in Self.runKeys { if let v = num(key) { run[key] = v } }
        runBests = run
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: RawKey.self)
        try c.encodeIfPresent(loadTss, forKey: RawKey(stringValue: "load_tss"))
        try c.encodeIfPresent(loadSource, forKey: RawKey(stringValue: "load_source"))
        try c.encodeIfPresent(intensityFactor, forKey: RawKey(stringValue: "intensity_factor"))
        try c.encodeIfPresent(np, forKey: RawKey(stringValue: "np"))
        try c.encodeIfPresent(ftpUsed, forKey: RawKey(stringValue: "ftp_used"))
        try c.encodeIfPresent(ef, forKey: RawKey(stringValue: "ef"))
        try c.encodeIfPresent(decouplingPct, forKey: RawKey(stringValue: "decoupling_pct"))
        try c.encodeIfPresent(workKj, forKey: RawKey(stringValue: "work_kj"))
        for (k, v) in powerBests { try c.encode(v, forKey: RawKey(stringValue: k)) }
        for (k, v) in runBests { try c.encode(v, forKey: RawKey(stringValue: k)) }
    }
}
