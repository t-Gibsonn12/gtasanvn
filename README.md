# GTASANVN

Source gamemode Pawn cho open.mp, lấy từ bản ZIP Los-Santos-Roleplay-2028-main.

## Cài đặt trên Windows

1. Cài bộ open.mp Windows x86 vào thư mục dự án để có runtime và trình biên dịch Qawno. Giữ file cấu hình và source của repo.
2. Chạy `powershell -NoProfile -ExecutionPolicy Bypass -File tools/setup_dependencies.ps1` để cài MySQL R41-4, bcrypt và YSI.
3. Với cài đặt mới, tạo database `gtasanvn`, nhập `database_structure.sql` rồi chạy các file trong `database/migrations` theo thứ tự tên file. Migration `20260725_inventory_weapon_loadout.sql` tạo bảng lưu túi đồ.
4. Sao chép `mysql.ini.example` thành `mysql.ini` và điền thông tin database. Với server đang chạy, giữ `mysql.ini` hiện có và dùng đúng database đang chứa tài khoản và nhân vật. Gamemode đọc `mysql.ini` ở thư mục chạy server khi khởi động.
5. Chạy `COMPILE.bat` để tạo gamemode, sau đó chạy `omp-server.exe`.

Người chơi dùng `/inv` hoặc `/inventory` để mở túi đồ.

## Điện thoại CEF trên GTASANVN

- Cài đúng bộ CEF server/client có API `CEF_RegisterEvent` và `OnCefReady` tương thích `qawno/include/cef.inc`. Trong file cấu hình server, nạp plugin hoặc component theo gói CEF đang dùng. Bản này không đóng gói binary CEF.
- Áp dụng migration `012_phone_system.sql` và `20260726_phone_cef.sql` trên database GTASANVN.
- Chép thư mục `scriptfiles/cef/gtasanvn_phone` lên server. Chạy `COMPILE.bat cef` để tạo `main.amx` bật CEF. `COMPILE.bat` thường vẫn hỗ trợ điện thoại dialog cho server chưa cài CEF.
- Sau khi có vật phẩm Phone, dùng `/phone`, `/dienthoai`, hoặc bấm dùng Phone trong inventory. Client chưa có CEF sẽ tiếp tục dùng dialog khi gọi `/phone`. Tin nhắn lưu offline trong hộp thư CEF. Cuộc gọi dùng chat `/p` của gamemode. Ứng dụng Máy ảnh hướng dẫn đính URL HTTPS.
- Bản demo giao diện mở qua `scriptfiles/cef/gtasanvn_phone/index.html?demo=1`.

Để bật CEF khi biên dịch thủ công, thêm đối số `GTASANVN_CEF_PHONE=1` vào lệnh Pawn.
