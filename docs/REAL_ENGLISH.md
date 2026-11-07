# Real English — nội dung và cách vận hành

Module `/real-english` giới thiệu tiếng Anh theo ngữ cảnh: slang, idiom, phrasal verb, cách nói thân mật, hội thoại thường ngày và cảnh thoại mang phong cách phim **được viết mới**. Mỗi mục có nghĩa tiếng Việt, giải thích ngữ cảnh, ví dụ song ngữ, mức độ trang trọng, ghi chú vùng miền, nguồn và thông tin quyền sử dụng. Các câu thoại không lấy từ kịch bản phim, không có video hoặc tệp âm thanh của bên thứ ba.

## Nguồn gốc và quyền sử dụng

Seed `backend/seeds/real_english_development.sql` chứa sáu mục và sáu câu hỏi do Englify Quest biên soạn cho mục đích giáo dục. `source_name = Englify Quest editorial`, `license_id = project-original`; `provenance_note` ghi rõ ví dụ và hội thoại gốc. Không có nguồn thứ ba cần ghi công trong seed này. Nhãn `project-original` mô tả nguồn gốc nội bộ, chưa phải giấy phép tái phân phối công khai. Nếu thêm nội dung ngoài dự án, người biên tập phải kiểm tra quyền sử dụng, ghi nguồn và điều kiện giấy phép trước khi xuất bản. Không sao chép lời thoại phim dài hoặc nhúng media không được cấp phép.

## Dữ liệu và API

Migration `20261107_09` thêm `real_english_expressions`, `real_english_quiz_questions`, `saved_expressions` và `real_english_quiz_attempts`. Từ `GET /api/v1/real-english` có thể tìm theo cụm tiếng Anh hoặc nghĩa tiếng Việt, lọc loại và danh sách đã lưu. `POST/DELETE /api/v1/real-english/{id}/save` lưu hoặc bỏ lưu cho tài khoản hiện tại. `GET /api/v1/real-english/{id}/quiz` trả câu hỏi và lựa chọn, không trả đáp án. `POST` cùng đường dẫn chấm đáp án ở backend; `request_id` bảo vệ thao tác nộp lặp. Bài quiz này chưa cấp XP.

Các bảng cá nhân chỉ đọc được bằng UID chủ sở hữu qua RLS; client không có quyền ghi trực tiếp. Bảng câu hỏi chứa đáp án không được cấp quyền `SELECT` cho role `authenticated`. Backend đọc đáp án bằng kết nối máy chủ và kiểm tra JWT trên mọi endpoint.

## Chạy phát triển

Từ thư mục gốc, sau khi cấu hình database và chạy migration:

```powershell
.\.venv\Scripts\python.exe -m alembic -c backend/alembic.ini upgrade head
.\.venv\Scripts\python.exe backend/seeds/load_real_english.py
.\.venv\Scripts\python.exe -m uvicorn app.main:app --app-dir backend --reload
npm.cmd start -- --clear
```

Lệnh seed đọc `ENGLIFY_DATABASE_URL` từ `.env` gốc và từ chối chạy nếu `ENGLIFY_ENVIRONMENT=production`. Cần cài backend theo README để module `app` có sẵn trong môi trường Python. Seed chỉ thêm nội dung, không tạo tài khoản. Có thể chạy lại seed; cùng `slug` hoặc `expression_id` sẽ cập nhật bản mẫu.

Trên mobile, nút nghe dùng TTS của thiết bị (`en-US`). Người học nghe và tự nói lại; ứng dụng hiện chưa ghi âm hoặc chấm phát âm. Đầu ra TTS phụ thuộc giọng có sẵn trên Android/iOS và có thể khác giữa các thiết bị. Kiểm tra tự động với PostgreSQL tạm xác nhận tìm kiếm, lưu riêng theo tài khoản, câu hỏi đúng/sai, nộp lặp và RLS; kiểm tra trên thiết bị thật cần thực hiện riêng.
