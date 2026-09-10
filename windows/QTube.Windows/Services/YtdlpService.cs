using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using QTube.Windows.Models;

namespace QTube.Windows.Services
{
    public class DownloadRequest
    {
        public string Url { get; set; } = string.Empty;
        public string OutputDirectory { get; set; } = string.Empty;
        public DownloadMode Mode { get; set; } = DownloadMode.Video;
        public VideoQuality Quality { get; set; } = VideoQuality.Best;
        public AudioFormat AudioFormat { get; set; } = AudioFormat.Mp3;
        public bool DownloadSubtitles { get; set; } = false;
        public string? CustomFilename { get; set; }
        public BrowserCookieSource BrowserCookieSource { get; set; } = BrowserCookieSource.Auto;
    }

    public class ProgressUpdate
    {
        public double Fraction { get; set; }
        public long DownloadedBytes { get; set; }
        public long? TotalBytes { get; set; }
        public double? SpeedBytesPerSecond { get; set; }
        public int? EtaSeconds { get; set; }
    }

    public class YtdlpService
    {
        private Process? _process;
        private readonly object _lock = new();
        private bool _isCancelled;

        public event Action<string>? TitleReceived;
        public event Action<ProgressUpdate>? ProgressReceived;
        public event Action? ProcessingStarted;
        public event Action<string>? FilePathReceived;

        public async Task DownloadAsync(DownloadRequest request, CancellationToken cancellationToken = default)
        {
            lock (_lock)
            {
                _isCancelled = false;
            }

            string? ytDlpPath = ToolLocator.YtDlp();
            if (string.IsNullOrEmpty(ytDlpPath))
            {
                throw new FileNotFoundException("Không tìm thấy yt-dlp.exe. Vui lòng kiểm tra thư mục Tools.");
            }

            string? ffmpegPath = ToolLocator.Ffmpeg();
            if (string.IsNullOrEmpty(ffmpegPath))
            {
                throw new FileNotFoundException("Không tìm thấy ffmpeg.exe. Vui lòng kiểm tra thư mục Tools.");
            }

            string? quickJsPath = ToolLocator.QuickJs();
            string? denoPath = ToolLocator.Deno();

            await ExecuteAttemptAsync(request, ytDlpPath, ffmpegPath, quickJsPath, denoPath, attempt: 1, cancellationToken);
        }

        private async Task ExecuteAttemptAsync(
            DownloadRequest request,
            string ytDlpPath,
            string ffmpegPath,
            string? quickJsPath,
            string? denoPath,
            int attempt,
            CancellationToken cancellationToken)
        {
            var args = BuildArguments(request, ffmpegPath, quickJsPath, denoPath);

            var psi = new ProcessStartInfo
            {
                FileName = ytDlpPath,
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true,
                StandardOutputEncoding = Encoding.UTF8,
                StandardErrorEncoding = Encoding.UTF8
            };

            foreach (var arg in args)
            {
                psi.ArgumentList.Add(arg);
            }

            var process = new Process { StartInfo = psi };

            lock (_lock)
            {
                if (_isCancelled) throw new OperationCanceledException();
                _process = process;
            }

            var diagnosticLines = new List<string>();

            try
            {
                process.Start();

                var registration = cancellationToken.Register(() =>
                {
                    Cancel();
                });

                var stdoutTask = Task.Run(async () =>
                {
                    using var reader = process.StandardOutput;
                    string? line;
                    while ((line = await reader.ReadLineAsync()) != null)
                    {
                        ParseLine(line);
                        if (!string.IsNullOrWhiteSpace(line))
                        {
                            diagnosticLines.Add(line);
                            if (diagnosticLines.Count > 20) diagnosticLines.RemoveAt(0);
                        }
                    }
                });

                var stderrTask = Task.Run(async () =>
                {
                    using var reader = process.StandardError;
                    string? line;
                    while ((line = await reader.ReadLineAsync()) != null)
                    {
                        if (!string.IsNullOrWhiteSpace(line))
                        {
                            diagnosticLines.Add(line);
                            if (diagnosticLines.Count > 20) diagnosticLines.RemoveAt(0);
                        }
                    }
                });

                await Task.WhenAll(stdoutTask, stderrTask, process.WaitForExitAsync(cancellationToken));
                registration.Dispose();

                lock (_lock)
                {
                    if (_isCancelled || cancellationToken.IsCancellationRequested)
                    {
                        throw new OperationCanceledException();
                    }
                }

                if (process.ExitCode != 0)
                {
                    string diagnostics = string.Join("\n", diagnosticLines).ToLowerInvariant();

                    bool isBotOrRateLimit = diagnostics.Contains("sign in to confirm you're not a bot")
                        || diagnostics.Contains("sign in to confirm you’re not a bot")
                        || diagnostics.Contains("http error 429")
                        || diagnostics.Contains("http error 403");

                    if (attempt < 2 && isBotOrRateLimit)
                    {
                        await Task.Delay(1500, cancellationToken);
                        await ExecuteAttemptAsync(request, ytDlpPath, ffmpegPath, quickJsPath, denoPath, attempt + 1, cancellationToken);
                        return;
                    }

                    if (diagnostics.Contains("sign in to confirm you're not a bot"))
                    {
                        throw new InvalidOperationException("YouTube yêu cầu xác minh tài khoản. Vui lòng chọn trình duyệt (Edge/Chrome) đã đăng nhập.");
                    }

                    throw new InvalidOperationException($"Quá trình tải thất bại (Mã lỗi {process.ExitCode}): {string.Join(" ", diagnosticLines)}");
                }
            }
            finally
            {
                lock (_lock)
                {
                    _process = null;
                }
                process.Dispose();
            }
        }

        public void Cancel()
        {
            lock (_lock)
            {
                _isCancelled = true;
                if (_process != null && !_process.HasExited)
                {
                    try
                    {
                        _process.Kill(entireProcessTree: true);
                    }
                    catch
                    {
                        // Process may have already terminated
                    }
                }
            }
        }

        private void ParseLine(string line)
        {
            if (string.IsNullOrWhiteSpace(line)) return;

            if (line.StartsWith("[BT_TITLE]"))
            {
                string title = line.Substring("[BT_TITLE]".Length).Trim();
                TitleReceived?.Invoke(title);
            }
            else if (line.StartsWith("[BT_FILE]"))
            {
                string path = line.Substring("[BT_FILE]".Length).Trim();
                FilePathReceived?.Invoke(path);
            }
            else if (line.StartsWith("[BT_PROGRESS]"))
            {
                string json = line.Substring("[BT_PROGRESS]".Length).Trim();
                try
                {
                    using var doc = JsonDocument.Parse(json);
                    var root = doc.RootElement;

                    var update = new ProgressUpdate();

                    if (root.TryGetProperty("downloaded_bytes", out var dlElem) && dlElem.TryGetInt64(out var dl))
                    {
                        update.DownloadedBytes = dl;
                    }

                    if (root.TryGetProperty("total_bytes", out var totalElem) && totalElem.TryGetInt64(out var total))
                    {
                        update.TotalBytes = total;
                    }
                    else if (root.TryGetProperty("total_bytes_estimate", out var estElem) && estElem.TryGetInt64(out var est))
                    {
                        update.TotalBytes = est;
                    }

                    if (update.TotalBytes > 0)
                    {
                        update.Fraction = Math.Clamp((double)update.DownloadedBytes / update.TotalBytes.Value, 0.0, 1.0);
                    }

                    if (root.TryGetProperty("speed", out var speedElem) && speedElem.TryGetDouble(out var speed))
                    {
                        update.SpeedBytesPerSecond = speed;
                    }

                    if (root.TryGetProperty("eta", out var etaElem) && etaElem.TryGetInt32(out var eta))
                    {
                        update.EtaSeconds = eta;
                    }

                    ProgressReceived?.Invoke(update);
                }
                catch
                {
                    // Ignore JSON parse errors for incomplete chunks
                }
            }
            else if (line.Contains("[ExtractAudio]") || line.Contains("[Merger]") || line.Contains("[FixupM3u8]"))
            {
                ProcessingStarted?.Invoke();
            }
        }

        private List<string> BuildArguments(
            DownloadRequest request,
            string ffmpegPath,
            string? quickJsPath,
            string? denoPath)
        {
            string ffmpegDir = Path.GetDirectoryName(ffmpegPath) ?? AppDomain.CurrentDomain.BaseDirectory;

            var args = new List<string>
            {
                "--ignore-config",
                "--no-plugin-dirs",
                "--newline",
                "--no-color",
                "--continue",
                "--no-overwrites",
                "--progress",
                "--progress-delta", "0.5",
                "--progress-template", "download:[BT_PROGRESS]%(progress)j",
                "--print", "before_dl:[BT_TITLE]%(title)s",
                "--print", "after_move:[BT_FILE]%(filepath)s",
                "--ffmpeg-location", ffmpegDir,
                "--paths", request.OutputDirectory,
                "--extractor-args", "youtube:player_client=ios,mweb,web",
                "--socket-timeout", "30",
                "--retries", "10",
                "--fragment-retries", "10",
                "--retry-sleep", "fragment:exp=1:20",
                "--sleep-requests", "1.0"
            };

            // Custom or default filename output template
            if (!string.IsNullOrWhiteSpace(request.CustomFilename))
            {
                string safeName = string.Join("-", request.CustomFilename.Split(Path.GetInvalidFileNameChars())).Trim();
                args.Add("--output");
                args.Add($"{safeName} [%(id)s].%(ext)s");
            }
            else
            {
                args.Add("--output");
                args.Add("%(title).180B [%(id)s].%(ext)s");
            }

            // JavaScript engine to evade YouTube bot challenge
            if (!string.IsNullOrEmpty(quickJsPath))
            {
                args.Add("--js-runtimes");
                args.Add($"quickjs:{quickJsPath}");
            }
            else if (!string.IsNullOrEmpty(denoPath))
            {
                args.Add("--js-runtimes");
                args.Add($"deno:{denoPath}");
            }

            // Browser Cookies
            string? cookieBrowser = request.BrowserCookieSource.GetYtDlpIdentifier();
            if (!string.IsNullOrEmpty(cookieBrowser))
            {
                args.Add("--cookies-from-browser");
                args.Add(cookieBrowser);
            }
            else
            {
                args.Add("--user-agent");
                args.Add("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36");
            }

            // Mode & Format selection
            if (request.Mode == DownloadMode.Audio)
            {
                string ext = request.AudioFormat.GetFileExtension();
                args.Add("--extract-audio");
                args.Add("--audio-format");
                args.Add(ext);
                args.Add("--audio-quality");
                args.Add("0");
                args.Add("--embed-thumbnail");
                args.Add("--add-metadata");
            }
            else
            {
                int? maxHeight = request.Quality.GetMaximumHeight();
                string format;
                if (maxHeight.HasValue)
                {
                    format = $"bestvideo[height<={maxHeight.Value}][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height<={maxHeight.Value}]+bestaudio/best[height<={maxHeight.Value}]/best";
                }
                else
                {
                    format = "bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio/best";
                }

                args.Add("-f");
                args.Add(format);
                args.Add("--merge-output-format");
                args.Add("mp4");
                args.Add("--embed-thumbnail");
                args.Add("--add-metadata");
            }

            if (request.DownloadSubtitles)
            {
                args.Add("--write-subs");
                args.Add("--sub-langs");
                args.Add("all");
                args.Add("--embed-subs");
            }

            // Target URL
            args.Add(request.Url);

            return args;
        }
    }
}
