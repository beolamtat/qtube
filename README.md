<p align="center">
  <img src="icon.png" width="128" height="128" alt="QTube Logo" style="border-radius: 28px;">
</p>

<h1 align="center">QTube</h1>

<p align="center">
  Ứng dụng native tải video và âm thanh YouTube hàng loạt cho macOS.<br>
  Tự động vượt cơ chế chặn bot, giao diện đơn giản, tốc độ tối đa.
</p>

<p align="center">
  <a href="https://github.com/beolamtat/qtube/releases/download/v1.0.1/QTube-1.0.1-AppleSilicon.dmg">
    <img src="https://img.shields.io/badge/macOS-Apple%20Silicon%20(.dmg)-000000?style=for-the-badge&logo=apple&logoColor=white" alt="Download macOS Apple Silicon">
  </a>
  &nbsp;&nbsp;
  <a href="https://github.com/beolamtat/qtube/releases/download/v1.0.1/QTube-1.0.1-Intel.dmg">
    <img src="https://img.shields.io/badge/macOS-Intel%20Chip%20(.dmg)-555555?style=for-the-badge&logo=apple&logoColor=white" alt="Download macOS Intel">
  </a>
</p>

---

## 📥 Tải về

Chọn phiên bản phù hợp với dòng máy Mac của bạn:

| Hệ điều hành | Dòng máy / Cấu hình | Định dạng | Link tải trực tiếp |
| :--- | :--- | :---: | :--- |
|  **macOS** | **Mac Apple Silicon** | `.dmg` | [Tải về QTube-1.0.1-AppleSilicon.dmg](https://github.com/beolamtat/qtube/releases/download/v1.0.1/QTube-1.0.1-AppleSilicon.dmg) |
|  **macOS** | **Mac chip Intel** | `.dmg` | [Tải về QTube-1.0.1-Intel.dmg](https://github.com/beolamtat/qtube/releases/download/v1.0.1/QTube-1.0.1-Intel.dmg) |

---

## ✨ Tính năng nổi bật

- **Tự động 100%**: Chỉ cần dán link là tải, tự động vượt cơ chế chống bot của YouTube mà không cần thao tác thủ công.
- **Tối ưu siêu nhẹ**:
  - Bản Apple Silicon: ~50 MB.
  - Bản Intel: ~51 MB.
  - Tích hợp QuickJS runtime siêu gọn nhẹ, loại bỏ hoàn toàn các thành phần thừa.
- **Hỗ trợ Menu Bar Native**: Giữ app chạy nền với logo app và bộ đếm video tải trực quan trong thời gian thực trên thanh Menu Bar.
- **Chống ngủ máy (Sleep Prevention)**: Tự động giữ máy luôn thức trong quá trình tải để không bị đứt kết nối mạng giữa chừng.
- **Tự động bắt link Clipboard**: Copy link YouTube từ bất kỳ trình duyệt nào là app tự động nhận diện và đưa vào danh sách tải ngay.
- **Hỗ trợ Playlist & YouTube Mix**: Quét và xem trước danh sách phát, hỗ trợ tải trọn bộ và nhận diện thông minh đài phát Mix.
- **Tính năng cốt lõi**:
  - Hỗ trợ tải Video chất lượng cao (lên đến 4K) hoặc trích xuất Audio (MP3/M4A có bìa bài hát).
  - Tích hợp cookies trình duyệt giúp vượt qua cơ chế chặn bot và hạn chế độ tuổi của YouTube.
  - Đóng gói sẵn toàn bộ công cụ cần thiết (`yt-dlp`, `ffmpeg`, `quickjs`), mở lên là dùng, không cần cài đặt thêm phần mềm phụ trợ.

---

## 🚀 Hướng dẫn cài đặt

### Dành cho macOS:
1. Tải file `.dmg` tương ứng với dòng máy của bạn ở phần [Tải về](#-tải-về) bên trên.
2. Mở file `.dmg` vừa tải về, kéo biểu tượng **QTube** vào thư mục **Applications**.
3. Mở **QTube** từ Launchpad hoặc thư mục Applications để sử dụng.

> [!NOTE]
> **Lưu ý khi mở lần đầu (Nếu macOS hiển thị cảnh báo chưa xác minh):**
> 1. Đóng thông báo cảnh báo của macOS.
> 2. Vào **System Settings** > **Privacy & Security**.
> 3. Cuộn xuống mục **Security**, bấm **Open Anyway** và chọn **Open** để xác nhận.
> *(Bạn chỉ cần thực hiện bước này một lần duy nhất).*

