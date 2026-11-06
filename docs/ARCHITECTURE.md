# Kiến trúc ban đầu

`apps/mobile` và `apps/admin` là hai ứng dụng npm workspace. `packages/shared` lưu các token màu và kiểu dữ liệu dùng chung. `backend` là gói Python độc lập. `app.main.create_app()` cấu hình CORS, logging, lỗi và router; `app.core` chứa chính sách chung; `app.db` cung cấp engine/session lazy và metadata Alembic. `/health` và `/api/v1/health` không phụ thuộc database. Việc xác thực và đồng bộ ngoại tuyến sẽ được bổ sung theo từng tính năng.
