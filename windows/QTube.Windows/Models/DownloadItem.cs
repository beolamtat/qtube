using System;
using CommunityToolkit.Mvvm.ComponentModel;

namespace QTube.Windows.Models
{
    public partial class DownloadItem : ObservableObject
    {
        public Guid Id { get; } = Guid.NewGuid();
        public string Url { get; }

        [ObservableProperty]
        private string _title;

        [ObservableProperty]
        private string? _authorName;

        [ObservableProperty]
        private string? _thumbnailUrl;

        [ObservableProperty]
        private string? _durationText;

        [ObservableProperty]
        private DownloadMode _mode;

        [ObservableProperty]
        private VideoQuality _quality;

        [ObservableProperty]
        private AudioFormat _audioFormat;

        [ObservableProperty]
        private bool _hasSubtitles;

        [ObservableProperty]
        private string? _formatBadge;

        [ObservableProperty]
        private string? _destinationDirectory;

        [ObservableProperty]
        private string? _customFilename;

        [ObservableProperty]
        private double _progress; // 0.0 to 1.0

        [ObservableProperty]
        private long _downloadedBytes;

        [ObservableProperty]
        private long? _totalBytes;

        [ObservableProperty]
        private double? _speedBytesPerSecond;

        [ObservableProperty]
        private int? _etaSeconds;

        [ObservableProperty]
        [NotifyPropertyChangedFor(nameof(StatusLabel))]
        [NotifyPropertyChangedFor(nameof(IsActive))]
        [NotifyPropertyChangedFor(nameof(IsCompleted))]
        [NotifyPropertyChangedFor(nameof(IsFailed))]
        private DownloadStatus _status = DownloadStatus.Waiting;

        [ObservableProperty]
        private string? _outputPath;

        [ObservableProperty]
        private string? _errorMessage;

        [ObservableProperty]
        private DateTime? _startedAt;

        [ObservableProperty]
        private DateTime? _finishedAt;

        public string StatusLabel => Status.GetLabel();
        public bool IsActive => Status.IsActive();
        public bool IsCompleted => Status == DownloadStatus.Completed;
        public bool IsFailed => Status == DownloadStatus.Failed;

        public string? FormattedSpeed
        {
            get
            {
                if (SpeedBytesPerSecond == null || SpeedBytesPerSecond <= 0) return null;
                double speed = SpeedBytesPerSecond.Value;
                if (speed >= 1024 * 1024)
                    return $"{speed / (1024 * 1024):F1} MB/s";
                if (speed >= 1024)
                    return $"{speed / 1024:F0} KB/s";
                return $"{speed:F0} B/s";
            }
        }

        public string? FormattedEta
        {
            get
            {
                if (EtaSeconds == null || EtaSeconds <= 0) return null;
                int eta = EtaSeconds.Value;
                if (eta >= 3600)
                    return $"{eta / 3600}h {(eta % 3600) / 60}m";
                if (eta >= 60)
                    return $"{eta / 60}m {eta % 60}s";
                return $"{eta}s";
            }
        }

        public DownloadItem(
            string url,
            DownloadMode mode = DownloadMode.Video,
            VideoQuality quality = VideoQuality.Best,
            AudioFormat audioFormat = AudioFormat.Mp3,
            bool hasSubtitles = false)
        {
            Url = url;
            _title = url;
            _mode = mode;
            _quality = quality;
            _audioFormat = audioFormat;
            _hasSubtitles = hasSubtitles;
            _formatBadge = mode == DownloadMode.Audio ? audioFormat.GetBadgeText() : quality.GetBadgeText();
        }
    }
}
