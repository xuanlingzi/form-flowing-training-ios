import Foundation
import Security

/// 认证管理器
@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var isAuthenticated = false
    @Published var username: String = ""
    @Published var token: String = ""

    private let accessTokenKey = "access_token"
    private let usernameKey = "username"
    private let keychainService = "com.formflowing.ios.auth"
    private let keychainAccount = "saved_refresh_token"

    private init() {
        let savedToken = UserDefaults.standard.string(forKey: accessTokenKey) ?? ""
        let savedUsername = UserDefaults.standard.string(forKey: usernameKey) ?? ""
        if !savedToken.isEmpty {
            token = savedToken
            username = savedUsername
            isAuthenticated = true
        }
    }

    func login(accessToken: String, refreshToken: String?, username: String) {
        self.token = accessToken
        self.username = username
        isAuthenticated = true

        UserDefaults.standard.set(accessToken, forKey: accessTokenKey)
        UserDefaults.standard.set(username, forKey: usernameKey)

        if let refreshToken, !refreshToken.isEmpty {
            saveRefreshToken(refreshToken)
        }
    }

    func updateAccessToken(_ token: String) {
        self.token = token
        isAuthenticated = !token.isEmpty
        UserDefaults.standard.set(token, forKey: accessTokenKey)
    }

    func storedRefreshToken() -> String? {
        guard let refreshToken = loadRefreshToken(), !refreshToken.isEmpty else {
            return nil
        }
        return refreshToken
    }

    func shouldRefreshToken(within seconds: TimeInterval = 300) -> Bool {
        guard let expiryDate = tokenExpiryDate() else {
            return false
        }
        return expiryDate.timeIntervalSinceNow <= seconds
    }

    func logout(clearStoredCredentials: Bool = false) {
        token = ""
        username = ""
        isAuthenticated = false

        UserDefaults.standard.removeObject(forKey: accessTokenKey)
        UserDefaults.standard.removeObject(forKey: usernameKey)

        if clearStoredCredentials {
            deleteRefreshToken()
        }
        
        // 清除本地 API 缓存
        Task { await CacheService.shared.clearAll() }
    }

    private func tokenExpiryDate() -> Date? {
        guard !token.isEmpty else { return nil }
        let segments = token.split(separator: ".")
        guard segments.count > 1 else { return nil }

        var base64 = String(segments[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let remainder = base64.count % 4
        if remainder != 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }

        guard let data = Data(base64Encoded: base64),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = payload["exp"] as? TimeInterval else {
            return nil
        }

        return Date(timeIntervalSince1970: exp)
    }

    private func saveRefreshToken(_ refreshToken: String) {
        let encodedToken = Data(refreshToken.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ]

        SecItemDelete(query as CFDictionary)

        var item = query
        item[kSecValueData as String] = encodedToken
        SecItemAdd(item as CFDictionary, nil)
    }

    private func loadRefreshToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let refreshToken = String(data: data, encoding: .utf8) else {
            return nil
        }

        return refreshToken
    }

    private func deleteRefreshToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
