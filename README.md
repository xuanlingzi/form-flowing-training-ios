# FormFlowing iOS

一个使用 SwiftUI 构建的 iOS 版 FormFlowing 训练数据分析应用。

## 功能模块

| 模块 | 文件 | 功能 |
|------|------|------|
| 登录 | `LoginView.swift` | 用户名/密码登录注册 |
| 仪表盘 | `HomeView.swift` | 训练状态、心率、体力电池、睡眠、AI 分析 |
| 活动列表 | `ActivitiesView.swift` | 分页加载活动列表，卡片展示 |
| 活动详情 | `ActivityDetailView.swift` | 核心指标、分圈数据、AI 分析 |
| 训练计划 | `TrainingView.swift` | 日历视图、今日训练、月份导航 |
| 设置 | `SettingsView.swift` | 个人档案/Garmin 账号/密码修改 |
| 上传 | `UploadView.swift` | FIT 文件上传 |
| 记忆管理 | `MemoryView.swift` | 可编辑数据/AI 生成数据管理 |

## 技术栈

- **SwiftUI** (iOS 17+)
- **Swift Concurrency** (async/await)
- **URLSession** 网络请求
- **Codable** 数据模型

## 开始使用

1. 使用 Xcode 15+ 打开 `ios/` 目录
2. 在 `APIService.swift` 中修改 `baseURL` 为你的 API 地址
3. Build & Run

## 项目结构

```
ios/
├── Package.swift
└── FormFlowing/
    ├── Assets.xcassets/
    └── Sources/
        ├── FormFlowingApp.swift    # App 入口
        ├── Models/
        │   └── Models.swift         # 数据模型
        ├── Services/
        │   ├── APIService.swift     # API 服务
        │   └── AuthManager.swift    # 认证管理
        └── Views/
            ├── MainTabView.swift    # 底部导航
            ├── Login/
            ├── Home/
            ├── Activities/
            ├── ActivityDetail/
            ├── Training/
            ├── Settings/
            ├── Upload/
            └── Memory/
```
