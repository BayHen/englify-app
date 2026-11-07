# Admin Dashboard — TASK 08.1

## Quyền truy cập

Admin đăng nhập bằng Supabase Auth email/mật khẩu đang có. FastAPI xác minh access token như các endpoint riêng tư khác, sau đó kiểm tra `public.admin_members` theo `auth.users.id` ở **mọi** endpoint `/api/v1/admin`. Vai trò admin không lấy từ metadata hay dữ liệu do client tự gửi. Bảng `admin_members` và `admin_audit_logs` bật RLS nhưng không cấp quyền cho `anon`/`authenticated`; thao tác quản trị chỉ đi qua backend với kết nối database được bảo vệ. Không dùng service role key trên web hoặc mobile.

Migration không tự cấp quyền cho bất kỳ tài khoản nào. Để cấp quyền cho một người quản trị đã đăng ký bình thường, lấy UUID của tài khoản đó từ Supabase Dashboard → Authentication → Users, rồi chạy bằng kết nối database chủ sở hữu:

```sql
INSERT INTO public.admin_members(user_id) VALUES ('UUID_CUA_ADMIN_DA_XAC_MINH');
```

Chỉ cấp quyền sau khi xác minh danh tính. Thu hồi bằng `DELETE FROM public.admin_members WHERE user_id = 'UUID_CUA_ADMIN'`. Không cho người dùng bình thường tự ghi bảng này. Nếu chưa có tài khoản được cấp quyền, màn hình đăng nhập hoạt động nhưng trả `403 Administrator access required`; đây là trạng thái cấu hình an toàn.

## Cài đặt

1. Áp dụng migration `20261107_11` bằng `.\.venv\Scripts\python.exe -m alembic -c backend/alembic.ini upgrade head` từ thư mục gốc.
2. Sao chép `apps/admin/.env.example` thành `apps/admin/.env.local`. Điền Supabase Project URL, **publishable key** và địa chỉ API. `.env.local` đã được `.gitignore` loại trừ. Không dùng secret/service role key.
3. Chạy FastAPI: `.\.venv\Scripts\python.exe -m uvicorn app.main:app --app-dir backend --reload`.
4. Chạy admin: `npm.cmd run admin`; mở `http://localhost:3000`.
5. Đăng nhập tài khoản đã có trong `admin_members`.

Nếu web và API khác origin, thêm origin HTTPS của admin vào `ENGLIFY_CORS_ORIGINS` ở backend và khởi động lại API. CORS là lớp trình duyệt; quyền admin vẫn được kiểm tra ở server.

## Module và quy trình xuất bản

Dashboard, Vocabulary, Courses, Units, Lesson Builder, Lesson Items, Quiz Builder, Quiz Options, Real English, Badge Rules, Learning Analytics, Publishing và Audit Log có trong menu. Nội dung mới là bản nháp. Admin tạo, kiểm tra, rồi bấm **Publish**. API mobile chỉ trả nội dung đã xuất bản và chưa lưu trữ. `DELETE` trong admin là **archive mềm**: đặt `archived_at`, gỡ xuất bản và giữ lịch sử học của người dùng. Tài khoản thường không thể gọi các thao tác này.

Quan hệ: tạo Course → Unit (dán `course_id`) → Lesson (dán `course_id` và `unit_id`) → Lesson Item/Quiz Question (dán `lesson_id`). Quiz nhiều lựa chọn cần ít nhất hai Quiz Options, đúng một đáp án `is_correct=true` trước khi publish câu hỏi. Các dạng điền từ/nghe/ngữ pháp dùng `answer` JSON array; matching dùng JSON object. Bảng đáp án không được cấp quyền đọc trực tiếp cho người học. Badge Rules dùng `metric` là `completed_lessons` hoặc `total_xp`, cùng `target` dương.

Giao diện hiển thị lỗi kiểm tra trường từ backend, hỗ trợ tìm kiếm và phân trang 15 mục. Analytics chỉ hiển thị số lượng tổng hợp. Audit log lưu actor, action, resource, record ID và ảnh chụp trước/sau trong PostgreSQL; UI chỉ hiển thị thông tin tổng quát, không hiển thị token.

## Seed và kiểm chứng

`backend/seeds/development.sql` có từ vựng, khóa học, bài học và quiz gốc của dự án; `backend/seeds/real_english_development.sql` có nội dung Real English. Các seed không tạo người dùng hoặc quyền admin. Sau migration mới, seed chính đánh dấu các bản mẫu xác định là đã xuất bản để mobile vẫn dùng được. Không chạy seed phát triển trên dữ liệu production.

Trên database phát triển trống đã tạo và migrate, có thể nạp nội dung bằng `psql -v ON_ERROR_STOP=1 -f backend/seeds/development.sql` rồi `psql -v ON_ERROR_STOP=1 -f backend/seeds/real_english_development.sql` với kết nối PostgreSQL phát triển. Database phải dùng UTF-8 để lưu đúng nội dung tiếng Việt. Không trỏ lệnh vào database chứa dữ liệu người dùng nếu chưa xem tác động của seed.

Kiểm tra tự động: `npm.cmd run lint -w apps/admin`, `npm.cmd run build -w apps/admin`, `.\.venv\Scripts\python.exe -m ruff check backend`, và pytest với `ENGLIFY_TEST_DATABASE_URL` trỏ **database riêng cho test** đã migration/seed. Bài tích hợp `backend/tests/test_admin_integration.py` kiểm tra 401/403, tạo/sửa/xuất bản/lưu trữ, audit và khả năng đọc nội dung từ API mobile. Chưa kiểm thử đăng nhập với tài khoản admin Supabase thật trên trình duyệt; bước đó cần tài khoản được cấp quyền theo hướng dẫn trên.

## Giới hạn

- Editor dùng trường ID cha và JSON thô cho nội dung phức tạp; cần cải thiện trải nghiệm biên tập trước khi giao cho đội nội dung lớn.
- Quiz đã có lượt làm bị chặn sửa câu hỏi; Quiz Options của câu hỏi đã xuất bản cũng bị chặn sửa. Việc lưu trữ một bài học đang dùng sẽ làm bài đó biến mất khỏi danh mục mới, nhưng không xóa lịch sử học.
- Không có cơ chế duyệt hai người hoặc lịch xuất bản tự động. Chỉ admin được cấp quyền có thể publish.
