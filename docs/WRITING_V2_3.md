# Writing V2.3 — Daily Writing Challenge, XP và streak

## Audit trước triển khai

- Writing V2.1 đã có submission, feedback, AI Coach, AI Rewrite, revision, quota và RLS.
- Writing V2.2 đã có cấp độ Writing A1–C1 độc lập, 10 chủ đề, 7 dạng bài và ít nhất 50 bài phát triển.
- `xp_events` là sổ cái XP hiện hành, có khóa duy nhất `(user_id, source_type, source_id)` và đã hỗ trợ `source_type='writing'`.
- `user_levels`, `reward_notifications`, `badges` và `user_badges` được tái sử dụng. Không tạo hệ thống XP hoặc achievement thứ hai.
- Quest hiện tại đếm lesson theo UTC; dự án chưa có Writing streak hoặc timezone IANA. Vì vậy Daily Writing có lịch riêng nhưng không thay đổi quy tắc quest/global gamification cũ.

## Thiết kế dữ liệu

Migration `20261117030000_writing_daily_challenges.sql` bổ sung:

- `writing_daily_settings`: bật/tắt tính năng và XP A1–C1 cho assignment tương lai.
- `writing_daily_assignments`: liên kết người học với bài Writing đã xuất bản theo ngày cục bộ. Nội dung bài không bị sao chép.
- `writing_daily_completions`: liên kết chính xác assignment, submission, người học và ngày hoàn thành.
- `writing_milestone_rules`: chỉ chứa điều kiện Writing; định nghĩa badge và award vẫn dùng `badges`/`user_badges` hiện có.
- `user_preferences.writing_timezone`, timezone chờ và thời điểm có hiệu lực.

Khóa unique bảo đảm mỗi người có tối đa một assignment/ngày, một completion/assignment, một completion/ngày và một XP event cho assignment. Lịch sử Writing, XP và reward cũ không bị sửa hoặc xóa.

## Chọn thử thách

`englify_writing_daily_overview()` sử dụng giờ PostgreSQL, không nhận ngày từ mobile. Lựa chọn có thứ tự xác định:

1. Bài đã xuất bản, chưa lưu trữ và chủ đề khả dụng.
2. Ưu tiên đúng `writing_cefr_level`; nếu cấp đó không có bài, chọn cấp gần nhất.
3. Tránh bài của ngày trước và bài đã hoàn thành trong bảy ngày gần đây khi có lựa chọn khác.
4. Dùng hash ổn định của user, ngày và exercise để phá hòa.

Assignment đã tạo không đổi khi refresh hoặc khi người học đổi CEFR trong ngày. Cấp độ mới áp dụng cho assignment kế tiếp. Nếu không có bài đã xuất bản, API trả `challenge=null`, không lộ draft. Nếu Admin thu hồi bài đang được gán, assignment ID không bị thay thế nhưng nội dung chuyển thành unavailable và không thể nộp.

## Timezone và ngày mới

- Mặc định: `Asia/Ho_Chi_Minh`.
- Chấp nhận tên trong `pg_timezone_names`, ví dụ `UTC`, `Asia/Tokyo`, `Europe/London`, `America/New_York`.
- Timestamp được lưu UTC; `challenge_date` là ngày lịch trong timezone đã ghim trên assignment.
- Lần cấu hình đầu có hiệu lực ngay nếu chưa có assignment.
- Sau assignment đầu tiên, thay đổi timezone chỉ có hiệu lực từ nửa đêm kế tiếp của timezone hiện tại. Cơ chế này ngăn đổi liên tục múi giờ để nhận nhiều reward trong cùng ngày cũ.
- Trigger chặn client sửa trực tiếp ba cột timezone; phải dùng `englify_set_writing_timezone`.
- PostgreSQL xử lý DST qua cơ sở dữ liệu IANA. Mobile không gửi ngày hoặc thời gian authoritative, nên đổi đồng hồ thiết bị không tạo reward.

## Hoàn thành và XP

RPC `englify_submit_daily_writing` chạy trong một transaction và khóa theo user:

1. Xác minh assignment thuộc user và còn đúng ngày.
2. Gọi validation Writing hiện có để lưu submission/feedback.
3. Bài có answer key chỉ hoàn thành khi `rule_result=matched`.
4. Bài mở phải đạt `min_words`; `recommended_words` vẫn chỉ là hướng dẫn.
5. Ghi completion, XP event, reward notification và `user_levels`.
6. Kiểm tra milestone rồi ghi `user_badges` idempotent.

Mức XP được ghim khi assignment được tạo: A1 10, A2 15, B1 20, B2 25, C1 30. Mức này tương đương hoặc thấp hơn phần lớn lesson mẫu 20–30 XP và chỉ nhận một lần mỗi ngày. Client không gửi XP. Revision, AI Coach, AI Rewrite và grammar provider không cấp XP.

## Writing streak và calendar

- Streak dùng chính `challenge_date` của completion.
- Nhiều submission cùng ngày không tăng streak.
- Ngày liên tiếp tăng `current_streak`; ngày bị bỏ lỡ tạo khoảng ngắt nhưng không xóa lịch sử.
- Nếu hôm qua đã hoàn thành và hôm nay chưa hoàn thành, streak vẫn hiển thị active cho đến hết hôm nay.
- `longest_streak` và `total_completed_days` được tính từ completion ledger.
- Calendar trả completed, missed, today, future hoặc unavailable; tương lai không bao giờ bị đánh dấu missed.

Milestone hiện có: First Step, Three-Day Writer, Weekly Writer, Consistent Writer, Writing Champion và Dedicated Writer. Không có bonus XP lớn; milestone chỉ dùng badge/notification hiện hành.

## Mobile và lỗi mạng

Route `/writing` giữ nguyên thư viện CEFR, chủ đề, lịch sử, AI Coach và AI Rewrite. Phần đầu trang hiển thị thử thách hôm nay, streak, calendar, milestones và timezone. Draft nằm trong state nên không bị xóa khi request submit thất bại trong phiên hiện tại. Chỉ phản hồi server mới hiển thị completion/XP; retry dùng request UUID và ràng buộc database để không thưởng trùng.

Challenge đã tải vẫn hiển thị nếu một lần refresh sau đó lỗi nhưng màn hình chưa bị đóng. Cold-start offline chưa có cache SQLite chuyên dụng; ứng dụng không cấp XP hoặc đánh dấu hoàn thành ngoại tuyến. Đây là giới hạn có chủ ý để không tạo kiến trúc đồng bộ thứ hai.

## Bảo mật và RLS

- Người học chỉ đọc assignment/completion của mình; không có quyền insert/update/delete hai ledger.
- Completion RPC đối chiếu assignment–exercise–submission; arbitrary exercise không thể hoàn thành challenge khác.
- XP dùng `source_type='writing'` và `source_id=assignment_id`; unique constraint là hàng rào cuối chống duplicate.
- Timezone, ngày, streak, completion và milestone đều do server tính.
- Admin mới được cập nhật `writing_daily_settings`; thay đổi chỉ ảnh hưởng assignment mới, không sửa reward lịch sử.
- Không có service-role key hoặc database secret trong Expo.

## Kiểm tra local

```powershell
npx.cmd supabase db reset
npx.cmd supabase db lint --level error
.\.venv\Scripts\python.exe scripts\run_local_sql_test.py supabase\tests\security_definer_privileges_smoke.sql supabase\tests\writing_ai_v2_smoke.sql supabase\tests\writing_v2_2_smoke.sql supabase\tests\writing_v2_3_smoke.sql
.\.venv\Scripts\python.exe scripts\supabase_writing_daily_concurrency.py
.\.venv\Scripts\python.exe scripts\supabase_local_integration.py
npm.cmd run typecheck -w apps/mobile
npm.cmd run lint -w apps/mobile
npm.cmd test -w apps/mobile
npm.cmd run lint -w apps/admin
npm.cmd test -w apps/admin
npm.cmd run build -w apps/admin
```

## Kết quả xác minh ngày 17/11/2026

- PASS — reset database local từ trống, seed V2.2 và migration V2.3.
- PASS — database lint, security smoke và Writing V2.1/V2.2/V2.3 smoke.
- PASS — timezone Việt Nam, UTC và DST New York; assignment ổn định; level/timezone change; no-content fallback; RLS; invalid input; retry; streak; milestone; revision không thưởng XP.
- PASS — hai request completion đồng thời chỉ tạo một completion và một XP event.
- PASS — full Supabase Auth/RLS/integration regression.
- PASS — mobile typecheck, lint và 176 test trong 46 file.
- PASS — Admin lint, 6 test và production build.
- PASS — Expo Web export và SSR `/writing` trả HTTP 200.
- NOT TESTED — browser Console/LogBox: công cụ browser không khởi tạo được do `helper_unknown_error`. Cần mở `/writing`, submit/retry và xác nhận không có `Unexpected text node`.
- NOT TESTED — thiết bị Android/iOS vật lý, production Supabase và cold-start offline.

## Triển khai

Không có migration nào được áp lên production trong task này. Trước khi triển khai:

1. Backup và đối chiếu migration history của Supabase project.
2. Áp riêng V2.1, V2.2 và `20261117030000_writing_daily_challenges.sql` trên staging/local trước.
3. Chạy toàn bộ smoke/concurrency test.
4. Deploy hai Writing AI Function chỉ nếu V2.1 chưa có và đã cấu hình secret hợp lệ.
5. Mở Expo bằng `npx.cmd expo start --tunnel --clear`, đăng nhập hai tài khoản test và kiểm tra assignment, completion, retry, XP và RLS.

Các thay đổi trên production chỉ được thực hiện khi có ủy quyền rõ ràng.
