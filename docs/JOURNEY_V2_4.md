# Journey V2.4 – Checkpoint, Mastery và Smart Review

V2.4 tái sử dụng lesson quiz và XP ledger hiện hữu. Checkpoint chỉ khả dụng khi mọi lesson bắt buộc trong Unit đã hoàn thành; cấu hình và việc chấm đều ở PostgreSQL. Mỗi attempt chụp question IDs, content version, score, threshold và objective result. Request ID và ledger XP ngăn thưởng trùng khi retry/replay.

Thuật toán mastery phiên bản 1 dùng evidence checkpoint: fail → `practicing`, pass → `proficient`, hai lần pass với lần mới đạt ít nhất 90% → `mastered`. Lesson completion riêng lẻ không tạo mastery. Fail tạo objective review stage 0, đến hạn sau 10 phút; lịch success dự kiến tái sử dụng 1/3/7/14/30 ngày của Arena Mistake Review.

Ngưỡng V2.4 ban đầu được giới hạn 70% để giữ nguyên transaction grading/XP đã được kiểm chứng. Không cho lưu threshold khác cho đến migration thuật toán version tiếp theo; tránh trường hợp UI báo fail nhưng engine cũ đã mở khóa/thưởng XP. Người dùng lịch sử không bị relock, lesson đã completed/mastered vẫn được ưu tiên bởi `englify_lesson_state`.

Các bảng attempt, mastery và review bật RLS theo `auth.uid()`. Client không gửi score/pass, không đọc answer key và không sửa config. Admin config chỉ được ghi khi `englify_is_admin()`.
