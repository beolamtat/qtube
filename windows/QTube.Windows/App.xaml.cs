using System;
using Microsoft.UI.Xaml;
using QTube.Windows.Services;

namespace QTube.Windows
{
    public partial class App : Application
    {
        public static MainWindow? MainWindow { get; private set; }

        public App()
        {
            InitializeComponent();
        }

        protected override void OnLaunched(LaunchActivatedEventArgs args)
        {
            NotificationService.Initialize();

            MainWindow = new MainWindow();
            MainWindow.Activate();
        }
    }
}
