# Gamification Engine

## Cài đặt và nguồn dữ liệu

Áp dụng migration `20261106_07` bằng `alembic upgrade head`. PostgreSQL là nguồn sự thật cho XP, cấp độ, nhiệm vụ, huy hiệu và lượt đổi thưởng. Mobile chỉ gửi câu trả lời bài học hoặc yêu cầu đổi một phần thưởng theo ID; **không có endpoint nhận số XP từ client**. Backend phải dùng kết nối cơ sở dữ liệu có quyền ghi các bảng hệ thống. Không đưa chuỗi kết nối này vào Expo.

## Quy tắc tính điểm

- Mỗi lần hoàn thành bài học lần đầu, backend lấy `lessons.xp_reward`, nhân với `gamification_config.lesson_multiplier_percent` rồi chia nguyên cho 100. Mặc định hệ số 100%. Chơi lại không nhận thêm XP của bài đó.
- Một nhiệm vụ ngày mặc định yêu cầu hoàn thành 1 bài mới và cho 5 XP. Một nhiệm vụ tuần yêu cầu 3 bài mới và cho 15 XP. Cửa sổ tính theo UTC: ngày bắt đầu lúc 00:00, tuần bắt đầu thứ Hai. Tiến độ được đếm từ `learning_progress.completed_at`. Không có cơ chế trừ điểm hay mất chuỗi ngày học.
- Cấp độ mặc định `floor(total_xp / 100) + 1`; bước 100 được cấu hình trong `gamification_config.level_xp_step`. `user_levels` lưu kết quả sau mỗi lần cấp XP; `xp_events` là sổ cái để kiểm tra. Khi đổi cấu hình cấp độ sau khi đã có người học, cần một migration tính lại `user_levels`. Hệ số XP mới chỉ áp dụng cho các lượt hoàn thành sau khi đổi.
- Quy tắc huy hiệu nằm trong `badge_rules`: số bài đã hoàn thành hoặc tổng XP tối thiểu. Seed có First step, Pathfinder và Rising star.
- XP trọn đời dùng để tính cấp độ. XP khả dụng để đổi thưởng bằng XP trọn đời trừ tổng `reward_claims.xp_cost`. Đổi thưởng không làm giảm cấp độ. Điều kiện đổi gồm phần thưởng còn hoạt động, đủ cấp độ, đủ XP khả dụng và chưa đổi trước đó.

Quản trị viên có thể chỉnh quy tắc trong PostgreSQL bằng migration hoặc thao tác quản trị có kiểm soát; mobile không có quyền sửa. `quests.reward_xp`, `target_lessons`, `reward_items.xp_cost`, `required_level` đều được lưu trong cơ sở dữ liệu. Tránh sửa quy tắc của nhiệm vụ đang diễn ra vì lượt đã nhận thưởng giữ giá trị tại thời điểm nhận.

## Giao dịch và chống trùng

Nộp bài lấy khóa giao dịch theo người dùng. Kết quả quiz, tiến độ, sự kiện XP, lượt hoàn thành nhiệm vụ, cấp độ, huy hiệu và thông báo được ghi cùng một giao dịch. `lesson_attempts.request_id` cho phép gửi lại yêu cầu khi mạng lỗi và trả đúng kết quả cũ. `xp_events` duy nhất theo `(user_id, source_type, source_id)`; `quest_claims` duy nhất theo `(user_id, quest_id, period_start)`; `user_badges` và `reward_claims` cũng có ràng buộc duy nhất. Đổi thưởng lấy cùng khóa giao dịch theo người dùng, kiểm tra lại số dư và điều kiện trên server. Yêu cầu đổi lại cùng phần thưởng trả về lượt đổi trước, không trừ XP lần hai.

Thông báo nằm trong `reward_notifications` và chỉ xuất hiện trong ứng dụng. Chưa có push notification. Chuyển động XP và thông báo trên mobile tôn trọng cài đặt giảm chuyển động của hệ điều hành.

## API

Các endpoint cần Supabase Bearer token:

| Endpoint | Chức năng |
| --- | --- |
| `GET /api/v1/gamification` | XP, cấp độ, XP khả dụng, nhiệm vụ, huy hiệu, phần thưởng, thống kê học tập. |
| `POST /api/v1/gamification/rewards/{id}/claim` | Kiểm tra điều kiện và đổi thưởng; gửi lại an toàn. |
| `GET /api/v1/gamification/notifications` | 50 thông báo mới nhất của chính người học. |
| `POST /api/v1/gamification/notifications/{id}/read` | Đánh dấu đã đọc, chỉ với thông báo của chủ sở hữu. |

`POST /api/v1/lessons/{id}/submit` trả thêm `rewards` và `earned_xp`. Trường `earned_xp` là XP bài học; `rewards` gồm cả nhiệm vụ, cấp độ và huy hiệu mới. `GET /api/v1/journey/summary` trả `xp_for_next_level` để giao diện không tự đoán bước cấp độ.

## Kiểm thử

Trên PostgreSQL **tạm** đã có Auth fixture, migration và seed:

```powershell
$env:ENGLIFY_TEST_DATABASE_URL = 'postgresql+psycopg://USER@127.0.0.1:PORT/TEST_DB'
.\.venv\Scripts\python.exe -m pytest backend/tests -q
psql -v ON_ERROR_STOP=1 -d 'postgresql://USER@127.0.0.1:PORT/TEST_DB' -f backend/tests/sql/rls_and_constraints.sql
```

Fixture `backend/tests/fixtures/supabase_auth_stub.sql` chỉ dành cho cơ sở dữ liệu kiểm thử. Kiểm thử tích hợp xác nhận hoàn thành cả unit, nhiệm vụ ngày/tuần, huy hiệu, cấp độ, gửi bài/đổi thưởng trùng, cô lập hai người dùng và giữ tiến độ qua phiên API mới.
