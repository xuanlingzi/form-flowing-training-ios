import Foundation

/// API 服务层 — 与前端 api.ts 1:1 对应
class APIService {
    static let shared = APIService()
    
    // TODO: 替换为实际 API 地址（生产环境）
    // 开发调试时使用本机地址
    #if targetEnvironment(simulator)
    private let baseURL = "http://localhost:8000/api"
    #else
    private let baseURL = "https://api.formflowing.com/api"
    #endif
    
    private var token: String {
        UserDefaults.standard.string(forKey: "access_token") ?? ""
    }
    
    // MARK: - 通用请求方法
    
    private func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        body: [String: Any]? = nil,
        timeout: TimeInterval = 30
    ) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            DispatchQueue.main.async {
                AuthManager().logout() // Token 过期
            }
            throw APIError.unauthorized
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let detail = try? JSONDecoder().decode(ErrorDetail.self, from: data)
            throw APIError.serverError(httpResponse.statusCode, detail?.detail ?? "请求失败")
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: data)
    }
    
    private func requestVoid(
        _ path: String,
        method: String = "POST",
        body: [String: Any]? = nil,
        timeout: TimeInterval = 30
    ) async throws {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(httpResponse.statusCode, "请求失败")
        }
    }
    
    // MARK: - 认证
    
    func login(username: String, password: String) async throws -> LoginResponse {
        return try await request("/auth/login", method: "POST", body: ["username": username, "password": password])
    }
    
    func register(username: String, password: String) async throws -> LoginResponse {
        return try await request("/auth/register", method: "POST", body: ["username": username, "password": password])
    }
    
    // MARK: - 个人档案 & Garmin 状态
    
    func getGarminStatus() async throws -> GarminStatusResponse {
        return try await request("/profile/garmin-status")
    }
    
    func getProfile() async throws -> ProfileResponse {
        return try await request("/profile")
    }
    
    func updateProfile(_ data: [String: Any]) async throws {
        try await requestVoid("/profile", method: "PUT", body: data)
    }
    
    func refreshGarmin() async throws {
        try await requestVoid("/profile/garmin-refresh")
    }
    
    // MARK: - 账号
    
    func getAccount() async throws -> AccountInfo {
        return try await request("/account")
    }
    
    func updateAccount(_ data: [String: Any]) async throws {
        try await requestVoid("/account", method: "PUT", body: data)
    }
    
    func changePassword(oldPassword: String, newPassword: String) async throws {
        try await requestVoid("/account/password", method: "PUT", body: [
            "old_password": oldPassword,
            "new_password": newPassword
        ])
    }
    
    func getAccountStatus() async throws -> AccountStatusResponse {
        return try await request("/account/status")
    }
    
    func clearGarmin(region: String) async throws {
        try await requestVoid("/account/garmin/\(region)", method: "DELETE")
    }
    
    // MARK: - 活动
    
    func getActivities(page: Int = 1, pageSize: Int = 20, sport: String? = nil) async throws -> [ActivityListItem] {
        var path = "/activity/list?page=\(page)&page_size=\(pageSize)"
        if let sport = sport { path += "&sport=\(sport)" }
        return try await request(path)
    }
    
    func getActivityDetail(id: Int) async throws -> ActivitySummary {
        return try await request("/activity/\(id)")
    }
    
    func getActivityLaps(id: Int) async throws -> [LapData] {
        return try await request("/activity/\(id)/laps")
    }
    
    func getActivityRecords(id: Int) async throws -> [RecordData] {
        return try await request("/activity/\(id)/records")
    }
    
    // MARK: - 分析
    
    func triggerAnalysis(activityId: Int, tier: String = "pro") async throws {
        try await requestVoid("/analysis/trigger/\(activityId)?tier=\(tier)", method: "POST", timeout: 120)
    }
    
    func getAnalysisHistory(page: Int = 1, size: Int = 20) async throws -> AnalysisHistoryResponse {
        return try await request("/analysis/history?page=\(page)&size=\(size)")
    }
    
    func getAnalysisDetail(id: Int) async throws -> AnalysisResult {
        return try await request("/analysis/\(id)")
    }
    
    func getAnalysisByActivity(activityId: Int) async throws -> AnalysisByActivityResponse {
        return try await request("/analysis/activity/\(activityId)")
    }
    
    func getAnalysisStatus(activityId: Int) async throws -> AnalysisStatusResponse {
        return try await request("/analysis/status/\(activityId)")
    }
    
    // MARK: - 训练计划
    
    func getTrainingPlans() async throws -> TrainingPlanListResponse {
        return try await request("/training/plan")
    }
    
    func getPlanDetail(planId: Int) async throws -> TrainingPlanDetailResponse {
        return try await request("/training/plan/\(planId)")
    }
    
    func deletePlan(planId: Int) async throws {
        try await requestVoid("/training/plan/\(planId)", method: "DELETE")
    }
    
    func pushPlanToGarmin(planId: Int) async throws {
        try await requestVoid("/training/plan/\(planId)/push-garmin", method: "POST")
    }
    
    // MARK: - 记忆
    
    func getMemories() async throws -> MemoryListResponse {
        return try await request("/memory")
    }
    
    func updateMemory(type: String, content: String) async throws {
        try await requestVoid("/memory/\(type)", method: "PUT", body: ["content": content])
    }
    
    func resetMemory(type: String) async throws {
        try await requestVoid("/memory/\(type)/reset")
    }
    
    // MARK: - Strava
    
    func disconnectStrava() async throws {
        try await requestVoid("/strava/disconnect")
    }
    
    // MARK: - iGPSport
    
    func getIGPSportConfig() async throws -> IGPSportConfigResponse {
        return try await request("/igpsport/config")
    }
    
    func updateIGPSportConfig(_ data: [String: Any]) async throws -> IGPSportConfigResponse {
        return try await request("/igpsport/config", method: "PUT", body: data)
    }
    
    func clearIGPSportConfig() async throws {
        try await requestVoid("/igpsport/config", method: "DELETE")
    }
    
    // MARK: - Intervals.icu
    
    func getIntervalsConfig() async throws -> IntervalsConfigResponse {
        return try await request("/intervals/config")
    }
    
    func updateIntervalsConfig(userId: String, apiKey: String) async throws -> IntervalsConfigResponse {
        return try await request("/intervals/config", method: "PUT", body: [
            "user_id": userId,
            "api_key": apiKey
        ])
    }
    
    func clearIntervalsConfig() async throws {
        try await requestVoid("/intervals/config", method: "DELETE")
    }
    
    // MARK: - 训练目标/生成
    
    func getTrainingGoal() async throws -> TrainingGoalResponse {
        return try await request("/training-goal")
    }
    
    func saveTrainingGoal(content: String) async throws {
        try await requestVoid("/training-goal", method: "POST", body: ["content": content])
    }
    
    func generateTrainingPlan(goal: [String: Any]) async throws {
        try await requestVoid("/training/goal", method: "POST", body: goal, timeout: 120)
    }
    
    // MARK: - 文件上传
    
    func uploadActivity(fileURL: URL) async throws -> UploadResponse {
        let url = URL(string: "\(baseURL)/activity/upload")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        
        if !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        let fileData = try Data(contentsOf: fileURL)
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(0, "上传失败")
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(UploadResponse.self, from: data)
    }
}

// MARK: - Error Types

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case serverError(Int, String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的请求地址"
        case .invalidResponse: return "无效的响应"
        case .unauthorized: return "登录已过期"
        case .serverError(_, let message): return message
        }
    }
}

struct ErrorDetail: Codable {
    let detail: String?
}
