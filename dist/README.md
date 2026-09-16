# ToriumBot IPA Distribution

Thư mục này chứa file cài đặt `ToriumBot.ipa` sau khi GitHub Actions biên dịch xong từ macOS runner.

### Cách tải file IPA từ GitHub:
1. Truy cập repo GitHub của bạn: `https://github.com/<username>/<repo>/actions`
2. Chọn workflow chạy mới nhất (`Build iOS IPA for TrollStore`).
3. Kéo xuống phần **Artifacts** -> Tải file `ToriumBot-TrollStore-IPA.zip`.
4. Giải nén ra file `ToriumBot.ipa`.

### Cách cài đặt vào iPhone qua TrollStore:
1. Gửi file `ToriumBot.ipa` sang iPhone 6s/6s Plus (AirDrop, Telegram, Google Drive, hoặc Safari).
2. Mở TrollStore -> Nhấn nút **Install IPA File** (hoặc share file vào TrollStore).
3. Ứng dụng sẽ được cài đặt với quyền rootful unsandboxed (`com.apple.private.security.no-container = true`).
