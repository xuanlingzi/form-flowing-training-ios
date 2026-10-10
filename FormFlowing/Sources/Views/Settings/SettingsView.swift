import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var activeTab = "profile"
    @State private var profile = UserProfile()
    @State private var account: AccountInfo?
    
    // Garmin 账号
    @State private var cnUsername = ""
    @State private var cnPassword = ""
    @State private var globalUsername = ""
    @State private var globalPassword = ""
    @State private var syncFrequency = 180.0
    @State private var syncCnGlobal = true
    @State private var syncToStrava = false
    @State private var stravaConnected = false
    
    // iGPSport
    @State private var igpsUsername = ""
    @State private var igpsPassword = ""
    @State private var igpsToken = ""
    @State private var igpsConfigured = false
    
    // Intervals.icu
    @State private var intervalsUserId = ""
    @State private var intervalsApiKey = ""
    @State private var intervalsConfigured = false
    
    // 连接状态
    @State private var platformStatuses: [PlatformStatus] = []
    @State private var statusLoading = false
    
    // 密码
    @State private var oldPwd = ""
    @State private var newPwd = ""
    @State private var confirmPwd = ""
    
    @State private var saving = false
    @State private var message: (type: String, text: String)?
    @State private var trainingGoalContent = ""
    @State private var trainingGoalUpdatedAt: String?
    
    var body: some View {
        NavigationStack {
            Form {
                if let msg = message {
                    Section {
                        Label(msg.text, systemImage: msg.type == "success" ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(msg.type == "success" ? .green : .red)
                    }
                }

                switch activeTab {
                case "datasources": dataSourcesTab
                case "password": passwordTab
                default: profileTab
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("设置分类", selection: $activeTab) {
                        Text("档案").tag("profile")
                        Text("数据源").tag("datasources")
                        Text("密码").tag("password")
                    }
                    .pickerStyle(.segmented)
                }
            }
            .task { await loadData() }
        }
    }

    // MARK: - Profile Tab

    private static let birthDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private var birthDateBinding: Binding<Date> {
        Binding(
            get: {
                profile.birthDate.flatMap { Self.birthDateFormatter.date(from: String($0.prefix(10))) } ?? Date()
            },
            set: { profile.birthDate = Self.birthDateFormatter.string(from: $0) }
        )
    }

    private func numberField(_ label: String, text: Binding<String>, prompt: String, decimal: Bool = false) -> some View {
        LabeledContent(label) {
            TextField(prompt, text: text)
                .keyboardType(decimal ? .decimalPad : .numberPad)
                .multilineTextAlignment(.trailing)
        }
    }

    @ViewBuilder
    var profileTab: some View {
        Section {
            numberField("体重 (kg)", text: Binding(
                get: { profile.weightKg.map { "\($0)" } ?? "" },
                set: { profile.weightKg = Double($0) }
            ), prompt: "如 72.5", decimal: true)

            numberField("身高 (cm)", text: Binding(
                get: { profile.heightCm.map { "\($0)" } ?? "" },
                set: { profile.heightCm = Double($0) }
            ), prompt: "如 175", decimal: true)

            Picker("性别", selection: Binding(
                get: { profile.gender ?? "" },
                set: { profile.gender = $0.isEmpty ? nil : $0 }
            )) {
                Text("未设置").tag("")
                Text("男").tag("male")
                Text("女").tag("female")
            }

            if profile.birthDate != nil {
                DatePicker("出生日期", selection: birthDateBinding, in: ...Date(), displayedComponents: .date)
            } else {
                LabeledContent("出生日期") {
                    Button("设置") {
                        profile.birthDate = "1990-01-01"
                    }
                }
            }

            numberField("最大心率 (bpm)", text: Binding(
                get: { profile.hrMax.map { "\($0)" } ?? "" },
                set: { profile.hrMax = Int($0) }
            ), prompt: "如 190")

            numberField("静息心率 (bpm)", text: Binding(
                get: { profile.hrRest.map { "\($0)" } ?? "" },
                set: { profile.hrRest = Int($0) }
            ), prompt: "如 55")

            numberField("FTP (W)", text: Binding(
                get: { profile.ftpWatts.map { "\($0)" } ?? "" },
                set: { profile.ftpWatts = Int($0) }
            ), prompt: "如 200")

            numberField("VO₂Max", text: Binding(
                get: { profile.vo2Max.map { "\($0)" } ?? "" },
                set: { profile.vo2Max = Double($0) }
            ), prompt: "如 48.5", decimal: true)
        } header: {
            Label("个人档案", systemImage: "person.circle.fill")
        } footer: {
            if let syncAt = profile.garminSyncedAt ?? profile.updatedAt {
                Text("基本身体数据，Garmin 同步后会自动覆盖。更新于 \(syncAt.prefix(16).replacingOccurrences(of: "T", with: " "))")
            } else {
                Text("基本身体数据，Garmin 同步后会自动覆盖")
            }
        }

        Section {
            saveButton("保存档案", action: saveProfile)
        }

        Section {
            NavigationLink(destination: MemoryView()) {
                Label("记忆管理", systemImage: "brain.head.profile")
            }
        }

        subscriptionSection
    }

    var subscriptionSection: some View {
        Section {
            LabeledContent {
                Text(auth.tier.uppercased())
                    .fontWeight(.bold)
                    .foregroundStyle(auth.isPro ? .orange : .secondary)
            } label: {
                Label("会员等级", systemImage: "crown.fill")
            }
            if let expiresAt = auth.tierExpiresAt {
                LabeledContent("到期时间", value: String(expiresAt.prefix(10)))
            }
        } footer: {
            if !auth.isPro {
                Text("升级 Pro 解锁 AI 深度分析、Strava/Intervals 同步等高级功能")
            }
        }
    }

    private func saveButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                if saving {
                    Spacer()
                    ProgressView()
                }
            }
        }
        .disabled(saving)
    }

    // MARK: - Data Sources Tab (merged: Garmin + iGPSport + Intervals + Strava + Sync)

    @ViewBuilder
    var dataSourcesTab: some View {
        // ---- Garmin CN ----
        Section {
            TextField("用户名（邮箱）", text: $cnUsername, prompt: Text("your@email.cn"))
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            SecureField("密码", text: $cnPassword, prompt: Text("密码，留空则不修改"))
            saveButton("保存并验证", action: saveGarminCn)
            if !cnUsername.isEmpty {
                Button("移除账号", role: .destructive, action: clearGarminCn)
                    .disabled(saving)
            }
        } header: {
            sourceHeader("佳明中国区", systemImage: "mappin.circle.fill", platform: "garmin_cn")
        }

        // ---- Garmin Global ----
        Section {
            TextField("用户名（邮箱）", text: $globalUsername, prompt: Text("your@email.com"))
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            SecureField("密码", text: $globalPassword, prompt: Text("密码，留空则不修改"))
            saveButton("保存并验证", action: saveGarminGlobal)
            if !globalUsername.isEmpty {
                Button("移除账号", role: .destructive, action: clearGarminGlobal)
                    .disabled(saving)
            }
        } header: {
            sourceHeader("Garmin Global", systemImage: "globe", platform: "garmin_global")
        }

        // CN/Global 双区同步 Toggle (auto-save)
        Section {
            Toggle(auth.isPro ? "CN/Global 双区同步" : "CN/Global 双区同步（PRO）", isOn: Binding(
                get: { syncCnGlobal },
                set: { newVal in
                    syncCnGlobal = newVal
                    autoSaveSyncSetting(["sync_cn_global": newVal])
                }
            ))
            .disabled(!auth.isPro)
        } footer: {
            Text("自动同步中国区和国际区的活动数据")
        }

        // ---- iGPSport ----
        Section {
            TextField("用户名", text: $igpsUsername, prompt: Text("手机号或邮箱"))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            SecureField("密码", text: $igpsPassword, prompt: Text("密码，留空则不修改"))
            TextField("手动 Bearer Token", text: $igpsToken, prompt: Text("或手动填入 Bearer Token"))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            saveButton("保存并验证", action: saveIGPSport)
            if igpsConfigured {
                Button("清除配置", role: .destructive, action: clearIGPSport)
                    .disabled(saving)
            }
        } header: {
            sourceHeader("iGPSport", systemImage: "bicycle", platform: "igpsport")
        } footer: {
            Text("iGPSport 活动数据同步。无法用账号密码登录时，可手动填入 Bearer Token")
        }

        // ---- Intervals.icu ----
        Section {
            TextField("Athlete ID", text: $intervalsUserId, prompt: Text("Athlete ID，如 i12345"))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            SecureField("API Key", text: $intervalsApiKey, prompt: Text("API Key，留空则不修改"))
            saveButton("保存并验证", action: saveIntervals)
            if intervalsConfigured {
                Button("清除配置", role: .destructive, action: clearIntervals)
                    .disabled(saving)
            }
        } header: {
            sourceHeader("Intervals.icu", systemImage: "chart.bar.fill", platform: "intervals")
        } footer: {
            Text("Athlete ID 与 API Key 可在 Intervals.icu → Settings → Developer 中找到")
        }

        // ---- Strava ----
        Section {
            LabeledContent(stravaConnected ? "已连接" : "需要授权 Strava 账号") {
                if stravaConnected {
                    Button("断开连接", role: .destructive) { disconnectStrava() }
                } else {
                    Button("连接 Strava") { connectStrava() }
                }
            }

            // Strava 直传 Toggle (auto-save)
            Toggle(auth.isPro ? "自动直传 Strava" : "自动直传 Strava（PRO）", isOn: Binding(
                get: { syncToStrava },
                set: { newVal in
                    syncToStrava = newVal
                    autoSaveSyncSetting(["sync_to_strava": newVal])
                }
            ))
            .disabled(!auth.isPro)
        } header: {
            sourceHeader("Strava", systemImage: "arrow.up.circle.fill", platform: "strava")
        } footer: {
            if syncToStrava {
                Label("开启后，请在 Garmin Connect Global 设置中取消 Strava 自动连接，避免活动重复上传。", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            } else {
                Text("从 CN 区拉取 FIT 文件直接上传到 Strava")
            }
        }

        // ---- Sync Options ----
        Section {
            Slider(value: Binding(
                get: { syncFrequency },
                set: { newVal in
                    syncFrequency = newVal
                    autoSaveSyncSettingDebounced()
                }
            ), in: 1...1440, step: 1) {
                Text("同步频率")
            }
        } header: {
            Label("同步频率", systemImage: "clock")
        } footer: {
            Text(syncFrequencyText)
        }
    }

    private func sourceHeader(_ title: String, systemImage: String, platform: String) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            statusBadgeView(platform: platform)
        }
    }

    @ViewBuilder
    private func statusBadgeView(platform: String) -> some View {
        if let s = platformStatuses.first(where: { $0.platform == platform }) {
            if s.configured && s.connected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .accessibilityLabel("已连接")
            } else if s.configured {
                Image(systemName: "wifi.slash")
                    .foregroundStyle(.red)
                    .accessibilityLabel("连接失败")
            }
        }
    }

    var syncFrequencyText: String {
        let mins = Int(syncFrequency)
        if mins >= 60 {
            let h = mins / 60
            let m = mins % 60
            return "每 \(h) 小时\(m > 0 ? " \(m) 分钟" : "") 自动同步一次"
        }
        return "每 \(mins) 分钟 自动同步一次"
    }

    // MARK: - Password Tab

    @ViewBuilder
    var passwordTab: some View {
        Section {
            SecureField("当前密码", text: $oldPwd)
                .textContentType(.password)
            SecureField("新密码（至少 6 个字符）", text: $newPwd)
                .textContentType(.newPassword)
            SecureField("确认新密码", text: $confirmPwd)
                .textContentType(.newPassword)
        } header: {
            Label("修改登录密码", systemImage: "lock.fill")
        } footer: {
            if !confirmPwd.isEmpty && newPwd == confirmPwd {
                Label("密码匹配", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Text("定期修改密码保障账号安全")
            }
        }

        Section {
            saveButton("修改密码", action: changePassword)
        }

        Section {
            Button("退出登录", role: .destructive) {
                auth.logout()
            }
        }
    }

    // MARK: - Helpers
    
    private func platformIcon(_ platform: String) -> String {
        switch platform {
        case "garmin_cn": return "🇨🇳"
        case "garmin_global": return "🌍"
        case "igpsport": return "🚴"
        case "intervals": return "📊"
        case "strava": return "🏃"
        default: return "🔗"
        }
    }
    
    private func platformLabel(_ platform: String) -> String {
        switch platform {
        case "garmin_cn": return "佳明中国区"
        case "garmin_global": return "Garmin Global"
        case "igpsport": return "iGPSport"
        case "intervals": return "Intervals.icu"
        case "strava": return "Strava"
        default: return platform
        }
    }
    
    // MARK: - Data
    
    private func loadData() async {
        // 1. 先从本地缓存加载，立即显示
        await loadFromCache()
        
        // 2. 后台请求，拿到最新数据后自动写入缓存并刷新 UI
        async let profileFetch: Void = {
            if let profileRes = try? await APIService.shared.getProfile(),
               let p = profileRes.profile {
                await MainActor.run { profile = p }
            }
        }()
        
        async let accountFetch: Void = {
            if let accountRes = try? await APIService.shared.getAccount() {
                await MainActor.run {
                    account = accountRes
                    cnUsername = accountRes.cnUsername ?? ""
                    globalUsername = accountRes.globalUsername ?? ""
                    syncFrequency = Double(accountRes.syncFrequency ?? 180)
                    syncCnGlobal = accountRes.syncCnGlobal ?? true
                    syncToStrava = accountRes.syncToStrava ?? false
                    stravaConnected = accountRes.stravaConnected ?? false
                    igpsConfigured = accountRes.igpsportConfigured ?? false
                    igpsUsername = accountRes.igpsportUsername ?? ""
                    intervalsConfigured = accountRes.intervalsConfigured ?? false
                    intervalsUserId = accountRes.intervalsUserId ?? ""
                }
            }
        }()
        
        async let goalFetch: Void = {
            if let goalRes = try? await APIService.shared.getTrainingGoal() {
                await MainActor.run {
                    trainingGoalContent = goalRes.content ?? ""
                    trainingGoalUpdatedAt = goalRes.updatedAt
                }
            }
        }()
        
        async let statusFetch: Void = {
            if let statusRes = try? await APIService.shared.getAccountStatus() {
                await MainActor.run { platformStatuses = statusRes.platforms }
            }
        }()
        
        _ = await (profileFetch, accountFetch, goalFetch, statusFetch)
    }
    
    private func loadFromCache() async {
        if let cached = await APIService.shared.cached("/profile", as: ProfileResponse.self), let p = cached.profile {
            await MainActor.run { profile = p }
        }
        if let cached = await APIService.shared.cached("/account", as: AccountInfo.self) {
            await MainActor.run {
                account = cached
                cnUsername = cached.cnUsername ?? ""
                globalUsername = cached.globalUsername ?? ""
                syncFrequency = Double(cached.syncFrequency ?? 180)
                syncCnGlobal = cached.syncCnGlobal ?? true
                syncToStrava = cached.syncToStrava ?? false
                stravaConnected = cached.stravaConnected ?? false
                igpsConfigured = cached.igpsportConfigured ?? false
                igpsUsername = cached.igpsportUsername ?? ""
                intervalsConfigured = cached.intervalsConfigured ?? false
                intervalsUserId = cached.intervalsUserId ?? ""
            }
        }
        if let cached = await APIService.shared.cached("/training-goal", as: TrainingGoalResponse.self) {
            await MainActor.run {
                trainingGoalContent = cached.content ?? ""
                trainingGoalUpdatedAt = cached.updatedAt
            }
        }
        if let cached = await APIService.shared.cached("/account/status", as: AccountStatusResponse.self) {
            await MainActor.run { platformStatuses = cached.platforms }
        }
    }
    
    private func loadPlatformStatus() {
        statusLoading = true
        Task {
            do {
                let res = try await APIService.shared.getAccountStatus()
                await MainActor.run {
                    platformStatuses = res.platforms
                    statusLoading = false
                }
            } catch {
                await MainActor.run {
                    platformStatuses = []
                    statusLoading = false
                }
            }
        }
    }
    
    private func saveProfile() {
        saving = true; message = nil
        Task {
            do {
                var data: [String: Any] = [:]
                if let v = profile.weightKg { data["weight_kg"] = v }
                if let v = profile.heightCm { data["height_cm"] = v }
                if let v = profile.birthDate { data["birth_date"] = v }
                if let v = profile.gender { data["gender"] = v }
                if let v = profile.ftpWatts { data["ftp_watts"] = v }
                if let v = profile.hrMax { data["hr_max"] = v }
                if let v = profile.hrRest { data["hr_rest"] = v }
                if let v = profile.vo2Max { data["vo2_max"] = v }
                if let v = profile.goalDesc { data["goal_desc"] = v }
                try await APIService.shared.updateProfile(data)
                // 保存训练目标到记忆库
                if !trainingGoalContent.isEmpty {
                    try? await APIService.shared.updateMemory(type: "training_goal", content: trainingGoalContent)
                }
                await MainActor.run { message = ("success", "个人档案已保存"); saving = false }
            } catch {
                await MainActor.run { message = ("error", error.localizedDescription); saving = false }
            }
        }
    }
    
    private func saveGarminCn() {
        saving = true; message = nil
        Task {
            do {
                var data: [String: Any] = [:]
                if !cnUsername.isEmpty { data["cn_username"] = cnUsername }
                if !cnPassword.isEmpty { data["cn_password"] = cnPassword }
                try await APIService.shared.updateAccount(data)
                cnPassword = ""
                
                if cnPassword.isEmpty {
                    // 没有密码变更时先显示保存信息，再验证
                }
                
                await MainActor.run { message = ("success", "账号已保存，正在验证连接…") }
                
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                let statusRes = try await APIService.shared.getAccountStatus()
                let s = statusRes.platforms.first(where: { $0.platform == "garmin_cn" })
                await MainActor.run {
                    platformStatuses = statusRes.platforms
                    if s?.connected == true {
                        message = ("success", s?.message ?? "连接成功")
                    } else {
                        message = ("error", s?.message ?? "连接失败")
                    }
                    saving = false
                }
            } catch {
                await MainActor.run { message = ("error", error.localizedDescription); saving = false }
            }
        }
    }
    
    private func saveGarminGlobal() {
        saving = true; message = nil
        Task {
            do {
                var data: [String: Any] = [:]
                if !globalUsername.isEmpty { data["global_username"] = globalUsername }
                if !globalPassword.isEmpty { data["global_password"] = globalPassword }
                try await APIService.shared.updateAccount(data)
                globalPassword = ""
                
                await MainActor.run { message = ("success", "账号已保存，正在验证连接…") }
                
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                let statusRes = try await APIService.shared.getAccountStatus()
                let s = statusRes.platforms.first(where: { $0.platform == "garmin_global" })
                await MainActor.run {
                    platformStatuses = statusRes.platforms
                    if s?.connected == true {
                        message = ("success", s?.message ?? "连接成功")
                    } else {
                        message = ("error", s?.message ?? "连接失败")
                    }
                    saving = false
                }
            } catch {
                await MainActor.run { message = ("error", error.localizedDescription); saving = false }
            }
        }
    }
    
    private func clearGarminCn() {
        saving = true; message = nil
        Task {
            do {
                try await APIService.shared.clearGarmin(region: "cn")
                await MainActor.run {
                    cnUsername = ""; cnPassword = ""
                    message = ("success", "佳明中国区账号已移除")
                    saving = false
                }
                let statusRes = try? await APIService.shared.getAccountStatus()
                if let s = statusRes {
                    await MainActor.run { platformStatuses = s.platforms }
                }
            } catch {
                await MainActor.run { message = ("error", "移除失败"); saving = false }
            }
        }
    }
    
    private func clearGarminGlobal() {
        saving = true; message = nil
        Task {
            do {
                try await APIService.shared.clearGarmin(region: "global")
                await MainActor.run {
                    globalUsername = ""; globalPassword = ""
                    message = ("success", "Garmin Global 账号已移除")
                    saving = false
                }
                let statusRes = try? await APIService.shared.getAccountStatus()
                if let s = statusRes {
                    await MainActor.run { platformStatuses = s.platforms }
                }
            } catch {
                await MainActor.run { message = ("error", "移除失败"); saving = false }
            }
        }
    }
    
    private func autoSaveSyncSetting(_ data: [String: Any]) {
        Task {
            do {
                try await APIService.shared.updateAccount(data)
            } catch {
                await MainActor.run { message = ("error", "自动保存失败") }
            }
        }
    }
    
    private func autoSaveSyncSettingDebounced() {
        // Simple immediate save for slider on end
        autoSaveSyncSetting(["sync_frequency": Int(syncFrequency)])
    }
    
    private func saveIGPSport() {
        saving = true; message = nil
        Task {
            do {
                var data: [String: Any] = [:]
                if !igpsToken.isEmpty {
                    data["token"] = igpsToken
                } else {
                    data["username"] = igpsUsername
                    data["password"] = igpsPassword
                }
                let res = try await APIService.shared.updateIGPSportConfig(data)
                await MainActor.run {
                    igpsConfigured = res.configured
                    if let u = res.username { igpsUsername = u }
                    message = (res.connected ? "success" : "error",
                               res.message ?? (res.connected ? "iGPSport 连接成功" : "保存成功但连接失败"))
                    igpsPassword = ""; igpsToken = ""
                    saving = false
                }
                let statusRes = try? await APIService.shared.getAccountStatus()
                if let s = statusRes {
                    await MainActor.run { platformStatuses = s.platforms }
                }
            } catch {
                await MainActor.run { message = ("error", error.localizedDescription); saving = false }
            }
        }
    }
    
    private func clearIGPSport() {
        saving = true
        Task {
            do {
                try await APIService.shared.clearIGPSportConfig()
                await MainActor.run {
                    igpsConfigured = false; igpsUsername = ""
                    message = ("success", "iGPSport 配置已清除")
                    saving = false
                }
                let statusRes = try? await APIService.shared.getAccountStatus()
                if let s = statusRes {
                    await MainActor.run { platformStatuses = s.platforms }
                }
            } catch {
                await MainActor.run { message = ("error", "清除失败"); saving = false }
            }
        }
    }
    
    private func saveIntervals() {
        saving = true; message = nil
        Task {
            do {
                let res = try await APIService.shared.updateIntervalsConfig(
                    userId: intervalsUserId, apiKey: intervalsApiKey)
                await MainActor.run {
                    intervalsConfigured = res.configured
                    if let u = res.userId { intervalsUserId = u }
                    let name = res.athleteName ?? ""
                    message = (res.connected ? "success" : "error",
                               res.message ?? (res.connected
                                               ? "Intervals.icu 已连接\(!name.isEmpty ? ": \(name)" : "")"
                                               : "保存成功但连接失败"))
                    intervalsApiKey = ""
                    saving = false
                }
                let statusRes = try? await APIService.shared.getAccountStatus()
                if let s = statusRes {
                    await MainActor.run { platformStatuses = s.platforms }
                }
            } catch {
                await MainActor.run { message = ("error", error.localizedDescription); saving = false }
            }
        }
    }
    
    private func clearIntervals() {
        saving = true
        Task {
            do {
                try await APIService.shared.clearIntervalsConfig()
                await MainActor.run {
                    intervalsConfigured = false; intervalsUserId = ""
                    message = ("success", "Intervals.icu 配置已清除")
                    saving = false
                }
                let statusRes = try? await APIService.shared.getAccountStatus()
                if let s = statusRes {
                    await MainActor.run { platformStatuses = s.platforms }
                }
            } catch {
                await MainActor.run { message = ("error", "清除失败"); saving = false }
            }
        }
    }
    
    private func changePassword() {
        guard !oldPwd.isEmpty && !newPwd.isEmpty else {
            message = ("error", "请填写所有密码字段"); return
        }
        guard newPwd.count >= 6 else {
            message = ("error", "新密码至少需要 6 个字符"); return
        }
        guard newPwd == confirmPwd else { message = ("error", "两次密码不一致"); return }
        saving = true; message = nil
        Task {
            do {
                try await APIService.shared.changePassword(oldPassword: oldPwd, newPassword: newPwd)
                await MainActor.run {
                    message = ("success", "密码修改成功")
                    oldPwd = ""; newPwd = ""; confirmPwd = ""
                    saving = false
                }
            } catch {
                await MainActor.run { message = ("error", error.localizedDescription); saving = false }
            }
        }
    }
    
    private func connectStrava() {
        // 先保存开关状态
        Task {
            try? await APIService.shared.updateAccount(["sync_to_strava": true])
            // 在 iOS 上打开 Safari 进行 Strava OAuth
            // 实际需要配置回调 URL scheme
            await MainActor.run {
                message = ("success", "请在浏览器中完成 Strava 授权")
            }
        }
    }
    
    private func disconnectStrava() {
        Task {
            do {
                try await APIService.shared.disconnectStrava()
                // Also auto-disable sync_to_strava
                syncToStrava = false
                try? await APIService.shared.updateAccount(["sync_to_strava": false])
                await MainActor.run {
                    stravaConnected = false
                    message = ("success", "Strava 已断开连接")
                }
                let statusRes = try? await APIService.shared.getAccountStatus()
                if let s = statusRes {
                    await MainActor.run { platformStatuses = s.platforms }
                }
            } catch {
                await MainActor.run { message = ("error", "断开失败，请重试") }
            }
        }
    }
}
