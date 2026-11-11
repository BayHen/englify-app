# Journey và quiz trên Supabase

## Luồng dữ liệu

Mobile gọi RPC `englify_journey`, `englify_journey_summary`, `englify_lesson_detail`, `englify_start_lesson` và `englify_submit_lesson` bằng phiên Supabase Auth. Mỗi RPC kiểm tra `auth.uid()`. Bảng tiến độ, lượt làm bài và XP chỉ cho phép học viên đọc dữ liệu của mình qua RLS; client không được ghi trực tiếp. Nội dung bài tải ngoại tuyến gồm câu hỏi và lựa chọn, không gồm `quiz_answer_keys` hoặc cờ `is_correct`.

Một lần nộp dùng UUID `request_id`. RPC khóa theo người dùng, chấm trên server, ghi kết quả và tiến độ, thưởng XP/quest/badge trong cùng giao dịch. Gửi lại cùng UUID trả kết quả cũ; gửi UUID đó cho bài khác trả HTTP 409. Bản nội dung ngoại tuyến cũ trả HTTP 409 để ứng dụng yêu cầu tải lại. XP chỉ cấp cho lần vượt qua bài đầu tiên; học lại vẫn lưu lịch sử.

## Migration và kiểm tra

- SQL nguồn: `supabase/migrations/20261110140000_journey_read_rpc.sql` và `20261110150000_journey_submit_rpc.sql`.
- Database đang dùng: Alembic bridge revision `20261110_20` và `20261110_21`, đã xác nhận revision 21. Không chạy lại baseline trên database hiện hữu.
- Cục bộ: `npx.cmd supabase db reset --network-id englify-local-test-20261110`, rồi `.\.venv\Scripts\python.exe scripts\supabase_local_integration.py`. Script chỉ chạy với Supabase local loopback, tạo và xóa hai tài khoản thử nghiệm. Đã kiểm tra hoàn thành cả unit, đủ các dạng câu hỏi, khóa bài, bản ngoại tuyến cũ, request lặp, XP và RLS.
- Kiểm tra mobile: `npm.cmd run check` từ gốc. TypeScript, lint và 82 unit tests đã đạt. Expo Web render/Console và iOS/Android thật chưa được kiểm tra.

## Giới hạn

Quy tắc chấm hiện giữ ngưỡng 70% của FastAPI cũ. Bản tải offline hiện có trên thiết bị được tạo bằng hàm băm Python cũ có thể bị báo hết hạn; tải lại bài một lần để dùng dấu vân tay nội dung từ RPC mới. Edge `study-plan` chưa deploy nên kế hoạch học mặc định vẫn dùng FastAPI. Writing và Admin cũng chưa port; không xóa `backend/` ở giai đoạn này.
