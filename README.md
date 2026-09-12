<p align="center">
  <img src="icon.png" width="128" height="128" alt="QTube Logo" style="border-radius: 28px;">
</p>

<h1 align="center">QTube</h1>

<p align="center">
  Ứng dụng native tải video và âm thanh YouTube hàng loạt cho macOS &amp; Windows.<br>
  Tự động vượt cơ chế chặn bot, giao diện đơn giản, tốc độ tối đa.
</p>

<p align="center">
  <a href="https://github.com/beolamtat/qtube/releases/download/v1.0.2/QTube-1.0.2-AppleSilicon.dmg">
    <img src="https://img.shields.io/badge/macOS-Apple%20Silicon%20(.dmg)-000000?style=for-the-badge&logo=apple&logoColor=white" alt="Download macOS Apple Silicon">
  </a>
  &nbsp;&nbsp;
  <a href="https://github.com/beolamtat/qtube/releases/download/v1.0.2/QTube-1.0.2-Intel.dmg">
    <img src="https://img.shields.io/badge/macOS-Intel%20Chip%20(.dmg)-555555?style=for-the-badge&logo=apple&logoColor=white" alt="Download macOS Intel">
  </a>
  &nbsp;&nbsp;
  <a href="https://github.com/beolamtat/qtube/releases/download/v1.0.2/QTube-1.0.2-Windows-x64-Setup.exe">
    <img src="https://img.shields.io/badge/Windows-10%2F11%20x64%20(.exe)-0078D4?style=for-the-badge&logo=windows&logoColor=white" alt="Download Windows Setup">
  </a>
</p>

---

## 📥 Tải về

Chọn phiên bản phù hợp với thiết bị của bạn:

| Hệ điều hành | Dòng máy / Cấu hình | Định dạng | Link tải trực tiếp |
| :--- | :--- | :---: | :--- |
|  **macOS** | **Mac Apple Silicon** | `.dmg` | [Tải về QTube-1.0.2-AppleSilicon.dmg](https://github.com/beolamtat/qtube/releases/download/v1.0.2/QTube-1.0.2-AppleSilicon.dmg) |
|  **macOS** | **Mac chip Intel** | `.dmg` | [Tải về QTube-1.0.2-Intel.dmg](https://github.com/beolamtat/qtube/releases/download/v1.0.2/QTube-1.0.2-Intel.dmg) |
| 🪟 **Windows** | **Windows 10 / 11 (64-bit)** | `.exe` | [Tải về QTube-1.0.2-Windows-x64-Setup.exe](https://github.com/beolamtat/qtube/releases/download/v1.0.2/QTube-1.0.2-Windows-x64-Setup.exe) |

**Mới ở v1.0.2:** Sửa lỗi chọn 1080p nhưng tệp chỉ có 480p trên Windows và macOS. Các mức phân giải cụ thể chỉ tải đúng mức được chọn; nếu không có luồng phù hợp, ứng dụng báo lỗi thay vì âm thầm hạ chất lượng. Tên tệp video mới có kèm độ phân giải để tránh trùng tệp cũ, và nhãn hàng đợi cập nhật theo chất lượng đã chọn thực tế. Smart App Control vẫn có thể chặn ứng dụng chưa được Windows xác minh; bản cập nhật này không tự tắt bảo vệ của hệ thống.

---

## ✨ Tính năng nổi bật

- **Tự động 100%**: Chỉ cần dán link là tải, tự động vượt cơ chế chống bot của YouTube mà không cần thao tác thủ công.
- **Đóng gói trọn gói (All-in-One Standalone)**:
  -  **macOS (Apple Silicon)**: ~50 MB (`.dmg`).
  -  **macOS (Intel Chip)**: ~51 MB (`.dmg`).
  - 🪟 **Windows 10 / 11 (64-bit)**: ~81 MB (`Setup.exe` tích hợp sẵn .NET 8 Runtime, Windows App SDK, bộ giải mã và công cụ).
  - Tích hợp QuickJS runtime siêu gọn nhẹ, mở app là dùng ngay mà không cần cài thêm bất kỳ runtime hay phần mềm phụ trợ nào.
- **Giao diện Native hiện đại**:
  - macOS: Giao diện SwiftUI tối ưu với Menu Bar icon chạy nền.
  - Windows: Giao diện Fluent Design (WinUI 3) chuẩn Windows 11 với hiệu ứng nền Mica, thông báo Windows Toast.
- **Chống ngủ máy (Sleep Prevention)**: Tự động giữ máy luôn thức trong quá trình tải để không bị đứt kết nối mạng giữa chừng.
- **Tự động bắt link Clipboard**: Copy link YouTube từ bất kỳ trình duyệt nào là app tự động nhận diện và đưa vào danh sách tải ngay.
- **Hỗ trợ Playlist & YouTube Mix**: Quét và xem trước danh sách phát, hỗ trợ tải trọn bộ và nhận diện thông minh đài phát Mix.
- **Tính năng cốt lõi**:
  - Hỗ trợ tải Video chất lượng cao (lên đến 4K) hoặc trích xuất Audio (MP3/M4A có bìa bài hát).
  - Khi chọn 480p/720p/1080p/1440p/2160p, ứng dụng chỉ tải đúng độ phân giải đó và báo rõ nếu nguồn không có luồng phù hợp.
  - Đóng gói sẵn toàn bộ công cụ cần thiết (`yt-dlp`, `ffmpeg`, `quickjs`), tự động tối ưu hóa luồng tải và thử lại thông minh khi gặp lỗi.

---

## 🚀 Hướng dẫn cài đặt

### Dành cho macOS:
1. Tải file `.dmg` tương ứng với dòng máy của bạn:
   - [Tải QTube cho Mac Apple Silicon (.dmg)](https://github.com/beolamtat/qtube/releases/download/v1.0.2/QTube-1.0.2-AppleSilicon.dmg)
   - [Tải QTube cho Mac chip Intel (.dmg)](https://github.com/beolamtat/qtube/releases/download/v1.0.2/QTube-1.0.2-Intel.dmg)
2. Mở file `.dmg` vừa tải về, kéo biểu tượng **QTube** vào thư mục **Applications**.
3. Mở **QTube** từ Launchpad hoặc thư mục Applications để sử dụng.

> [!NOTE]
> **Lưu ý khi mở lần đầu trên macOS (Nếu hiển thị cảnh báo chưa xác minh):**
> 1. Đóng thông báo cảnh báo của macOS.
> 2. Vào **System Settings** > **Privacy & Security**.
> 3. Cuộn xuống mục **Security**, bấm **Open Anyway** và chọn **Open** để xác nhận.
> *(Bạn chỉ cần thực hiện bước này một lần duy nhất).*

### Dành cho Windows:
1. Tải file cài đặt trọn gói: [**Tải về QTube-1.0.2-Windows-x64-Setup.exe**](https://github.com/beolamtat/qtube/releases/download/v1.0.2/QTube-1.0.2-Windows-x64-Setup.exe) (~81 MB)
2. Mở file setup vừa tải và nhấn **Next** để hoàn tất cài đặt (đã tích hợp sẵn trọn gói .NET 8 Runtime, Windows App SDK và toàn bộ công cụ cần thiết).
3. Mở **QTube** từ Desktop hoặc Start Menu để bắt đầu sử dụng.

> [!NOTE]
> **Lưu ý khi mở lần đầu trên Windows (Nếu Windows Defender SmartScreen hiển thị cảnh báo):**
> Do phần mềm mới được phát hành, Windows có thể hiển thị bảng thông báo màu xanh *"Windows protected your PC / Windows đã bảo vệ PC của bạn"*:
> 1. Bấm vào dòng chữ **"More info" (Xem thêm thông tin)**.
> 2. Bấm nút **"Run anyway" (Vẫn chạy)** để tiến hành cài đặt bình thường.
>
> Nếu cảnh báo ghi **Smart App Control blocked an app** (mã 4551), đây là chính sách khác với SmartScreen và không có nút **Run anyway** cho từng ứng dụng. Mở **Windows Security > App & browser control > Smart App Control settings** để kiểm tra trạng thái. Chỉ khi bạn tin cậy nguồn tải và chấp nhận thay đổi bảo vệ cho toàn bộ máy, bạn mới nên cân nhắc tắt Smart App Control; có thể không bật lại được nếu không cài đặt lại Windows.

---

## 💻 Yêu cầu hệ thống

- **macOS**: macOS 13.0 (Ventura) trở lên (hỗ trợ cả Apple Silicon M1/M2/M3/M4 và chip Intel).
- **Windows**: Windows 10 (bản 64-bit build 1809 trở lên) hoặc Windows 11.
