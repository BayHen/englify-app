# Englify Quest

Kho mã chung cho ứng dụng học tiếng Anh trên Expo, trang quản trị Next.js và API FastAPI. Mobile đã có điều hướng và nội dung mẫu; xác thực thật, nội dung học tập từ server và cơ sở dữ liệu sẽ được triển khai ở các nhiệm vụ tiếp theo.

## Cấu trúc

| Đường dẫn | Vai trò |
| --- | --- |
| `apps/mobile` | Ứng dụng React Native/Expo Router |
| `apps/admin` | Trang quản trị Next.js App Router |
| `backend` | API FastAPI phiên bản `/api/v1` |
| `packages/shared` | Kiểu dữ liệu, tiện ích và design tokens TypeScript |
| `docs` | Tài liệu kiến trúc và phát triển |
| `.agents/skills` | Vị trí cho kỹ năng riêng của dự án |
| `.github/workflows` | Kiểm tra CI |

## Cài đặt và chạy

Yêu cầu Node.js 22 trở lên, npm và Python 3.11 trở lên. Từ thư mục gốc:

```powershell
Copy-Item .env.example .env
Copy-Item apps/mobile/.env.example apps/mobile/.env
npm.cmd ci
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -e './backend[dev]'
```

Trong PowerShell bị chặn script, dùng `npm.cmd` thay cho `npm`. Mỗi dịch vụ chạy ở một cửa sổ riêng:

```powershell
npm.cmd run mobile
npm.cmd run admin
.\.venv\Scripts\python.exe -m uvicorn app.main:app --app-dir backend --reload
```

Expo Router nằm trong `apps/mobile` (`main: expo-router/entry`). Khi đứng ở thư mục gốc, dùng `npm.cmd start -- --clear` hoặc `npm.cmd run mobile -- --clear`; không chạy `npx.cmd expo start` trực tiếp tại root vì Expo sẽ tìm `App` của root thay vì route `apps/mobile/src/app`. Xem [hướng dẫn mobile](apps/mobile/README.md) để mở bằng Expo Go trên iPhone.

Expo hiển thị mã QR và địa chỉ Metro; trang quản trị ở `http://localhost:3000`; kiểm tra API tại `http://127.0.0.1:8000/api/v1/health`. Android cần trình giả lập hoặc Expo Go phù hợp SDK; iOS simulator cần macOS. Xem [hướng dẫn môi trường](docs/DEVELOPMENT.md), [nền tảng mobile](docs/MOBILE_FOUNDATION.md) và [hệ thiết kế](docs/DESIGN_SYSTEM.md).

Admin Dashboard cần thêm `apps/admin/.env.local` và tài khoản có trong `public.admin_members`; xem [hướng dẫn quản trị](docs/ADMIN_DASHBOARD.md). Tài khoản học viên thông thường không có quyền sửa nội dung.

## Kiểm tra

```powershell
npm.cmd run typecheck -w apps/mobile
npm.cmd run lint -w apps/mobile
npm.cmd run test -w apps/mobile
npm.cmd run typecheck -w packages/shared
npm.cmd run lint -w apps/admin
npm.cmd run build -w apps/admin
.\.venv\Scripts\python.exe -m ruff check backend
.\.venv\Scripts\python.exe -m pytest backend/tests
```

## Phụ thuộc chính

- Mobile: Expo SDK 58, React Native 0.88, React 19.3, Expo Router, Zustand, TanStack Query, Vitest, TypeScript 6.
- Admin: Next.js 16.4, React 19.3, TypeScript 5.
- Backend: FastAPI 0.162, Pydantic Settings, SQLAlchemy 2.1, Alembic 1.20, PostgreSQL/psycopg, Uvicorn; pytest, httpx và Ruff khi phát triển.
- Shared: TypeScript 6; chưa có phụ thuộc chạy thực tế.

Các phiên bản JavaScript cụ thể được khóa trong `package-lock.json`. Backend giới hạn phiên bản trong `pyproject.toml`; có thể tạo lock riêng khi bổ sung công cụ quản lý Python ở nhiệm vụ sau.
