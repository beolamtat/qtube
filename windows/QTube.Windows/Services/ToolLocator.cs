using System;
using System.IO;

namespace QTube.Windows.Services
{
    public static class ToolLocator
    {
        public static string? YtDlp() => Locate("yt-dlp.exe");

        public static string? Ffmpeg() => Locate("ffmpeg.exe");

        public static string? QuickJs() => Locate("quickjs.exe") ?? Locate("qjs.exe");

        public static string? Deno() => Locate("deno.exe");

        private static string? Locate(string filename)
        {
            // 1. Check bundled Tools subfolder in application directory
            string appDir = AppDomain.CurrentDomain.BaseDirectory;
            string bundledPath = Path.Combine(appDir, "Tools", filename);
            if (File.Exists(bundledPath))
            {
                return bundledPath;
            }

            // 2. Check directly in app directory
            string rootPath = Path.Combine(appDir, filename);
            if (File.Exists(rootPath))
            {
                return rootPath;
            }

            // 3. Fallback to system PATH environment variable
            string? pathEnv = Environment.GetEnvironmentVariable("PATH");
            if (!string.IsNullOrEmpty(pathEnv))
            {
                foreach (string folder in pathEnv.Split(Path.PathSeparator, StringSplitOptions.RemoveEmptyEntries))
                {
                    try
                    {
                        string fullPath = Path.Combine(folder.Trim(), filename);
                        if (File.Exists(fullPath))
                        {
                            return fullPath;
                        }
                    }
                    catch
                    {
                        // Ignore invalid folder entries in PATH
                    }
                }
            }

            // 4. Common package manager locations (Scoop / Chocolatey)
            string userProfile = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
            string[] commonPaths = new[]
            {
                Path.Combine(userProfile, "scoop", "shims", filename),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData), "chocolatey", "bin", filename)
            };

            foreach (var path in commonPaths)
            {
                if (File.Exists(path)) return path;
            }

            return null;
        }
    }
}
