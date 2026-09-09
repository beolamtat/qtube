<p align="center">
  <img src="icon.png" width="128" height="128" alt="QTube Logo" style="border-radius: 28px;">
</p>

<h1 align="center">QTube</h1>

<p align="center">
  Ứng dụng macOS native tải video và âm thanh YouTube hàng loạt.<br>
  Tự động vượt cơ chế chặn bot, giao diện đơn giản, tốc độ tối đa.
</p>

<p align="center">
  <a href="https://github.com/beolamtat/qtube/releases/download/v1.0.1/QTube-1.0.1-AppleSilicon.dmg">
    <img src="https://img.shields.io/badge/Download-Apple%20Silicon%20(.dmg)-000000?style=for-the-badge&logo=apple&logoColor=white" alt="Download Apple Silicon">
  </a>
  &nbsp;&nbsp;
  <a href="https://github.com/beolamtat/qtube/releases/download/v1.0.1/QTube-1.0.1-Intel.dmg">
    <img src="https://img.shields.io/badge/Download-Mac%20Intel%20(.dmg)-0071C5?style=for-the-badge&logo=intel&logoColor=white" alt="Download Intel">
  </a>
</p>

---

## 📥 Tải về

Chọn phiên bản phù hợp với máy Mac của bạn:

| Phiên bản | Dành cho | Link tải trực tiếp | Dung lượng |
| :--- | :--- | :--- | :--- |
| **Bản Apple Silicon** | Máy Mac dùng chip M1/M2/M3/M4 | [Tải về QTube-1.0.1-AppleSilicon.dmg](https://github.com/beolamtat/qtube/releases/download/v1.0.1/QTube-1.0.1-AppleSilicon.dmg) | **~49 MB** *(Đã tối ưu)* |
| **Bản Intel** | Máy Mac dùng chip Intel | [Tải về QTube-1.0.1-Intel.dmg](https://github.com/beolamtat/qtube/releases/download/v1.0.1/QTube-1.0.1-Intel.dmg) | **~14 MB** *(Đã tối ưu)* |

---

## ✨ Tính năng nổi bật

- **Tự động 100%**: Chỉ cần dán link là tải, tự động vượt cơ chế chống bot của YouTube mà không cần thao tác thủ công.
- **Trích xuất link thông minh**: Tự động nhận diện nhiều link YouTube từ văn bản dán vào và loại bỏ link trùng.
- **Tùy chọn linh hoạt**: Tải video (tùy chọn chất lượng đến 4K) hoặc chỉ trích xuất âm thanh M4A chất lượng cao.
- **Tải theo hàng đợi**: Hỗ trợ tải đồng thời từ 1 đến 4 video, theo dõi tiến độ chi tiết, tốc độ và thời gian còn lại.
- **Tích hợp sẵn**: Đóng gói sẵn toàn bộ công cụ cần thiết (`yt-dlp`, `ffmpeg`, `quickjs`), không cần cài đặt thêm phần mềm phụ trợ nào khác.

---

## 🚀 Hướng dẫn cài đặt

1. Tải file `.dmg` tương ứng với dòng máy của bạn ở phần [Tải về](#-tải-về) bên trên.
2. Mở file `.dmg` vừa tải về, kéo biểu tượng **QTube** vào thư mục **Applications**.
3. Mở **QTube** từ Launchpad hoặc thư mục Applications để sử dụng.

> [!NOTE]
> **Lưu ý khi mở lần đầu (Nếu macOS hiển thị cảnh báo chưa xác minh):**
> 1. Đóng thông báo cảnh báo của macOS.
> 2. Vào **System Settings** > **Privacy & Security**.
> 3. Cuộn xuống mục **Security**, bấm **Open Anyway** và chọn **Open** để xác nhận.
> *(Bạn chỉ cần thực hiện bước này một lần duy nhất).*

---

## 🛠 Phát triển & Đóng gói từ mã nguồn

```bash
# Cài đặt công cụ và build
chmod +x scripts/*.sh
./scripts/package-dmg.sh       # Tạo cả 2 bản: Apple Silicon và Intel
# hoặc:
# ./scripts/package-dmg.sh arm64      # Chỉ tạo bản Apple Silicon
# ./scripts/package-dmg.sh x86_64     # Chỉ tạo bản Intel
```

Kiểm thử:
```bash
swift test --disable-sandbox
```

