# Khởi tạo môi trường phát triển

## Điều kiện

- Node.js >=22, npm, Python >=3.11.
- Expo Go hoặc Android emulator để xem ứng dụng di động. iOS simulator chỉ hoạt động trên macOS.
- Docker/PostgreSQL là tùy chọn cho unit tests và health endpoint. Cần PostgreSQL khi phát triển endpoint dữ liệu hoặc chạy Alembic.

## Biến môi trường

Sao chép `.env.example` thành `.env` ở thư mục gốc và `apps/mobile/.env.example` thành `apps/mobile/.env` cho Expo. Backend đọc biến có tiền tố `ENGLIFY_` từ môi trường hoặc `.env` gốc. `ENGLIFY_DATABASE_URL` có thể để trống cho health/unit tests; endpoint dùng dữ liệu và Alembic yêu cầu URL PostgreSQL. `ENGLIFY_CORS_ORIGINS` là danh sách origin phân tách bằng dấu phẩy; mặc định chỉ cho localhost:3000 và localhost:8081 trong development, rỗng trong test/production. Production yêu cầu HTTPS origin nếu cấu hình. Mobile vẫn dùng dữ liệu mẫu. Biến `EXPO_PUBLIC_*` nằm trong ứng dụng được đóng gói, không chứa khóa bí mật. Khi thử bằng điện thoại thật, thay `localhost` trong URL API bằng địa chỉ IP LAN của máy phát triển.

## Lệnh

Chạy các lệnh cài đặt và khởi động trong README từ thư mục gốc. Trên macOS/Linux dùng `npm` thay `npm.cmd`, và dùng `.venv/bin/python` thay đường dẫn Python trên Windows. API có tài liệu tự động tại `http://127.0.0.1:8000/docs`.

### Docker tùy chọn

Điền `POSTGRES_PASSWORD` trong `.env` bằng mật khẩu riêng chỉ dùng ở máy phát triển; với Compose hiện tại, dùng ký tự chữ và số để URL kết nối được tạo đúng. `docker compose up -d db` khởi động PostgreSQL; nếu chạy API trên host, đặt `ENGLIFY_DATABASE_URL=postgresql+psycopg://englify:<password>@localhost:5432/englify` trong `.env`. `docker compose up --build api` khởi động cả database và API trong container, dùng cùng mật khẩu từ `.env`. Compose chỉ bind cổng vào `127.0.0.1`. Không commit `.env`, không dùng mật khẩu này cho môi trường thật.

Kiểm tra backend mà không cần Docker:

```powershell
.\.venv\Scripts\python.exe -m ruff check backend
.\.venv\Scripts\python.exe -m pytest backend/tests
```

Xem `docs/API.md` và `docs/DATABASE.md` cho hợp đồng response và migration.

## Giới hạn hiện tại

Mobile có tám route, nội dung mẫu và đăng nhập demo cục bộ; admin vẫn dùng màn hình khởi đầu của framework. Backend có health và nền tảng database nhưng chưa có bảng, auth hoặc nội dung học tập từ server. CI kiểm tra kiểu dữ liệu, lint/Ruff, unit tests mobile/backend và build admin. Xem `docs/MOBILE_FOUNDATION.md` để biết giới hạn Android/iOS.
