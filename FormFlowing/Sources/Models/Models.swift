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
}

struct TrainingPlanListResponse: Codable, Sendable {
    let plans: [TrainingPlan]
}

struct TrainingPlanDetailResponse: Codable, Sendable {
    let plan: TrainingPlan
    let workouts: [Workout]
}

struct Workout: Codable, Identifiable, Sendable {
    var id: Int { trainingPlanWorkoutId }
    let trainingPlanWorkoutId: Int
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

