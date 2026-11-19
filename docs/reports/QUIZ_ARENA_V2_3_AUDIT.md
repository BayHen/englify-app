# Audit Quiz Arena V2.3 — Ranked, leaderboard và season

Ngày rà soát: 2026-11-18. Báo cáo phản ánh mã trong workspace, không suy ra trạng thái đã deploy.

## Phần đã có và có thể tái sử dụng

- V2.1 có Question Bank A1–C1, sáu dạng câu, snapshot bất biến theo session, key riêng tư, grading phía PostgreSQL, Practice history và reward XP giới hạn theo ngày.
- V2.2 có server clock, deadline, one-question-at-a-time, request UUID chống gửi trùng, advisory/row lock, combo/speed scoring và review chỉ sau khi server nhận đáp án.
- `profiles` cung cấp `display_name`; leaderboard chỉ cần tên hiển thị và không cần email, điện thoại hay lịch sử học riêng tư. `avatar_url` hiện là đường dẫn storage riêng tư, chưa có cờ đồng ý công khai nên V2.3 không trả avatar.
- Arena Rating phải là hệ riêng. `user_levels`/`xp_events` không phù hợp và không được dùng làm rating.
- Hạ tầng reward hiện hữu gồm `badges` và `user_badges` với unique `(user_id, badge_id)`, phù hợp để cấp huy hiệu season. Cần ledger riêng theo season/tier để chứng minh idempotency.
- Admin dùng Supabase Auth, `admin_members`, `englify_is_admin()` và `admin_audit_logs`; không cần FastAPI hay auth thứ hai.
- Mobile dùng Expo SDK 58, Expo Router, Supabase client và token giao diện hiện hữu. Route chỉ chứa adapter; API/state/UI nằm trong feature learning.

## Khoảng trống trước V2.3

- Chưa có ranked ruleset, season lifecycle, match/rating history, weekly/season leaderboard hoặc snapshot standings.
- Chưa có mô hình rating bất đồng bộ; Time Attack score/PB không thể dùng thay rating.
- Chưa có quyền admin quản lý season/rules/reward và chưa có màn quản trị Arena.
- Chưa có privacy projection cho leaderboard. RLS `profiles` chỉ cho owner đọc, vì vậy leaderboard phải đi qua RPC `SECURITY DEFINER` trả trường tối thiểu.
- Chưa có security metadata/audit cho ranked match đáng ngờ.

## Quyết định triển khai

- Ranked là mode thứ ba, dùng snapshot/grader chung nhưng có bảng match/answer/rating riêng và ruleset được ghim theo match.
- Ruleset đầu tiên chuẩn hóa Normal: 10 câu, 120 giây, 3 lives, base 100, cùng công thức điểm V2.2. Mọi người trong một leaderboard dùng cùng `ruleset_version` của season.
- Rating khởi tạo 1000, tính hoàn toàn phía server bằng công thức hiệu suất công khai, giới hạn thay đổi ±30. Abandon chịu mức giảm cố định; retry/finalize không thể ghi rating lần hai.
- Weekly dùng tổng ba score tốt nhất trong tuần UTC; season dùng tổng ba score tốt nhất toàn season. Tie-break theo tổng correct/tổng question của ba trận, thời điểm đạt tổng rồi khóa nội bộ ổn định. UUID không được trả ra cho người khác.
- Season có `scheduled → active → closing → finalized`; chỉ một season active. Match mới chỉ vào active season; match đã bắt đầu được nộp tới deadline của chính match, kể cả season vừa chuyển `closing`, nhưng không sau khi season finalized.
- Finalization chụp standings bất biến và cấp badge qua ledger unique. Không cấp XP trong V2.3.
- Heuristic chỉ gắn cờ để admin rà soát, không tự ban. Tín hiệu gồm tốc độ phi thực tế, abandon lặp và tiến triển rating bất thường.

## Rủi ro và giới hạn cần kiểm thử

- Ranked bất đồng bộ không phải Elo đối đầu và không thể ngăn trợ giúp ngoài ứng dụng/người chơi đã biết bank.
- Server-observed elapsed gồm network/queue; không phải phép đo phản xạ tuyệt đối.
- Cần test transaction đồng thời, replay, cross-user/RLS, season transition, leaderboard tie/pagination, reward idempotency và hồi quy Practice/Time Attack/Journey/XP.
- Cần kiểm tra Web Console/LogBox sau render và thao tác; bundle thành công không chứng minh hết lỗi text node.
