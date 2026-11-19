# Audit Quiz Arena V2.4 — Mistake Review và spaced repetition

Ngày rà soát: 2026-11-18. Báo cáo phản ánh mã trong workspace, không suy ra đã deploy.

## Nguồn lịch sử có thể dùng

- Journey ghi từng đáp án trong lesson_answer_attempts, liên kết lesson_attempts để lấy owner và quiz_questions/quiz_answer_keys để lấy nội dung/key. Lịch sử đủ cho đúng/sai và answer thực; explanation nằm trên quiz question nhưng không bảo đảm luôn là tiếng Việt.
- Practice không có bảng answer event riêng nhưng session completed lưu result.review chứa snapshot question, given answer, correct answer, correct flag và explanation_vi. Có thể backfill và ingest sau completion mà không sửa lịch sử.
- Time Attack và Ranked có bảng answer event riêng, FK về arena_session_questions snapshot; đủ owner, thời gian, answer, correctness và explanation_vi.
- Arena Question Bank có explanation_vi bắt buộc, vì vậy ba mode Arena có giải thích tiếng Việt đã biên tập. Journey chỉ trả explanation hiện có và phải ghi rõ khi nội dung chưa có bản Việt; V2.4 không tự gọi Gemini.
- Vocabulary review đã có scheduler riêng cho thẻ từ. Có thể tái sử dụng nguyên tắc UTC, algorithm version và request UUID, nhưng không gộp tiến độ câu quiz vào saved_vocabulary.

## Khoảng trống

- Chưa có hàng tiến độ duy nhất theo user/câu hỏi, review event ledger, review session, mastery state hoặc next review time cho quiz.
- Chưa có projection thống nhất giữa Journey question và Arena question.
- Chưa có thống kê attempt/error theo topic/CEFR/kind hoặc recommendation dựa trên tỷ lệ lỗi.
- Practice completion cần hook ingest từ result JSON; không thể giả định có answer rows.
- UI hiện chỉ review trong từng attempt/game đã kết thúc, chưa có dashboard xuyên mode.

## Quyết định

- Tạo progress riêng theo khóa user + question_source + question_id. Mỗi incorrect attempt vẫn có ledger nguồn riêng; progress chỉ là projection hiện hành, không thay lịch sử.
- Snapshot câu hỏi/key/explanation tại lúc ingest để review không phụ thuộc content bị sửa hoặc archive. Key không cấp SELECT và chỉ xuất sau submit review.
- Backfill chỉ từ persisted attempts thực; trigger/RPC completion ingest cho dữ liệu tương lai. Không tạo mistake giả.
- SRS version 1 dùng UTC và stage 0–5: thành công lần lượt 1, 3, 7, 14, 30 ngày; sai đưa về stage 0 và due sau 10 phút. Mastered cần stage 5, không thể đạt sau một lần.
- Analytics dùng attempt ledger thật. Chỉ gọi topic yếu khi có ít nhất 5 attempts; recommendation giải thích bằng due count hoặc error rate. Không dùng Gemini.
- Review không cấp XP, không đổi Journey completion, Arena score, rating, leaderboard hoặc season standings.
