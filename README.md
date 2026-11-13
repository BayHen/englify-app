# Englify Quest

> Việc chuyển hoàn toàn khỏi FastAPI sang Supabase đang triển khai. Xem [audit migration](docs/SUPABASE_MIGRATION_AUDIT.md) và [báo cáo kiểm thử](docs/SUPABASE_MIGRATION_TEST_REPORT.md). Hiện tại không xóa `backend/` hoặc bỏ lệnh chạy API khi các màn hình vẫn gọi FastAPI.

Auth/profile/onboarding, từ điển, Real English, Journey/quiz và XP trên mobile đã gọi Supabase trực tiếp. Màn hình Translate đã nối Supabase Edge Function cho MyMemory; Function `translate` đã triển khai ngày 11/11/2026. Sau bản sửa kết quả từ/cụm ngắn, người dùng xác nhận trên Expo Go `License → Giấy phép.` và `giấy phép → License`. Xem [cách cấu hình provider và quota](docs/TRANSLATION_API_SETUP.md). Ứng dụng không trả bản dịch mẫu khi provider không sẵn sàng. Kế hoạch học và Writing đã có bản Supabase nhưng mobile còn giữ FastAPI mặc định cho đến khi Edge Function được triển khai/kiểm tra; [Admin Supabase](docs/ADMIN_SUPABASE_MIGRATION.md) mới được kiểm thử cục bộ, cờ chuyển đổi đang tắt. Xem [trạng thái migration V3](docs/SUPABASE_FINAL_MIGRATION_V3.md).

Real English Hybrid V2 đã có migration, hàng chờ duyệt Admin và Edge Function trên Supabase đang dùng; cờ giao diện Admin cục bộ đã bật. Tạo bài AI và feed mobile chưa được xác nhận đầu cuối; Cron vẫn tắt. Xem [kế hoạch kích hoạt và giới hạn kiểm chứng](docs/REAL_ENGLISH_HYBRID_V2.md).

Trong Admin, mục **AI lesson review** nay luôn hiện. Ngày 12/11/2026 đã áp migration Admin RLS và Real English V2, triển khai Function `real-english-generate` với JWT verification, và bật cờ giao diện trong `apps/admin/.env.local` cục bộ. Admin gọi Function qua route Next.js cùng origin để không cần mở CORS production cho localhost. Dòng “V2 lesson table: Ready” sai trước đó đã được sửa bằng GET thật. Người dùng đã xác nhận hàng chờ và biểu mẫu mới hiện sau khi khởi động lại Admin. Đã bật thử Free tier thủ công tối đa 1 yêu cầu/ngày với chủ đề “Coffee conversation”; chưa xác nhận tạo bài đầu cuối hoặc duyệt/xuất bản.

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
winget install ngrok -s msstore
ngrok help
ngrok config add-authtoken "<AUTHTOKEN_CỦA_BẠN>"
ngrok http 8000
cd apps/mobilnpx.cmd expo start --tunnel --cleare

.\.venv\Scripts\python.exe -m uvicorn app.main:app --app-dir backend --host 0.0.0.0 --port 8000 --reload
```

Expo Router nằm trong `apps/mobile` (`main: expo-router/entry`). Khi đứng ở thư mục gốc, dùng `npm.cmd start -- --clear` hoặc `npm.cmd run mobile -- --clear`; không chạy `npx.cmd expo start` trực tiếp tại root vì Expo sẽ tìm `App` của root thay vì route `apps/mobile/src/app`. Xem [hướng dẫn mobile](apps/mobile/README.md) để mở bằng Expo Go trên iPhone.

Expo hiển thị mã QR và địa chỉ Metro; trang quản trị ở `http://localhost:3000`; kiểm tra API tại `http://127.0.0.1:8000/api/v1/health`. Android cần trình giả lập hoặc Expo Go phù hợp SDK; iOS simulator cần macOS. Xem [hướng dẫn môi trường](docs/DEVELOPMENT.md), [nền tảng mobile](docs/MOBILE_FOUNDATION.md) và [hệ thiết kế](docs/DESIGN_SYSTEM.md).

Admin Dashboard cần thêm `apps/admin/.env.local` và tài khoản có trong `public.admin_members`; xem [hướng dẫn quản trị](docs/ADMIN_DASHBOARD.md). Tài khoản học viên thông thường không có quyền sửa nội dung.

Giao diện mobile V2 có Home, Journey, Explore, Practice và Profile; xem [hướng dẫn UI V2](docs/UI_REDESIGN_V2.md). Bản xem trước `/dev/ui-v2-preview` chỉ chạy trong development và luôn gắn nhãn dữ liệu mẫu.

Giao diện đăng nhập, đăng ký và khôi phục mật khẩu V4 được mô tả tại [tài liệu Auth UI V4](docs/AUTH_UI_V4.md).

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
