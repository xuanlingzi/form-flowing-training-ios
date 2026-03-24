import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var username = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isRegister = false
    @State private var loading = false
    @State private var error = ""
    @State private var showPassword = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Logo
            VStack(spacing: 8) {
                Image("BrandLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: .teal.opacity(0.3), radius: 12, y: 6)
                
                Text("FormFlowing")
                    .font(.system(size: 28, weight: .bold))
                
                Text("训练数据分析平台")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 40)
            
            // Form
            VStack(spacing: 16) {
                Text(isRegister ? "注册账号" : "登录")
                    .font(.title2.bold())
                
                if !error.isEmpty {
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill")
                        Text(error)
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("用户名").font(.subheadline.weight(.semibold))
                    TextField("请输入用户名", text: $username)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("密码").font(.subheadline.weight(.semibold))
                    if showPassword {
                        TextField("请输入密码", text: $password)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("请输入密码", text: $password)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                
                if isRegister {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("确认密码").font(.subheadline.weight(.semibold))
                        SecureField("请再次输入密码", text: $confirmPassword)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                
                Button(action: handleSubmit) {
                    HStack {
                        if loading {
                            ProgressView().tint(.white)
                        }
                        Text(isRegister ? "注册" : "登录")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(LinearGradient(colors: [.teal, .green], startPoint: .leading, endPoint: .trailing))
                    .foregroundColor(.white)
                    .font(.headline)
                    .cornerRadius(14)
                }
                .disabled(loading)
                
                Button {
                    isRegister.toggle()
                    error = ""
                } label: {
                    HStack(spacing: 4) {
                        Text(isRegister ? "已有账号？" : "没有账号？")
                            .foregroundColor(.secondary)
                        Text(isRegister ? "去登录" : "去注册")
                            .foregroundColor(.teal)
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                }
            }
            .padding(28)
            .background(.white)
            .cornerRadius(24)
            .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
            .padding(.horizontal, 24)
            
            Spacer()
        }
        .background(
            LinearGradient(colors: [Color.teal.opacity(0.05), Color(UIColor.systemGroupedBackground)], startPoint: .top, endPoint: .bottom)
        )
        .ignoresSafeArea()
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
                    auth.login(token: res.accessToken, username: username, password: password)
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
