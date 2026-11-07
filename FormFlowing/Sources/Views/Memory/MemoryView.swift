import SwiftUI

struct MemoryView: View {
    @State private var memories: [MemoryItem] = []
    @State private var editingContent: [String: String] = [:]
    @State private var editingTypes: Set<String> = []
    @State private var loading = true
    @State private var saving = false
    @State private var sessionPoints: [SessionPointItem] = []
    @State private var pointsLoaded = false

    var editableMemories: [MemoryItem] {
        memories.filter { $0.editable == true }
    }

    var aiMemories: [MemoryItem] {
        memories.filter { $0.editable != true }
    }

    var body: some View {
        List {
            if !editableMemories.isEmpty {
                Section("可编辑数据") {
                    ForEach(editableMemories) { item in
                        memoryRow(item: item)
                    }
                }
            }

            if !aiMemories.isEmpty {
                Section("AI 生成数据") {
                    ForEach(aiMemories) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            LabeledContent {
                                Text("v\(item.version ?? 0)")
                            } label: {
                                Text(item.label ?? item.type).font(.subheadline.weight(.semibold))
                            }
                            MarkdownTextView(markdown: item.content ?? "暂无数据", baseFontSize: 13)
                        }
                    }
                }
            }

            if pointsLoaded && !(memories.isEmpty && sessionPoints.isEmpty) {
                sessionPointsSection
            }
        }
        .overlay {
            if loading {
                ProgressView()
            } else if memories.isEmpty && sessionPoints.isEmpty {
                ContentUnavailableView("暂无数据", systemImage: "brain.head.profile")
            }
        }
        .navigationTitle("记忆管理")
        .navigationBarTitleDisplayMode(.inline)
        .hideTabBar()
        .task { await loadMemories() }
        // 本场要点单独加载，失败不影响记忆展示
        .task { await loadSessionPoints() }
    }

    // MARK: - 最近训练要点

    /// 最近几场分析的「本场要点」：运动员模型的原始证据，只读
    private var sessionPointsSection: some View {
        Section {
            if sessionPoints.isEmpty {
                Text("暂无。新的单场分析完成后会在这里出现。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sessionPoints) { item in
                    NavigationLink(destination: ActivityDetailView(activityId: item.activityId)) {
                        sessionPointRow(item)
                    }
                }
            }
        } header: {
            Text("最近训练要点")
        } footer: {
            Text("每场 AI 分析记下的要点，运动员模型每周从这里汇总。重新分析旧活动只更新那一场，不会改写当前的判断。")
        }
    }

    private func sessionPointRow(_ item: SessionPointItem) -> some View {
        let meta = [item.sessionTypeLabel, item.planMatch]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
        let observations = item.observations ?? []
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(String((item.date ?? "").prefix(10)))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Text(item.name ?? item.sport ?? "活动 \(item.activityId)")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            if !meta.isEmpty || (item.dataQuality != nil && item.dataQuality != "ok") {
                HStack(spacing: 6) {
                    if !meta.isEmpty {
                        Text(meta)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let quality = item.dataQuality, quality != "ok" {
                        badge(item.dataQualityLabel ?? quality, color: .orange)
                    }
                }
            }
            if observations.isEmpty {
                Text("无值得记录的观察")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(observations.enumerated()), id: \.offset) { _, obs in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        badge(obs.kindLabel ?? obs.kind ?? "-", color: kindColor(obs.kind))
                        Text(observationText(obs))
                            .font(.footnote)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
    }

    private func kindColor(_ kind: String?) -> Color {
        switch kind ?? "" {
        case "limiter": return .orange
        case "strength": return .green
        case "execution": return .blue
        case "health": return .purple
        default: return .gray
        }
    }

    private func observationText(_ obs: SessionPointObservation) -> String {
        let text = obs.text ?? ""
        let confidence: String? = switch obs.confidence ?? "" {
        case "high": "把握高"
        case "medium": "把握中"
        case "low": "把握低"
        default: nil
        }
        return confidence.map { "\(text)（\($0)）" } ?? text
    }

    private func loadSessionPoints() async {
        let res = try? await APIService.shared.getSessionPoints(limit: 5)
        await MainActor.run {
            if let res { sessionPoints = res.items }
            pointsLoaded = true
        }
    }

    @ViewBuilder
    func memoryRow(item: MemoryItem) -> some View {
        let isEditing = editingTypes.contains(item.type)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.label ?? item.type).font(.subheadline.weight(.semibold))
                Spacer()
                if isEditing {
                    Button("取消") { editingTypes.remove(item.type) }
                        .buttonStyle(.bordered)
                    Button("保存") { saveMemory(type: item.type) }
                        .buttonStyle(.borderedProminent)
                        .disabled(saving)
                } else {
                    Button("编辑") {
                        // 内容为空时用服务端给的模板预填（运动员声明等）
                        let current = item.content ?? ""
                        editingContent[item.type] = current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? (item.template ?? "")
                            : current
                        editingTypes.insert(item.type)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .controlSize(.small)

            if isEditing {
                TextEditor(text: Binding(
                    get: { editingContent[item.type] ?? "" },
                    set: { editingContent[item.type] = $0 }
                ))
                .frame(minHeight: 120)
            } else {
                MarkdownTextView(markdown: item.content ?? "暂无数据", baseFontSize: 13)
            }
        }
    }

    private func loadMemories() async {
        if let cached = await APIService.shared.cached("/memory", as: MemoryListResponse.self) {
            await MainActor.run {
                memories = cached.memories
                loading = false
            }
        }

        do {
            let res = try await APIService.shared.getMemories()
            await MainActor.run {
                memories = res.memories
                loading = false
            }
        } catch {
            await MainActor.run {
                if memories.isEmpty { loading = false }
            }
        }
    }

    private func saveMemory(type: String) {
        guard let content = editingContent[type] else { return }
        saving = true
        Task {
            do {
                try await APIService.shared.updateMemory(type: type, content: content)
                await MainActor.run {
                    editingTypes.remove(type)
                    saving = false
                }
                await loadMemories()
            } catch {
                await MainActor.run { saving = false }
            }
        }
    }
}
