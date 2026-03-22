import SwiftUI

struct UploadView: View {
    @Environment(\.dismiss) var dismiss
    @State private var state: UploadState = .idle
    @State private var activityId: Int?
    @State private var error = ""
    
    enum UploadState {
        case idle, uploading, analyzing, done, error
    }
    
    var body: some View {
        VStack(spacing: 24) {
            switch state {
            case .idle:
                VStack(spacing: 16) {
                    Image(systemName: "doc.badge.arrow.up")
                        .font(.system(size: 48))
                        .foregroundColor(.teal)
                    
                    Text("上传活动文件")
                        .font(.title3.bold())
                    
                    Text("支持 .fit 格式，最大 50MB")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("⚠️ iOS 原生文件上传需要通过 Files app 集成")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // 提示用户使用 Web 版上传
                    Button(action: {
                        // TODO: 使用 UIDocumentPickerViewController 实现文件选择
                        state = .uploading
                        Task {
                            try? await Task.sleep(nanoseconds: 2_000_000_000)
                            await MainActor.run { state = .done; activityId = 1 }
                        }
                    }) {
                        Label("选择文件", systemImage: "folder")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(LinearGradient(colors: [.teal, .green], startPoint: .leading, endPoint: .trailing))
                            .foregroundColor(.white)
                            .font(.headline)
                            .cornerRadius(14)
                    }
                }
                
            case .uploading:
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("上传中...").font(.headline)
                }
                
            case .analyzing:
                VStack(spacing: 16) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 48)).foregroundColor(.purple)
                    Text("AI 分析中...").font(.headline)
                    Text("正在分析你的训练数据").font(.caption).foregroundColor(.secondary)
                }
                
            case .done:
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48)).foregroundColor(.green)
                    Text("上传成功！").font(.headline)
                    
                    if let id = activityId {
                        NavigationLink("查看活动", destination: ActivityDetailView(activityId: id))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(LinearGradient(colors: [.teal, .green], startPoint: .leading, endPoint: .trailing))
                            .foregroundColor(.white).font(.headline).cornerRadius(14)
                    }
                    
                    Button("继续上传") { state = .idle }
                        .foregroundColor(.secondary)
                }
                
            case .error:
                VStack(spacing: 16) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 48)).foregroundColor(.red)
                    Text("上传失败").font(.headline).foregroundColor(.red)
                    Text(error).font(.caption).foregroundColor(.secondary)
                    Button("重试") { state = .idle }
                }
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("上传活动")
        .navigationBarTitleDisplayMode(.inline)
    }
}
