import Foundation

enum DownloadStatus: Equatable {
    case waiting
    case preparing
    case downloading
    case processing
    case completed
    case failed(String)
    case cancelled

    var label: String {
        switch self {
        case .waiting: return "Đang chờ lượt tải…"
        case .preparing: return "Đang kết nối & chuẩn bị luồng tải…"
        case .downloading: return "Đang tải dữ liệu"
        case .processing: return "Đang ghép video và âm thanh…"
        case .completed: return "Hoàn tất"
        case .failed: return "Lỗi"
        case .cancelled: return "Đã dừng"
        }
    }

    var isActive: Bool {
        self == .preparing || self == .downloading || self == .processing
    }
}

struct DownloadItem: Identifiable, Equatable {
    let id: UUID
    let url: URL
    var title: String
    var authorName: String?
    var thumbnailURL: URL?
    var durationText: String?
    var mode: DownloadMode
    var quality: VideoQuality
    var audioFormat: AudioFormat
    var hasSubtitles: Bool
    var formatBadge: String?
    var destinationDirectory: URL?
    var customFilename: String?
    var titleLocked: Bool
    var progress: Double
    var downloadedBytes: Int64
    var totalBytes: Int64?
    var speedBytesPerSecond: Double?
    var etaSeconds: Int?
    var status: DownloadStatus
    var outputPath: String?
    var finalFileSize: Int64?
    var startedAt: Date?
    var finishedAt: Date?
    var requiresBrowserCookies: Bool

    var formattedSpeed: String? {
        guard let speed = speedBytesPerSecond, speed > 0 else { return nil }
        return "\(ByteCountFormatter.string(fromByteCount: Int64(speed), countStyle: .file))/s"
    }

    var formattedETA: String? {
        guard let eta = etaSeconds, eta > 0 else { return nil }
        if eta >= 3600 {
            return "\(eta / 3600)h\((eta % 3600) / 60)m"
        } else if eta >= 60 {
            return "\(eta / 60)m\(eta % 60)s"
        } else {
            return "\(eta)s"
        }
    }

    init(
        url: URL,
        mode: DownloadMode = .video,
        quality: VideoQuality = .best,
        audioFormat: AudioFormat = .mp3,
        hasSubtitles: Bool = false
    ) {
        id = UUID()
        self.url = url
        title = url.host ?? url.absoluteString
        authorName = nil
        thumbnailURL = nil
        durationText = nil
        self.mode = mode
        self.quality = quality
        self.audioFormat = audioFormat
        self.hasSubtitles = hasSubtitles
        self.formatBadge = (mode == .audio) ? audioFormat.badgeText : quality.badgeText
        self.destinationDirectory = nil
        self.customFilename = nil
        self.titleLocked = false
        progress = 0
        downloadedBytes = 0
        totalBytes = nil
        speedBytesPerSecond = nil
        etaSeconds = nil
        status = .waiting
        outputPath = nil
        finalFileSize = nil
        startedAt = nil
        finishedAt = nil
        requiresBrowserCookies = false
    }
}

enum DownloadMode: String, CaseIterable, Identifiable {
    case video = "Video (MP4)"
    case audio = "Chỉ âm thanh"

    var id: String { rawValue }
}

enum VideoQuality: String, CaseIterable, Identifiable {
    case best = "Tốt nhất (Gốc)"
    case p2160 = "4K Ultra HD (2160p)"
    case p1440 = "2K Quad HD (1440p)"
    case p1080 = "Full HD (1080p)"
    case p720 = "HD (720p)"
    case p480 = "Tiết kiệm (480p)"

    var id: String { rawValue }

    var badgeText: String {
        switch self {
        case .best: return "GỐC"
        case .p2160: return "4K"
        case .p1440: return "2K"
        case .p1080: return "1080p"
        case .p720: return "720p"
        case .p480: return "480p"
        }
    }

    var maximumHeight: Int? {
        switch self {
        case .best: return nil
        case .p2160: return 2160
        case .p1440: return 1440
        case .p1080: return 1080
        case .p720: return 720
        case .p480: return 480
        }
    }
}

enum AudioFormat: String, CaseIterable, Identifiable {
    case mp3 = "MP3 (320 kbps)"
    case m4a = "M4A (Apple AAC)"

    var id: String { rawValue }

    var badgeText: String {
        switch self {
        case .mp3: return "MP3"
        case .m4a: return "M4A"
        }
    }

    var fileExtension: String {
        switch self {
        case .mp3: return "mp3"
        case .m4a: return "m4a"
        }
    }
}
