# Kế hoạch triển khai Giai đoạn 01 — Nền tảng Englify Quest

## Kết quả khảo sát

- Kho mã hiện chỉ có thư mục `.git`; nhánh `main` chưa có commit, mã nguồn, tài liệu, cấu hình hay bài kiểm thử.
- Các lệnh `node`, `npm`, `npx`, `python`, `docker`, `psql` và `git` có trong môi trường. Chưa xác minh phiên bản, trạng thái Docker daemon hoặc kết nối PostgreSQL.
- Danh mục kỹ năng của phiên làm việc đã được kiểm tra. Chưa thấy kỹ năng chuyên biệt cho kiến trúc di động, FastAPI, thiết kế cơ sở dữ liệu, máy học tập, âm thanh hay bảo mật; không tạo kỹ năng dự án khi chưa có quy trình lặp lại cụ thể.
- Chưa có tính năng cần giữ tương thích hoặc dữ liệu người dùng cần di chuyển.

## Mục tiêu Giai đoạn 01

Tạo bộ khung monorepo có thể khởi chạy tại máy phát triển, một đường đi dọc tối thiểu từ ứng dụng di động đến API và PostgreSQL, cùng quy ước chung cho xác thực, dữ liệu ngoại tuyến và kiểm thử. Nội dung học tập đầy đủ và các tính năng nâng cao thuộc các giai đoạn sau.

## Trình tự thực hiện đề xuất

1. **Quy ước kho mã:** tạo `AGENTS.md`, `README.md`, `apps/mobile`, `apps/admin`, `backend`, `packages`, `supabase`, `docs`, `.github/workflows`; thiết lập `.gitignore`, biến môi trường mẫu và lệnh chạy chung. Ghim phiên bản phụ thuộc tương thích thay vì chọn phiên bản theo suy đoán.
2. **Backend và dữ liệu:** khởi tạo FastAPI với `/api/v1/health`, cấu hình Pydantic, SQLAlchemy và Alembic. Tạo migration đầu tiên cho hồ sơ người dùng và nội dung bài học tối thiểu; mỗi bảng có khóa chính, khóa ngoại thích hợp và chỉ mục phục vụ truy vấn. Dùng PostgreSQL qua Docker Compose tại máy phát triển.
3. **Ứng dụng di động:** khởi tạo Expo Router/TypeScript, theme sáng/tối, safe area và các thành phần giao diện cơ bản theo bảng màu trong brief. Tạo màn hình chào, trang chủ và một bài học mẫu; truy cập API qua lớp client có kiểu dữ liệu. Lưu bài học đã tải và tiến độ chờ đồng bộ bằng Expo SQLite.
4. **Admin:** khởi tạo Next.js/TypeScript và giao diện đọc danh sách bài học mẫu qua API. Chức năng chỉnh sửa nội dung chỉ được mở sau khi có xác thực và phân quyền quản trị.
5. **Chất lượng và tài liệu:** thêm kiểm tra kiểu dữ liệu, lint, kiểm thử API/migration và luồng học tập tối thiểu; cấu hình CI trong giới hạn miễn phí. Viết `README.md` và các tài liệu `ARCHITECTURE.md`, `DATABASE.md`, `API.md`, `DEVELOPMENT.md`, `ROADMAP.md`, `TESTING.md`, `FREE_SERVICES.md` bằng tiếng Việt.

## Quyết định cần giữ nhất quán

- PostgreSQL là nguồn dữ liệu chính; SQLite trên thiết bị chỉ lưu nội dung đã tải và hàng đợi thay đổi. Gắn ID ổn định và thời điểm cập nhật cho bản ghi đồng bộ; quy tắc xử lý xung đột phải được xác định trước khi ghi hai chiều.
- API có tiền tố `/api/v1`; hợp đồng dữ liệu được định nghĩa ở backend và chia sẻ kiểu dữ liệu hoặc sinh client cho mobile/admin khi cấu trúc thực tế đã rõ.
- Xác thực phải dùng cơ chế được kiểm chứng và kiểm tra quyền ở backend. Không lưu khóa bí mật trong ứng dụng di động; không để endpoint quản trị công khai.
- Dùng nội dung mẫu tự biên soạn cho bản đầu. Chỉ nhập bộ từ điển hoặc dịch vụ bên ngoài sau khi kiểm tra giấy phép, chất lượng và tài nguyên vận hành.
- Phát âm bằng Expo Speech chỉ là phát âm văn bản. Chấm điểm phát âm chuyên sâu được hoãn; mọi giao diện liên quan phải nêu đúng giới hạn kỹ thuật.
- Không dùng API hoặc hạ tầng trả phí nếu chưa có chấp thuận rõ ràng.

## Tiêu chí hoàn thành Giai đoạn 01

- Một người mới có thể làm theo tài liệu để khởi chạy API, PostgreSQL, mobile và admin tại máy phát triển.
- Migration chạy trên cơ sở dữ liệu trống; API health và đọc bài học mẫu hoạt động; mobile hiển thị bài học lấy từ API và đọc lại bản đã tải khi ngoại tuyến.
- Kiểm thử backend, kiểm tra kiểu dữ liệu và lint của các ứng dụng chạy thành công; CI chạy cùng các kiểm tra đó.
- Tài liệu chỉ rõ tính năng đã có, tính năng hoãn, dịch vụ miễn phí dùng đến và các giới hạn còn tồn tại.

## Phạm vi chưa triển khai

Từ điển hai chiều hoàn chỉnh, dịch máy, đánh giá phát âm, bài viết có chấm ngữ pháp, cá nhân hóa sâu, hệ thống thưởng đầy đủ và đồng bộ hai chiều sẽ được chia thành các nhiệm vụ tiếp theo sau khi nền tảng hoạt động.
