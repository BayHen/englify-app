# Writing V2.4 — tiến độ, phân tích và gợi ý cá nhân hóa

## Nguồn dữ liệu và nguyên tắc

Dashboard chỉ tổng hợp dữ liệu Writing đã lưu trong PostgreSQL. Bài gốc nằm ở `writing_submissions`; phản hồi rule-based ở `writing_feedback`; điểm và lỗi AI có cấu trúc ở `writing_ai_feedback`; bản viết lại và revision vẫn là dữ liệu riêng, không được tính thành bài luyện mới. XP và streak tiếp tục dùng ledger Daily Writing V2.3.

Không gọi Gemini để tính thống kê. Không suy luận lỗi ngữ pháp từ văn bản tự do. Nhóm lỗi chỉ đến từ trường `errors` có cấu trúc của bản AI feedback mới nhất cho mỗi submission. Điểm AI là hướng dẫn học tập, không phải điểm giáo viên. Xu hướng dưới ba mẫu được đánh dấu là chưa đủ tin cậy.

## Migration

`20261117040000_writing_analytics.sql` bổ sung snapshot CEFR, topic, loại bài và timezone vào submission để thay đổi nội dung sau này không làm sai lịch sử. Dữ liệu cũ được backfill khi exercise còn tồn tại; bản ghi thiếu nguồn được ghi rõ `analytics_metadata_source=unavailable`, không bị xóa hay gán dữ liệu giả.

Các index mới tối ưu truy vấn theo user, thời gian, CEFR/topic và AI feedback mới nhất. Trigger chỉ chụp metadata khi tạo submission; không sửa bài lịch sử.

## API an toàn

Các RPC sau đều `SECURITY DEFINER`, kiểm tra `auth.uid()`, đặt `search_path=''`, chỉ cấp quyền cho `authenticated` và trả dữ liệu của chính người dùng:

- `englify_writing_progress_summary`
- `englify_writing_activity_stats`
- `englify_writing_score_analytics`
- `englify_writing_mistake_summary`
- `englify_writing_cefr_progress`
- `englify_writing_topic_progress`
- `englify_writing_recommendations`
- `englify_writing_analytics_history`
- `englify_writing_analytics_detail`
- `englify_writing_report`

History giới hạn tối đa 30 bản ghi mỗi request; mobile dùng 5 bản ghi/trang. Khoảng thời gian chỉ nhận `7d`, `30d`, `90d`, `all`. Report chỉ nhận `weekly` hoặc `monthly`.

Một submission chỉ được tính là hoàn thành khi rule là `matched`, hoặc bài mở có `self_review` và đạt `min_words`. Bài `needs_revision` vẫn xuất hiện trong history để người học xem lại nhưng không làm tăng summary/progress. Rewrite và revision không tăng word count, completion, XP hoặc streak.

## Gợi ý cá nhân hóa

Gợi ý là rule engine giải thích được: ưu tiên bài chưa hoàn thành ở đúng Writing CEFR; xem tần suất luyện 7 ngày; dùng nhóm lỗi có cấu trúc gần đây; chỉ tăng độ khó khi có ít nhất ba điểm AI và trung bình đủ cao. Bài draft, archived, topic bị ẩn và bài đã hoàn thành đều bị loại. Mobile hiển thị lý do bằng tiếng Việt và chỉ điều hướng người học tới thư viện Writing.

## Mobile

Route `/writing-progress` có:

- summary card và khoảng thời gian 7/30/90 ngày hoặc toàn bộ;
- activity chart nhẹ bằng React Native View, không thêm thư viện chart;
- xu hướng điểm AI và nhãn độ tin cậy;
- tiến độ CEFR/topic, nhóm feedback, gợi ý tiếp theo;
- tổng kết tuần/tháng;
- history lọc theo trạng thái AI, 5 bài/trang.

Route `/writing-progress/[id]` hiển thị riêng original submission, rule feedback, AI guidance và revision history. Loading, empty và error state không dùng dữ liệu mẫu.

## Kiểm tra local

```powershell
npx.cmd supabase db reset
npx.cmd supabase db lint --level error
.\.venv\Scripts\python.exe scripts\run_local_sql_test.py supabase\tests\writing_v2_4_smoke.sql
npm.cmd run typecheck -w apps/mobile
npm.cmd run lint -w apps/mobile
npm.cmd test -w apps/mobile
```

Smoke test kiểm tra empty state, bài hợp lệ/không hợp lệ, latest AI feedback, nhóm lỗi, phân trang, report, tham số sai và cô lập hai tài khoản. Migration chưa được áp lên production trong task này.

## Giới hạn

- Thống kê cũ thiếu exercise snapshot vẫn được giữ nhưng có thể thiếu CEFR/topic.
- Không tạo “điểm tiến bộ” tổng hợp giả; UI trình bày từng chỉ số thực tế.
- Không có autosave hoặc thay đổi draft workflow (thuộc V2.5 nếu được yêu cầu sau).
- Thiết bị vật lý và Console/LogBox phải được kiểm tra thủ công nếu môi trường browser/device không khả dụng.

## Kết quả xác minh ngày 17/11/2026

- PASS — reset Supabase local từ database trống và áp toàn bộ migration đến V2.4.
- PASS — `supabase db lint --level error`.
- PASS — security smoke và Writing V2.1, V2.2, V2.3, V2.4 smoke.
- PASS — V2.4 smoke cho empty state, rule đủ/không đủ, latest AI score, mistake category, report, pagination và cross-user detail.
- PASS — mobile TypeScript, ESLint và 177 tests trong 46 files.
- PASS — Admin ESLint, 6 tests và production build.
- PASS — Expo Web export tạo bundle cho `/writing-progress` và dynamic detail route.
- PASS — full local Auth/RLS/integration regression. Hai lần đầu dừng ở `study-plan` HTTP 503 vì container `supabase_edge_runtime_englify-app` đang ở trạng thái stopped; sau khi khởi động lại đúng container, toàn bộ suite PASS.
- NOT TESTED — render và thao tác route trong browser: công cụ browser của phiên này không khởi tạo do Windows sandbox `helper_unknown_error`/kernel exit. Cần mở `/writing-progress`, đổi tất cả filter, mở detail và kiểm tra Console không có `Unexpected text node`.
- NOT TESTED — Android/iOS vật lý và production Supabase. Không có migration nào được deploy production trong task này.
