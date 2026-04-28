import Foundation

/// API 服务层 — 与前端 api.ts 1:1 对应
@MainActor
final class APIService: @unchecked Sendable {
    static let shared = APIService()

    // TODO: 替换为实际 API 地址（生产环境）
    // 开发调试时使用本机地址
    // #if targetEnvironment(simulator)
    // private let baseURL = "http://localhost:8000/api"
    // #else
    private let baseURL = "https://api.formflowing.com/api"
    // #endif

    private let tokenRefreshCoordinator = TokenRefreshCoordinator()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    private var token: String {
        UserDefaults.standard.string(forKey: "access_token") ?? ""
    }

    // MARK: - 通用请求方法

    private func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        body: [String: Any]? = nil,
        timeout: TimeInterval = 30,
        requiresAuth: Bool = true
    ) async throws -> T {
        let request = try await makeRequest(
            path: path,
            method: method,
            body: body,
            timeout: timeout,
            requiresAuth: requiresAuth
        )
        let (data, httpResponse) = try await send(request, retryOnUnauthorized: requiresAuth)

        guard (200...299).contains(httpResponse.statusCode) else {
            throw serverError(statusCode: httpResponse.statusCode, data: data, fallback: "请求失败")
        }

        // GET 请求自动写入缓存
        if method == "GET" {
            await CacheService.shared.set(path, data: data)
        }

        return try decodeResponse(T.self, from: data)
    }
    
    /// 从本地缓存加载数据（不发网络请求）
    /// 用于页面打开时先展示缓存数据
    func cached<T: Decodable & Sendable>(_ path: String, as type: T.Type) async -> T? {
        return await CacheService.shared.get(path, as: type)
    }
    
    /// 使指定缓存失效（写操作后调用）
    func invalidateCache(_ path: String) async {
        await CacheService.shared.invalidate(path)
    }
    
    /// 使匹配前缀的缓存失效
    func invalidateCachePrefix(_ prefix: String) async {
        await CacheService.shared.invalidatePrefix(prefix)
    }
    
    /// 清除全部缓存（登出时调用）
    func clearAllCache() async {
        await CacheService.shared.clearAll()
    }
    
    private func requestVoid(
        _ path: String,
        method: String = "POST",
        body: [String: Any]? = nil,
        timeout: TimeInterval = 30,
        requiresAuth: Bool = true
    ) async throws {
        let request = try await makeRequest(
            path: path,
            method: method,
            body: body,
            timeout: timeout,
            requiresAuth: requiresAuth
        )
        let (data, httpResponse) = try await send(request, retryOnUnauthorized: requiresAuth)

        guard (200...299).contains(httpResponse.statusCode) else {
            throw serverError(statusCode: httpResponse.statusCode, data: data, fallback: "请求失败")
        }
    }

    private func makeRequest(
        path: String,
        method: String,
        body: [String: Any]? = nil,
        timeout: TimeInterval,
        requiresAuth: Bool,
        contentType: String = "application/json"
    ) async throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        if requiresAuth {
            try await refreshAccessTokenIfNeeded()
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = timeout
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")

        if requiresAuth, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        return request
    }

    private func send(_ request: URLRequest, retryOnUnauthorized: Bool) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 401 else {
            return (data, httpResponse)
        }

        guard retryOnUnauthorized else {
            await AuthManager.shared.logout()
            throw APIError.unauthorized
        }

        do {
            let refreshedToken = try await forceRefreshAccessToken()
            var retryRequest = request
            retryRequest.setValue("Bearer \(refreshedToken)", forHTTPHeaderField: "Authorization")

            let (retryData, retryResponse) = try await URLSession.shared.data(for: retryRequest)
            guard let retryHTTPResponse = retryResponse as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            if retryHTTPResponse.statusCode == 401 {
                await AuthManager.shared.logout()
                throw APIError.unauthorized
            }

            return (retryData, retryHTTPResponse)
        } catch {
            await AuthManager.shared.logout()
            throw APIError.unauthorized
        }
    }

    private func refreshAccessTokenIfNeeded() async throws {
        let shouldRefresh = await MainActor.run {
            AuthManager.shared.isAuthenticated && AuthManager.shared.shouldRefreshToken()
        }
        guard shouldRefresh else { return }
        _ = try await forceRefreshAccessToken()
    }

    private func forceRefreshAccessToken() async throws -> String {
        try await tokenRefreshCoordinator.refreshToken {
            // 从 Keychain 读取长期 refresh_token
            guard let refreshToken = await MainActor.run(body: {
                AuthManager.shared.storedRefreshToken()
            }) else {
                throw APIError.unauthorized
            }

            // 发送刷新请求换去全新双 token
            let response = try await self.refreshToken(refreshToken)

            await AuthManager.shared.login(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken,
                username: response.username ?? "",
                tier: response.tier,
                tierExpiresAt: response.tierExpiresAt
            )

            return response.accessToken
        }
    }

    // MARK: - 认证

    func refreshToken(_ token: String) async throws -> LoginResponse {
        return try await request(
            "/auth/refresh_token",
            method: "POST",
            body: ["refresh_token": token],
            requiresAuth: false
        )
    }

    func login(username: String, password: String, requiresAuth: Bool = false) async throws -> LoginResponse {
        return try await request(
            "/auth/login",
            method: "POST",
            body: ["username": username, "password": password],
            requiresAuth: requiresAuth
        )
    }

    func register(username: String, password: String) async throws -> LoginResponse {
        return try await request(
            "/auth/register",
            method: "POST",
            body: ["username": username, "password": password],
            requiresAuth: false
        )
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
    
    func triggerAnalysis(activityId: Int, tier: String = "pro", extraPrompt: String? = nil) async throws {
        var body: [String: Any] = [:]
        if let extraPrompt, !extraPrompt.isEmpty {
            body["extra_prompt"] = extraPrompt
        }
        try await requestVoid("/analysis/trigger/\(activityId)?tier=\(tier)", method: "POST", body: body.isEmpty ? nil : body, timeout: 120)
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
    
    func analysisChat(analysisResultId: Int, message: String, autoApply: Bool = false) async throws -> AnalysisChatResponse {
        var body: [String: Any] = ["message": message]
        if autoApply { body["auto_apply"] = true }
        return try await request("/analysis/\(analysisResultId)/chat", method: "POST", body: body, timeout: 120)
    }
    
    func applyAnalysisAdjustments(analysisResultId: Int, adjustments: [[String: Any]]) async throws -> AdjustmentResult {
        return try await request(
            "/analysis/\(analysisResultId)/apply-adjustments",
            method: "POST",
            body: ["adjustments": adjustments],
            timeout: 60
        )
    }
    
    // MARK: - 训练计划
    
    func getTrainingPlans() async throws -> TrainingPlanListResponse {
        return try await request("/training/plan")
    }
    
    func getPlanStatus() async throws -> TrainingPlanStatusResponse {
        return try await request("/training/plan/status")
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
    
    func cancelWorkoutSchedule(workoutId: Int) async throws {
        try await requestVoid("/training/workout/\(workoutId)/schedule", method: "DELETE")
    }
    
    func postponeWorkout(workoutId: Int) async throws {
        try await requestVoid("/training/workout/\(workoutId)/postpone", method: "POST")
    }
    
    func rescheduleWorkout(workoutId: Int, newDate: String) async throws {
        try await requestVoid("/training/workout/\(workoutId)/reschedule", method: "PUT", body: [
            "new_date": newDate
        ])
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
    
    func saveTrainingGoal(goal: [String: Any]) async throws {
        try await requestVoid("/training-goal", method: "POST", body: goal)
    }
    
    func generateTrainingPlan(req: [String: Any]) async throws {
        try await requestVoid("/training/plan/generate", method: "POST", body: req, timeout: 120)
    }

    // MARK: - 订阅

    func getSubscriptionStatus() async throws -> SubscriptionStatusResponse {
        return try await request("/subscription")
    }

    func getSubscriptionUsage() async throws -> UsageResponse {
        return try await request("/subscription/usage")
    }
    
    // MARK: - 文件上传

    func uploadActivity(fileURL: URL) async throws -> UploadResponse {
        var request = try await makeRequest(
            path: "/activity/upload",
            method: "POST",
            timeout: 120,
            requiresAuth: true,
            contentType: "multipart/form-data"
        )

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

        let (data, httpResponse) = try await send(request, retryOnUnauthorized: true)
        guard (200...299).contains(httpResponse.statusCode) else {
            throw serverError(statusCode: httpResponse.statusCode, data: data, fallback: "上传失败")
        }

        return try decodeResponse(UploadResponse.self, from: data)
    }

    private func decodeResponse<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw APIError.decodingFailed(error.localizedDescription)
        }
    }

    private func serverError(statusCode: Int, data: Data, fallback: String) -> APIError {
        if let detail = try? decoder.decode(ErrorDetail.self, from: data),
           let message = detail.detail,
           !message.isEmpty {
            return .serverError(statusCode, message)
        }

        if let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty {
            return .serverError(statusCode, text)
        }

        return .serverError(statusCode, fallback)
    }
}

// MARK: - Error Types

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case serverError(Int, String)
    case decodingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的请求地址"
        case .invalidResponse: return "无效的响应"
        case .unauthorized: return "登录已过期"
        case .serverError(_, let message): return message
        case .decodingFailed(let message): return "响应解析失败: \(message)"
        }
    }
}

struct ErrorDetail: Codable {
    let detail: String?
}

actor TokenRefreshCoordinator {
    private var refreshTask: Task<String, Error>?

    func refreshToken(using operation: @escaping @Sendable () async throws -> String) async throws -> String {
        if let refreshTask {
            return try await refreshTask.value
        }

        let refreshTask = Task {
            try await operation()
        }
        self.refreshTask = refreshTask
        defer { self.refreshTask = nil }

        return try await refreshTask.value
    }
}
