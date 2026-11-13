# Writing trên Supabase

Mobile có thể dùng `englify_submit_writing`, `englify_writing_history` và bảng `writing_exercises` với Supabase Auth. Bài viết gốc và feedback nằm ở hai bảng riêng. RPC kiểm tra đáp án câu có cấu trúc bằng quy tắc cố định; đoạn văn chỉ nhận gợi ý tự xem lại, không có điểm số giả. `request_id` chống nộp trùng. RLS ngăn đọc lịch sử người khác.

Khi người học bật kiểm tra ngữ pháp, bài viết được lưu trước với trạng thái `unavailable`; Edge Function `writing-grammar` mới gửi nội dung tới LanguageTool **tự lưu trữ** nếu đã cấu hình `LANGUAGETOOL_URL`. Edge kiểm tra JWT và quyền sở hữu, dùng service role trong Edge Secrets để gắn feedback; khóa này không xuất hiện trong mobile. Nếu Function hoặc LanguageTool lỗi, bài viết và phản hồi quy tắc vẫn tồn tại. Người học phải chủ động bật kiểm tra ngữ pháp trước khi nội dung được gửi đến LanguageTool.

Migration nguồn: `supabase/migrations/20261110160000_writing_rpc.sql`; database hiện hữu qua Alembic revision `20261110_22`. Kiểm thử local từ database trống, hai tài khoản tạm, bài có cấu trúc/đoạn văn, lưu lịch sử, chống lặp, chặn đọc chéo và chặn client tự gắn grammar đã PASS. Edge runtime thật trả `unavailable` khi thiếu LanguageTool. **Chưa kiểm thử LanguageTool thật hoặc Writing trên thiết bị.**

Mobile hiện dùng trực tiếp bảng và RPC Writing trên Supabase; không còn cờ chuyển về FastAPI. Edge Function `writing-grammar` chỉ là phần kiểm tra ngữ pháp tùy chọn: nếu Function hoặc LanguageTool chưa khả dụng, việc tải bài tập, chấm theo quy tắc và lưu lịch sử vẫn hoạt động. Sau khi đổi cấu hình, chạy `npx.cmd expo start --tunnel --clear` từ `apps/mobile`. Đặt `EDGE_ALLOWED_ORIGINS` thành danh sách origin Expo Web thực tế nếu dùng Web; ứng dụng native không gửi Origin.
