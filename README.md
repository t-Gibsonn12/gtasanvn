# GTASANVN

Source gamemode Pawn cho open.mp, lấy từ bản ZIP Los-Santos-Roleplay-2028-main.

## Cài đặt trên Windows

1. Cài bộ open.mp Windows x86 vào thư mục dự án để có runtime và trình biên dịch Qawno. Giữ file cấu hình và source của repo.
2. Chạy `powershell -NoProfile -ExecutionPolicy Bypass -File tools/setup_dependencies.ps1` để cài MySQL R41-4, bcrypt và YSI.
3. Tạo database `lsrp`, nhập `database_structure.sql` rồi chạy các file trong `database/migrations` theo thứ tự tên file. Migration `20260725_inventory_weapon_loadout.sql` tạo bảng lưu túi đồ.
4. Sao chép `mysql.ini.example` thành `mysql.ini` và điền thông tin database.
5. Chạy `COMPILE.bat` để tạo gamemode, sau đó chạy `omp-server.exe`.

Người chơi dùng `/inv` hoặc `/inventory` để mở túi đồ.
