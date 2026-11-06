# Nền tảng dữ liệu

PostgreSQL là nguồn dữ liệu chính. `backend/app/db/base.py` cung cấp SQLAlchemy Declarative Base; `backend/app/db/session.py` tạo engine khi endpoint cần dữ liệu và cung cấp session theo request qua `Depends(get_db_session)`. Health endpoint không mở kết nối. Nếu thiếu `ENGLIFY_DATABASE_URL`, endpoint sử dụng database trả 503 `database_not_configured` với hướng dẫn cấu hình.

Alembic được cấu hình trong `backend/alembic.ini` và `backend/migrations/`. Chưa có bảng hoặc revision trong TASK 01.4; không tạo migration rỗng. Khi thêm bảng, định nghĩa khóa chính, khóa ngoại, chỉ mục theo truy vấn và tạo revision trong `versions/`; thử nâng cấp trên dữ liệu mẫu trước khi triển khai.

URL dùng driver `postgresql+psycopg`, ví dụ cấu trúc `postgresql+psycopg://user:<password>@localhost:5432/database`. Giá trị thật chỉ đặt trong `.env` không được commit. Mật khẩu có ký tự đặc biệt cần URL-encode. Chạy migration từ thư mục gốc bằng:

```powershell
.\.venv\Scripts\python.exe -m alembic -c backend/alembic.ini upgrade head
```

Lệnh này cần PostgreSQL và URL hợp lệ; unit tests hiện không cần Docker.
