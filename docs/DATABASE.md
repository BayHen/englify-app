# Kiến trúc PostgreSQL – TASK 03.1

PostgreSQL là nguồn dữ liệu chính. Migration `20261106_01` tạo 19 bảng ứng dụng trong `public`, không tạo bảng xác thực. Supabase quản lý `auth.users`; `profiles.id` tham chiếu trực tiếp khóa chính này với `ON DELETE CASCADE`. Trigger `on_auth_user_created` tạo profile mặc định khi Auth thêm người dùng và migration bổ sung profile còn thiếu cho người dùng đã tồn tại. Chỉ sao chép `display_name` đã giới hạn 80 ký tự từ metadata; không lấy vai trò hoặc quyền từ metadata do người dùng nhập.

Migration `20261106_02` thêm `learning_goal`, `initial_proficiency` và `onboarding_completed_at` vào `user_preferences`. Dữ liệu cũ giữ nguyên; lựa chọn onboarding được ghi bằng một transaction ở endpoint riêng tư.

Migration `20261106_03` bổ sung IPA và nguồn/giấy phép cho từ điển, cùng chỉ mục tìm kiếm tiền tố. Chi tiết hợp đồng dữ liệu và nguồn seed ở `docs/DICTIONARY.md`.

## Sơ đồ quan hệ

```mermaid
erDiagram
    AUTH_USERS ||--|| PROFILES : "id"
    PROFILES ||--o| USER_PREFERENCES : "user_id"
    PROFILES ||--o{ LEARNING_PROGRESS : "user_id"
    PROFILES ||--o{ LEARNING_PLANS : "user_id"
    PROFILES ||--o{ SAVED_VOCABULARY : "user_id"
    PROFILES ||--o{ REVIEW_HISTORY : "user_id"
    PROFILES ||--o{ QUIZ_ATTEMPTS : "user_id"
    PROFILES ||--o{ SPEAKING_ATTEMPTS : "user_id"
    PROFILES ||--o{ WRITING_SUBMISSIONS : "user_id"
    DICTIONARY_ENTRIES ||--o{ SAVED_VOCABULARY : "entry_id"
    SAVED_VOCABULARY ||--o{ REVIEW_HISTORY : "saved_vocabulary_id, user_id"
    COURSES ||--o{ LESSONS : "course_id"
    LESSONS ||--o{ QUIZ_QUESTIONS : "lesson_id"
    LESSONS ||--o{ LEARNING_PROGRESS : "lesson_id"
    LESSONS ||--o{ SPEAKING_ATTEMPTS : "lesson_id"
    LESSONS ||--o{ WRITING_SUBMISSIONS : "lesson_id"
    QUIZ_QUESTIONS ||--o{ QUIZ_OPTIONS : "question_id"
    QUIZ_QUESTIONS ||--o{ QUIZ_ATTEMPTS : "question_id"
    QUIZ_OPTIONS ||--o{ QUIZ_ATTEMPTS : "selected_option_id, question_id"
```

```mermaid
erDiagram
    PROFILES ||--o{ XP_EVENTS : "user_id"
    PROFILES ||--o{ USER_BADGES : "user_id"
    BADGES ||--o{ USER_BADGES : "badge_id"
    PROFILES ||--o{ REWARD_CLAIMS : "user_id"
    REWARD_ITEMS ||--o{ REWARD_CLAIMS : "reward_id"
```

`AUTH_USERS` trong sơ đồ là bảng **do Supabase Auth quản lý**, không thuộc migration. Mọi bảng ứng dụng có khóa chính UUID. Bảng nội dung dùng UUID mặc định `gen_random_uuid()`, còn `profiles.id` lấy UUID từ Auth. Các bảng có `created_at`; bảng có thể sửa có thêm `updated_at` tự cập nhật bằng trigger. Thời gian lưu bằng `timestamptz` (UTC ở tầng ứng dụng).

## Ràng buộc và chỉ mục

- Từ điển có `(language, normalized_term)` duy nhất; khóa học có `slug` duy nhất. Bài học có `(course_id, slug)` và `(course_id, position)` duy nhất; câu hỏi và đáp án có thứ tự duy nhất trong cha. Chỉ một đáp án đúng cho mỗi câu hỏi được bảo đảm bằng partial unique index; quy trình biên tập phải bảo đảm có ít nhất một đáp án đúng trước khi phát hành.
- Tiến độ có `(user_id, lesson_id)` duy nhất và trạng thái hoàn thành phải khớp `completed_at`. Mỗi người có tối đa một kế hoạch `active`. Từ đã lưu có `(user_id, entry_id)` duy nhất. FK ghép `(saved_vocabulary_id, user_id)` ngăn lịch sử ôn tập trỏ sang từ của người khác; FK ghép ở quiz ngăn chọn đáp án của câu hỏi khác.
- `xp_events` là sổ cái XP, duy nhất theo `(user_id, source_type, source_id)` để chống cộng trùng từ cùng một nguồn. Chỉ backend tin cậy được ghi tiến độ, kết quả quiz, XP, huy hiệu và lượt đổi thưởng. Đổi thưởng trong tương lai phải khóa hàng/balance và ghi `reward_claims` cùng bút toán XP trong **một giao dịch**; schema chưa triển khai nghiệp vụ đổi thưởng.
- Chỉ mục bao phủ tra cứu từ, bài học theo khóa học/thứ tự, tiến độ theo người học/trạng thái, từ đến hạn ôn, lịch sử mới nhất và hoạt động gần đây. FK không nằm đầu một chỉ mục ghép được bổ sung chỉ mục riêng khi cần truy vấn từ phía bản ghi cha.

## Quyền và RLS

RLS được bật trên cả 19 bảng. `anon` không được cấp quyền bảng. `authenticated` chỉ đọc nội dung được công bố và hàng cá nhân có `auth.uid() = user_id` (riêng profile so theo `id`). Người dùng có thể tự ghi `user_preferences` và `saved_vocabulary`; policy kiểm tra chủ sở hữu ở cả `USING` lẫn `WITH CHECK`. Không cấp quyền ghi trực tiếp cho các bảng tính điểm, tiến độ, bài nói/viết hay nội dung học. `quiz_options` không mở cho client vì có `is_correct`; API sau này phải trả lựa chọn đã bỏ cột đáp án và kiểm tra câu trả lời ở server.

Backend dùng kết nối đặc quyền phải kiểm tra danh tính và quyền ở tầng API, vì role chủ sở hữu/service role có thể bỏ qua RLS. Không đưa service key hoặc chuỗi kết nối vào ứng dụng Expo. Các chính sách tham chiếu `(select auth.uid())` và các cột chủ sở hữu có chỉ mục phù hợp.

## Migration và seed

Yêu cầu PostgreSQL 15+ với Supabase Auth schema/roles đã có. Migration không chạy trên PostgreSQL thuần khi thiếu `auth.users`, `auth.uid()`, `anon`, `authenticated`. Đặt `ENGLIFY_DATABASE_URL` trong `.env` cục bộ, không commit giá trị thật. Từ thư mục gốc:

```powershell
.\.venv\Scripts\python.exe -m alembic -c backend/alembic.ini upgrade head
psql -v ON_ERROR_STOP=1 -d "$env:ENGLIFY_PSQL_URL" -f backend/seeds/development.sql
```

`ENGLIFY_PSQL_URL` là URL PostgreSQL thuần (`postgresql://...`), không dùng URL SQLAlchemy có `+psycopg`. Có thể đặt `PG*` environment variables hoặc dùng Supabase SQL editor để nạp seed. Seed chỉ chứa nội dung học mẫu và chạy lại được; không tạo Auth user hoặc tiến độ giả. File seed bọc trong `BEGIN`/`COMMIT`.

Kiểm thử RLS ở PostgreSQL cục bộ dùng fixture **chỉ cho test** `backend/tests/fixtures/supabase_auth_stub.sql` trên database tạm, sau đó chạy migration, seed, và `backend/tests/sql/rls_and_constraints.sql`. Không chạy fixture này trên Supabase thật. Bài test kiểm tra tạo profile, quyền `anon`, cô lập hai người dùng, ghi sai chủ sở hữu, quyền ghi XP/progress, FK ghép và uniqueness. Không dùng tài khoản hoặc bí mật thật.

## Giới hạn hiện tại

Backend chưa có endpoint dữ liệu hoặc model ORM cho các bảng mới; migration SQL là nguồn schema hiện hành. Vì vậy Alembic tạm tắt `autogenerate` để metadata rỗng không đề xuất xóa bảng. Khi xây API, thêm mapping SQLAlchemy đầy đủ rồi bật lại autogenerate và kiểm tra giao dịch/ủy quyền ở endpoint. Docker Compose hiện cung cấp PostgreSQL thuần cho nền tảng backend; để chạy migration này cần môi trường Supabase hoặc fixture Auth dành riêng cho test như trên. Đừng áp dụng fixture test vào database phát triển lâu dài.
