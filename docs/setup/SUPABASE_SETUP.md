# Thiết lập Supabase Free cho Englify Quest

## 1. Tạo dự án và lấy cấu hình công khai

Tạo dự án tại [Supabase Dashboard](https://supabase.com/dashboard) bằng gói Free. Trong màn hình **Connect** hoặc **Project Settings → API**, sao chép **Project URL** có dạng `https://<project-ref>.supabase.co` và **publishable key** bắt đầu bằng `sb_publishable_`. Địa chỉ `*.on.expo.app` là địa chỉ Expo, không phải Supabase. Không dùng `sb_secret_`, service role key hoặc database password trong ứng dụng mobile.

Sao chép `apps/mobile/.env.example` thành `apps/mobile/.env` và thay hai placeholder. Điền `EXPO_PUBLIC_API_URL` bằng URL FastAPI truy cập được từ điện thoại. Trên iPhone, `localhost` trỏ về iPhone, vì vậy dùng địa chỉ LAN của máy phát triển hoặc API qua HTTPS. Ở môi trường production, đặt cùng tên biến trong cấu hình build/deploy riêng; không commit file `.env`. `.gitignore` đã loại trừ file này. Expo nhúng `EXPO_PUBLIC_*` vào bundle, vì vậy chỉ dùng khóa công khai.

Backend cần `ENGLIFY_SUPABASE_URL` trong `.env` ở thư mục gốc. Nếu dự án vẫn dùng JWT HS256 cũ, thêm `ENGLIFY_SUPABASE_PUBLISHABLE_KEY` để backend hỏi Supabase Auth xác thực token. Với khóa ký bất đối xứng RS256/ES256, backend xác thực qua JWKS; không cần khóa bí mật. URL của mobile và backend phải trỏ cùng một dự án.

## 2. Email Auth và deep link

Trong **Authentication → Providers**, bật Email. Trong **Authentication → URL Configuration → Redirect URLs**, thêm `englifyquest://auth-callback` và `englifyquest://reset-password`. Giữ xác minh email nếu dự án yêu cầu; sau đăng ký, người dùng mở link xác minh trên cùng thiết bị để trao đổi PKCE code. Đặt lại mật khẩu dùng redirect `englifyquest://reset-password`. Kiểm tra deep link trên bản development build hoặc thiết bị; Expo Go có giới hạn với custom scheme.

## 3. Schema và RLS

**Alembic trong `backend/migrations/versions` là nguồn chân lý duy nhất cho schema ứng dụng.** Supabase quản lý `auth.users`; migration không tạo lại bảng Auth. Migration đầu tạo `profiles`, `user_preferences`, trigger cấp profile khi đăng ký và các policy RLS. Migration `20261106_04` cho phép người dùng cập nhật chỉ `display_name`, `avatar_url` trên profile của chính họ. Dùng PostgreSQL URL của dự án Supabase **chỉ ở backend** và chạy:

```powershell
.\.venv\Scripts\python.exe -m alembic -c backend/alembic.ini upgrade head
```

Không chạy migration trên dự án production trước khi kiểm tra môi trường, quyền và bản sao lưu. Nếu cần dữ liệu học mẫu ở môi trường phát triển, chạy `backend/seeds/development.sql` sau migration bằng tài khoản quản trị database. Script có ID cố định và không tạo user giả; mục tiêu học là tập lựa chọn `conversation`, `travel`, `work`, `exams` trong schema và onboarding. Người thử nghiệm tạo tài khoản qua đăng ký email bình thường.

## 4. Khởi động và chẩn đoán

Nếu đăng nhập Supabase thành công nhưng màn hình báo **Could not load your profile / Cannot reach the learning API**, kiểm tra `EXPO_PUBLIC_API_URL` trong `apps/mobile/.env` và khởi động FastAPI ở một terminal riêng. Trên web ở cùng máy, `http://localhost:8000/api/v1/health` phải trả HTTP 200. Với Expo Go trên điện thoại, thay `localhost` bằng IP LAN của máy chạy backend, cho phép cổng 8000 qua firewall và dùng `--host 0.0.0.0` khi chạy Uvicorn. Sau khi đổi `.env`, khởi động lại Expo bằng `npm.cmd run mobile -- --clear`.

Health trả 200 chỉ xác nhận tiến trình API chạy; endpoint `/api/v1/me` còn cần `ENGLIFY_SUPABASE_URL` và `ENGLIFY_DATABASE_URL` trong `.env` ở thư mục gốc, migration đã áp dụng, và profile của tài khoản đã được trigger tạo. Không điền URL database hoặc khóa bí mật vào `apps/mobile/.env`. Nếu web báo lỗi CORS trong Developer Tools, thêm **đúng origin web** vào `ENGLIFY_CORS_ORIGINS` ở backend rồi khởi động lại FastAPI.

Để lấy `ENGLIFY_DATABASE_URL`, mở dự án Supabase → **Connect** → sao chép chuỗi PostgreSQL. Trên mạng chỉ có IPv4, chọn **Session pooler** (cổng 5432); không tự đoán hostname pooler. Thay tiền tố `postgresql://` bằng `postgresql+psycopg://`, điền database password vào chỗ giữ chỗ và mã hóa phần trăm các ký tự đặc biệt trong mật khẩu. Chỉ lưu chuỗi này trong `.env` backend đã được Git bỏ qua. [Hướng dẫn kết nối PostgreSQL của Supabase](https://supabase.com/docs/guides/database/connecting-to-postgres) giải thích cách chọn Direct hoặc Session pooler.

```powershell
npm.cmd start -- --clear
.\.venv\Scripts\python.exe -m uvicorn app.main:app --app-dir backend --reload
```

Chạy mỗi lệnh ở một terminal từ thư mục gốc. Màn hình đăng nhập trong bản development có liên kết **Run Supabase diagnostic**. Nó kiểm tra định dạng URL/key, phản hồi Auth health, session hiện tại và truy vấn hai bảng. Trạng thái `passed` của bảng chỉ xác nhận API truy vấn thành công, **không chứng minh RLS giữa hai user**. Kiểm tra RLS cần hai tài khoản test và `backend/tests/sql/rls_and_constraints.sql` trên database tạm có Auth fixture. Không nhập mật khẩu test vào diagnostic.

Nếu thông báo `invalid_url`, thay URL Expo bằng Project URL Supabase. `missing_key`/`invalid_key`: kiểm tra publishable key. `Network error`: kiểm tra mạng, DNS và địa chỉ dự án. HTTP lỗi ở Auth health: kiểm tra URL và key. `Table or API schema missing`: chạy Alembic và kiểm tra schema `public`. `Authorization/RLS denied`: kiểm tra token, grants, policy và migration. Sau khi đổi `.env`, dừng Metro rồi khởi động lại với `--clear`.

## 5. Kiểm thử và giới hạn hiện tại

```powershell
npm.cmd run typecheck -w apps/mobile
npm.cmd run lint -w apps/mobile
npm.cmd run test -w apps/mobile
.\.venv\Scripts\python.exe -m pytest backend/tests -q
.\.venv\Scripts\python.exe -m ruff check backend
```

Đăng nhập, đăng ký, logout, khôi phục session và RLS trên Supabase thật chỉ được xác nhận sau khi điền Project URL đúng, chạy migration và tạo tài khoản thử nghiệm. Không báo các bước này thành công chỉ nhờ unit test. JWT RS256/ES256 dùng JWKS; HS256 cũ được xác thực bằng `/auth/v1/user` của Supabase. [Tài liệu Supabase về xác minh JWT](https://supabase.com/docs/guides/auth/jwts) khuyến nghị hỏi Auth server trực tiếp cho HS256. Dữ liệu nhạy cảm và token không được ghi vào log.
