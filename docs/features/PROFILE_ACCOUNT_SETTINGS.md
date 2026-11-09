# Hồ sơ và cài đặt tài khoản V2

## Kiến trúc

`Profile → Account settings` dẫn đến chỉnh hồ sơ, ảnh đại diện, mật khẩu và sở thích học. `AuthProvider` giữ hồ sơ hiện tại, gọi FastAPI bằng access token Supabase và cập nhật cache sau khi lưu. Home và Profile đọc cùng hồ sơ này. Email chỉ đọc từ phiên Supabase Auth; ứng dụng không ghi `auth.users`.

PostgreSQL là nguồn sự thật. Alembic `20261109_13_profile_v2` thêm `username`, `bio`, CEFR hiện tại, giọng và ngôn ngữ giao diện. Cột `avatar_url` đã có được dùng làm **đường dẫn đối tượng** trong bucket `avatars`, không phải URL công khai. Unique index trên `lower(username)` ngăn trùng không phân biệt hoa thường. Migration không xóa hồ sơ hay lịch sử học. Tên cũ trên 50 ký tự vẫn được giữ; giới hạn 50 áp dụng cho lần cập nhật mới.

## API và kiểm tra đầu vào

| Endpoint | Công dụng |
| --- | --- |
| `GET /api/v1/me` | Đọc hồ sơ của UID trong JWT đã xác minh |
| `PATCH /api/v1/me/profile` | Chỉ nhận các trường thay đổi: `display_name`, `username`, `bio`, `avatar_url` |
| `PATCH /api/v1/me/preferences` | Chỉ nhận mục tiêu, CEFR, số phút, giọng, ngôn ngữ |
| `POST /api/v1/learning-plan/regenerate` | Tạo lại nhiệm vụ tương lai sau xác nhận |

Tên bắt buộc, bỏ khoảng trắng hai đầu, tối đa 50 ký tự. Username tùy chọn, chuẩn hóa chữ thường, 3–30 chữ cái ASCII/số/gạch dưới. Bio tối đa 160 ký tự và giữ xuống dòng. Thời lượng 1–180 phút ở API; UI cung cấp 5/10/15/20/30. CEFR A1–C2 được quy đổi sang mức đầu vào cho bộ lập kế hoạch hiện có. Mục tiêu `real_english` dùng cùng bộ lập kế hoạch quy tắc, chưa có lộ trình chuyên biệt. `interface_language` là sở thích đã lưu; toàn bộ giao diện chưa được bản địa hóa theo giá trị này.

Khi sửa mục tiêu, mức hoặc thời lượng, ứng dụng lưu sở thích trước, sau đó hỏi có làm mới kế hoạch tương lai hay không. Từ chối giữ kế hoạch hiện tại. Dịch vụ tạo lại đánh dấu kế hoạch cũ là tạm dừng và tạo kế hoạch mới; bài học đã hoàn thành và kết quả lịch sử vẫn còn.

## Ảnh đại diện và Supabase Storage

Migration tạo bucket `avatars` **private** nếu Supabase Storage có sẵn, giới hạn JPEG 2 MB, và tạo policy SELECT/INSERT/DELETE cho thư mục `UID/` của chính người dùng. Nếu bucket đã tồn tại, migration không đổi cấu hình cũ: hãy kiểm tra trong Dashboard rằng bucket không public, MIME `image/jpeg`, giới hạn 2 MB. Nếu kết nối database không có schema `storage`, tạo bucket/policy trong dự án Supabase trước khi thử upload; migration ứng dụng có thể chạy độc lập với Storage ở môi trường test.

Ứng dụng xin quyền thư viện ảnh trên thiết bị, cho chọn/cắt vuông, chuyển JPEG 512×512 và nén. Trước khi gửi kiểm tra kích thước. Đối tượng mới được upload vào `UID/tên.jpg`; API chỉ cho lưu đường dẫn bắt đầu bằng UID trong JWT. Sau khi API lưu thành công mới xóa ảnh cũ. Nếu API lỗi, ứng dụng cố xóa ảnh vừa upload. Xóa ảnh thực hiện theo thứ tự bỏ tham chiếu trong hồ sơ rồi xóa đối tượng. Ảnh riêng tư được hiển thị bằng signed URL ngắn hạn; không dùng service role key trong mobile.

Giới hạn: signed URL hiện tại có hạn một giờ và được lấy lại khi màn hình mount hoặc đường dẫn thay đổi; nếu người dùng giữ màn hình mở lâu hơn, cần mở lại màn hình để tải lại ảnh. Trình chọn ảnh trên web không cung cấp cùng UI cắt như Android/iOS; bước xử lý ảnh vẫn cắt giữa về hình vuông.

## Mật khẩu và quyền riêng tư

Màn đổi mật khẩu gửi `current_password` và mật khẩu mới đến Supabase Auth qua `updateUser`, theo API Supabase JS hiện có. Mật khẩu không đi qua FastAPI, PostgreSQL ứng dụng, cache hay log. Dự án Supabase có thể bật yêu cầu xác thực lại bằng email/nonce; khi đó dùng email khôi phục ở màn đăng nhập nếu Supabase trả `reauthentication_needed`. Kiểm tra phiên hết hạn trước khi gửi. API profile không nhận UID đích, XP, badge hay role. RLS trên `profiles` và `user_preferences` giới hạn dữ liệu theo `auth.uid()`; cột sửa hồ sơ được cấp riêng cho role `authenticated`.

## Chạy và kiểm tra

1. Cấu hình `.env` theo `docs/setup/SUPABASE_SETUP.md`; không chép khóa bí mật vào mobile.
2. Từ `backend`, chạy `..\.venv\Scripts\python.exe -m alembic upgrade head` với `ENGLIFY_DATABASE_URL` trỏ đến database dự định. Sao lưu trước khi nâng cấp môi trường thật.
3. Chạy `npm.cmd run typecheck -w apps/mobile`, `npm.cmd run lint -w apps/mobile`, `npm.cmd run test -w apps/mobile` từ gốc.
4. Chạy `.venv\Scripts\python.exe -m pytest backend/tests/test_profile_v2_validation.py backend/tests/test_auth_database_integration.py -q`. Ca tích hợp cần `ENGLIFY_TEST_DATABASE_URL` của PostgreSQL thử nghiệm đã migration.
5. Chạy `npm.cmd run start -w apps/mobile -- --clear`; đăng nhập, mở Profile → Account settings. Thử lưu tên/username/bio, tải ảnh và xóa, đổi mật khẩu, đổi mục tiêu và từ chối/đồng ý tạo lại kế hoạch. Đăng xuất/đăng nhập lại để xác nhận dữ liệu. Thử hai tài khoản: username trùng phải trả 409, tài khoản khác không đọc/sửa được dữ liệu riêng. Kiểm tra Console/LogBox trên web sau từng thao tác để phát hiện `Unexpected text node`.

Kiểm thử trên iPhone/Android và Supabase Storage thực cần thiết trước khi phát hành; build web hoặc unit test không chứng minh các quyền ảnh, trình cắt, upload và luồng mật khẩu hoạt động trên thiết bị.
