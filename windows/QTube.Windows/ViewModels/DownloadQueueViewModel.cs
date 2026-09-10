using System;
using System.Collections.Concurrent;
using System.Collections.ObjectModel;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Microsoft.UI.Dispatching;
using QTube.Windows.Models;
using QTube.Windows.Services;
using Windows.ApplicationModel.DataTransfer;

namespace QTube.Windows.ViewModels
{
    public partial class DownloadQueueViewModel : ObservableObject
    {
        private readonly DispatcherQueue _dispatcherQueue;
        private readonly ConcurrentDictionary<Guid, (YtdlpService Service, CancellationTokenSource Cts)> _runningServices = new();
        private readonly PlaylistService _playlistService = new();
        private bool _isScheduling;

        public ObservableCollection<DownloadItem> Items { get; } = new();
        public ObservableCollection<LinkDraft> LinkDrafts { get; } = new();

        [ObservableProperty]
        private string _linkInputText = string.Empty;

        [ObservableProperty]
        private DownloadMode _selectedMode = DownloadMode.Video;

        [ObservableProperty]
        private VideoQuality _selectedQuality = VideoQuality.Best;

        [ObservableProperty]
        private AudioFormat _selectedAudioFormat = AudioFormat.Mp3;

        [ObservableProperty]
        private bool _downloadSubtitles = false;

        [ObservableProperty]
        private string _outputDirectory;

        [ObservableProperty]
        private int _maxConcurrentDownloads = 2;

        [ObservableProperty]
        private BrowserCookieSource _browserCookieSource = BrowserCookieSource.Auto;

        [ObservableProperty]
        private bool _isInspectingPlaylist;

        [ObservableProperty]
        private PlaylistInfo? _activePlaylist;

        public int ActiveCount => Items.Count(i => i.IsActive);
        public int CompletedCount => Items.Count(i => i.IsCompleted);
        public bool HasPendingOrActiveItems => Items.Any(i => i.Status == DownloadStatus.Waiting || i.IsActive);

        public event Action<PlaylistInfo>? RequestPlaylistDialog;

        public DownloadQueueViewModel(DispatcherQueue dispatcherQueue)
        {
            _dispatcherQueue = dispatcherQueue;

            string downloadsFolder = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
            _outputDirectory = Path.Combine(downloadsFolder, "Downloads", "QTube");

            if (!Directory.Exists(_outputDirectory))
            {
                try { Directory.CreateDirectory(_outputDirectory); } catch { }
            }

            // Clipboard auto detection
            ClipboardMonitor.Instance.UrlDetected += OnClipboardUrlDetected;
            ClipboardMonitor.Instance.Start(_dispatcherQueue);
        }

        private void OnClipboardUrlDetected(Uri url)
        {
            _dispatcherQueue.TryEnqueue(() =>
            {
                if (LinkExtractor.IsPlaylistUrl(url))
                {
                    _ = InspectPlaylistAsync(url);
                }
                else
                {
                    AddSingleUrl(url.AbsoluteUri);
                }
            });
        }

        [RelayCommand]
        public async Task PasteLinksAsync()
        {
            try
            {
                var package = Clipboard.GetContent();
                if (package != null && package.Contains(StandardDataFormats.Text))
                {
                    string text = await package.GetTextAsync();
                    if (!string.IsNullOrWhiteSpace(text))
                    {
                        var urls = LinkExtractor.ExtractYouTubeUrls(text);
                        if (urls.Count == 1 && LinkExtractor.IsPlaylistUrl(urls[0]))
                        {
                            await InspectPlaylistAsync(urls[0]);
                            return;
                        }

                        foreach (var url in urls)
                        {
                            AddSingleUrl(url.AbsoluteUri);
                        }
                    }
                }
            }
            catch { }
        }

        [RelayCommand]
        public async Task AddCurrentInputAsync()
        {
            if (string.IsNullOrWhiteSpace(LinkInputText)) return;

            string text = LinkInputText.Trim();
            LinkInputText = string.Empty;

            var urls = LinkExtractor.ExtractYouTubeUrls(text);
            if (urls.Count == 1 && LinkExtractor.IsPlaylistUrl(urls[0]))
            {
                await InspectPlaylistAsync(urls[0]);
                return;
            }

            if (urls.Count > 0)
            {
                foreach (var url in urls)
                {
                    AddSingleUrl(url.AbsoluteUri);
                }
            }
            else
            {
                AddSingleUrl(text);
            }
        }

        public void AddSingleUrl(string urlText)
        {
            var item = new DownloadItem(
                urlText,
                SelectedMode,
                SelectedQuality,
                SelectedAudioFormat,
                DownloadSubtitles)
            {
                DestinationDirectory = OutputDirectory
            };

            Items.Add(item);
            UpdateCounters();
            ScheduleDownloads();
        }

        public async Task InspectPlaylistAsync(Uri playlistUrl)
        {
            IsInspectingPlaylist = true;
            try
            {
                var info = await _playlistService.InspectPlaylistAsync(playlistUrl, BrowserCookieSource);
                ActivePlaylist = info;
                RequestPlaylistDialog?.Invoke(info);
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"Error inspecting playlist: {ex.Message}");
            }
            finally
            {
                IsInspectingPlaylist = false;
            }
        }

        public void EnqueuePlaylistItems(PlaylistInfo playlist)
        {
            foreach (var entry in playlist.Entries.Where(e => e.IsSelected))
            {
                var item = new DownloadItem(
                    entry.Url,
                    SelectedMode,
                    SelectedQuality,
                    SelectedAudioFormat,
                    DownloadSubtitles)
                {
                    Title = entry.Title,
                    AuthorName = entry.Uploader,
                    ThumbnailUrl = entry.ThumbnailUrl,
                    DestinationDirectory = OutputDirectory
                };
                Items.Add(item);
            }

            UpdateCounters();
            ScheduleDownloads();
        }

        [RelayCommand]
        public void CancelItem(DownloadItem item)
        {
            if (_runningServices.TryGetValue(item.Id, out var tuple))
            {
                tuple.Cts.Cancel();
                tuple.Service.Cancel();
            }
            item.Status = DownloadStatus.Cancelled;
            UpdateCounters();
            ScheduleDownloads();
        }

        [RelayCommand]
        public void RetryItem(DownloadItem item)
        {
            item.Status = DownloadStatus.Waiting;
            item.Progress = 0;
            item.ErrorMessage = null;
            UpdateCounters();
            ScheduleDownloads();
        }

        [RelayCommand]
        public void RemoveItem(DownloadItem item)
        {
            CancelItem(item);
            Items.Remove(item);
            UpdateCounters();
        }

        [RelayCommand]
        public void ClearCompleted()
        {
            var completed = Items.Where(i => i.IsCompleted).ToList();
            foreach (var item in completed)
            {
                Items.Remove(item);
            }
            UpdateCounters();
        }

        [RelayCommand]
        public void OpenFolder(DownloadItem? item = null)
        {
            string folder = item?.DestinationDirectory ?? OutputDirectory;
            if (Directory.Exists(folder))
            {
                Process.Start(new ProcessStartInfo
                {
                    FileName = folder,
                    UseShellExecute = true
                });
            }
        }

        [RelayCommand]
        public void OpenFile(DownloadItem item)
        {
            if (!string.IsNullOrEmpty(item.OutputPath) && File.Exists(item.OutputPath))
            {
                Process.Start(new ProcessStartInfo
                {
                    FileName = item.OutputPath,
                    UseShellExecute = true
                });
            }
            else
            {
                OpenFolder(item);
            }
        }

        private void ScheduleDownloads()
        {
            if (_isScheduling) return;
            _isScheduling = true;

            try
            {
                while (_runningServices.Count < MaxConcurrentDownloads)
                {
                    var next = Items.FirstOrDefault(i => i.Status == DownloadStatus.Waiting);
                    if (next == null) break;

                    StartDownload(next);
                }

                if (_runningServices.Count > 0)
                {
                    SleepPreventionService.PreventSleep();
                }
                else
                {
                    SleepPreventionService.AllowSleep();
                }
            }
            finally
            {
                _isScheduling = false;
            }
        }

        private void StartDownload(DownloadItem item)
        {
            item.Status = DownloadStatus.Preparing;
            item.StartedAt = DateTime.Now;
            UpdateCounters();

            var service = new YtdlpService();
            var cts = new CancellationTokenSource();
            _runningServices[item.Id] = (service, cts);

            service.TitleReceived += title =>
            {
                _dispatcherQueue.TryEnqueue(() => item.Title = title);
            };

            service.ProgressReceived += progress =>
            {
                _dispatcherQueue.TryEnqueue(() =>
                {
                    item.Status = DownloadStatus.Downloading;
                    item.Progress = progress.Fraction;
                    item.DownloadedBytes = progress.DownloadedBytes;
                    item.TotalBytes = progress.TotalBytes;
                    item.SpeedBytesPerSecond = progress.SpeedBytesPerSecond;
                    item.EtaSeconds = progress.EtaSeconds;
                });
            };

            service.ProcessingStarted += () =>
            {
                _dispatcherQueue.TryEnqueue(() => item.Status = DownloadStatus.Processing);
            };

            service.FilePathReceived += path =>
            {
                _dispatcherQueue.TryEnqueue(() => item.OutputPath = path);
            };

            _ = Task.Run(async () =>
            {
                var req = new DownloadRequest
                {
                    Url = item.Url,
                    OutputDirectory = item.DestinationDirectory ?? OutputDirectory,
                    Mode = item.Mode,
                    Quality = item.Quality,
                    AudioFormat = item.AudioFormat,
                    DownloadSubtitles = item.HasSubtitles,
                    BrowserCookieSource = BrowserCookieSource
                };

                try
                {
                    await service.DownloadAsync(req, cts.Token);

                    _dispatcherQueue.TryEnqueue(() =>
                    {
                        item.Status = DownloadStatus.Completed;
                        item.Progress = 1.0;
                        item.FinishedAt = DateTime.Now;
                        NotificationService.ShowDownloadCompleted(item.Title, item.OutputPath ?? req.OutputDirectory);
                    });
                }
                catch (OperationCanceledException)
                {
                    _dispatcherQueue.TryEnqueue(() =>
                    {
                        item.Status = DownloadStatus.Cancelled;
                    });
                }
                catch (Exception ex)
                {
                    _dispatcherQueue.TryEnqueue(() =>
                    {
                        item.Status = DownloadStatus.Failed;
                        item.ErrorMessage = ex.Message;
                        NotificationService.ShowDownloadFailed(item.Title, ex.Message);
                    });
                }
                finally
                {
                    _runningServices.TryRemove(item.Id, out _);
                    _dispatcherQueue.TryEnqueue(() =>
                    {
                        UpdateCounters();
                        ScheduleDownloads();
                    });
                }
            });
        }

        private void UpdateCounters()
        {
            OnPropertyChanged(nameof(ActiveCount));
            OnPropertyChanged(nameof(CompletedCount));
            OnPropertyChanged(nameof(HasPendingOrActiveItems));
        }
    }
}
