import SwiftUI

struct MemoryView: View {
    @State private var memories: [MemoryItem] = []
    @State private var editingContent: [String: String] = [:]
    @State private var editingTypes: Set<String> = []
    @State private var loading = true
    @State private var saving = false

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
        }
        .overlay {
            if loading {
                ProgressView()
            } else if memories.isEmpty {
                ContentUnavailableView("暂无数据", systemImage: "brain.head.profile")
            }
        }
        .navigationTitle("记忆管理")
        .navigationBarTitleDisplayMode(.inline)
        .hideTabBar()
        .task { await loadMemories() }
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
                        editingContent[item.type] = item.content ?? ""
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
