import AppKit
import Foundation

@MainActor
final class DownloadQueueViewModel: ObservableObject {
    @Published var linkInputText = ""
    @Published var linkDrafts: [LinkDraft] = [] {
        didSet {
            updateDuplicateDrafts()
        }
    }
    @Published var items: [DownloadItem] = [] {
        didSet {
            updateSleepPrevention()
        }
    }
    private var sleepActivityToken: NSObjectProtocol?
    @Published var selectedMode: DownloadMode = .video
    @Published var selectedQuality: VideoQuality = .best
    @Published var selectedAudioFormat: AudioFormat = .mp3
    @Published var downloadSubtitles: Bool = false
    @Published var outputDirectory: URL
    @Published var maxConcurrentDownloads = 2
    @Published var generalError: String?
    @Published var activePlaylist: PlaylistInfo?
    @Published var isInspectingPlaylist: Bool = false
    @Published var inspectingPlaylistTitle: String?
    @Published var inspectingPlaylistUploader: String?
    @Published var inspectingCurrentIndex: Int = 0
    @Published var inspectingTotalCount: Int?
    @Published var inspectingCurrentVideoTitle: String?
    @Published var playlistPromptURL: URL?

    var isPromptingMix: Bool {
        guard let url = playlistPromptURL else { return false }
        return LinkExtractor.isYouTubeMixURL(url)
    }

    var inspectingProgressFraction: Double {
        guard let total = inspectingTotalCount, total > 0 else { return 0 }
        return min(max(Double(inspectingCurrentIndex) / Double(total), 0), 1.0)
    }
    @Published var browserCookieSource: BrowserCookieSource {
        didSet {
            UserDefaults.standard.set(browserCookieSource.rawValue, forKey: browserCookieSourceKey)
        }
    }

    private var duplicateDraftIDs: Set<UUID> = []
    private var services: [UUID: YTDLPService] = [:]
    private var playlistService = PlaylistService()
    private let outputDirectoryKey = "BatchTube.outputDirectory"
    private let outputDirectoryVersionKey = "BatchTube.outputDirectoryVersion"
    private let browserCookieSourceKey = "BatchTube.browserCookieSource"
    private var hasConfirmedOutputDirectory: Bool
    private var isSchedulingDownloads = false

    init() {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
        let savedPath = UserDefaults.standard.string(forKey: outputDirectoryKey)
        let savedVersion = UserDefaults.standard.integer(forKey: outputDirectoryVersionKey)
        let needsVersionOneMigration = savedVersion < 2 && savedPath == downloads.path

        browserCookieSource = .auto

        if let savedPath, !needsVersionOneMigration {
            outputDirectory = URL(fileURLWithPath: savedPath, isDirectory: true)
            hasConfirmedOutputDirectory = true
        } else {
            outputDirectory = downloads.appendingPathComponent("QTube", isDirectory: true)
            hasConfirmedOutputDirectory = false
        }

        NotificationManager.shared.requestAuthorization()
        ClipboardMonitor.shared.onURLDetected = { [weak self] url in
            guard let self = self else { return }
            self.addLinkDrafts(from: url.absoluteString)
        }
    }

    var detectedLinkCount: Int {
        validDraftURLs.count
    }

    var activeCount: Int {
        items.filter { $0.status.isActive }.count
    }

    var completedCount: Int {
        items.filter { $0.status == .completed }.count
    }

    var hasPendingOrActiveItems: Bool {
        items.contains { $0.status == .waiting || $0.status.isActive }
    }

    func pasteLinks() {
        guard let clipboard = NSPasteboard.general.string(forType: .string), !clipboard.isEmpty else { return }
        let trimmed = clipboard.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = LinkExtractor.youtubeURL(from: trimmed) {
            if LinkExtractor.isWatchVideoWithPlaylistURL(url) {
                playlistPromptURL = url
                return
            } else if LinkExtractor.isPlaylistURL(url) {
                inspectPlaylist(url: url)
                return
            }
        }
        addLinkDrafts(from: clipboard)
    }

    func addCurrentInput() {
        let trimmed = linkInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let url = LinkExtractor.youtubeURL(from: trimmed) {
            if LinkExtractor.isWatchVideoWithPlaylistURL(url) {
                playlistPromptURL = url
                linkInputText = ""
                return
            } else if LinkExtractor.isPlaylistURL(url) {
                linkInputText = ""
                inspectPlaylist(url: url)
                return
            }
        }
        addLinkDrafts(from: linkInputText)
        linkInputText = ""
    }

    func inspectPlaylist(url: URL) {
        playlistPromptURL = nil
        isInspectingPlaylist = true
        inspectingPlaylistTitle = "Đang phân tích Danh sách phát…"
        inspectingPlaylistUploader = nil
        inspectingCurrentIndex = 0
        inspectingTotalCount = nil
        inspectingCurrentVideoTitle = nil
        generalError = nil

        let playlistID = LinkExtractor.playlistID(from: url) ?? UUID().uuidString
        self.activePlaylist = PlaylistInfo(
            id: playlistID,
            title: "Đang phân tích danh sách…",
            uploader: nil,
            webpageURL: url,
            entries: []
        )

        Task {
            do {
                let info = try await playlistService.fetchPlaylistInfo(for: url) { [weak self] update in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        if let title = update.playlistTitle, !title.isEmpty {
                            self.inspectingPlaylistTitle = title
                            self.activePlaylist?.title = title
                        }
                        if let uploader = update.playlistUploader, !uploader.isEmpty {
                            self.inspectingPlaylistUploader = uploader
                            self.activePlaylist?.uploader = uploader
                        }
                        self.inspectingCurrentIndex = update.currentIndex
                        self.inspectingTotalCount = update.totalCount
                        self.inspectingCurrentVideoTitle = update.currentVideoTitle

                        if !update.entries.isEmpty {
                            var currentIDs = Set(self.activePlaylist?.entries.map(\.id) ?? [])
                            for entry in update.entries {
                                if !currentIDs.contains(entry.id) {
                                    self.activePlaylist?.entries.append(entry)
                                    currentIDs.insert(entry.id)
                                }
                            }
                        }
                    }
                }
                await MainActor.run {
                    self.isInspectingPlaylist = false
                    if var active = self.activePlaylist {
                        let selectedMap = Dictionary(uniqueKeysWithValues: active.entries.map { ($0.id, $0.isSelected) })
                        var updatedEntries = info.entries
                        for i in updatedEntries.indices {
                            if let userSelection = selectedMap[updatedEntries[i].id] {
                                updatedEntries[i].isSelected = userSelection
                            }
                        }
                        active.title = info.title
                        active.uploader = info.uploader
                        active.entries = updatedEntries
                        self.activePlaylist = active
                    } else {
                        self.activePlaylist = info
                    }
                }
            } catch {
                if error is CancellationError {
                    await MainActor.run {
                        self.isInspectingPlaylist = false
                        if self.activePlaylist?.entries.isEmpty == true {
                            self.activePlaylist = nil
                        }
                    }
                    return
                }
                await MainActor.run {
                    self.isInspectingPlaylist = false
                    if self.activePlaylist?.entries.isEmpty == true {
                        self.activePlaylist = nil
                    }
                    self.generalError = error.localizedDescription
                }
            }
        }
    }

    func cancelPlaylistInspection() {
        Task {
            await playlistService.cancel()
        }
        isInspectingPlaylist = false
        if activePlaylist?.entries.isEmpty == true {
            activePlaylist = nil
        }
    }

    func acceptPlaylistPrompt() {
        guard let url = playlistPromptURL else { return }
        playlistPromptURL = nil
        inspectPlaylist(url: url)
    }

    func declinePlaylistPromptToSingleVideo() {
        guard let url = playlistPromptURL else { return }
        playlistPromptURL = nil
        let clean = LinkExtractor.cleanVideoURL(from: url)
        addLinkDrafts(from: clean.absoluteString)
    }

    func cancelPlaylistPrompt() {
        playlistPromptURL = nil
    }

    func importSelectedPlaylist(numberFiles: Bool, targetDirectory: URL) {
        cancelPlaylistInspection()
        guard let playlist = activePlaylist else { return }
        let selectedEntries = playlist.entries.filter(\.isSelected)
        guard !selectedEntries.isEmpty else {
            activePlaylist = nil
            return
        }

        try? FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true)

        let existing = Set(items.map { $0.url.absoluteString })
        var newItems: [DownloadItem] = []

        for (index, entry) in selectedEntries.enumerated() {
            if existing.contains(entry.url.absoluteString) {
                continue
            }
            let prefix = numberFiles ? "\(String(format: "%02d", index + 1)). " : ""
            let cleanTitle = "\(prefix)\(entry.title)"
            var item = DownloadItem(
                url: entry.url,
                mode: selectedMode,
                quality: selectedQuality,
                audioFormat: selectedAudioFormat,
                hasSubtitles: selectedMode == .video && downloadSubtitles
            )
            item.title = cleanTitle
            item.titleLocked = true
            item.customFilename = cleanTitle
            item.destinationDirectory = targetDirectory
            item.thumbnailURL = entry.thumbnailURL
            item.authorName = entry.author
            item.durationText = entry.durationText
            newItems.append(item)
        }

        items.append(contentsOf: newItems)
        activePlaylist = nil
        startNextDownloads()
    }

    func removeLinkDraft(id: UUID) {
        linkDrafts.removeAll { $0.id == id }
    }

    func removeAllLinkDrafts() {
        linkDrafts.removeAll()
        linkInputText = ""
    }

    func url(for draft: LinkDraft) -> URL? {
        LinkExtractor.youtubeURL(from: draft.text)
    }

    func isDuplicate(_ draft: LinkDraft) -> Bool {
        duplicateDraftIDs.contains(draft.id)
    }

    private func updateDuplicateDrafts() {
        var seen = [String: UUID]()
        var duplicates = Set<UUID>()
        for draft in linkDrafts {
            guard let url = LinkExtractor.youtubeURL(from: draft.text) else { continue }
            let key = url.absoluteString
            if let firstID = seen[key] {
                duplicates.insert(firstID)
                duplicates.insert(draft.id)
            } else {
                seen[key] = draft.id
            }
        }
        duplicateDraftIDs = duplicates
    }

    @discardableResult
    func chooseOutputDirectory() -> Bool {
        try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let panel = NSOpenPanel()
        panel.title = "Chọn thư mục lưu video"
        panel.message = "QTube sẽ lưu toàn bộ nội dung tải xuống tại đây."
        panel.prompt = "Chọn thư mục"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = outputDirectory

        guard panel.runModal() == .OK, let selected = panel.url else { return false }
        outputDirectory = selected
        hasConfirmedOutputDirectory = true
        UserDefaults.standard.set(selected.path, forKey: outputDirectoryKey)
        UserDefaults.standard.set(2, forKey: outputDirectoryVersionKey)
        return true
    }

    func openOutputDirectory() {
        try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        NSWorkspace.shared.open(outputDirectory)
    }

    func addLinksAndStart() {
        generalError = nil
        if !linkInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            addCurrentInput()
        }
        let urls = validDraftURLs
        guard !urls.isEmpty else {
            generalError = "Không có link YouTube hợp lệ để tải. Hãy sửa các tag đang báo đỏ."
            return
        }

        if !hasConfirmedOutputDirectory, !chooseOutputDirectory() {
            return
        }

        do {
            try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        } catch {
            generalError = "Không thể tạo thư mục lưu: \(error.localizedDescription)"
            return
        }

        let existing = Set(items.map { $0.url.absoluteString })
        let newURLs = urls.filter { !existing.contains($0.absoluteString) }
        guard !newURLs.isEmpty else {
            generalError = "Các link này đã có trong danh sách."
            return
        }

        let newItems: [DownloadItem] = newURLs.map { url in
            var item = DownloadItem(
                url: url,
                mode: selectedMode,
                quality: selectedQuality,
                audioFormat: selectedAudioFormat,
                hasSubtitles: selectedMode == .video && downloadSubtitles
            )
            if let draft = linkDrafts.first(where: { LinkExtractor.youtubeURL(from: $0.text)?.absoluteString == url.absoluteString }) {
                if let t = draft.title { item.title = t }
                if let thumb = draft.thumbnailURL { item.thumbnailURL = thumb }
            }
            return item
        }
        items.append(contentsOf: newItems)
        for item in newItems {
            fetchMetadata(for: item.id, url: item.url)
        }
        let queuedURLStrings = Set(urls.map(\.absoluteString))
        linkDrafts.removeAll { draft in
            guard let url = LinkExtractor.youtubeURL(from: draft.text) else { return false }
            return queuedURLStrings.contains(url.absoluteString)
        }
        startNextDownloads()
    }

    private func fetchMetadata(for itemID: UUID, url: URL) {
        Task {
            if let meta = await VideoMetadataService.shared.fetchMetadata(for: url) {
                if let index = self.items.firstIndex(where: { $0.id == itemID }) {
                    if self.items[index].title == self.items[index].url.host || self.items[index].title == self.items[index].url.absoluteString {
                        self.items[index].title = meta.title
                    }
                    self.items[index].authorName = meta.authorName
                    self.items[index].thumbnailURL = meta.thumbnailURL
                }
            }
        }
    }

    func cancel(itemID: UUID) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        if items[index].status == .waiting {
            items[index].status = .cancelled
            startNextDownloads()
        } else {
            services[itemID]?.cancel()
        }
    }

    func removeItem(itemID: UUID) {
        cancel(itemID: itemID)
        items.removeAll { $0.id == itemID }
    }

    func retry(itemID: UUID) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        resetForRetry(at: index)
        startNextDownloads()
    }

    func retryVerificationFailures(using source: BrowserCookieSource) {
        browserCookieSource = source
        var foundItem = false
        for index in items.indices where items[index].requiresBrowserCookies {
            resetForRetry(at: index)
            foundItem = true
        }
        guard foundItem else { return }
        startNextDownloads()
    }

    private func resetForRetry(at index: Int) {
        items[index].progress = 0
        items[index].downloadedBytes = 0
        items[index].totalBytes = nil
        items[index].speedBytesPerSecond = nil
        items[index].etaSeconds = nil
        items[index].finalFileSize = nil
        items[index].startedAt = nil
        items[index].finishedAt = nil
        items[index].requiresBrowserCookies = false
        items[index].status = .waiting
    }

    var hasResumableItems: Bool {
        items.contains { item in
            item.status == .cancelled || {
                if case .failed = item.status { return true }
                return false
            }()
        }
    }

    func stopAllDownloads() {
        for (_, service) in services {
            service.cancel()
        }
        services.removeAll()
        for index in items.indices {
            if items[index].status == .waiting || items[index].status.isActive {
                items[index].status = .cancelled
            }
        }
        isSchedulingDownloads = false
    }

    func resumeAllDownloads() {
        for index in items.indices {
            let isPaused = items[index].status == .cancelled || {
                if case .failed = items[index].status { return true }
                return false
            }()
            if isPaused {
                resetForRetry(at: index)
            }
        }
        startNextDownloads()
    }

    func clearAllQueue() {
        stopAllDownloads()
        items.removeAll()
    }

    func removeFinished() {
        items.removeAll { item in
            item.status == .completed || item.status == .cancelled || {
                if case .failed = item.status { return true }
                return false
            }()
        }
    }

    func reveal(itemID: UUID) {
        guard let item = items.first(where: { $0.id == itemID }) else { return }
        if let outputPath = item.outputPath {
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: outputPath)])
        } else {
            openOutputDirectory()
        }
    }

    private func startNextDownloads() {
        guard !isSchedulingDownloads else { return }
        isSchedulingDownloads = true
        startNextDownloadWithSpacing()
    }

    private func startNextDownloadWithSpacing() {
        guard services.count < maxConcurrentDownloads,
              let nextIndex = items.firstIndex(where: { $0.status == .waiting })
        else {
            isSchedulingDownloads = false
            return
        }

        start(itemAt: nextIndex)
        guard services.count < maxConcurrentDownloads,
              items.contains(where: { $0.status == .waiting })
        else {
            isSchedulingDownloads = false
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.startNextDownloadWithSpacing()
        }
    }

    private var validDraftURLs: [URL] {
        var seen = Set<String>()
        return linkDrafts.compactMap { draft in
            guard let url = LinkExtractor.youtubeURL(from: draft.text),
                  seen.insert(url.absoluteString).inserted
            else { return nil }
            return url
        }
    }

    private func addLinkDrafts(from text: String) {
        let extractedURLs = LinkExtractor.youtubeURLs(from: text)
        let candidates: [String]

        if extractedURLs.isEmpty {
            candidates = text
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        } else {
            candidates = extractedURLs.map(\.absoluteString)
        }

        let existing = Set(linkDrafts.compactMap { LinkExtractor.youtubeURL(from: $0.text)?.absoluteString })
        var added = Set<String>()
        var newDrafts: [LinkDraft] = []
        for candidate in candidates {
            if let url = LinkExtractor.youtubeURL(from: candidate) {
                guard !existing.contains(url.absoluteString), added.insert(url.absoluteString).inserted else { continue }
            }
            let draft = LinkDraft(text: candidate)
            linkDrafts.append(draft)
            newDrafts.append(draft)
        }

        for draft in newDrafts {
            if let url = LinkExtractor.youtubeURL(from: draft.text) {
                Task {
                    if let meta = await VideoMetadataService.shared.fetchMetadata(for: url) {
                        if let idx = self.linkDrafts.firstIndex(where: { $0.id == draft.id }) {
                            self.linkDrafts[idx].title = meta.title
                            self.linkDrafts[idx].thumbnailURL = meta.thumbnailURL
                        }
                    }
                }
            }
        }
    }

    private func start(itemAt index: Int) {
        let item = items[index]
        let id = item.id
        let targetDirectory = item.destinationDirectory ?? outputDirectory
        try? FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true)

        let request = DownloadRequest(
            url: item.url,
            outputDirectory: targetDirectory,
            mode: item.mode,
            quality: item.quality,
            audioFormat: item.audioFormat,
            downloadSubtitles: item.hasSubtitles,
            customFilename: item.customFilename,
            browserCookieSource: browserCookieSource
        )
        let service = YTDLPService()
        services[id] = service
        items[index].status = .preparing
        items[index].startedAt = Date()

        service.start(
            request: request,
            onEvent: { [weak self] event in
                DispatchQueue.main.async {
                    self?.handle(event: event, for: id)
                }
            },
            completion: { [weak self] result in
                DispatchQueue.main.async {
                    self?.finish(itemID: id, result: result)
                }
            }
        )
    }

    private func handle(event: DownloadEvent, for id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        switch event {
        case .title(let title):
            if !items[index].titleLocked {
                items[index].title = title
            }
        case .expectedTotalBytes(let total):
            items[index].totalBytes = total
        case .progress(let snapshot):
            items[index].status = .downloading
            items[index].progress = snapshot.fraction
            items[index].downloadedBytes = snapshot.downloadedBytes
            items[index].totalBytes = snapshot.totalBytes
            items[index].speedBytesPerSecond = snapshot.speedBytesPerSecond
            items[index].etaSeconds = snapshot.etaSeconds
        case .processing:
            items[index].status = .processing
        case .outputFile(let path):
            items[index].outputPath = path
        }
    }

    private func finish(itemID: UUID, result: Result<Void, Error>) {
        services[itemID] = nil
        guard let index = items.firstIndex(where: { $0.id == itemID }) else {
            startNextDownloads()
            return
        }

        switch result {
        case .success:
            items[index].progress = 1
            items[index].status = .completed
            NotificationManager.shared.sendDownloadCompletedNotification(
                title: items[index].title,
                filePath: items[index].outputPath
            )
        case .failure(let error) where error is CancellationError:
            items[index].status = .cancelled
        case .failure(let error):
            if let serviceError = error as? DownloadServiceError {
                items[index].requiresBrowserCookies = serviceError.requiresBrowserCookies
            }
            items[index].status = .failed(error.localizedDescription)
            NotificationManager.shared.sendDownloadFailedNotification(
                title: items[index].title,
                errorMessage: error.localizedDescription
            )
        }
        items[index].finishedAt = Date()
        items[index].speedBytesPerSecond = nil
        items[index].etaSeconds = nil
        if let path = items[index].outputPath,
           let attributes = try? FileManager.default.attributesOfItem(atPath: path),
           let size = attributes[.size] as? NSNumber {
            items[index].finalFileSize = size.int64Value
        }
        startNextDownloads()
    }

    func openDownloadsFolder() {
        NSWorkspace.shared.open(outputDirectory)
    }

    func quickDownload(urlString: String) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        hasConfirmedOutputDirectory = true
        addLinkDrafts(from: trimmed)
        addLinksAndStart()
    }

    func pauseAll() {
        for index in items.indices where items[index].status.isActive || items[index].status == .waiting {
            cancel(itemID: items[index].id)
        }
    }

    func resumeAll() {
        for index in items.indices where items[index].status == .cancelled || {
            if case .failed = items[index].status { return true }
            return false
        }() {
            resetForRetry(at: index)
        }
        startNextDownloads()
    }

    private func updateSleepPrevention() {
        if activeCount > 0 {
            if sleepActivityToken == nil {
                sleepActivityToken = ProcessInfo.processInfo.beginActivity(
                    options: [.idleSystemSleepDisabled, .suddenTerminationDisabled],
                    reason: "QTube đang tải video/âm thanh"
                )
            }
        } else {
            if let token = sleepActivityToken {
                ProcessInfo.processInfo.endActivity(token)
                sleepActivityToken = nil
            }
        }
    }

    deinit {
        if let token = sleepActivityToken {
            ProcessInfo.processInfo.endActivity(token)
        }
    }

    nonisolated static func sanitizeFilename(_ name: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "\\/:*?\"<>|")
        let cleaned = name.components(separatedBy: invalidCharacters).joined(separator: " ")
        let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Playlist" : trimmed
    }
}
