import AppKit
import Combine
import Darwin
import ImageIO
import StillDockCore
import UniformTypeIdentifiers

struct PhotoItem: Identifiable {
    let id: UUID
    let url: URL
    let inspection: ImageInspection
    let thumbnail: NSImage
    let hasSecurityScope: Bool
    var result: ExportResult?
    var exportError: String?

    var hasGPS: Bool { inspection.metadataGroups.contains { $0.localizedCaseInsensitiveContains("GPS") } }
}

struct WorkbenchIssue: Identifiable {
    let id = UUID()
    let filename: String
    let message: String
}

private struct ImportedPhoto {
    let inspection: ImageInspection
    let thumbnail: CGImage
}

@MainActor
final class WorkbenchModel: ObservableObject {
    @Published private(set) var photos: [PhotoItem] = []
    @Published var selectedID: UUID?
    @Published var format: ExportFormat = .jpeg
    @Published var maxPixelSize = 1920
    @Published var quality = 0.85
    @Published private(set) var isBusy = false
    @Published private(set) var isChoosing = false
    @Published private(set) var operationLabel = ""
    @Published private(set) var progress = 0.0
    @Published private(set) var progressDetail = ""
    @Published private(set) var issues: [WorkbenchIssue] = []
    @Published private(set) var completedDirectory: URL?
    @Published private(set) var exportSummary: String?
    @Published private(set) var cancelRequested = false

    private var task: Task<Void, Never>?
    private var loadedQAFixtures = false
    private let maxBatchCount = 100

    var selectedPhoto: PhotoItem? { photos.first { $0.id == selectedID } }
    var inputBytes: Int64 { photos.reduce(0) { $0 + $1.inspection.inputBytes } }
    var successfulResults: [ExportResult] { photos.compactMap(\.result) }
    var outputBytes: Int64 { successfulResults.reduce(0) { $0 + $1.outputBytes } }
    var gpsCount: Int { photos.filter(\.hasGPS).count }
    var isLocked: Bool { isBusy || isChoosing }
    var canExport: Bool { !photos.isEmpty && !isLocked }

    static func bytes(_ count: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: count, countStyle: .file)
    }

    func chooseImages() {
        guard !isLocked else { return }
        let panel = NSOpenPanel()
        panel.title = "공유할 사진 추가"
        panel.message = "JPEG, PNG, HEIC 사진을 최대 100장까지 추가할 수 있습니다."
        panel.prompt = "사진 추가"
        panel.allowedContentTypes = [.jpeg, .png, .heic, .heif]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        presentChooser(panel) { [weak self] response in
            if response == .OK { self?.importImages(panel.urls) }
        }
    }

    func importImages(_ urls: [URL]) {
        guard !isLocked, !urls.isEmpty else { return }
        let existing = Set(photos.map { $0.url.standardizedFileURL })
        var seen = existing
        let unique = urls.filter { seen.insert($0.standardizedFileURL).inserted }
        let availableCount = max(0, maxBatchCount - photos.count)
        let accepted = Array(unique.prefix(availableCount))
        issues = []
        if unique.count > availableCount {
            issues.append(.init(filename: "최대 100장", message: "남은 \(unique.count - availableCount)장은 추가하지 않았습니다. 사진을 제거한 후 다시 추가하세요."))
        }
        guard !accepted.isEmpty else { return }
        invalidateResults()
        isBusy = true
        cancelRequested = false
        operationLabel = "사진 확인 중"
        progress = 0
        task = Task { [weak self] in
            guard let self else { return }
            defer { self.finishOperation() }
            for (offset, url) in accepted.enumerated() {
                if Task.isCancelled { break }
                self.progressDetail = "\(offset + 1) / \(accepted.count) · \(url.lastPathComponent)"
                let scoped = url.startAccessingSecurityScopedResource()
                do {
                    let imported = try await Task.detached(priority: .userInitiated) {
                        let inspection = try ImageProcessor().inspect(url)
                        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
                        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions),
                              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                                kCGImageSourceCreateThumbnailFromImageAlways: true,
                                kCGImageSourceCreateThumbnailWithTransform: true,
                                kCGImageSourceThumbnailMaxPixelSize: 800,
                                kCGImageSourceShouldCacheImmediately: true
                              ] as CFDictionary) else {
                            throw CocoaError(.fileReadCorruptFile)
                        }
                        return ImportedPhoto(inspection: inspection, thumbnail: image)
                    }.value
                    if Task.isCancelled {
                        if scoped { url.stopAccessingSecurityScopedResource() }
                        break
                    }
                    let item = PhotoItem(id: UUID(), url: url, inspection: imported.inspection,
                                         thumbnail: NSImage(cgImage: imported.thumbnail, size: .zero),
                                         hasSecurityScope: scoped)
                    self.photos.append(item)
                    if self.selectedID == nil { self.selectedID = item.id }
                } catch {
                    if scoped { url.stopAccessingSecurityScopedResource() }
                    self.issues.append(.init(filename: url.lastPathComponent, message: Self.message(for: error)))
                }
                self.progress = Double(offset + 1) / Double(accepted.count)
            }
        }
    }

    func chooseExportDirectory() {
        guard canExport else { return }
        let panel = NSOpenPanel()
        panel.title = "복사본을 저장할 위치"
        panel.message = "선택한 위치 안에 새로운 StillDock 폴더를 만듭니다. 원본은 수정하지 않습니다."
        panel.prompt = "여기에 저장"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        presentChooser(panel) { [weak self] response in
            if response == .OK, let url = panel.url { self?.export(to: url) }
        }
    }

    func export(to parentDirectory: URL) {
        guard canExport else { return }
        let entries = photos.map { (id: $0.id, url: $0.url) }
        let options = ExportOptions(format: format, maxPixelSize: maxPixelSize == 0 ? nil : maxPixelSize, jpegQuality: quality)
        invalidateResults()
        issues = []
        isBusy = true
        cancelRequested = false
        operationLabel = "복사본 저장 중"
        progress = 0
        let hasScope = parentDirectory.startAccessingSecurityScopedResource()
        task = Task { [weak self] in
            guard let self else {
                if hasScope { parentDirectory.stopAccessingSecurityScopedResource() }
                return
            }
            defer {
                if hasScope { parentDirectory.stopAccessingSecurityScopedResource() }
                self.finishOperation()
            }
            do {
                let directory = try await Task.detached(priority: .userInitiated) {
                    let formatter = DateFormatter()
                    formatter.locale = Locale(identifier: "en_US_POSIX")
                    formatter.dateFormat = "yyyy-MM-dd_HHmmss"
                    let stem = "StillDock_\(formatter.string(from: Date()))_\(UUID().uuidString.prefix(8).lowercased())"
                    let candidate = parentDirectory.appendingPathComponent(stem, isDirectory: true)
                    guard mkdir(candidate.path, 0o700) == 0 else {
                        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: [NSFilePathErrorKey: candidate.path])
                    }
                    return candidate
                }.value
                self.completedDirectory = directory
                var failureCount = 0
                for (offset, entry) in entries.enumerated() {
                    if Task.isCancelled { break }
                    self.progressDetail = "\(offset + 1) / \(entries.count) · \(entry.url.lastPathComponent)"
                    do {
                        let result = try await Task.detached(priority: .userInitiated) {
                            try ImageProcessor().export(inputURL: entry.url, to: directory,
                                                        filename: String(format: "photo-%03d", offset + 1), options: options)
                        }.value
                        if let index = self.photos.firstIndex(where: { $0.id == entry.id }) { self.photos[index].result = result }
                    } catch {
                        failureCount += 1
                        if let index = self.photos.firstIndex(where: { $0.id == entry.id }) { self.photos[index].exportError = Self.message(for: error) }
                        self.issues.append(.init(filename: entry.url.lastPathComponent, message: Self.message(for: error)))
                    }
                    self.progress = Double(offset + 1) / Double(entries.count)
                }
                let count = self.successfulResults.count
                let failureSummary = failureCount == 0 ? "" : " · \(failureCount)장 실패"
                self.exportSummary = Task.isCancelled
                    ? "저장을 중단했습니다. 완료된 \(count)장은 폴더에 남아 있습니다." + failureSummary
                    : "\(count)장 저장 완료" + (failureCount == 0 ? " · 메타데이터 재검사 완료" : failureSummary)
            } catch {
                self.issues.append(.init(filename: "저장 폴더", message: Self.message(for: error)))
            }
        }
    }

    func cancel() {
        guard isBusy else { return }
        cancelRequested = true
        task?.cancel()
    }

    func removeSelection() {
        guard !isLocked, let id = selectedID, let index = photos.firstIndex(where: { $0.id == id }) else { return }
        let removed = photos.remove(at: index)
        if removed.hasSecurityScope { removed.url.stopAccessingSecurityScopedResource() }
        selectedID = photos.isEmpty ? nil : photos[min(index, photos.count - 1)].id
        invalidateResults()
    }

    func clear() {
        guard !isLocked else { return }
        for photo in photos where photo.hasSecurityScope { photo.url.stopAccessingSecurityScopedResource() }
        photos = []
        selectedID = nil
        issues = []
        invalidateResults()
    }

    func dismissIssues() { issues = [] }

    func revealExports() {
        guard let directory = completedDirectory else { return }
        NSWorkspace.shared.activateFileViewerSelecting([directory])
    }

    func revealSelectedExport() {
        guard let result = selectedPhoto?.result else { return }
        NSWorkspace.shared.activateFileViewerSelecting([result.outputURL])
    }

    func importQAFixturesIfRequested() {
        guard !loadedQAFixtures else { return }
        loadedQAFixtures = true
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--qa-fixtures"), arguments.indices.contains(index + 1) else { return }
        let directory = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        Task {
            let urls = await Task.detached {
                (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil))?
                    .filter { ["jpg", "jpeg", "png", "heic", "heif"].contains($0.pathExtension.lowercased()) }
                    .sorted { $0.lastPathComponent < $1.lastPathComponent } ?? []
            }.value
            self.importImages(urls)
        }
    }

    private func invalidateResults() {
        completedDirectory = nil
        exportSummary = nil
        for index in photos.indices {
            photos[index].result = nil
            photos[index].exportError = nil
        }
    }

    private func presentChooser(_ panel: NSOpenPanel, completion: @escaping @MainActor (NSApplication.ModalResponse) -> Void) {
        isChoosing = true
        let handler: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            Task { @MainActor in
                guard let self else { return }
                self.isChoosing = false
                completion(response)
            }
        }
        if let window = NSApp.keyWindow {
            panel.beginSheetModal(for: window, completionHandler: handler)
        } else {
            panel.begin(completionHandler: handler)
        }
    }

    private func finishOperation() {
        isBusy = false
        task = nil
        operationLabel = ""
        progressDetail = ""
        cancelRequested = false
    }

    private static func message(for error: Error) -> String {
        guard let imageError = error as? ImageProcessingError else { return error.localizedDescription }
        switch imageError {
        case .invalidInput: return "파일을 읽을 수 없습니다. 이 Mac에 저장된 사진 파일을 선택하세요."
        case .unsupportedFormat: return "JPEG, PNG, HEIC/HEIF 형식의 사진만 추가할 수 있습니다."
        case .multipleFrames: return "움직이는 이미지나 여러 프레임이 든 파일은 지원하지 않습니다. 한 장의 사진으로 저장한 뒤 추가하세요."
        case .imageTooLarge: return "한 장의 사진은 1억 화소와 512 MB 이하여야 합니다."
        case .invalidOptions: return "내보내기 크기 또는 JPEG 품질 설정을 확인하세요."
        case .decodeFailed: return "사진이 손상되었거나 이미지 내용을 읽을 수 없습니다."
        case .encodeFailed: return "새 복사본으로 변환하지 못했습니다. 다른 포맷으로 다시 시도하세요."
        case .verificationFailed: return "저장한 사진이 크기 또는 메타데이터 재검사를 통과하지 못했습니다."
        case .invalidDestination: return "저장할 수 있는 폴더를 선택하세요. 폴더 접근 권한을 확인해 주세요."
        case .fileOperation(let detail): return "복사본을 저장하지 못했습니다. 저장 공간과 폴더 접근 권한을 확인하세요.\n\(detail)"
        }
    }
}
