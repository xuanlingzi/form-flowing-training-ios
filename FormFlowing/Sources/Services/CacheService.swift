import Foundation

/// 磁盘 JSON 缓存服务
/// 将 API 响应以 JSON 文件形式缓存到 Caches 目录
/// 采用 Cache-First + Background Refresh 策略
actor CacheService {
    static let shared = CacheService()
    
    private let cacheDir: URL
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()
    private let encoder = JSONEncoder()
    
    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDir = caches.appendingPathComponent("api_cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }
    
    // MARK: - 缓存条目结构
    
    private struct CacheEntry: Codable {
        let data: Data       // 原始 JSON 数据
        let cachedAt: Date   // 缓存时间
    }
    
    // MARK: - 公开方法
    
    /// 从缓存读取数据（如果存在且未过期）
    /// - Parameters:
    ///   - key: 缓存 key（通常是 API path）
    ///   - type: 解码目标类型
    ///   - maxAge: 最大缓存时间（秒），默认 nil = 忽略过期
    /// - Returns: 缓存数据，不存在或已过期则返回 nil
    func get<T: Decodable & Sendable>(_ key: String, as type: T.Type, maxAge: TimeInterval? = nil) -> T? {
        let fileURL = fileURL(for: key)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        
        do {
            let fileData = try Data(contentsOf: fileURL)
            let entry = try JSONDecoder().decode(CacheEntry.self, from: fileData)
            
            // 检查是否过期
            if let maxAge, Date().timeIntervalSince(entry.cachedAt) > maxAge {
                return nil
            }
            
            return try decoder.decode(type, from: entry.data)
        } catch {
            // 缓存损坏，清除
            try? FileManager.default.removeItem(at: fileURL)
            return nil
        }
    }
    
    /// 将数据写入缓存
    /// - Parameters:
    ///   - key: 缓存 key
    ///   - data: 原始 JSON Data（直接从网络响应获取）
    func set(_ key: String, data: Data) {
        let entry = CacheEntry(data: data, cachedAt: Date())
        do {
            let encoded = try JSONEncoder().encode(entry)
            try encoded.write(to: fileURL(for: key), options: .atomic)
        } catch {
            // 写入失败不影响业务
        }
    }
    
    /// 将 Encodable 对象写入缓存
    func set<T: Encodable & Sendable>(_ key: String, value: T) {
        do {
            let jsonData = try encoder.encode(value)
            set(key, data: jsonData)
        } catch {
            // 编码失败不影响业务
        }
    }
    
    /// 使指定 key 的缓存失效
    func invalidate(_ key: String) {
        try? FileManager.default.removeItem(at: fileURL(for: key))
    }
    
    /// 使匹配前缀的所有缓存失效
    func invalidatePrefix(_ prefix: String) {
        let safePrefix = safeFileName(prefix)
        guard let files = try? FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil) else { return }
        for file in files where file.lastPathComponent.hasPrefix(safePrefix) {
            try? FileManager.default.removeItem(at: file)
        }
    }
    
    /// 清除全部缓存（登出时调用）
    func clearAll() {
        try? FileManager.default.removeItem(at: cacheDir)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }
    
    // MARK: - 私有方法
    
    private func fileURL(for key: String) -> URL {
        cacheDir.appendingPathComponent(safeFileName(key) + ".json")
    }
    
    /// 将 API path 转换为安全文件名
    private func safeFileName(_ key: String) -> String {
        key.replacingOccurrences(of: "/", with: "_")
           .replacingOccurrences(of: "?", with: "_")
           .replacingOccurrences(of: "&", with: "_")
           .replacingOccurrences(of: "=", with: "_")
           .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
    }
}
