import Foundation

/// Garmin 数据中文本地化 — 与 frontend HomePage.tsx 保持一致
struct GarminLocalization {
    
    // MARK: - 训练状态
    static func trainingStatus(_ raw: String?) -> String {
        guard let s = raw else { return "-" }
        // 去掉尾部数字后缀，如 MAINTAINING_2 → MAINTAINING
        let base = s.components(separatedBy: "_").first(where: { !$0.allSatisfy(\.isNumber) })
            .flatMap { prefix in
                s.hasPrefix(prefix) ? String(s.split(separator: "_").filter { !$0.allSatisfy(\.isNumber) }.joined(separator: "_")) : nil
            } ?? s
        
        let map: [String: String] = [
            "MAINTAINING": "维持中",
            "PRODUCTIVE": "高效期",
            "PEAKING": "巅峰期",
            "RECOVERY": "恢复中",
            "UNPRODUCTIVE": "低效期",
            "DETRAINING": "退训中",
            "OVERREACHING": "过度训练",
        ]
        return map[base] ?? map[s] ?? s
    }
    
    // MARK: - ACWR 状态
    static func acwrStatus(_ raw: String?) -> (text: String, color: String) {
        guard let s = raw else { return ("-", "gray") }
        let map: [String: (String, String)] = [
            "OPTIMAL": ("最佳", "green"),
            "HIGH": ("偏高", "orange"),
            "LOW": ("偏低", "blue"),
            "VERY_HIGH": ("过高", "red"),
        ]
        if let found = map[s] { return found }
        return (s, "gray")
    }
    
    // MARK: - HRV 状态
    static func hrvStatus(_ raw: String?) -> String {
        guard let s = raw else { return "-" }
        let map: [String: String] = [
            "BALANCED": "均衡",
            "UNBALANCED": "失衡",
            "LOW": "偏低",
            "POOR": "差",
        ]
        return map[s] ?? s
    }
    
    // MARK: - 睡眠质量
    static func sleepQuality(_ raw: String?) -> String {
        guard let s = raw else { return "-" }
        let map: [String: String] = [
            "EXCELLENT": "优秀",
            "GOOD": "良好",
            "FAIR": "一般",
            "POOR": "较差",
        ]
        return map[s] ?? s
    }
    
    // MARK: - 运动类型
    static func sportType(_ raw: String?) -> String {
        guard let s = raw else { return "活动" }
        let map: [String: String] = [
            "cycling": "骑行",
            "running": "跑步",
            "swimming": "游泳",
            "walking": "步行",
            "strength_training": "力量训练",
            "hiking": "徒步",
            "yoga": "瑜伽",
            "elliptical": "椭圆机",
            "indoor_cycling": "室内骑行",
            "treadmill_running": "跑步机",
            "open_water_swimming": "公开水域",
            "trail_running": "越野跑",
            "multi_sport": "多项运动",
        ]
        return map[s] ?? s
    }
    
    // MARK: - 训练负荷反馈
    static func trainingLoadFeedback(_ raw: String?) -> String {
        guard let s = raw else { return "" }
        let map: [String: String] = [
            "AEROBIC_LOW_SHORTAGE": "缺乏低强度有氧负荷",
            "AEROBIC_HIGH_SHORTAGE": "缺乏高强度有氧负荷",
            "ANAEROBIC_SHORTAGE": "缺乏无氧负荷",
            "BALANCED": "训练负荷均衡",
            "AEROBIC_LOW_SURPLUS": "低强度有氧负荷过多",
            "AEROBIC_HIGH_SURPLUS": "高强度有氧负荷过多",
            "ANAEROBIC_SURPLUS": "无氧负荷过多",
        ]
        return map[s] ?? s
    }
}
