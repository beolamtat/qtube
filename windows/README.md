# QTube cho Windows (Native WinUI 3 / C#)

Phiên bản Native chính thức của **QTube** dành cho hệ điều hành Windows (Windows 11 & Windows 10 64-bit), được thiết kế theo phong cách **Fluent Design** hiện đại với hiệu ứng kính **Mica**, tốc độ tức thì và tối ưu phần cứng.

---

## 🚀 Tính năng nổi bật trên Windows
- **Giao diện Windows 11 Fluent Design**: Hiệu ứng nền Mica mờ ảo, bo góc tròn và hỗ trợ Dark/Light Theme tự động theo hệ thống.
- **Tự động bắt link Clipboard**: Sao chép bất kỳ link YouTube nào từ Chrome, Edge, Brave, ứng dụng sẽ tự động nhận diện và đưa vào hàng đợi tải.
- **Tích hợp đầy đủ các định dạng**:
  - Video chất lượng cao: Tùy chọn từ Tiết kiệm (480p) đến 4K Ultra HD (2160p).
  - Trích xuất Audio MP3 (320kbps) & M4A (Apple AAC) tự động gắn ảnh bìa bài hát và metadata.
- **Hỗ trợ Danh sách phát (Playlist) & YouTube Mix**: Hộp thoại xem trước danh sách, cho phép chọn từng video cụ thể hoặc tải toàn bộ.
- **Chống ngủ máy (Sleep Prevention)**: Sử dụng Win32 API `SetThreadExecutionState` để ngăn máy tính tự ngủ hoặc ngắt mạng khi đang tải video lớn.
- **Vượt kiểm duyệt & Bot Detection**: Tích hợp sẵn `quickjs` runtime và hỗ trợ đọc cookie an toàn từ Edge/Chrome.

---

## 🛠️ Yêu cầu môi trường phát triển
- **Hệ điều hành**: Windows 10 (bản build 19041 trở lên) hoặc Windows 11.
- **IDE**: [Visual Studio 2022](https://visualstudio.microsoft.com/vs/) (bản Community miễn phí) với gói workload:
  - `.NET Desktop Development`
  - `Windows App SDK C# Templates`
- **.NET SDK**: .NET 8.0 SDK hoặc .NET 9.0 SDK.

---

## 📦 Hướng dẫn cài đặt & Chạy dự án

### Bước 1: Tải các công cụ phụ trợ (yt-dlp, ffmpeg, quickjs)
Chạy script PowerShell sau trên máy Windows để tự động tải các file `.exe` cần thiết vào thư mục `Tools`:
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\download-windows-tools.ps1
```

### Bước 2: Mở và chạy trên Visual Studio
1. Mở thư mục `windows/QTube.Windows` bằng **Visual Studio 2022**.
2. Chọn cấu hình **Debug** hoặc **Release**, nền tảng **x64**.
3. Bấm **F5** (hoặc nút Run) để khởi chạy ứng dụng.

### Hoặc chạy qua dòng lệnh (.NET CLI):
```powershell
cd windows/QTube.Windows
dotnet build -c Release -r win-x64
dotnet run -c Release -r win-x64
```

---

## 🎁 Đóng gói file cài đặt (Installer)

### Cách 1: Xuất bản tệp tự chạy (Standalone Folder)
```powershell
cd windows/QTube.Windows
dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=false
```
Thư mục xuất bản sẽ nằm tại: `bin\Release\net8.0-windows10.0.19041.0\win-x64\publish`. Bạn có thể nén zip thư mục này và chia sẻ cho người dùng mở lên dùng ngay.

### Cách 2: Tạo bộ cài đặt chuyên nghiệp (.exe) với Inno Setup
1. Cài đặt [Inno Setup](https://jrsoftware.org/isdl.php).
2. Chuột phải vào file `windows/installer.iss` và chọn **Compile**.
3. File cài đặt `QTube-1.0.1-Windows-x64-Setup.exe` sẽ được tạo ra tại thư mục `dist/`.

---

## 📁 Cấu trúc thư mục dự án

```
windows/
├── QTube.Windows/
│   ├── Assets/                       # Biểu tượng và tài nguyên ảnh
│   ├── Converters/                   # XAML Value Converters
│   ├── Models/                       # DownloadItem, PlaylistInfo, Enums
│   ├── Services/                     # YtdlpService, ToolLocator, ClipboardMonitor, SleepPrevention...
│   ├── ViewModels/                   # DownloadQueueViewModel (MVVM)
│   ├── Views/                        # PlaylistInspectorDialog
│   ├── MainWindow.xaml               # Giao diện chính (Fluent Design)
│   ├── App.xaml                      # Application Lifecycle & Resources
│   ├── app.manifest                  # DPI Awareness & Windows compatibility
│   └── QTube.Windows.csproj          # File cấu hình dự án .NET WinUI 3
├── scripts/
│   └── download-windows-tools.ps1    # Script tải yt-dlp.exe, ffmpeg.exe, quickjs.exe
├── installer.iss                     # Kịch bản đóng gói Inno Setup
└── README.md                         # Hướng dẫn này
```
