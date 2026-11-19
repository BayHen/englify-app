# Audit Quiz Arena V2.5 — Question Management

## Hiện trạng có thể tái sử dụng

- Admin là Next.js App Router dạng client dashboard, xác thực bằng Supabase Auth và kiểm tra `englify_is_admin()` ở cả client adapter lẫn RPC.
- `arena_questions` và `arena_answer_keys` là nguồn câu hỏi Arena hiện hành. Sáu loại câu hỏi, CEFR A1–C1, độ khó 1–3 và chín topic đã có ràng buộc PostgreSQL.
- `englify_arena_publish_guard` đã kiểm tra cấu trúc đáp án theo từng loại; `englify_arena_key_guard` ngăn sửa key của câu đang phát hành.
- Practice, Time Attack và Ranked chụp nguyên câu hỏi, key và giải thích vào `arena_session_questions` khi bắt đầu. Vì vậy phiên đang chạy và lịch sử hoàn tất không phụ thuộc nội dung ngân hàng sau đó.
- Mistake Review lưu snapshot riêng trong `quiz_mistake_progress`; Journey dùng bảng `quiz_questions` riêng và không cần hợp nhất.
- `admin_members`, `englify_is_admin`, `admin_audit_logs` và các RPC security-definer hiện có đủ cho một vai trò Admin duy nhất. V2.5 cho phép self-review/self-approval và ghi rõ actor; không tạo role system giả.
- Gemini hiện chạy trong Supabase Edge Functions, khóa chỉ ở server, có allowlist model Free tier, timeout, quota và kiểm tra JSON. Có thể tái sử dụng mẫu này, không gọi provider từ browser.
- Admin đã có import/review cho Real English và adapter `supabaseAdminRequest`; V2.5 nên là module riêng thay vì ép Arena vào generic Journey CRUD.

## Khoảng trống

- `arena_questions` mới có cờ `is_published`, chưa có lifecycle `draft/in_review/published/archived`, revision hay provenance.
- Chưa có API danh sách lọc/phân trang chuyên biệt, duplicate detection, import batch, AI review queue, topic metadata, reports hoặc analytics gộp bốn mode.
- Việc chỉnh câu đã phát hành hiện yêu cầu unpublish và sửa cùng row. Snapshot bảo vệ lịch sử nhưng chưa có revision/audit rõ ràng.
- CSV/XLSX chưa có parser Question Bank. Repository chưa có dependency `.xlsx`.
- Learner chưa có RPC report câu hỏi và chưa gắn report với revision.

## Quyết định triển khai

- Giữ `arena_questions`/`arena_answer_keys`; bổ sung lifecycle và bảng revision, không tạo question bank song song.
- Mỗi mutation nội dung đi qua RPC giao dịch, tạo immutable revision và audit. Câu đã published khi sửa trở về draft; session snapshot cũ không đổi.
- Topic là bảng metadata tham chiếu slug hiện hữu; CEFR vẫn là enum-check A1–C1, không tạo bảng CEFR.
- Import luôn stage/preview trước, commit các row được chọn thành draft, idempotent theo request và hash nội dung.
- AI chỉ tạo batch draft `pending_review`; validation/duplicate detection dùng cùng hàm deterministic với CRUD/import. Không tự publish.
- Analytics lấy attempt ledger thật. Ngưỡng thống kê chỉ là cờ hỗ trợ review, không tự archive/xóa.
- Report chỉ nhận cho revision đã published, chống trùng theo user/revision/reason và không lộ reporter cho response Admin mặc định.
