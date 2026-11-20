# Journey V2.3 – Bài học tương tác có cấu trúc

## Audit và phạm vi

Engine cũ đã có `lesson_items` dạng reading/tip, quiz chấm phía PostgreSQL, attempt bất biến, offline content hash và ledger XP idempotent. V2.3 giữ nguyên toàn bộ cấu trúc này, bổ sung revision/block tương thích và không triển khai checkpoint/mastery nâng cao của V2.4.

## Content block và version

`journey_lesson_revisions` giữ phiên bản draft/published/retired; mỗi lesson chỉ có một revision published. `journey_lesson_blocks` hỗ trợ introduction, objective, theory, example, vocabulary, grammar, dialogue, audio, practice và summary. Payload là JSON được kiểm tra theo loại, không nhận trường `html`. Migration tạo revision `legacy` từ reading/tip hiện hữu mà không xóa dữ liệu cũ.

Content version tải offline bao gồm lesson, revision, blocks, questions và options nhưng không chứa answer key. Attempt mới chụp `revision_id`; thay nội dung sau này không sửa attempt lịch sử. Admin chỉ được publish draft có block hợp lệ qua `englify_admin_publish_lesson_revision`; AI content phải dùng `source=ai_draft` và vẫn cần publish thủ công.

## Player và âm thanh

Player hiển thị từng block, tiến độ, Previous/Next, chuyển English-only/Việt ngữ, dialogue, vocabulary, note và bookmark. Expo Speech đọc text tiếng Anh bằng giọng thiết bị; UI gọi rõ đây là “device voice”, không nhận là bản thu người bản xứ. Nội dung chữ luôn là fallback khi audio không có.

## Resume, ghi chú và bảo mật

Resume lưu revision/block/answer draft theo `(user_id, lesson_id)` và không tương đương completion. Notes/bookmarks là dữ liệu riêng tư, chỉ đọc qua RLS theo `auth.uid()` và chỉ ghi qua RPC kiểm tra lesson/block published. Các thao tác này không tạo XP.

## Feedback

Hint curated chỉ hiển thị khi người học yêu cầu. Sau khi submit, wrapper trả review từng câu từ attempt đã được server chấm, gồm learner answer, correct answer và explanation; answer key không xuất hiện trước submission.

## Giới hạn

V2.3 chưa tự sinh lesson bằng Gemini trong mobile. Hạ tầng revision hỗ trợ `ai_draft`, nhưng Edge Function/Admin form tạo draft cần hoàn thiện trước khi bật; tuyệt đối không publish tự động. Audio URL curated chưa có player streaming riêng, nên hiện dùng Expo Speech và text fallback.
