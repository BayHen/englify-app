# Xác thực và onboarding – TASK 03.2

Englify Quest dùng Supabase Auth Free tier cho email và mật khẩu. Ứng dụng Expo chỉ chứa **publishable key** công khai; không đưa service role key, JWT secret hoặc mật khẩu database vào `EXPO_PUBLIC_*`. FastAPI kiểm tra chữ ký access token bằng JWKS và lấy UUID người dùng từ token trước mọi truy vấn riêng tư. Profile được tạo bởi trigger khi Supabase Auth thêm user.

## Cấu hình Supabase

1. Tạo dự án Supabase, bật Email provider và chọn **asymmetric JWT signing key** (RSA hoặc EC). Migration và backend hiện hỗ trợ RS256/ES256; nếu dự án còn dùng HS256, chuyển khóa ký trước khi dùng API. Không sao chép JWT secret vào ứng dụng.
2. Áp dụng Alembic `upgrade head` vào PostgreSQL của dự án. Migration tham chiếu `auth.users` có sẵn, tạo profile trigger và cột onboarding. Dùng database URL chỉ ở backend.
3. Thêm `englifyquest://auth-callback` và `englifyquest://reset-password` vào **Authentication → URL Configuration → Redirect URLs**. Giữ email confirmation bật: luồng PKCE cần xác nhận email và trao đổi mã một lần trên **cùng thiết bị** đã bắt đầu đăng ký/reset. Email đưa người học trở về ứng dụng qua custom scheme `englifyquest` trong `app.json`. Kiểm thử liên kết trên development build hoặc ứng dụng đã cài; Expo Go có giới hạn với custom scheme.
4. Sao chép `apps/mobile/.env.example` thành `apps/mobile/.env` và điền `EXPO_PUBLIC_SUPABASE_URL`, `EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY`, `EXPO_PUBLIC_API_URL`. URL API trên thiết bị thật phải dùng địa chỉ mạng mà thiết bị truy cập được, không phải `localhost` của máy phát triển.
5. Trong `.env` gốc, đặt `ENGLIFY_SUPABASE_URL` cùng project URL và `ENGLIFY_DATABASE_URL` (driver `postgresql+psycopg`). Không commit `.env`.

Không có Supabase project URL/key trong repository. Vì vậy không thể kiểm thử email delivery hoặc đăng ký/đăng nhập với dịch vụ thật chỉ từ mã nguồn này. Supabase email mặc định có giới hạn gửi; cấu hình SMTP riêng trước khi phát hành quy mô lớn.

## Luồng ứng dụng

- Đăng ký gửi email, mật khẩu và `display_name` tới Supabase Auth. Nếu xác nhận email được bật, màn hình nhắc kiểm tra hộp thư và chưa mở màn hình riêng tư. Trigger database tạo profile sau khi Auth thêm user.
- Đăng nhập email/mật khẩu nhận session từ Supabase SDK. Session được phục hồi khi mở lại ứng dụng. Trên iOS/Android, SDK lưu session trong Expo SecureStore; trên web phiên đăng nhập chỉ tồn tại trong bộ nhớ để tránh ghi token vào localStorage.
- Khi ứng dụng ở foreground, Supabase SDK tự làm mới access token. Backend trả 401 cho token hết hạn, chữ ký sai, sai issuer/audience/role hoặc subject không phải UUID; mobile xóa session cục bộ khi API trả 401. Logout dùng scope `local` để chỉ kết thúc phiên của thiết bị hiện tại, rồi xóa session, profile và cache ở ứng dụng.
- Người học chọn mục tiêu, trình độ ban đầu và số phút/ngày ở `/onboarding`. `PUT /api/v1/me/onboarding` ghi vào `user_preferences`; khởi động lại sẽ bỏ qua onboarding nếu `onboarding_completed_at` đã có. Route học tập được bảo vệ bởi Expo Router và mọi endpoint dữ liệu đều kiểm tra token ở backend.
- Đặt lại mật khẩu gửi email qua `resetPasswordForEmail`. Link mở `reset-password`, app trao đổi mã PKCE lấy recovery session rồi hiển thị màn hình nhập mật khẩu mới. App dùng `updateUser` của Supabase để đổi mật khẩu. Yêu cầu reset luôn hiển thị thông báo chung để không tiết lộ email có tài khoản hay không.

## Kiểm thử

```powershell
.\.venv\Scripts\python.exe -m pytest backend/tests -q
npm run typecheck -w apps/mobile
npm run lint -w apps/mobile
npm run test -w apps/mobile
```

`backend/tests/test_auth_tokens.py` dùng khóa RSA thử nghiệm để xác nhận kiểm tra token. `backend/tests/test_auth_database_integration.py` chỉ chạy khi đặt `ENGLIFY_TEST_DATABASE_URL` trỏ tới PostgreSQL **tạm** đã nạp Auth fixture và migration; nó tạo hai user thử nghiệm, kiểm tra lưu/đọc dữ liệu và cô lập tài khoản. Không trỏ biến này tới dự án Supabase thật. SQL RLS test của TASK 03.1 ở `backend/tests/sql/rls_and_constraints.sql` tiếp tục kiểm tra policy trực tiếp tại PostgreSQL.

## Giới hạn bảo mật

Expo Router guard chỉ bảo vệ điều hướng UI; backend vẫn xác minh JWT trên từng endpoint. Kết nối database backend hiện là role đặc quyền và có thể bỏ qua RLS, do đó endpoint luôn lấy user ID từ token đã xác minh và lọc SQL theo ID đó. Chưa có Google/Apple Sign-In. Web không khôi phục session sau khi tải lại trang và luồng PKCE qua email chưa hỗ trợ mở email ở tab/trình duyệt khác; phiên bản đầu ưu tiên Android/iOS. Token đã phát hành có thể còn hợp lệ tới `exp` sau khi logout; ứng dụng xóa local session ngay, còn backend xác minh chữ ký và thời hạn JWT nhưng chưa tra danh sách thu hồi theo request. Dùng access token ngắn hạn trong cấu hình Supabase.
