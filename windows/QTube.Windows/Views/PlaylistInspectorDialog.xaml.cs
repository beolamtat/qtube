using System.ComponentModel;
using System.Linq;
using Microsoft.UI.Xaml.Controls;
using QTube.Windows.Models;

namespace QTube.Windows.Views
{
    public sealed partial class PlaylistInspectorDialog : ContentDialog, INotifyPropertyChanged
    {
        public PlaylistInfo Playlist { get; }

        public event PropertyChangedEventHandler? PropertyChanged;

        private bool? _selectAll = true;
        public bool? SelectAll
        {
            get => _selectAll;
            set
            {
                if (_selectAll != value)
                {
                    _selectAll = value;
                    PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(SelectAll)));
                    if (value.HasValue)
                    {
                        foreach (var entry in Playlist.Entries)
                        {
                            entry.IsSelected = value.Value;
                        }
                        UpdateSelectedCount();
                    }
                }
            }
        }

        public string SelectedCountText => $"Đã chọn {Playlist.Entries.Count(e => e.IsSelected)}/{Playlist.TotalCount} video";

        public PlaylistInspectorDialog(PlaylistInfo playlist)
        {
            InitializeComponent();
            Playlist = playlist;

            foreach (var entry in Playlist.Entries)
            {
                entry.PropertyChanged += (s, e) =>
                {
                    if (e.PropertyName == nameof(PlaylistEntry.IsSelected))
                    {
                        UpdateSelectedCount();
                    }
                };
            }
        }

        private void UpdateSelectedCount()
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(SelectedCountText)));
        }
    }
}
