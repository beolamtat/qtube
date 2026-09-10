using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;
using System.Web;

namespace QTube.Windows.Services
{
    public static class LinkExtractor
    {
        private static readonly string[] AcceptedHosts = new[]
        {
            "youtube.com",
            "www.youtube.com",
            "m.youtube.com",
            "music.youtube.com",
            "youtu.be"
        };

        private static readonly Regex UrlRegex = new Regex(
            @"(https?://[^\s<>""]+)",
            RegexOptions.Compiled | RegexOptions.IgnoreCase
        );

        public static List<Uri> ExtractYouTubeUrls(string text)
        {
            if (string.IsNullOrWhiteSpace(text)) return new List<Uri>();

            var matches = UrlRegex.Matches(text);
            var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            var results = new List<Uri>();

            foreach (Match match in matches)
            {
                if (Uri.TryCreate(match.Value, UriKind.Absolute, out var uri) && IsYouTubeUrl(uri))
                {
                    if (seen.Add(uri.AbsoluteUri))
                    {
                        results.Add(uri);
                    }
                }
            }

            return results;
        }

        public static Uri? ParseSingleYouTubeUrl(string text)
        {
            if (string.IsNullOrWhiteSpace(text)) return null;
            var trimmed = text.Trim();
            if (trimmed.Any(char.IsWhiteSpace)) return null;

            if (Uri.TryCreate(trimmed, UriKind.Absolute, out var uri) && IsYouTubeUrl(uri))
            {
                return uri;
            }
            return null;
        }

        public static string? GetPlaylistId(Uri url)
        {
            if (!IsYouTubeUrl(url)) return null;
            var query = HttpUtility.ParseQueryString(url.Query);
            var list = query["list"];
            return string.IsNullOrWhiteSpace(list) ? null : list;
        }

        public static bool IsPlaylistUrl(Uri url)
        {
            if (!IsYouTubeUrl(url)) return false;
            if (!string.IsNullOrEmpty(GetPlaylistId(url))) return true;

            string path = url.AbsolutePath.ToLowerInvariant();
            return path.StartsWith("/@") || path.StartsWith("/channel/") || path.StartsWith("/c/") || path.StartsWith("/user/");
        }

        public static bool IsYouTubeMix(string listId)
        {
            return listId.StartsWith("RD", StringComparison.OrdinalIgnoreCase) ||
                   listId.StartsWith("UL", StringComparison.OrdinalIgnoreCase) ||
                   listId.StartsWith("PU", StringComparison.OrdinalIgnoreCase);
        }

        public static bool IsYouTubeMixUrl(Uri url)
        {
            var listId = GetPlaylistId(url);
            return listId != null && IsYouTubeMix(listId);
        }

        public static bool IsWatchVideoWithPlaylistUrl(Uri url)
        {
            if (!IsYouTubeUrl(url)) return false;
            var listId = GetPlaylistId(url);
            if (string.IsNullOrEmpty(listId)) return false;

            string path = url.AbsolutePath.ToLowerInvariant();
            return path.Contains("/watch") || string.Equals(url.Host, "youtu.be", StringComparison.OrdinalIgnoreCase);
        }

        public static Uri CleanVideoUrl(Uri url)
        {
            var builder = new UriBuilder(url);
            var query = HttpUtility.ParseQueryString(builder.Query);

            query.Remove("list");
            query.Remove("index");
            query.Remove("start_radio");

            builder.Query = query.ToString();
            return builder.Uri;
        }

        public static Uri? PlaylistUrlFromId(string listId)
        {
            return new Uri($"https://www.youtube.com/playlist?list={listId}");
        }

        public static bool IsYouTubeUrl(Uri url)
        {
            if (url.Scheme != Uri.UriSchemeHttp && url.Scheme != Uri.UriSchemeHttps) return false;
            string host = url.Host.ToLowerInvariant();

            return AcceptedHosts.Contains(host) || host.EndsWith(".youtube.com", StringComparison.OrdinalIgnoreCase);
        }
    }
}
