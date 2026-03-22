import Foundation

/// 认证管理器
class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var username: String = ""
    @Published var token: String = ""
    
    init() {
        let savedToken = UserDefaults.standard.string(forKey: "access_token") ?? ""
        let savedUsername = UserDefaults.standard.string(forKey: "username") ?? ""
        if !savedToken.isEmpty {
            self.token = savedToken
            self.username = savedUsername
            self.isAuthenticated = true
        }
    }
    
    func login(token: String, username: String) {
        self.token = token
        self.username = username
        self.isAuthenticated = true
        UserDefaults.standard.set(token, forKey: "access_token")
        UserDefaults.standard.set(username, forKey: "username")
    }
    
    func logout() {
        self.token = ""
        self.username = ""
        self.isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: "access_token")
        UserDefaults.standard.removeObject(forKey: "username")
    }
}
