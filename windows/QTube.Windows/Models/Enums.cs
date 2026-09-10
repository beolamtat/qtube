using System;

namespace QTube.Windows.Models
{
    public enum DownloadStatus
    {
        Waiting,
        Preparing,
        Downloading,
        Processing,
        Completed,
        Failed,
        Cancelled
    }

    public static class DownloadStatusExtensions
    {
        public static string GetLabel(this DownloadStatus status) => status switch
        {
            DownloadStatus.Waiting => "Đang chờ lượt tải…",
            DownloadStatus.Preparing => "Đang kết nối & chuẩn bị luồng tải…",
            DownloadStatus.Downloading => "Đang tải dữ liệu",
            DownloadStatus.Processing => "Đang ghép video và âm thanh…",
            DownloadStatus.Completed => "Hoàn tất",
            DownloadStatus.Failed => "Lỗi",
            DownloadStatus.Cancelled => "Đã dừng",
            _ => "Không xác định"
        };

        public static bool IsActive(this DownloadStatus status) =>
            status is DownloadStatus.Preparing or DownloadStatus.Downloading or DownloadStatus.Processing;
    }

    public enum DownloadMode
    {
        Video,
        Audio
    }

    public enum VideoQuality
    {
        Best,
        P2160,
        P1440,
        P1080,
        P720,
        P480
    }

    public static class VideoQualityExtensions
    {
        public static string GetDisplayName(this VideoQuality quality) => quality switch
        {
            VideoQuality.Best => "Tốt nhất (Gốc)",
            VideoQuality.P2160 => "4K Ultra HD (2160p)",
            VideoQuality.P1440 => "2K Quad HD (1440p)",
            VideoQuality.P1080 => "Full HD (1080p)",
            VideoQuality.P720 => "HD (720p)",
            VideoQuality.P480 => "Tiết kiệm (480p)",
            _ => "Tốt nhất"
        };

        public static string GetBadgeText(this VideoQuality quality) => quality switch
        {
            VideoQuality.Best => "GỐC",
            VideoQuality.P2160 => "4K",
            VideoQuality.P1440 => "2K",
            VideoQuality.P1080 => "1080p",
            VideoQuality.P720 => "720p",
            VideoQuality.P480 => "480p",
            _ => "GỐC"
        };

        public static int? GetMaximumHeight(this VideoQuality quality) => quality switch
        {
            VideoQuality.P2160 => 2160,
            VideoQuality.P1440 => 1440,
            VideoQuality.P1080 => 1080,
            VideoQuality.P720 => 720,
            VideoQuality.P480 => 480,
            _ => null
        };
    }

    public enum AudioFormat
    {
        Mp3,
        M4a
    }

    public static class AudioFormatExtensions
    {
        public static string GetDisplayName(this AudioFormat format) => format switch
        {
            AudioFormat.Mp3 => "MP3 (320 kbps)",
            AudioFormat.M4a => "M4A (Apple AAC)",
            _ => "MP3"
        };

        public static string GetBadgeText(this AudioFormat format) => format switch
        {
            AudioFormat.Mp3 => "MP3",
            AudioFormat.M4a => "M4A",
            _ => "MP3"
        };

        public static string GetFileExtension(this AudioFormat format) => format switch
        {
            AudioFormat.Mp3 => "mp3",
            AudioFormat.M4a => "m4a",
            _ => "mp3"
        };
    }

    public enum BrowserCookieSource
    {
        None,
        Auto,
        Edge,
        Chrome,
        Brave,
        Firefox,
        Opera
    }

    public static class BrowserCookieSourceExtensions
    {
        public static string GetDisplayName(this BrowserCookieSource source) => source switch
        {
            BrowserCookieSource.None => "Không dùng cookie",
            BrowserCookieSource.Auto => "Tự động (Khuyên dùng)",
            BrowserCookieSource.Edge => "Microsoft Edge",
            BrowserCookieSource.Chrome => "Google Chrome",
            BrowserCookieSource.Brave => "Brave Browser",
            BrowserCookieSource.Firefox => "Mozilla Firefox",
            BrowserCookieSource.Opera => "Opera",
            _ => "Tự động"
        };

        public static string? GetYtDlpIdentifier(this BrowserCookieSource source) => source switch
        {
            BrowserCookieSource.None => null,
            BrowserCookieSource.Auto => "edge", // Default on Windows is Edge, falls back to chrome
            BrowserCookieSource.Edge => "edge",
            BrowserCookieSource.Chrome => "chrome",
            BrowserCookieSource.Brave => "brave",
            BrowserCookieSource.Firefox => "firefox",
            BrowserCookieSource.Opera => "opera",
            _ => null
        };
    }
}
