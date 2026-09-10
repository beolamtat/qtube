using System;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.UI.Dispatching;
using Windows.ApplicationModel.DataTransfer;

namespace QTube.Windows.Services
{
    public class ClipboardMonitor
    {
        private static ClipboardMonitor? _instance;
        public static ClipboardMonitor Instance => _instance ??= new ClipboardMonitor();

        public event Action<Uri>? UrlDetected;

        private DispatcherQueueTimer? _timer;
        private string? _lastProcessedText;
        private bool _isEnabled = true;

        public bool IsEnabled
        {
            get => _isEnabled;
            set
            {
                _isEnabled = value;
                if (!value) _lastProcessedText = null;
            }
        }

        public void Start(DispatcherQueue dispatcherQueue)
        {
            if (_timer != null) return;

            _timer = dispatcherQueue.CreateTimer();
            _timer.Interval = TimeSpan.FromMilliseconds(800);
            _timer.Tick += (s, e) => CheckClipboard();
            _timer.Start();
        }

        public void Stop()
        {
            _timer?.Stop();
            _timer = null;
        }

        private async void CheckClipboard()
        {
            if (!_isEnabled) return;

            try
            {
                var package = Clipboard.GetContent();
                if (package != null && package.Contains(StandardDataFormats.Text))
                {
                    string text = await package.GetTextAsync();
                    if (!string.IsNullOrWhiteSpace(text) && text != _lastProcessedText)
                    {
                        _lastProcessedText = text;
                        var url = LinkExtractor.ParseSingleYouTubeUrl(text);
                        if (url != null)
                        {
                            UrlDetected?.Invoke(url);
                        }
                    }
                }
            }
            catch
            {
                // Clipboard might be locked by another application
            }
        }
    }
}
