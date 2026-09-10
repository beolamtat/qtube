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
    public class PlaylistService
    {
        public async Task<PlaylistInfo> InspectPlaylistAsync(
            Uri playlistUrl,
            BrowserCookieSource cookieSource = BrowserCookieSource.Auto,
            CancellationToken cancellationToken = default)
        {
            string? ytDlpPath = ToolLocator.YtDlp();
            if (string.IsNullOrEmpty(ytDlpPath))
            {
                throw new FileNotFoundException("Không tìm thấy yt-dlp.exe.");
            }

            var psi = new ProcessStartInfo
            {
                FileName = ytDlpPath,
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true,
                StandardOutputEncoding = Encoding.UTF8
            };

            psi.ArgumentList.Add("--ignore-config");
            psi.ArgumentList.Add("--no-plugin-dirs");
            psi.ArgumentList.Add("--flat-playlist");
            psi.ArgumentList.Add("-J");

            string? cookieBrowser = cookieSource.GetYtDlpIdentifier();
            if (!string.IsNullOrEmpty(cookieBrowser))
            {
                psi.ArgumentList.Add("--cookies-from-browser");
                psi.ArgumentList.Add(cookieBrowser);
            }

            string? quickJs = ToolLocator.QuickJs();
            if (!string.IsNullOrEmpty(quickJs))
            {
                psi.ArgumentList.Add("--js-runtimes");
                psi.ArgumentList.Add($"quickjs:{quickJs}");
            }

            psi.ArgumentList.Add(playlistUrl.AbsoluteUri);

            using var process = new Process { StartInfo = psi };
            var outputBuilder = new StringBuilder();

            process.Start();

            var readTask = Task.Run(async () =>
            {
                using var reader = process.StandardOutput;
                string? line;
                while ((line = await reader.ReadLineAsync()) != null)
                {
                    outputBuilder.AppendLine(line);
                }
            });

            await Task.WhenAll(readTask, process.WaitForExitAsync(cancellationToken));

            if (process.ExitCode != 0)
            {
                throw new InvalidOperationException($"Không thể quét danh sách phát. Mã lỗi: {process.ExitCode}");
            }

            string json = outputBuilder.ToString();
            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;

            var info = new PlaylistInfo
            {
                Id = root.TryGetProperty("id", out var idElem) ? idElem.GetString() ?? "" : "",
                Title = root.TryGetProperty("title", out var titleElem) ? titleElem.GetString() ?? "Danh sách phát YouTube" : "Danh sách phát YouTube",
                Uploader = root.TryGetProperty("uploader", out var upElem) ? upElem.GetString() : null,
                ThumbnailUrl = root.TryGetProperty("thumbnail", out var thumbElem) ? thumbElem.GetString() : null
            };

            if (root.TryGetProperty("entries", out var entriesElem) && entriesElem.ValueKind == JsonValueKind.Array)
            {
                foreach (var item in entriesElem.EnumerateArray())
                {
                    string entryId = item.TryGetProperty("id", out var eid) ? eid.GetString() ?? "" : "";
                    string entryTitle = item.TryGetProperty("title", out var etitle) ? etitle.GetString() ?? "Video không tên" : "Video không tên";
                    string entryUrl = item.TryGetProperty("url", out var eurl) ? eurl.GetString() ?? $"https://www.youtube.com/watch?v={entryId}" : $"https://www.youtube.com/watch?v={entryId}";
                    if (!entryUrl.StartsWith("http", StringComparison.OrdinalIgnoreCase))
                    {
                        entryUrl = $"https://www.youtube.com/watch?v={entryId}";
                    }

                    string? entryUploader = item.TryGetProperty("uploader", out var eup) ? eup.GetString() : null;
                    string? entryThumb = item.TryGetProperty("thumbnail", out var ethumb) ? ethumb.GetString() : null;

                    info.Entries.Add(new PlaylistEntry
                    {
                        Id = entryId,
                        Title = entryTitle,
                        Url = entryUrl,
                        Uploader = entryUploader,
                        ThumbnailUrl = entryThumb,
                        IsSelected = true
                    });
                }
            }

            return info;
        }
    }
}
