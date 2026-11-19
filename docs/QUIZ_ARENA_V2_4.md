# Quiz Arena V2.4 — Mistake Review, SRS và Smart Recommendations

## Phạm vi

V2.4 tổng hợp các câu trả lời sai đã được lưu thật từ bốn luồng: Journey, Practice, Time Attack và Ranked. Hệ thống không suy đoán lịch sử và không tạo dữ liệu mẫu cho người học. Audit nguồn dữ liệu và quyết định mapping nằm tại `docs/reports/QUIZ_ARENA_V2_4_AUDIT.md`.

Mobile có route `/mistakes` cho dashboard và `/mistake-review/[id]` cho phiên ôn. Dashboard hiển thị số câu đến hạn, trạng thái mastery, kho lỗi, giải thích tiếng Việt, điểm yếu có ngưỡng mẫu tối thiểu và gợi ý có lý do. Nút Practice trong gợi ý chỉ mở Quiz Arena; người học vẫn chủ động chọn cấu hình.

## Dữ liệu và bảo mật

- `quiz_answer_facts` là ledger lượt trả lời thật, duy nhất theo mode/attempt/question.
- `quiz_mistake_progress` lưu snapshot câu hỏi và key riêng tư theo user/question.
- `quiz_review_sessions`, `quiz_review_session_items`, `quiz_review_events` giữ lựa chọn ổn định và request UUID chống chấm lặp; dữ liệu con cascade khi tài khoản bị xóa.
- RLS cô lập theo `auth.uid()`. Client không có quyền đọc ledger, session items hay answer key và không có quyền ghi mastery.
- RPC review chỉ trả câu hỏi hiện tại đã bỏ `answer_key`; đáp án đúng chỉ xuất hiện trong review sau khi phiên hoàn tất.
- Gemini không được gọi tự động. V2.4 ưu tiên explanation đã biên tập và recommendation xác định từ dữ liệu thật.

## Thuật toán SRS phiên bản 1

Stage thành công lần lượt hẹn lại sau 1, 3, 7, 14 và 30 ngày. Trả lời sai đưa về stage 0 và hẹn sau 10 phút. Trạng thái được suy ra xác định: `needs_review` (0), `learning` (1–2), `improving` (3–4), `mastered` (5). Một lỗi mới ở câu đã mastered đưa câu về `needs_review`. Mọi mốc dùng `timestamptz`/UTC từ server.

Review không cấp XP, không thay đổi Practice reward, Time Attack score/combo, Ranked score/rating hay leaderboard.

## Kiểm tra cục bộ

```powershell
npm.cmd run typecheck -w apps/mobile
npm.cmd run lint -w apps/mobile
npm.cmd run test -w apps/mobile
.\.venv\Scripts\python.exe scripts/run_local_sql_test.py supabase/tests/quiz_mistake_review_smoke.sql
npx.cmd supabase db lint --local --level error
```

Sau thay đổi mobile phải mở `/mistakes` và một `/mistake-review/<id>` trên React Native Web, thao tác chọn/trả lời và kiểm tra Console không có `Unexpected text node`.

## Triển khai

Không có migration production nào được chạy trong task này. Quy trình dự kiến sau backup và review: áp dụng migration theo thứ tự, deploy mobile, rồi theo dõi lỗi RPC/RLS. Không nạp seed development lên production. Rollback ứng dụng nên tắt entry V2.4 trước; không xóa ledger hoặc lịch sử review khi chưa có kế hoạch bảo toàn dữ liệu.
