using System;
using System.Collections.Generic;
using CommunityToolkit.Mvvm.ComponentModel;

namespace QTube.Windows.Models
{
    public partial class PlaylistEntry : ObservableObject
    {
        public string Id { get; set; } = string.Empty;
        public string Url { get; set; } = string.Empty;
        public string Title { get; set; } = string.Empty;
        public string? Uploader { get; set; }
        public string? ThumbnailUrl { get; set; }
        public string? DurationText { get; set; }

        [ObservableProperty]
        private bool _isSelected = true;
    }

    public class PlaylistInfo
    {
        public string Id { get; set; } = string.Empty;
        public string Title { get; set; } = string.Empty;
        public string? Uploader { get; set; }
        public string? ThumbnailUrl { get; set; }
        public int TotalCount => Entries.Count;
        public List<PlaylistEntry> Entries { get; set; } = new();
    }

    public class LinkDraft
    {
        public Guid Id { get; } = Guid.NewGuid();
        public string OriginalText { get; }
        public string? NormalizedUrl { get; }
        public bool IsValid => !string.IsNullOrEmpty(NormalizedUrl);

        public LinkDraft(string originalText, string? normalizedUrl = null)
        {
            OriginalText = originalText;
            NormalizedUrl = normalizedUrl;
        }
    }
}
