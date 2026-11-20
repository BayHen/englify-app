# Journey V2.7 – Audit, hardening và trạng thái phát hành

## Kết luận

Journey V2.1–V2.6 dùng một luồng dữ liệu thống nhất: curriculum published → lesson/checkpoint transaction → progress/attempt snapshot → XP ledger/quest/badge/milestone. Không có ví XP, checkpoint engine hoặc hệ thống Admin thứ hai.

Trạng thái dự kiến sau kiểm thử tự động: **READY WITH LIMITATIONS**. Không có P0 đã biết; kiểm thử thiết bị Android/iOS, authenticated browser flow và Gemini provider thật vẫn phải được thực hiện trước release candidate cuối.

## Kết quả audit

| Module | Trạng thái | Bằng chứng | Giới hạn |
| --- | --- | --- | --- |
| V2.1 Progression | COMPLETE | prerequisite cycle guard, Journey state RPC, smoke V2.1 | Chưa test đa thiết bị thật |
| V2.2 Personalization | PARTIAL | placement server scoring, persisted preferences, smoke V2.2 | Placement nội bộ không phải chứng nhận CEFR |
| V2.3 Lesson Player | PARTIAL | immutable revision, resume, answer transaction, mobile unit tests | Audio/network interruption chưa test thiết bị |
| V2.4 Checkpoint | COMPLETE backend | server grading, request idempotency, immutable attempt snapshot | UI thiết bị thật chưa test |
| V2.5 Gamification | PARTIAL | single XP ledger, unique reward sources, RLS/smoke | Learning streak dùng ngày UTC |
| V2.6 Admin | COMPLETE backend/static UI | CRUD, review/publish, import, AI draft, audit, smoke | Authenticated browser/Gemini thật chưa test |

## Lỗi đã sửa trong V2.7

- Import khai báo hỗ trợ block nhưng commit bỏ qua: commit nay tạo draft revision và block, hoặc rollback toàn transaction nếu thiếu parent.
- AI có thể sinh `practice` block không có question/answer revision: loại block này bị từ chối ở generator; practice phải tạo qua question editor hiện hữu.
- AI provider failure để job kẹt `processing`: Edge Function nay cập nhật `failed` nhưng giữ nguyên lỗi gốc.
- Learner có thể INSERT report trực tiếp, bỏ qua published revision validation: thu hồi table INSERT; chỉ RPC được ghi.
- Security regression mở rộng để chặn direct write vào progress, attempt, checkpoint, milestone, quest, badge và report.

## Quy tắc bảo mật

- Mọi RPC `SECURITY DEFINER` có `search_path=''`; PUBLIC không có EXECUTE.
- Client không được ghi XP, progress, attempt, quest claim, badge hoặc checkpoint result.
- Draft curriculum chỉ Admin đọc/ghi; learner chỉ nhận curriculum published qua RPC.
- Gemini key và service role chỉ tồn tại trong Edge Secrets; mobile/Admin bundle không chứa secret.

## Kiểm thử còn lại

1. Android/iOS thật: Journey map, resume, audio, checkpoint, offline/reconnect.
2. Expo Web có session learner: kiểm tra Console/LogBox, đặc biệt lỗi text node dưới `View`.
3. Admin Web có session Admin: CSV/XLSX preview, review/publish và version history.
4. Gemini production: tạo một draft bằng Admin thật, kiểm tra quota/job/audit và xóa/archive draft theo quy trình Admin nếu không dùng.

## Triển khai

Migration V2.7 là `20261119062000_journey_v2_7_hardening.sql`, chỉ thay RPC/grant và không sửa dữ liệu người học. Chạy local reset/smoke trước, sau đó `supabase db push --remote --yes`, deploy lại `journey-lesson-generate`, rồi chạy production readiness gate. Không rollback bằng cách xóa progress/XP; nếu Edge Function lỗi, deploy lại phiên bản trước và giữ nguyên database.
