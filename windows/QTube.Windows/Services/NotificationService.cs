using System;
using Microsoft.Windows.AppNotifications;
using Microsoft.Windows.AppNotifications.Builder;

namespace QTube.Windows.Services
{
    public static class NotificationService
    {
        private static bool _isRegistered;

        public static void Initialize()
        {
            try
            {
                if (AppNotificationManager.IsSupported())
                {
                    AppNotificationManager.Default.Register();
                    _isRegistered = true;
                }
            }
            catch
            {
                _isRegistered = false;
            }
        }

        public static void ShowDownloadCompleted(string title, string filePath)
        {
            if (!_isRegistered) return;

            try
            {
                var notification = new AppNotificationBuilder()
                    .AddText("Tải xuống hoàn tất!")
                    .AddText(title)
                    .AddText("Nhấn để mở tệp")
                    .SetArguments($"open_file={Uri.EscapeDataString(filePath)}")
                    .BuildNotification();

                AppNotificationManager.Default.Show(notification);
            }
            catch
            {
                // Ignore toast notification failures
            }
        }

        public static void ShowDownloadFailed(string title, string error)
        {
            if (!_isRegistered) return;

            try
            {
                var notification = new AppNotificationBuilder()
                    .AddText("Tải xuống thất bại")
                    .AddText(title)
                    .AddText(error)
                    .BuildNotification();

                AppNotificationManager.Default.Show(notification);
            }
            catch
            {
                // Ignore toast notification failures
            }
        }

        public static void Unregister()
        {
            if (_isRegistered)
            {
                try
                {
                    AppNotificationManager.Default.Unregister();
                }
                catch { }
            }
        }
    }
}
