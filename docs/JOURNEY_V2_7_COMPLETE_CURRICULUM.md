# Journey V2.7 — Curriculum dựng sẵn Level 1–10

## Kiến trúc và phạm vi

Phần mở rộng này tái sử dụng nguyên kiến trúc Journey hiện có: `courses` là Level,
`journey_chapters` là Chapter, `learning_units` là Unit, `lessons` cùng revision/block
là nội dung học, còn `quiz_questions` và `journey_checkpoint_configs` đảm nhiệm chấm
bài phía máy chủ. Không có curriculum engine thứ hai.

Curriculum dùng version 2 và stable UUID. Seed chỉ thêm bản ghi còn thiếu bằng
`ON CONFLICT DO NOTHING`; không sửa revision đã xuất bản, tiến độ, attempt, XP, quest
hay achievement của người học.

## Kết quả local đã xác minh

| Thành phần | Số lượng |
| --- | ---: |
| Level | 10 |
| Chapter | 30 |
| Unit | 60 |
| Lesson thường | 180 |
| Unit Checkpoint | 60 |
| Level Final Assessment | 10 |
| Level 10 Capstone | 1 |

Mỗi Level có 3 Chapter, mỗi Chapter có 2 Unit và mỗi Unit có 3 Lesson cùng một
checkpoint. Mỗi lesson có introduction, objective, theory, vocabulary, example,
summary, revision xuất bản và ba câu hỏi có giải thích song ngữ. Checkpoint có sáu
câu hỏi; final assessment phủ sáu Unit; Capstone có nội dung tích hợp và chín câu hỏi.

CEFR chỉ là hướng dẫn giáo dục: Level 1–2 A1, Level 3–4 A2, Level 5–6 B1,
Level 7–8 B2, Level 9–10 dùng C1 làm mức nội dung nội bộ. UI phải hiển thị nhãn
`Advanced Integrated Practice` cho Level 10 và không mô tả đây là chứng chỉ.

## Tiến trình và bảo toàn dữ liệu

Level 1 mở cho người học mới. Bảng `journey_course_prerequisites` khóa Level 2–10;
Level kế tiếp chỉ mở sau khi final assessment của Level trước có trạng thái
`completed` hoặc `mastered` trong `learning_progress`. Kiểm tra nằm trong
`englify_lesson_state`, vì vậy client không thể tự bỏ khóa.

Checkpoint tiếp tục dùng `englify_submit_checkpoint`, ngưỡng 70% và snapshot câu
hỏi phía server. Final assessment/Capstone dùng luồng submit lesson có answer key và
prerequisite phía server. Stable request ID và milestone constraint hiện có ngăn cấp
XP lặp.

## Seed và kiểm tra chất lượng

- Nguồn blueprint/compiler: `scripts/build_journey_v27_curriculum.py`.
- Artifact SQL: `supabase/seeds/journey_v27_curriculum.sql`.
- Seed local được khai báo cuối `db.seed.sql_paths` trong `supabase/config.toml`.
- RPC `englify_admin_journey_curriculum_quality()` trả số lượng theo Level, nội dung
  thiếu, prompt trùng và trạng thái sẵn sàng về cấu trúc.
- Admin Curriculum Builder hiển thị bảng completeness 3/3, 6/6, 18/18, 6/6, 1/1
  cùng lỗi validation nếu có.

Tạo lại artifact sau khi sửa blueprint:

```powershell
python scripts/build_journey_v27_curriculum.py
python scripts/test_build_journey_v27_curriculum.py
npx.cmd supabase db reset
python scripts/run_local_sql_test.py supabase/tests/journey_v2_7_complete_curriculum_smoke.sql
```

## Nội dung cũ được giữ lại

Course mẫu `Everyday English` và toàn bộ learner history cũ không bị di chuyển hoặc
ghi đè. Các chủ đề tương thích như greeting, daily routine và travel được đưa vào
blueprint mới, nhưng bản ghi cũ không bị gắn lại vào version 2 vì việc đó có thể đổi
ý nghĩa progress đã tồn tại.

## Giới hạn và review còn lại

Artifact hiện đạt validation cấu trúc, quan hệ, answer key và khả năng chạy lại.
Trước khi xuất bản production, biên tập viên vẫn phải review ngôn ngữ toàn bộ 180
lesson, đặc biệt nghĩa tiếng Việt theo ngữ cảnh, độ tự nhiên của distractor, độ phân
hóa Level 8–10 và độ đa dạng dạng bài. Bộ deterministic seed ưu tiên dữ liệu an toàn,
có thể chơi và kiểm thử được; không thay thế bước editorial QA chuyên sâu.

Chưa kiểm thử Android/iOS thiết bị thật và chưa chạy browser runtime cho thay đổi
Admin trong lượt này. Không có migration hay curriculum nào của extension này được
đẩy lên production.

## Triển khai

1. Review và phê duyệt nội dung trên staging.
2. Chạy toàn bộ SQL smoke test, admin lint/build, mobile lint/typecheck/test.
3. Chạy gate production bắt buộc nếu bản release có thay đổi RPC Supabase.
4. Chỉ `db push` migration `20261119063000` sau khi có ủy quyền riêng.
5. Seed curriculum production trong batch có giám sát; không dùng `db reset` và không
   ghi đè curriculum đã xuất bản.

