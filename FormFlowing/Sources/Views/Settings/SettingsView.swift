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
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 16) {
                    // Message
                    if let msg = message {
                        HStack {
                            Image(systemName: msg.type == "success" ? "checkmark.circle.fill" : "xmark.circle.fill")
                            Text(msg.text)
                        }
                        .font(.caption)
                        .foregroundColor(msg.type == "success" ? .green : .red)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background((msg.type == "success" ? Color.green : Color.red).opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    if activeTab == "profile" { profileTab }
                    if activeTab == "datasources" { dataSourcesTab }
                    if activeTab == "password" { passwordTab }
                }
                .padding()
            }
            .safeAreaInset(edge: .top) {
                HStack(spacing: 4) {
                    TabButton(title: "档案", icon: "person.circle", active: activeTab == "profile") { activeTab = "profile" }
                    TabButton(title: "数据源", icon: "antenna.radiowaves.left.and.right", active: activeTab == "datasources") { activeTab = "datasources" }
                    TabButton(title: "密码", icon: "lock.fill", active: activeTab == "password") { activeTab = "password" }
                }
                .frame(maxWidth: .infinity)
                .padding(4)
                .background(Color(UIColor.systemGray5))
                .cornerRadius(14)
                .padding(.horizontal)
                .frame(height: 44)
                .background(Color(UIColor.systemBackground))
            }
            .background(Color(UIColor.systemGroupedBackground))
            .toolbar(.hidden, for: .navigationBar)
            .task { await loadData() }
        }
    }
    
    // MARK: - Profile Tab
    
    var profileTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "person.circle.fill")
                    .font(.title2).foregroundColor(.purple)
                VStack(alignment: .leading, spacing: 2) {
                    Text("个人档案").font(.headline)
                    Text("基本身体数据，Garmin 同步后会自动覆盖").font(.caption).foregroundColor(.secondary)
                }
            }
            
            // 身体数据区域
            VStack(spacing: 12) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    FormField(label: "体重 (kg)", value: Binding(
                        get: { profile.weightKg.map { "\($0)" } ?? "" },
                        set: { profile.weightKg = Double($0) }
                    ), placeholder: "如 72.5")
                    
                    FormField(label: "身高 (cm)", value: Binding(
                        get: { profile.heightCm.map { "\($0)" } ?? "" },
                        set: { profile.heightCm = Double($0) }
                    ), placeholder: "如 175")
                    
                    // 性别
                    VStack(alignment: .leading, spacing: 6) {
                        Text("性别").font(.subheadline.weight(.semibold))
                        Picker("", selection: Binding(
                            get: { profile.gender ?? "" },
                            set: { profile.gender = $0.isEmpty ? nil : $0 }
                        )) {
                            Text("未设置").tag("")
                            Text("男").tag("male")
                            Text("女").tag("female")
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    // 出生日期
                    VStack(alignment: .leading, spacing: 6) {
                        Text("出生日期").font(.subheadline.weight(.semibold))
                        TextField("如 1990-01-01", text: Binding(
                            get: { profile.birthDate ?? "" },
                            set: { profile.birthDate = $0.isEmpty ? nil : $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                    }
                    
                    FormField(label: "最大心率 (bpm)", value: Binding(
                        get: { profile.hrMax.map { "\($0)" } ?? "" },
                        set: { profile.hrMax = Int($0) }
                    ), placeholder: "如 190")
                    
                    FormField(label: "静息心率 (bpm)", value: Binding(
                        get: { profile.hrRest.map { "\($0)" } ?? "" },
                        set: { profile.hrRest = Int($0) }
                    ), placeholder: "如 55")
                    
                    FormField(label: "FTP (W)", value: Binding(
                        get: { profile.ftpWatts.map { "\($0)" } ?? "" },
                        set: { profile.ftpWatts = Int($0) }
                    ), placeholder: "如 200")
                    
                    FormField(label: "VO₂Max", value: Binding(
                        get: { profile.vo2Max.map { "\($0)" } ?? "" },
                        set: { profile.vo2Max = Double($0) }
                    ), placeholder: "如 48.5")
                }
            }
            .padding(14)
            .background(Color.teal.opacity(0.05))
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.teal.opacity(0.2), lineWidth: 1))
            
            // 同步信息
            if let syncAt = profile.garminSyncedAt ?? profile.updatedAt {
                Text("更新于 \(syncAt.prefix(16).replacingOccurrences(of: "T", with: " "))")
                    .font(.caption2).foregroundColor(.secondary).frame(maxWidth: .infinity)
            }
            
            Button(action: saveProfile) {
                HStack {
                    if saving { ProgressView().tint(.white) }
                    Image(systemName: "square.and.arrow.down")
                    Text("保存档案")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.purple)
                .foregroundColor(.white).font(.headline).cornerRadius(14)
            }
            .disabled(saving)
            
            // 记忆管理入口
            NavigationLink(destination: MemoryView()) {
                HStack {
                    Label("记忆管理", systemImage: "brain.head.profile")
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right").foregroundColor(.secondary)
                }
                .padding(14)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(12)
            }
        }
        .padding(16).background(.white).cornerRadius(16)
    }
    
    // MARK: - Data Sources Tab (merged: Garmin + iGPSport + Intervals + Strava + Sync)
    
    var dataSourcesTab: some View {
        VStack(spacing: 16) {
            // ---- Garmin Card ----
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    Image(systemName: "applewatch").font(.title2).foregroundColor(.teal)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Garmin 账号配置").font(.headline)
                        Text("填写中国区和国际区的 Garmin 账号信息").font(.caption).foregroundColor(.secondary)
                    }
                }
                
                // CN 区
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill").foregroundColor(.blue)
                        Text("佳明中国区").font(.subheadline.weight(.semibold)).foregroundColor(.blue)
                        Spacer()
                        statusBadgeView(platform: "garmin_cn")
                    }
                    FormField(label: "用户名（邮箱）", value: $cnUsername, placeholder: "your@email.cn")
                    FormField(label: "密码", value: $cnPassword, isSecure: true, placeholder: "留空则不修改")
                }
                .padding(14).background(Color.blue.opacity(0.05)).cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.blue.opacity(0.2), lineWidth: 1))
                
                HStack(spacing: 10) {
                    Button(action: saveGarminCn) {
                        HStack {
                            if saving { ProgressView().tint(.white) }
                            Image(systemName: "square.and.arrow.down")
                            Text("保存并验证")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .foregroundColor(.white).font(.subheadline.weight(.semibold)).cornerRadius(12)
                    }
                    .disabled(saving)
                    
                    if !cnUsername.isEmpty {
                        Button(action: clearGarminCn) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                                .padding(12)
                                .background(Color.red.opacity(0.1)).cornerRadius(12)
                        }
                        .disabled(saving)
                    }
                }
                
                Divider()
                
                // Global 区
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "globe").foregroundColor(.purple)
                        Text("Garmin Global").font(.subheadline.weight(.semibold)).foregroundColor(.purple)
                        Spacer()
                        statusBadgeView(platform: "garmin_global")
                    }
                    FormField(label: "用户名（邮箱）", value: $globalUsername, placeholder: "your@email.com")
                    FormField(label: "密码", value: $globalPassword, isSecure: true, placeholder: "留空则不修改")
                }
                .padding(14).background(Color.purple.opacity(0.05)).cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.purple.opacity(0.2), lineWidth: 1))
                
                HStack(spacing: 10) {
                    Button(action: saveGarminGlobal) {
                        HStack {
                            if saving { ProgressView().tint(.white) }
                            Image(systemName: "square.and.arrow.down")
                            Text("保存并验证")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.purple)
                        .foregroundColor(.white).font(.subheadline.weight(.semibold)).cornerRadius(12)
                    }
                    .disabled(saving)
                    
                    if !globalUsername.isEmpty {
                        Button(action: clearGarminGlobal) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                                .padding(12)
                                .background(Color.red.opacity(0.1)).cornerRadius(12)
                        }
                        .disabled(saving)
                    }
                }
                
                Divider()
                
                // CN/Global 双区同步 Toggle (auto-save)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CN/Global 双区同步").font(.subheadline.weight(.medium))
                        Text("自动同步中国区和国际区的活动数据").font(.caption2).foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { syncCnGlobal },
                        set: { newVal in
                            syncCnGlobal = newVal
                            autoSaveSyncSetting(["sync_cn_global": newVal])
                        }
                    )).labelsHidden().tint(.teal)
                }
            }
            .padding(16).background(.white).cornerRadius(16)
            
            // ---- iGPSport Card ----
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "bicycle").font(.title2).foregroundColor(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("iGPSport").font(.headline)
                        Text("iGPSport 活动数据同步").font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    statusBadgeView(platform: "igpsport")
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    FormField(label: "用户名", value: $igpsUsername, placeholder: "手机号或邮箱")
                    FormField(label: "密码", value: $igpsPassword, isSecure: true, placeholder: "留空则不修改")
                    
                    HStack {
                        VStack { Divider() }
                        Text("或").font(.caption2).foregroundColor(.secondary)
                        VStack { Divider() }
                    }
                    
                    FormField(label: "手动 Bearer Token", value: $igpsToken, placeholder: "无法登录时手动填入")
                }
                .padding(14).background(Color.green.opacity(0.05)).cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.green.opacity(0.2), lineWidth: 1))
                
                HStack(spacing: 10) {
                    Button(action: saveIGPSport) {
                        HStack {
                            if saving { ProgressView().tint(.white) }
                            Image(systemName: "square.and.arrow.down")
                            Text("保存并验证")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.green)
                        .foregroundColor(.white).font(.subheadline.weight(.semibold)).cornerRadius(12)
                    }
                    .disabled(saving)
                    
                    if igpsConfigured {
                        Button(action: clearIGPSport) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                                .padding(12)
                                .background(Color.red.opacity(0.1)).cornerRadius(12)
                        }
                        .disabled(saving)
                    }
                }
            }
            .padding(16).background(.white).cornerRadius(16)
            
            // ---- Intervals.icu Card ----
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "chart.bar.fill").font(.title2).foregroundColor(.indigo)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Intervals.icu").font(.headline)
                        Text("训练计划数据").font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    statusBadgeView(platform: "intervals")
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    FormField(label: "Athlete ID", value: $intervalsUserId, placeholder: "如 i12345")
                    Text("在 Intervals.icu → Settings → Developer 中可找到")
                        .font(.caption2).foregroundColor(.secondary)
                    FormField(label: "API Key", value: $intervalsApiKey, isSecure: true, placeholder: "留空则不修改")
                    Text("在 Intervals.icu → Settings → Developer → API Key 生成")
                        .font(.caption2).foregroundColor(.secondary)
                }
                .padding(14).background(Color.indigo.opacity(0.05)).cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.indigo.opacity(0.2), lineWidth: 1))
                
                HStack(spacing: 10) {
                    Button(action: saveIntervals) {
                        HStack {
                            if saving { ProgressView().tint(.white) }
                            Image(systemName: "square.and.arrow.down")
                            Text("保存并验证")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.indigo)
                        .foregroundColor(.white).font(.subheadline.weight(.semibold)).cornerRadius(12)
                    }
                    .disabled(saving)
                    
                    if intervalsConfigured {
                        Button(action: clearIntervals) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                                .padding(12)
                                .background(Color.red.opacity(0.1)).cornerRadius(12)
                        }
                        .disabled(saving)
                    }
                }
            }
            .padding(16).background(.white).cornerRadius(16)
            
            // ---- Strava Card ----
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.up.circle.fill").font(.title2).foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Strava").font(.headline)
                        Text("OAuth 授权连接").font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    statusBadgeView(platform: "strava")
                }
                
                HStack {
                    Text(stravaConnected ? "✅ Strava 已连接" : "需要授权 Strava 账号")
                        .font(.caption)
                    Spacer()
                    if stravaConnected {
                        Button("断开连接") { disconnectStrava() }
                            .font(.caption.weight(.medium))
                            .foregroundColor(.red)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Color.red.opacity(0.1)).cornerRadius(8)
                    } else {
                        Button("连接 Strava") { connectStrava() }
                            .font(.caption.weight(.medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Color.orange).cornerRadius(8)
                    }
                }
                .padding(14).background(Color.orange.opacity(0.05)).cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.orange.opacity(0.2), lineWidth: 1))
                
                Divider()
                
                // Strava 直传 Toggle (auto-save)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.circle.fill").font(.caption).foregroundColor(.orange)
                            Text("自动直传 Strava").font(.subheadline.weight(.medium))
                        }
                        Text("从 CN 区拉取 FIT 文件直接上传到 Strava").font(.caption2).foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { syncToStrava },
                        set: { newVal in
                            syncToStrava = newVal
                            autoSaveSyncSetting(["sync_to_strava": newVal])
                        }
                    )).labelsHidden().tint(.orange)
                }
                
                if syncToStrava {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                        Text("开启后，请在 Garmin Connect Global 设置中取消 Strava 自动连接，避免活动重复上传。")
                            .font(.caption2).foregroundColor(.orange)
                    }
                    .padding(10).background(Color.orange.opacity(0.1)).cornerRadius(10)
                }
            }
            .padding(16).background(.white).cornerRadius(16)
            
            // ---- Sync Options Card ----
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.left.arrow.right").font(.title2).foregroundColor(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("同步选项").font(.headline)
                        Text("数据同步规则与频率").font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    if saving {
                        ProgressView().scaleEffect(0.7)
                    }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock").font(.caption)
                        Text("同步频率").font(.subheadline.weight(.medium))
                    }
                    Slider(value: Binding(
                        get: { syncFrequency },
                        set: { newVal in
                            syncFrequency = newVal
                            autoSaveSyncSettingDebounced()
                        }
                    ), in: 1...1440, step: 1)
                        .tint(.teal)
                    Text(syncFrequencyText)
                        .font(.caption2).foregroundColor(.secondary)
                }
                .padding(14).background(Color(UIColor.systemGray6)).cornerRadius(14)
            }
            .padding(16).background(.white).cornerRadius(16)
        }
    }
    
    @ViewBuilder
    private func statusBadgeView(platform: String) -> some View {
        if let s = platformStatuses.first(where: { $0.platform == platform }) {
            if s.configured && s.connected {
                Text("✓")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.green)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.green.opacity(0.1)).cornerRadius(6)
            } else if s.configured {
                Image(systemName: "wifi.slash")
                    .font(.caption2)
                    .foregroundColor(.red)
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
    
    var passwordTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "lock.fill").font(.title2).foregroundColor(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("修改登录密码").font(.headline)
                    Text("定期修改密码保障账号安全").font(.caption).foregroundColor(.secondary)
                }
            }
            
            FormField(label: "当前密码", value: $oldPwd, isSecure: true, placeholder: "请输入当前密码")
            FormField(label: "新密码", value: $newPwd, isSecure: true, placeholder: "至少 6 个字符")
            FormField(label: "确认密码", value: $confirmPwd, isSecure: true, placeholder: "再次输入新密码")
            
            if !confirmPwd.isEmpty && newPwd == confirmPwd {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                    Text("密码匹配")
                }.font(.caption).foregroundColor(.green)
            }
            
            Button(action: changePassword) {
                HStack {
                    if saving { ProgressView().tint(.white) }
                    Image(systemName: "lock.fill")
                    Text("修改密码")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.orange)
                .foregroundColor(.white).font(.headline).cornerRadius(14)
            }
            .disabled(saving)
            
            // 退出登录
            Button(role: .destructive) {
                auth.logout()
            } label: {
                Text("退出登录")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.red.opacity(0.1)).cornerRadius(14)
            }
        }
        .padding(16).background(.white).cornerRadius(16)
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
        // 各请求独立执行，完成后立即更新 UI，实现渐进式渲染
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

// MARK: - Tab Button

struct TabButton: View {
    let title: String
    var icon: String? = nil
    let active: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon).font(.caption2)
                }
                Text(title)
            }
            .font(.footnote.weight(active ? .semibold : .regular))
            .foregroundColor(active ? .primary : .secondary)
            .frame(maxWidth: .infinity, minHeight: 28)
            .padding(.horizontal, 8)
            .background(active ? Color.white : Color.clear)
            .cornerRadius(8)
        }
    }
}

// MARK: - Form Field

struct FormField: View {
    let label: String
    @Binding var value: String
    var isSecure: Bool = false
    var placeholder: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.subheadline.weight(.semibold))
            if isSecure {
                SecureField(placeholder ?? label, text: $value)
                    .textFieldStyle(.roundedBorder)
            } else {
                TextField(placeholder ?? label, text: $value)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }
}
