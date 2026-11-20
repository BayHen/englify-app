# Journey V2.1 – Learning Map, Chapter và Progression

## Audit và phạm vi

Trước V2.1, Journey đã có course, unit, lesson, năm trạng thái bài học, chấm quiz server-side, offline package, attempts, XP, quests và badges. Unlock dựa vào bài đứng ngay trước trong course. V2.1 tái sử dụng toàn bộ engine này; không tạo lesson engine hoặc XP balance mới.

V2.1 bổ sung chapter, CEFR metadata, prerequisite tường minh, progress bắt buộc, Continue Learning và checkpoint foundation. Adaptive mastery và curriculum-management toàn diện không thuộc task này.

## Compatibility

- Giữ nguyên mọi course/unit/lesson ID, attempts, `learning_progress` và `xp_events`.
- Migration chuyển quy tắc tuần tự hiện tại thành prerequisite tường minh theo thứ tự course/unit/lesson.
- Unit cũ chưa map chapter xuất hiện trong `Existing learning path`; ID chapter được suy ra ổn định từ course ID.
- RPC vẫn trả `units` cho mobile cũ, đồng thời trả hierarchy mới trong `chapters`.
- Completed/mastered/in-progress đã lưu được ưu tiên trước prerequisite, vì vậy không relock lịch sử.

## Quy tắc mở khóa

Một bài published có trạng thái `available` khi tất cả prerequisite của nó đã `completed` hoặc `mastered`. Bài không có prerequisite là entry point. Quan hệ phải cùng course, không tự tham chiếu và không tạo cycle. Client không được ghi unlock; `englify_start_lesson`, detail và submit đều gọi trạng thái server.

Locked node vẫn có thể chạm để xem danh sách prerequisite nhưng không điều hướng vào lesson.

## Progress và Continue Learning

Unit progress chỉ đếm lesson published, `is_required=true`. Lesson optional không nằm trong tử số/mẫu số. Chapter hiển thị các unit đã publish theo thứ tự ổn định. Phần trăm này là tiến độ curriculum, không phải chứng nhận CEFR.

Continue Learning chọn theo thứ tự xác định:

1. Bài `in_progress`.
2. Lesson thường `available` sớm nhất.
3. Checkpoint `available`.
4. Bài completed/mastered sớm nhất để review khi không còn nội dung mới.

## Checkpoint

Checkpoint là lesson có `lesson_kind='checkpoint'`, gắn trực tiếp với unit và tái sử dụng question/answer/attempt/XP hiện tại. V2.1 cố định passing criteria ở 70%. Retry được phép; unique XP event `(user, source_type, source_id)` bảo đảm chỉ lần pass đầu nhận XP.

## Admin

Content Studio hiện có thêm chapter, CEFR course, chapter assignment của unit, required flag, estimated duration và lesson/checkpoint kind. RPC `englify_admin_set_journey_prerequisites` thay toàn bộ prerequisite của một lesson trong transaction, chạy cycle guard và ghi audit log. Learner không có quyền mutation curriculum.

## Migration và RPC

- Migration: `20261119010000_journey_v2_1_foundation.sql`.
- RPC thay đổi tương thích: `englify_journey`, `englify_lesson_state`, `englify_lesson_detail`, `englify_submit_lesson`.
- RPC nội bộ mới: `englify_journey_lesson_node`.
- RPC admin mới: `englify_admin_set_journey_prerequisites`.

Không triển khai migration này lên production trong task V2.1 nếu chưa có phê duyệt riêng.

## Kiểm thử

`journey_v2_1_smoke.sql` kiểm tra ordering/hierarchy, first unlock, prerequisite completion, cycle, missing parent, optional progress, checkpoint retry, XP idempotency, historical completion và quyền learner. CI chạy smoke này sau toàn bộ migration.

Các gate repository vẫn gồm mobile typecheck/lint/test, shared typecheck, Admin lint/test/build và kiểm tra React Native Web runtime.

## Triển khai

1. Backup và restore-test database đích.
2. Chạy migration trên clone có dữ liệu lịch sử.
3. Chạy `supabase db lint --level error` và `journey_v2_1_smoke.sql`.
4. Deploy mobile tương thích sau khi migration đã có trên remote.
5. Smoke Journey bằng learner cũ và learner mới; đối soát XP/attempt trước và sau.
6. Không rollback bằng cách xóa bảng/cột. Nếu cần, rollback app và forward-fix schema additive.

## Giới hạn V2.1

- Chưa có adaptive mastery hoặc checkpoint rule theo từng unit ngoài ngưỡng 70%.
- Chưa tự suy luận chapter cho nội dung cũ.
- Chưa có drag-and-drop curriculum editor; Admin dùng form allowlist và RPC prerequisite.
- Phần trăm progress dùng active published curriculum version; enrollment snapshot theo từng learner dành cho phiên bản sau.
