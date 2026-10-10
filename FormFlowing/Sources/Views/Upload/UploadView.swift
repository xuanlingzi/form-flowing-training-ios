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
        Group {
            switch state {
            case .idle:
                ContentUnavailableView {
                    Label("上传活动文件", systemImage: "doc.badge.arrow.up")
                } description: {
                    Text("支持 .fit 格式，最大 50MB")
                    if !selectedFileName.isEmpty {
                        Text("已选文件：\(selectedFileName)")
                    }
                } actions: {
                    Button {
                        showFileImporter = true
                    } label: {
                        Label("选择文件", systemImage: "folder")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                
            case .uploading:
                ProgressView {
                    Text("上传中...")
                    if !selectedFileName.isEmpty {
                        Text(selectedFileName).font(.caption)
                    }
                }
                .controlSize(.large)
                
            case .analyzing:
                ContentUnavailableView(
                    "AI 分析中...",
                    systemImage: "brain.head.profile",
                    description: Text("正在分析你的训练数据")
                )
                
            case .done:
                ContentUnavailableView {
                    Label("上传成功！", systemImage: "checkmark.circle.fill")
                } actions: {
                    if let id = activityId {
                        NavigationLink("查看活动", destination: ActivityDetailView(activityId: id))
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                    }
                    Button("继续上传") { state = .idle }
                }
                
            case .error:
                ContentUnavailableView {
                    Label("上传失败", systemImage: "xmark.circle.fill")
                } description: {
                    Text(error)
                } actions: {
                    Button("重试") { state = .idle }
                        .buttonStyle(.bordered)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
