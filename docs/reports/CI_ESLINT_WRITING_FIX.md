# Sửa ESLint và CI Daily Writing — 18/11/2026

## Thay đổi

- `.vscode/settings.json`: dùng flat config, chỉ validate JavaScript/TypeScript và chọn thư mục làm việc của mobile/admin. README không còn nằm trong danh sách validate của ESLint.
- `supabase/tests/writing_v2_3_smoke.sql`: chuẩn bị câu trả lời theo bài thực tế được giao. Bài có answer key dùng đáp án seed; bài mở dùng nội dung đạt min_words. Việc đọc answer key diễn ra bằng database owner trong transaction test; RPC vẫn được gọi với role authenticated.
- Không thay đổi migration, quy tắc chấm điểm, XP hoặc quyền truy cập của ứng dụng.

## Nguyên nhân

Daily selector chọn bài dựa trên user và ngày. A1 có cả bài mở và bài yêu cầu đáp án chính xác. Đoạn văn cố định trước đây có thể hợp lệ với bài mở nhưng sai với fill_blank, sentence_order hoặc sentence có answer key. Vì vậy smoke test có thể pass vào một ngày và fail vào ngày khác.

## Kiểm tra thực tế

- Tái hiện trước sửa: Third consecutive Daily Writing completion failed.
- PASS: cả 7 SQL transaction smoke test trong workflow CI.
- PASS: chạy smoke test với lần lượt cả 14 bài A1 seed được gán cho learner ở bước kiểm tra ngày thứ ba; các thay đổi fixture đều rollback.
- PASS: concurrent Daily Writing reward và concurrent Admin retry.
- PASS: Supabase database lint, mobile lint, admin lint và git diff --check.
- FAIL do môi trường local: bộ Auth/RLS/publishing integration dừng tại Edge study-plan read, HTTP 503, name resolution failed. Chưa xác nhận toàn bộ bộ integration pass.
- NOT TESTED: extension VS Code sau khi reload và workflow chạy lại trên GitHub Actions.

## Cách kiểm tra lại

Trong VS Code chạy `ESLint: Restart ESLint Server`, mở README và một file TSX ở mỗi ứng dụng, kiểm tra ESLint Output. Sau khi đưa bản sửa lên GitHub, chạy lại CI.

Chạy SQL smoke test với Supabase local đang hoạt động:

```powershell
.\.venv\Scripts\python.exe scripts/run_local_sql_test.py supabase/tests/security_definer_privileges_smoke.sql supabase/tests/admin_atomic_crud_smoke.sql supabase/tests/phase2_learning_content_smoke.sql supabase/tests/writing_ai_v2_smoke.sql supabase/tests/writing_v2_2_smoke.sql supabase/tests/writing_v2_3_smoke.sql supabase/tests/writing_v2_4_smoke.sql
```
