# Báo cáo kiểm chứng Phase 07 — Luyện nói và luyện viết

Ngày kiểm tra: 07/11/2026. Phạm vi: TASK 07.1 và TASK 07.2. Việc đóng gói Expo trên Windows chỉ xác nhận mã có thể bundle; không thay thế thử nghiệm âm thanh trên thiết bị.

## Trạng thái theo task

| Task | Trạng thái | Bằng chứng và phần còn thiếu |
| --- | --- | --- |
| 07.1 Luyện nói miễn phí | **NOT TESTED** | Mã có TTS, chọn giọng, xin quyền microphone khi ghi, phát lại, xóa bản ghi, lưu số buổi theo tài khoản và không gửi audio lên API. Unit test chống đếm trùng đạt; TypeScript, lint và Expo export Android/iOS/web đạt. Chưa thử microphone, loa, quyền bị từ chối và vòng đời nền/tiền cảnh trên thiết bị Android/iOS thật. |
| 07.2 Luyện viết miễn phí | **NOT TESTED** | Bốn dạng bài, quy tắc kiểm tra, API riêng tư, lịch sử PostgreSQL, migration, seed, RLS và trường hợp LanguageTool lỗi đã được kiểm thử bằng pytest; 31 bài backend đạt. Chưa chạy một LanguageTool tự lưu trữ thực hoặc xác nhận luồng UI đăng nhập và nộp bài thủ công trên thiết bị. |

Hai task chưa được đánh dấu PASS vì các bước kiểm tra runtime nêu trên còn thiếu. LanguageTool là tùy chọn; khi không cấu hình, API trả `grammar_status=unavailable` và vẫn lưu phản hồi quy tắc. Trạng thái này không được diễn giải thành kiểm tra ngữ pháp thành công.

## Tính năng và kiến trúc đã rà soát

- Speaking dùng `SpeechProvider` với Expo Speech và Expo Audio; bản ghi Android/iOS ở bộ nhớ riêng của ứng dụng. Web chỉ giữ blob âm thanh trong phiên; số buổi nằm trong localStorage. Số buổi hoàn thành do người học tự xác nhận, không phải điểm phát âm.
- Writing dùng `GET /api/v1/writing/exercises`, `POST /api/v1/writing/submit`, `GET /api/v1/writing/history` và `GET /api/v1/writing/history/{id}`. Đáp án cấu trúc được kiểm tra ở backend; đoạn văn chỉ nhận gợi ý tự rà soát. `request_id` và chỉ mục duy nhất chống nộp trùng.
- Migration `20261107_10` tách bài tập, đáp án và phản hồi khỏi bản nộp gốc. Bảng đáp án không cấp quyền SELECT cho vai trò `authenticated`; RLS trên phản hồi kiểm tra chủ sở hữu qua bản nộp. Tài liệu [luyện nói](../SPEAKING_PRACTICE.md), [luyện viết](../WRITING_PRACTICE.md) và [database](../DATABASE.md) đã mô tả cách chạy và giới hạn.
- Expo SDK 58: `npx.cmd expo install --check` trả **Dependencies are up to date**. Không thêm dịch vụ trả phí.

## Lỗi phát hiện và sửa

Màn hình Speaking trước đây giữ `history` của tài khoản vừa dùng trong lúc tải dữ liệu tài khoản mới. Điều này có thể tạm hiển thị số buổi hoặc đường dẫn audio cũ. Đã sửa `SpeakingScreen` để remount phần phiên luyện nói theo ID tài khoản; state cũ được hủy khi đổi tài khoản. Sau sửa, TypeScript, lint, Vitest và Expo export đều đạt.

## Kết quả kiểm tra

| Kiểm tra | Kết quả |
| --- | --- |
| `python -m pytest backend/tests -q` với PostgreSQL test đã migrate và seed | **PASS:** 31 bài; 1 cảnh báo deprecation của Starlette TestClient |
| `python -m ruff check backend` | **PASS** |
| `npm.cmd run typecheck -w @englify/mobile` | **PASS** |
| `npm.cmd run lint -w @englify/mobile` | **PASS** sau sửa lỗi chuyển tài khoản |
| `npm.cmd test -w @englify/mobile` | **PASS:** 29 bài trong 12 tệp |
| `npx.cmd expo install --check` trong `apps/mobile` | **PASS:** dependency phù hợp SDK hiện tại |
| `npx.cmd expo export --platform all` | **PASS:** bundle Android, iOS, web |
| Microphone, TTS, playback trên Android/iOS vật lý | **NOT TESTED:** không có thiết bị trong môi trường kiểm tra |
| LanguageTool server thật | **NOT TESTED:** chưa cấu hình server; hợp đồng HTTP được kiểm tra bằng mock transport |

Migration `20261107_10` và 4 bài viết mẫu đã áp dụng trên database phát triển trong TASK 07.2; bài kiểm thử tích hợp chạy trên PostgreSQL dùng riêng cho test. Không dùng database người học làm test fixture.

## Bảo mật và giới hạn

- Audio Speaking không được upload; có nút xóa tệp. Dữ liệu luyện nói ở thiết bị không đồng bộ sang thiết bị khác. Nội dung Speaking là mẫu, không có đánh giá phát âm.
- Writing chỉ gửi văn bản đến LanguageTool khi người học bật grammar check; URL được cấu hình ở backend. LanguageTool có thể đưa gợi ý sai hoặc bỏ sót lỗi; không có điểm bài luận. Chưa xác minh bảo mật hoặc chất lượng của một triển khai LanguageTool cụ thể.
- Phản hồi Writing được lưu riêng với nội dung gốc; API yêu cầu JWT và lọc theo user ID. Bài test đã xác nhận người dùng khác không đọc được lịch sử/phản hồi qua API và RLS. Nội dung đã lưu trong PostgreSQL giữ nguyên qua logout/login về mặt lưu trữ; chưa thử thủ công luồng đăng nhập lại trên thiết bị.
- `writing_submissions.feedback` cũ vẫn tồn tại để không phá dữ liệu trước đây. Màn hình mới liệt kê bản nộp có `exercise_id`; dữ liệu cũ chưa được chuyển sang lịch sử mới.

## Tệp liên quan

- Speaking: `apps/mobile/src/features/speaking/*`, `apps/mobile/src/app/speaking.tsx`, `apps/mobile/app.json`.
- Writing: `apps/mobile/src/features/writing/*`, `apps/mobile/src/app/writing.tsx`, `backend/app/api/writing.py`, `backend/app/writing/*`, `backend/migrations/versions/20261107_10_writing_practice.py`, `backend/seeds/load_writing.py`, `backend/seeds/writing_development.sql`, `backend/tests/test_writing_*.py`.
- Cấu hình và tài liệu: `backend/app/core/config.py`, `backend/app/main.py`, `.env.example`, `docs/SPEAKING_PRACTICE.md`, `docs/WRITING_PRACTICE.md`, `docs/DATABASE.md`, báo cáo này.

## Bước xác minh tiếp theo

1. Trên Android hoặc iPhone có Expo Go tương thích SDK 58: chạy `npm.cmd start -- --clear` từ thư mục gốc; đăng nhập, mở Speaking, nghe câu mẫu, từ chối rồi cấp quyền microphone, ghi trên 1 giây, phát lại, ghi lại, xóa, đưa ứng dụng ra nền khi đang ghi và mở lại. Kiểm tra trạng thái sau khi đổi tài khoản.
2. Trên web hoặc thiết bị có API và database phát triển: mở Writing, làm cả bốn dạng bài, tải lại/đăng xuất rồi đăng nhập và xem lịch sử. Dùng hai tài khoản để kiểm tra không xem được bài của nhau.
3. Nếu cần grammar check thực: chạy LanguageTool tự lưu trữ theo `docs/WRITING_PRACTICE.md`, cấu hình `ENGLIFY_LANGUAGETOOL_URL`, khởi động lại FastAPI, bật Grammar check và nộp câu có lỗi; xác nhận `grammar_status=available` cùng gợi ý thật. Dừng server rồi nộp bài khác để xác nhận `unavailable` và lịch sử vẫn lưu.
