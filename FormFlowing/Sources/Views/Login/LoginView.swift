import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var username = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isRegister = false
    @State private var loading = false
    @State private var error = ""

    var body: some View {
        Form {
            Section {
                VStack(spacing: 8) {
                    Image("BrandLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 18))

                    Text("FormFlowing")
                        .font(.title.bold())

                    Text("训练数据分析平台")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            Section {
                TextField("用户名", text: $username)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("密码", text: $password)
                    .textContentType(isRegister ? .newPassword : .password)
                if isRegister {
                    SecureField("确认密码", text: $confirmPassword)
                        .textContentType(.newPassword)
                }
            } header: {
                Text(isRegister ? "注册账号" : "登录")
            } footer: {
                if !error.isEmpty {
                    Label(error, systemImage: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button(action: handleSubmit) {
                    HStack {
                        if loading {
                            ProgressView()
                        }
                        Text(isRegister ? "注册" : "登录")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(loading)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                Button(isRegister ? "已有账号？去登录" : "没有账号？去注册") {
                    isRegister.toggle()
                    error = ""
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
    }

    private func handleSubmit() {
        guard !username.trimmingCharacters(in: .whitespaces).isEmpty,
              !password.isEmpty else {
            error = "请输入用户名和密码"
            return
        }

        if isRegister && password != confirmPassword {
            error = "两次密码不一致"
            return
        }

        loading = true
        error = ""

        Task {
            do {
                if isRegister {
                    _ = try await APIService.shared.register(username: username, password: password)
                }
                let res = try await APIService.shared.login(username: username, password: password)
                await MainActor.run {
                    auth.login(accessToken: res.accessToken, refreshToken: res.refreshToken, username: username, tier: res.tier, tierExpiresAt: res.tierExpiresAt)
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.loading = false
                }
            }
        }
    }
}
