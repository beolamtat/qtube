import Foundation

struct PlaylistProgressUpdate: Sendable {
    let playlistTitle: String?
    let playlistUploader: String?
    let currentIndex: Int
    let totalCount: Int?
    let currentVideoTitle: String?
    let entries: [PlaylistEntry]

    init(
        playlistTitle: String? = nil,
        playlistUploader: String? = nil,
        currentIndex: Int,
        totalCount: Int? = nil,
        currentVideoTitle: String? = nil,
        entries: [PlaylistEntry] = []
    ) {
        self.playlistTitle = playlistTitle
        self.playlistUploader = playlistUploader
        self.currentIndex = currentIndex
        self.totalCount = totalCount
        self.currentVideoTitle = currentVideoTitle
        self.entries = entries
    }

    var entry: PlaylistEntry? {
        entries.last
    }

    var fraction: Double {
        guard let total = totalCount, total > 0 else { return 0 }
        return min(max(Double(currentIndex) / Double(total), 0), 1.0)
    }
}

enum PlaylistError: LocalizedError {
    case missingTool
    case invalidURL
    case executionFailed(String)
    case parseFailed
    case emptyPlaylist

    var errorDescription: String? {
        switch self {
        case .missingTool:
            return "Không tìm thấy công cụ phân tích trong ứng dụng."
        case .invalidURL:
            return "Đường dẫn danh sách phát không hợp lệ."
        case .executionFailed(let message):
            return "Không thể tải danh sách phát: \(message)"
        case .parseFailed:
            return "Không thể phân tích dữ liệu danh sách phát từ YouTube."
        case .emptyPlaylist:
            return "Danh sách phát này không có video nào hoặc đã bị ẩn."
        }
    }
}

actor PlaylistService {
    private var process: Process?
    private var isCancelled = false

    func cancel() {
        isCancelled = true
        process?.terminate()
        process = nil
    }

    func fetchPlaylistInfo(
        for url: URL,
        onProgress: (@Sendable (PlaylistProgressUpdate) -> Void)? = nil
    ) async throws -> PlaylistInfo {
        isCancelled = false

        guard let ytDLP = ToolLocator.ytDLP() else {
            throw PlaylistError.missingTool
        }

        var args = [
            "--ignore-config",
            "--no-plugin-dirs",
            "--flat-playlist",
            "-j",
            "--newline",
            "--no-warnings",
            "--extractor-args", "youtube:player_client=ios,mweb,web",
            "--socket-timeout", "25",
            "--retries", "3"
        ]

        if let quickjs = ToolLocator.quickjs() {
            args += ["--js-runtimes", "quickjs:\(quickjs.path)"]
        } else if let deno = ToolLocator.deno() {
            args += ["--js-runtimes", "deno:\(deno.path)"]
        }

        args.append(url.absoluteString)

        let task = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        task.executableURL = ytDLP
        task.arguments = args
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        var environment = ProcessInfo.processInfo.environment
        environment["LC_ALL"] = "C"
        environment["LANG"] = "C"
        task.environment = environment

        if isCancelled {
            throw CancellationError()
        }
        process = task

        do {
            try task.run()
        } catch {
            process = nil
            throw PlaylistError.executionFailed(error.localizedDescription)
        }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var pending = ""
                var entries: [PlaylistEntry] = []
                var playlistTitle: String? = nil
                var playlistUploader: String? = nil
                var playlistID = UUID().uuidString
                var totalCount: Int? = nil

                let handle = outputPipe.fileHandleForReading
                var lastProgressTime = Date.distantPast
                var bufferedEntries: [PlaylistEntry] = []
                var lastIndex = 0
                var lastItemTitle: String? = nil

                let flushProgress = { (force: Bool) in
                    guard !bufferedEntries.isEmpty || force else { return }
                    let now = Date()
                    let elapsed = now.timeIntervalSince(lastProgressTime)
                    // Emit immediately on first item, or every 200ms, or when forced
                    if force || lastProgressTime == Date.distantPast || elapsed >= 0.20 {
                        let batch = bufferedEntries
                        bufferedEntries.removeAll(keepingCapacity: true)
                        lastProgressTime = now
                        onProgress?(PlaylistProgressUpdate(
                            playlistTitle: playlistTitle,
                            playlistUploader: playlistUploader,
                            currentIndex: lastIndex,
                            totalCount: totalCount,
                            currentVideoTitle: lastItemTitle,
                            entries: batch
                        ))
                    }
                }

                while true {
                    let data = handle.readData(ofLength: 4096)
                    if data.isEmpty { break }
                    pending += String(decoding: data, as: UTF8.self)

                    while let newlineIndex = pending.firstIndex(of: "\n") {
                        let rawLine = String(pending[..<newlineIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                        pending = String(pending[pending.index(after: newlineIndex)...])

                        guard !rawLine.isEmpty,
                              let lineData = rawLine.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any]
                        else { continue }

                        if playlistTitle == nil {
                            playlistTitle = json["playlist_title"] as? String ?? json["playlist"] as? String
                        }
                        if playlistUploader == nil {
                            playlistUploader = json["playlist_uploader"] as? String ?? json["playlist_channel"] as? String
                        }
                        if let pid = json["playlist_id"] as? String, !pid.isEmpty {
                            playlistID = pid
                        }
                        if totalCount == nil {
                            totalCount = json["playlist_count"] as? Int ?? json["n_entries"] as? Int
                        }

                        let index = json["playlist_index"] as? Int ?? (entries.count + 1)
                        let itemID = json["id"] as? String ?? UUID().uuidString
                        let itemTitle = json["title"] as? String ?? "Video #\(index)"
                        let itemURL = URL(string: "https://www.youtube.com/watch?v=\(itemID)") ?? url
                        let duration = json["duration"] as? Double
                        let durationText = duration.map { Self.formatDuration($0) }
                        let thumbURL = URL(string: "https://i.ytimg.com/vi/\(itemID)/mqdefault.jpg")
                        let author = json["uploader"] as? String ?? json["channel"] as? String ?? playlistUploader

                        let newEntry = PlaylistEntry(
                            id: itemID,
                            title: itemTitle,
                            url: itemURL,
                            durationSeconds: duration,
                            durationText: durationText,
                            thumbnailURL: thumbURL,
                            author: author,
                            isSelected: true
                        )
                        entries.append(newEntry)
                        bufferedEntries.append(newEntry)
                        lastIndex = index
                        lastItemTitle = itemTitle

                        flushProgress(false)
                    }
                }

                flushProgress(true)

                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                task.waitUntilExit()

                Task {
                    await self.finishProcess()
                }

                if task.terminationReason == .uncaughtSignal || task.terminationStatus == 15 {
                    continuation.resume(throwing: CancellationError())
                    return
                }

                guard task.terminationStatus == 0, !entries.isEmpty else {
                    if entries.isEmpty && task.terminationStatus == 0 {
                        continuation.resume(throwing: PlaylistError.emptyPlaylist)
                        return
                    }
                    let errStr = String(decoding: errorData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                    let msg = errStr.isEmpty ? "Mã lỗi: \(task.terminationStatus)" : errStr
                    continuation.resume(throwing: PlaylistError.executionFailed(msg))
                    return
                }

                let resolvedTitle = playlistTitle ?? entries.first?.title ?? "Danh sách phát"
                let info = PlaylistInfo(
                    id: playlistID,
                    title: resolvedTitle,
                    uploader: playlistUploader,
                    webpageURL: url,
                    entries: entries
                )
                continuation.resume(returning: info)
            }
        }
    }

    private func finishProcess() {
        process = nil
    }

    nonisolated static func formatDuration(_ seconds: Double) -> String {
        let total = max(Int(seconds.rounded()), 0)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }
}
