import SwiftUI
import UniformTypeIdentifiers

struct UploadView: View {
    @Environment(\.dismiss) var dismiss
    @State private var state: UploadState = .idle
    @State private var activityId: Int?
    @State private var error = ""
    @State private var showFileImporter = false
    @State private var selectedFileName = ""
    
    private let maxFileSize: Int64 = 50 * 1024 * 1024
    private var fitContentType: UTType {
        UTType(filenameExtension: "fit") ?? .data
    }
    
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
                    
                    if !selectedFileName.isEmpty {
                        Text("已选文件：\(selectedFileName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    Button(action: {
                        showFileImporter = true
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
                    if !selectedFileName.isEmpty {
                        Text(selectedFileName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
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
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("关闭") { dismiss() }
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [fitContentType],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task { await handlePickedFile(url) }
            case .failure(let importError):
                state = .error
                error = importError.localizedDescription
            }
        }
    }
    
    @MainActor
    private func handlePickedFile(_ url: URL) async {
        do {
            let fileURL = try prepareFileForUpload(from: url)
            selectedFileName = url.lastPathComponent
            activityId = nil
            error = ""
            state = .uploading
            
            let response = try await APIService.shared.uploadActivity(fileURL: fileURL)
            activityId = response.activityId
            state = .done
        } catch {
            state = .error
            self.error = error.localizedDescription
        }
    }
    
    private func prepareFileForUpload(from url: URL) throws -> URL {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let fileExtension = url.pathExtension.lowercased()
        guard fileExtension == "fit" else {
            throw UploadViewError.unsupportedFileType
        }

        let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
        let fileSize = Int64(resourceValues.fileSize ?? 0)
        guard fileSize > 0 else {
            throw UploadViewError.emptyFile
        }
        guard fileSize <= maxFileSize else {
            throw UploadViewError.fileTooLarge(maxMB: Int(maxFileSize / 1024 / 1024))
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString)-\(url.lastPathComponent)")

        if FileManager.default.fileExists(atPath: tempURL.path) {
            try FileManager.default.removeItem(at: tempURL)
        }

        try FileManager.default.copyItem(at: url, to: tempURL)
        return tempURL
    }
}

private enum UploadViewError: LocalizedError {
    case unsupportedFileType
    case fileTooLarge(maxMB: Int)
    case emptyFile

    var errorDescription: String? {
        switch self {
        case .unsupportedFileType:
            return "请选择 .fit 格式文件"
        case .fileTooLarge(let maxMB):
            return "文件过大，请选择小于 \(maxMB)MB 的 FIT 文件"
        case .emptyFile:
            return "文件为空，请重新选择"
        }
    }
}
