# Luyện viết tiếng Anh

## Chức năng

Màn hình `/writing` cung cấp bốn dạng bài: viết câu, điền từ, sắp xếp từ và viết đoạn văn. Các bài có cấu trúc được so với đáp án chấp nhận bằng quy tắc xác định (bỏ qua khác biệt chữ hoa, khoảng trắng và dấu câu cuối). Kết quả `matched` chỉ có nghĩa là trùng một đáp án mẫu, không đánh giá toàn diện chất lượng câu. Đoạn văn nhận gợi ý tự rà soát; hệ thống không chấm điểm bài luận hoặc khẳng định đã đánh giá năng lực viết.

API riêng tư gồm `GET /api/v1/writing/exercises`, `POST /api/v1/writing/submit`, `GET /api/v1/writing/history` và `GET /api/v1/writing/history/{id}`. `request_id` UUID giúp gửi lại cùng bài mà không tạo bản ghi trùng. Mọi endpoint yêu cầu JWT hợp lệ. Nội dung gốc được lưu trong `writing_submissions`, kết quả và gợi ý trong `writing_feedback`. Khóa đáp án nằm trong `writing_answer_keys`, không cấp quyền đọc trực tiếp cho vai trò `authenticated`. RLS giới hạn lịch sử và phản hồi theo chủ sở hữu. Bản ghi lịch sử tồn tại qua đăng xuất và đăng nhập lại.

## Cài đặt nội dung phát triển

Từ thư mục gốc, cấu hình `ENGLIFY_DATABASE_URL` trong `.env`, rồi chạy:

```powershell
.\.venv\Scripts\python.exe -m alembic -c backend/alembic.ini upgrade head
$env:PYTHONPATH='backend'; .\.venv\Scripts\python.exe -m backend.seeds.load_writing
```

Script seed chỉ chạy khi `ENGLIFY_ENVIRONMENT` không phải `production`. Bốn bài mẫu và đáp án là nội dung gốc của dự án; lệnh có thể chạy lại và không tạo người dùng mẫu.

## LanguageTool tùy chọn

LanguageTool chạy như một dịch vụ **tự lưu trữ**. Bản phát hành hiện hành cần Java 17; tải bản server từ nguồn chính thức, chạy HTTP server và kiểm tra `POST /v2/check` với `language=en-US` và `text`. Đặt `ENGLIFY_LANGUAGETOOL_URL` thành URL gốc của dịch vụ, ví dụ `http://127.0.0.1:8082`. Với máy chủ khác, dùng HTTPS và kiểm soát truy cập tại reverse proxy. FastAPI gọi server trong tối đa 4 giây. Không dùng public API cho yêu cầu tự động của ứng dụng vì [điều khoản public API](https://dev.languagetool.org/public-http-api.html) không cho phép trường hợp đó.

Người học phải bật **Grammar check** cho từng bài trước khi văn bản được gửi đến server LanguageTool đã cấu hình. Nếu server không được cấu hình, mất mạng hoặc trả lỗi, bài vẫn được lưu với phản hồi quy tắc và `grammar_status=unavailable`; không tạo gợi ý ngữ pháp giả. LanguageTool đưa ra gợi ý có thể sai hoặc bỏ sót lỗi, nhất là ý nghĩa, ngữ cảnh và cấu trúc đoạn văn. Người học cần tự xem lại; kết quả không phải điểm số.

Tham khảo: [hướng dẫn HTTP server](https://dev.languagetool.org/http-server), [tài liệu Java API và yêu cầu Java](https://github.com/languagetool-org/languagetool-org.github.io/blob/master/java-api.md), [mã nguồn và giấy phép LanguageTool](https://github.com/languagetool-org/languagetool). Dự án không đóng gói LanguageTool hoặc gửi bài đến dịch vụ bên thứ ba.

## Kiểm tra

Chạy `npm run typecheck -w @englify/mobile`, `npm run lint -w @englify/mobile`, `npm test -w @englify/mobile` và `python -m pytest backend/tests/test_writing_*.py`. Kiểm thử PostgreSQL tích hợp cần một database **dùng riêng cho test**, đã migration và nạp seed, được chỉ định qua `ENGLIFY_TEST_DATABASE_URL`; không trỏ biến này vào database chứa dữ liệu người dùng. Kiểm tra dịch vụ LanguageTool thật bằng cách bật grammar check, gửi bài và xác nhận `grammar_status=available`; nếu không có server, trạng thái này chưa được kiểm chứng trực tiếp.
