using System;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Media;
using QTube.Windows.Models;
using QTube.Windows.ViewModels;
using QTube.Windows.Views;
using Windows.Storage.Pickers;
using WinRT.Interop;

namespace QTube.Windows
{
    public sealed partial class MainWindow : Window
    {
        public DownloadQueueViewModel ViewModel { get; }

        public MainWindow()
        {
            InitializeComponent();

            // Set Windows 11 Mica backdrop effect
            SystemBackdrop = new MicaBackdrop();

            ViewModel = new DownloadQueueViewModel(DispatcherQueue);
            ViewModel.RequestPlaylistDialog += OnRequestPlaylistDialog;
        }

        private async void OnRequestPlaylistDialog(PlaylistInfo playlist)
        {
            var dialog = new PlaylistInspectorDialog(playlist)
            {
                XamlRoot = Content.XamlRoot
            };

            var result = await dialog.ShowAsync();
            if (result == ContentDialogResult.Primary)
            {
                ViewModel.EnqueuePlaylistItems(playlist);
            }
        }

        private void LinkInput_KeyDown(object sender, KeyRoutedEventArgs e)
        {
            if (e.Key == Windows.System.VirtualKey.Enter)
            {
                _ = ViewModel.AddCurrentInputAsync();
            }
        }

        private async void ChooseFolder_Click(object sender, RoutedEventArgs e)
        {
            var picker = new FolderPicker();
            picker.FileTypeFilter.Add("*");

            // Associate picker with window handle
            IntPtr hwnd = WindowNative.GetWindowHandle(this);
            InitializeWithWindow.Initialize(picker, hwnd);

            var folder = await picker.PickSingleFolderAsync();
            if (folder != null)
            {
                ViewModel.OutputDirectory = folder.Path;
            }
        }

        private void OpenFile_Click(object sender, RoutedEventArgs e)
        {
            if (sender is FrameworkElement element && element.DataContext is DownloadItem item)
            {
                ViewModel.OpenFile(item);
            }
        }

        private void Retry_Click(object sender, RoutedEventArgs e)
        {
            if (sender is FrameworkElement element && element.DataContext is DownloadItem item)
            {
                ViewModel.RetryItem(item);
            }
        }

        private void Cancel_Click(object sender, RoutedEventArgs e)
        {
            if (sender is FrameworkElement element && element.DataContext is DownloadItem item)
            {
                ViewModel.CancelItem(item);
            }
        }

        private void Delete_Click(object sender, RoutedEventArgs e)
        {
            if (sender is FrameworkElement element && element.DataContext is DownloadItem item)
            {
                ViewModel.RemoveItem(item);
            }
        }
    }
}
