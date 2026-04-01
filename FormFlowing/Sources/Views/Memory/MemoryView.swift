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
        GeometryReader { geometry in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 16) {
                    if loading {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 60)
                    } else {
                        // 可编辑
                        if !editableMemories.isEmpty {
                            Text("可编辑数据").font(.headline).padding(.horizontal)
                            ForEach(editableMemories) { item in
                                memoryCard(item: item)
                            }
                        }
                        
                        // AI 生成
                        if !aiMemories.isEmpty {
                            Text("AI 生成数据").font(.headline).padding(.horizontal).padding(.top, 8)
                            ForEach(aiMemories) { item in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(item.label ?? item.type)
                                            .font(.subheadline.weight(.semibold))
                                        Spacer()
                                        Text("v\(item.version ?? 0)")
                                            .font(.caption2).foregroundColor(.secondary)
                                    }
                                    MarkdownTextView(markdown: item.content ?? "暂无数据", baseFontSize: 13)
                                }
                                .padding(16)
                                .background(.white)
                                .cornerRadius(16)
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.vertical)
                .frame(width: geometry.size.width)
                .clipped()
            }
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("记忆管理")
        .navigationBarTitleDisplayMode(.inline)
        .hideTabBar()
        .task { await loadMemories() }
    }
    
    @ViewBuilder
    func memoryCard(item: MemoryItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.label ?? item.type).font(.subheadline.weight(.semibold))
                Spacer()
                if editingTypes.contains(item.type) {
                    Button("保存") { saveMemory(type: item.type) }
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12).padding(.vertical, 4)
                        .background(Color.teal).cornerRadius(8)
                    Button("取消") { editingTypes.remove(item.type) }
                        .font(.caption).foregroundColor(.secondary)
                } else {
                    Button("编辑") {
                        editingContent[item.type] = item.content ?? ""
                        editingTypes.insert(item.type)
                    }
                    .font(.caption).foregroundColor(.teal)
                }
            }
            
            if editingTypes.contains(item.type) {
                TextEditor(text: Binding(
                    get: { editingContent[item.type] ?? "" },
                    set: { editingContent[item.type] = $0 }
                ))
                .frame(minHeight: 100)
                .padding(8)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(10)
            } else {
                MarkdownTextView(markdown: item.content ?? "暂无数据", baseFontSize: 13)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .clipped()
            }
        }
        .padding(16)
        .background(.white)
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    private func loadMemories() async {
        loading = true
        do {
            let res = try await APIService.shared.getMemories()
            await MainActor.run {
                memories = res.memories
                loading = false
            }
        } catch {
            await MainActor.run { loading = false }
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
