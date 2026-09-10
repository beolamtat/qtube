import Foundation

struct DownloadRequest {
    let url: URL
    let outputDirectory: URL
    let mode: DownloadMode
    let quality: VideoQuality
    let audioFormat: AudioFormat
    let downloadSubtitles: Bool
    let customFilename: String?
    let browserCookieSource: BrowserCookieSource

    init(
        url: URL,
        outputDirectory: URL,
        mode: DownloadMode,
        quality: VideoQuality,
        audioFormat: AudioFormat = .mp3,
        downloadSubtitles: Bool = false,
        customFilename: String? = nil,
        browserCookieSource: BrowserCookieSource
    ) {
        self.url = url
        self.outputDirectory = outputDirectory
        self.mode = mode
        self.quality = quality
        self.audioFormat = audioFormat
        self.downloadSubtitles = downloadSubtitles
        self.customFilename = customFilename
        self.browserCookieSource = browserCookieSource
    }
}

enum DownloadEvent {
    case title(String)
    case expectedTotalBytes(Int64)
    case progress(DownloadProgressSnapshot)
    case processing
    case outputFile(String)
}

enum DownloadServiceError: LocalizedError {
    case missingTool(String)
    case launchFailed(String)
    case commandFailed(String)
    case youtubeVerificationRequired
    case browserCookiesUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .missingTool(let name): return "Không tìm thấy \(name) trong ứng dụng."
        case .launchFailed(let message): return "Không thể bắt đầu tải: \(message)"
        case .commandFailed(let message): return message
        case .youtubeVerificationRequired:
            return "YouTube yêu cầu xác minh. Hãy chọn trình duyệt đã đăng nhập rồi thử lại."
        case .browserCookiesUnavailable(let browser):
            return "Không thể đọc cookie từ \(browser). Hãy mở trình duyệt, đăng nhập YouTube hoặc chọn trình duyệt khác."
        }
    }

    var requiresBrowserCookies: Bool {
        switch self {
        case .youtubeVerificationRequired, .browserCookiesUnavailable:
            return true
        default:
            return false
        }
    }
}

final class YTDLPService {
    private let stateLock = NSLock()
    private var process: Process?
    private var isCancelled = false
    private let progressAccumulator = ProgressAccumulator()

    func start(
        request: DownloadRequest,
        onEvent: @escaping (DownloadEvent) -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        stateLock.lock()
        isCancelled = false
        stateLock.unlock()

        guard let ytDLP = ToolLocator.ytDLP() else {
            completion(.failure(DownloadServiceError.missingTool("yt-dlp")))
            return
        }
        guard let ffmpeg = ToolLocator.ffmpeg() else {
            completion(.failure(DownloadServiceError.missingTool("ffmpeg")))
            return
        }

        execute(
            request: request,
            attempt: 1,
            ytDLP: ytDLP,
            ffmpeg: ffmpeg,
            onEvent: onEvent,
            completion: completion
        )
    }

    private func checkCancelled() -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return isCancelled
    }

    private func execute(
        request: DownloadRequest,
        attempt: Int,
        ytDLP: URL,
        ffmpeg: URL,
        onEvent: @escaping (DownloadEvent) -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        if checkCancelled() {
            completion(.failure(CancellationError()))
            return
        }

        let clientStrategy: String
        switch attempt {
        case 1:
            clientStrategy = "ios,mweb,web"
        case 2:
            clientStrategy = "mweb,tv_embedded,ios"
        default:
            clientStrategy = "tv_embedded,mweb,web"
        }

        let task = Process()
        let outputPipe = Pipe()
        task.executableURL = ytDLP
        task.arguments = arguments(
            for: request,
            ffmpeg: ffmpeg,
            deno: ToolLocator.deno(),
            quickjs: ToolLocator.quickjs(),
            playerClients: clientStrategy
        )
        task.standardOutput = outputPipe
        task.standardError = outputPipe
        var environment = ProcessInfo.processInfo.environment
        environment["LC_ALL"] = "C"
        environment["LANG"] = "C"
        task.environment = environment

        stateLock.lock()
        if isCancelled {
            stateLock.unlock()
            completion(.failure(CancellationError()))
            return
        }
        process = task
        stateLock.unlock()

        do {
            try task.run()
        } catch {
            stateLock.lock()
            process = nil
            stateLock.unlock()
            completion(.failure(DownloadServiceError.launchFailed(error.localizedDescription)))
            return
        }

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            var pending = ""
            var diagnosticLines: [String] = []
            let handle = outputPipe.fileHandleForReading

            while true {
                let data = handle.readData(ofLength: 4096)
                if data.isEmpty { break }
                pending += String(decoding: data, as: UTF8.self)

                if let lastNewline = pending.lastIndex(of: "\n") {
                    let completeChunk = pending[..<lastNewline]
                    pending = String(pending[pending.index(after: lastNewline)...])

                    completeChunk.enumerateLines { line, _ in
                        self.parse(line: line, onEvent: onEvent)
                        if !line.isEmpty {
                            diagnosticLines.append(line)
                            if diagnosticLines.count > 12 {
                                diagnosticLines.removeFirst(diagnosticLines.count - 12)
                            }
                        }
                    }
                }
            }

            if !pending.isEmpty {
                self.parse(line: pending, onEvent: onEvent)
                diagnosticLines.append(pending)
            }

            task.waitUntilExit()
            self.stateLock.lock()
            self.process = nil
            let cancelled = self.isCancelled
            self.stateLock.unlock()

            if cancelled || task.terminationReason == .uncaughtSignal || task.terminationStatus == 15 {
                completion(.failure(CancellationError()))
                return
            }

            if task.terminationStatus == 0 {
                completion(.success(()))
                return
            }

            let diagnostics = diagnosticLines.joined(separator: "\n")
            let normalizedDiagnostics = diagnostics.lowercased()

            let isBotOrVerificationError = normalizedDiagnostics.contains("sign in to confirm you're not a bot")
                || normalizedDiagnostics.contains("sign in to confirm you’re not a bot")
                || normalizedDiagnostics.contains("unable to extract video data")
                || normalizedDiagnostics.contains("http error 429")
                || normalizedDiagnostics.contains("http error 403")

            // Auto retry with alternative client if attempt < 2
            if attempt < 2 && isBotOrVerificationError && !self.checkCancelled() {
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1.5) { [weak self] in
                    guard let self, !self.checkCancelled() else {
                        completion(.failure(CancellationError()))
                        return
                    }
                    self.execute(
                        request: request,
                        attempt: attempt + 1,
                        ytDLP: ytDLP,
                        ffmpeg: ffmpeg,
                        onEvent: onEvent,
                        completion: completion
                    )
                }
                return
            }

            if normalizedDiagnostics.contains("sign in to confirm you're not a bot")
                || normalizedDiagnostics.contains("sign in to confirm you’re not a bot") {
                completion(.failure(DownloadServiceError.youtubeVerificationRequired))
                return
            }
            if normalizedDiagnostics.contains("cookie"),
               normalizedDiagnostics.contains("permission denied")
                || normalizedDiagnostics.contains("could not find")
                || normalizedDiagnostics.contains("failed to decrypt") {
                completion(.failure(
                    DownloadServiceError.browserCookiesUnavailable(request.browserCookieSource.displayName)
                ))
                return
            }
            let useful = diagnosticLines
                .reversed()
                .first(where: { $0.localizedCaseInsensitiveContains("error") })
                ?? diagnosticLines.suffix(3).joined(separator: " ")
            let message = useful.isEmpty
                ? "Tải thất bại (mã lỗi \(task.terminationStatus))."
                : useful
            completion(.failure(DownloadServiceError.commandFailed(message)))
        }
    }

    func cancel() {
        stateLock.lock()
        isCancelled = true
        let runningProcess = process
        stateLock.unlock()
        guard let runningProcess, runningProcess.isRunning else { return }
        runningProcess.terminate()
    }

    func arguments(
        for request: DownloadRequest,
        ffmpeg: URL,
        deno: URL? = nil,
        quickjs: URL? = nil,
        playerClients: String = "ios,mweb,web"
    ) -> [String] {
        var result = [
            "--ignore-config",
            "--no-plugin-dirs",
            "--newline",
            "--no-color",
            "--continue",
            "--no-overwrites",
            "--progress",
            "--progress-delta",
            "0.5",
            "--progress-template",
            "download:[BT_PROGRESS]%(progress)j",
            "--print",
            "before_dl:[BT_TITLE]%(title)s",
            "--print",
            "before_dl:[BT_META]%(requested_formats)j",
            "--print",
            "after_move:[BT_FILE]%(filepath)s",
            "--ffmpeg-location",
            ffmpeg.deletingLastPathComponent().path,
            "--paths",
            request.outputDirectory.path,
            "--output",
            {
                if let custom = request.customFilename, !custom.isEmpty {
                    let sanitized = custom
                        .replacingOccurrences(of: "/", with: "-")
                        .replacingOccurrences(of: ":", with: "-")
                        .replacingOccurrences(of: "\"", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    return "\(sanitized) [%(id)s].%(ext)s"
                } else {
                    return "%(title).180B [%(id)s].%(ext)s"
                }
            }(),
            "--extractor-args",
            "youtube:player_client=\(playerClients)",
            "--socket-timeout",
            "30",
            "--retries",
            "10",
            "--fragment-retries",
            "10",
            "--retry-sleep",
            "fragment:exp=1:20",
            "--sleep-requests",
            "1.0"
        ]

        if let quickjs {
            result += ["--js-runtimes", "quickjs:\(quickjs.path)"]
        } else if let deno {
            result += ["--js-runtimes", "deno:\(deno.path)"]
        }

        if let browser = request.browserCookieSource.ytDLPIdentifier {
            result += ["--cookies-from-browser", browser]
        } else {
            result += [
                "--user-agent",
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15"
            ]
        }

        switch request.mode {
        case .audio:
            let ext = request.audioFormat.fileExtension
            result += [
                "--extract-audio",
                "--audio-format", ext,
                "--audio-quality", "0",
                "--embed-thumbnail",
                "--add-metadata"
            ]
        case .video:
            if let height = request.quality.maximumHeight {
                result += [
                    "--format",
                    "bv*[height<=\(height)]+ba/b[height<=\(height)]",
                    "--merge-output-format",
                    "mp4"
                ]
            } else {
                result += ["--format", "bv*+ba/b", "--merge-output-format", "mp4"]
            }

            if request.downloadSubtitles {
                result += [
                    "--write-sub",
                    "--write-auto-sub",
                    "--sub-lang", "vi,en",
                    "--convert-subs", "srt"
                ]
            }
        }

        result.append(request.url.absoluteString)
        return result
    }

    private func parse(line rawLine: String, onEvent: (DownloadEvent) -> Void) {
        let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if line.hasPrefix("[BT_TITLE]") {
            onEvent(.title(String(line.dropFirst("[BT_TITLE]".count))))
            return
        }
        if line.hasPrefix("[BT_FILE]") {
            onEvent(.outputFile(String(line.dropFirst("[BT_FILE]".count))))
            return
        }
        if line.hasPrefix("[BT_META]") {
            let json = String(line.dropFirst("[BT_META]".count))
            if let total = progressAccumulator.consumeMetadataJSON(json) {
                onEvent(.expectedTotalBytes(total))
            }
            return
        }
        if line.hasPrefix("[BT_PROGRESS]") {
            let json = String(line.dropFirst("[BT_PROGRESS]".count))
            if let snapshot = progressAccumulator.consumeProgressJSON(json) {
                onEvent(.progress(snapshot))
            }
            return
        }
        if line.contains("[Merger]") || line.contains("[ExtractAudio]") || line.contains("[VideoConvertor]") {
            onEvent(.processing)
        }
    }
}
