import AppKit
import Foundation

@MainActor
final class UpdateChecker: NSObject, ObservableObject {
    @Published var updateAvailable: AppUpdateInfo?
    @Published var showUpdateDialog = false
    @Published var isChecking = false
    @Published var isDownloading = false
    @Published var isReadyToRelaunch = false
    @Published var downloadProgress: Double = 0
    @Published var downloadedBytes: Int64 = 0
    @Published var totalBytes: Int64 = 0
    @Published var statusMessage: String?
    @Published var infoAlertMessage: String?
    @Published var errorMessage: String?
    @Published var hasDismissedBanner = false

    private var downloadedDMGURL: URL?
    private var downloadTask: URLSessionDownloadTask?
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 300
        return URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }()

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.1"
    }

    func checkOnLaunch() {
        Task {
            await checkForUpdates(isManual: false)
        }
    }

    func checkForUpdatesManually() {
        Task {
            await checkForUpdates(isManual: true)
        }
    }

    func checkForUpdates(isManual: Bool) async {
        guard !isChecking else { return }
        isChecking = true
        errorMessage = nil

        let apiURL = URL(string: "https://api.github.com/repos/beolamtat/qtube/releases/latest")!
        var request = URLRequest(url: apiURL)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("QTube-macOS", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                if isManual {
                    errorMessage = "Không thể kết nối đến máy chủ cập nhật."
                }
                isChecking = false
                return
            }

            let release = try JSONDecoder().decode(AppUpdateInfo.self, from: data)
            if isVersion(release.cleanVersion, newerThan: currentVersion) {
                self.updateAvailable = release
                self.showUpdateDialog = true
            } else if isManual {
                self.infoAlertMessage = "Bạn đang sử dụng phiên bản mới nhất (\(currentVersion))."
            }
        } catch {
            if isManual {
                errorMessage = "Lỗi khi kiểm tra: \(error.localizedDescription)"
            }
        }

        isChecking = false
    }

    func dismissUntilNextLaunch() {
        showUpdateDialog = false
    }

    func startDownload(for release: AppUpdateInfo) {
        guard let asset = release.assetForCurrentArchitecture() else {
            NSWorkspace.shared.open(release.htmlURL)
            return
        }

        isDownloading = true
        isReadyToRelaunch = false
        downloadProgress = 0
        downloadedBytes = 0
        totalBytes = asset.size
        errorMessage = nil
        statusMessage = "Đang tải xuống bản cập nhật…"

        let task = urlSession.downloadTask(with: asset.browserDownloadURL)
        self.downloadTask = task
        task.resume()
    }

    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
        isReadyToRelaunch = false
        statusMessage = nil
    }

    func applyUpdateAndRelaunch() {
        guard let dmgURL = downloadedDMGURL, FileManager.default.fileExists(atPath: dmgURL.path) else {
            errorMessage = "Không tìm thấy file cập nhật đã tải."
            return
        }

        // Đóng ngay pop-up để giải phóng modal sheet của AppKit
        showUpdateDialog = false
        statusMessage = "Đang khởi động lại ứng dụng…"

        let pid = ProcessInfo.processInfo.processIdentifier
        let currentAppPath = Bundle.main.bundleURL.path
        let targetAppPath: String
        if currentAppPath.hasPrefix("/Applications/") {
            targetAppPath = "/Applications/QTube.app"
        } else if currentAppPath.hasPrefix("/Volumes/") {
            targetAppPath = "/Applications/QTube.app"
        } else if currentAppPath.contains(".app") {
            targetAppPath = currentAppPath
        } else {
            targetAppPath = "/Applications/QTube.app"
        }

        let uniqueId = UUID().uuidString
        let scriptURL = FileManager.default.temporaryDirectory.appendingPathComponent("qtube_updater_\(uniqueId).sh")
        let mountDir = FileManager.default.temporaryDirectory.appendingPathComponent("qtube_mount_\(uniqueId)")

        let script = """
        #!/bin/bash
        PID=\(pid)
        DMG_PATH="\(dmgURL.path)"
        TARGET_APP="\(targetAppPath)"
        MOUNT_DIR="\(mountDir.path)"

        # 1. Chờ ứng dụng hiện tại thoát hẳn
        while kill -0 "$PID" 2>/dev/null; do
            sleep 0.2
        done

        # 2. Tạo mount point và mount DMG âm thầm
        mkdir -p "$MOUNT_DIR"
        hdiutil attach -nobrowse -readonly -mountpoint "$MOUNT_DIR" "$DMG_PATH" >/dev/null 2>&1

        # 3. Thay thế ứng dụng cũ bằng ứng dụng mới
        if [[ -d "$MOUNT_DIR/QTube.app" ]]; then
            rm -rf "$TARGET_APP"
            cp -R "$MOUNT_DIR/QTube.app" "$TARGET_APP"
            xattr -dr com.apple.quarantine "$TARGET_APP" 2>/dev/null || true
        fi

        # 4. Tháo gỡ DMG và dọn dẹp
        hdiutil detach "$MOUNT_DIR" -force >/dev/null 2>&1 || true
        rm -rf "$MOUNT_DIR" "$DMG_PATH"

        sync
        sleep 0.2

        # 5. Mở lại ứng dụng mới
        open "$TARGET_APP"

        # 6. Tự xóa script này
        rm -f "$0"
        """

        do {
            try script.write(to: scriptURL, atomically: true, encoding: .utf8)
            let chmod = Process()
            chmod.executableURL = URL(fileURLWithPath: "/bin/chmod")
            chmod.arguments = ["+x", scriptURL.path]
            try chmod.run()
            chmod.waitUntilExit()

            let updaterProcess = Process()
            updaterProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
            updaterProcess.arguments = ["-c", "nohup /bin/bash \"\(scriptURL.path)\" >/dev/null 2>&1 &"]
            try updaterProcess.run()

            // Thoát ứng dụng dứt khoát bằng exit(0) để không bị AppKit modal sheet chặn
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                exit(0)
            }
        } catch {
            errorMessage = "Lỗi khi chuẩn bị khởi động lại: \(error.localizedDescription)"
        }
    }

    nonisolated static func isVersion(_ newVersion: String, newerThan currentVersion: String) -> Bool {
        let newParts = newVersion.split(separator: ".").compactMap { Int($0) }
        let currentParts = currentVersion.split(separator: ".").compactMap { Int($0) }

        let count = max(newParts.count, currentParts.count)
        for i in 0..<count {
            let n = i < newParts.count ? newParts[i] : 0
            let c = i < currentParts.count ? currentParts[i] : 0
            if n > c { return true }
            if n < c { return false }
        }
        return false
    }

    private func isVersion(_ newVersion: String, newerThan currentVersion: String) -> Bool {
        Self.isVersion(newVersion, newerThan: currentVersion)
    }
}

extension UpdateChecker: URLSessionDownloadDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        Task { @MainActor in
            self.downloadedBytes = totalBytesWritten
            let total = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : self.totalBytes
            if total > 0 {
                self.downloadProgress = min(max(Double(totalBytesWritten) / Double(total), 0), 1)
            }
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let uniqueName = "QTube-update-\(UUID().uuidString).dmg"
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(uniqueName)

        try? FileManager.default.removeItem(at: destination)
        do {
            try FileManager.default.moveItem(at: location, to: destination)
            Task { @MainActor in
                self.downloadedDMGURL = destination
                self.isDownloading = false
                self.isReadyToRelaunch = true
                self.downloadProgress = 1.0
                self.statusMessage = "Tải xuống hoàn tất! Bản cập nhật đã sẵn sàng."
            }
        } catch {
            Task { @MainActor in
                self.isDownloading = false
                self.errorMessage = "Không thể lưu file cập nhật: \(error.localizedDescription)"
            }
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error = error as? URLError, error.code == .cancelled {
            return
        }
        if let error {
            Task { @MainActor in
                self.isDownloading = false
                self.errorMessage = "Lỗi khi tải cập nhật: \(error.localizedDescription)"
            }
        }
    }
}
