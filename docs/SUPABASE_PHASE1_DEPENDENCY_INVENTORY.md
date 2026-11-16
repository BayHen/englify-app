# Inventory phụ thuộc FastAPI — Phase 1

Ngày kiểm tra: 15/11/2026. Inventory này phân biệt **mã thay thế đã có**, **bản đã triển khai** và **luồng đang được ứng dụng sử dụng**. Không xóa `backend/` ở trạng thái hiện tại.

## Consumer đang hoạt động

| Consumer | FastAPI cũ | Thay thế Supabase | Trạng thái triển khai/kiểm thử | Kết luận |
| --- | --- | --- | --- | --- |
| Mobile Learning Plan | `/api/v1/learning-plan*` qua `features/plan/api.ts` khi cờ tắt | Edge `study-plan` + RPC migration `20261110120000` | Function `study-plan` không có trong danh sách Edge production ngày 15/11; cờ mobile không được bật; local integration trước đây đã có coverage | **BLOCKED**, FastAPI vẫn đang hoạt động |
| Admin catalog/analytics/audit | `/api/v1/admin*` qua `apps/admin/src/lib/client.ts` | PostgREST/RLS, `englify_admin_metrics`, audit trigger và adapter `supabase-admin.ts` | `apps/admin/.env.local` hiện đặt `NEXT_PUBLIC_SUPABASE_ADMIN_ENABLED=false`; migration history remote chưa được đăng ký; RPC atomic mới chưa áp production | **BLOCKED**, FastAPI vẫn đang hoạt động |

## Consumer đã rời FastAPI trong mã mobile

| Nhóm endpoint FastAPI legacy | Consumer hiện tại | Thay thế | Bằng chứng trong repository | Giới hạn |
| --- | --- | --- | --- | --- |
| `/me`, onboarding, profile/preferences | `auth/profile-repository.ts` | Supabase Auth, PostgREST, RPC onboarding, Storage avatar | Unit test và local Auth/RLS integration | Live device chưa chạy trong Phase 1 |
| `/dictionary`, `/me/vocabulary` | `features/dictionary/api.ts` | PostgREST + RLS + SQLite cache | Unit/local integration | Thiết bị/offline reconnect chưa chạy |
| `/journey`, `/lessons/*` | `features/learning/api.ts` | RPC Journey/read/submit/offline sync | Local full-unit/idempotency test hiện có | Thiết bị thật chưa chạy |
| `/gamification*` | Supabase RPC/repository | RPC gamification, bảng notification chỉ đọc theo owner | Local duplicate reward/XP test hiện có | Live end-to-end chưa chạy |
| `/real-english*` | `features/real-english/api.ts` | PostgREST/RPC + Edge generation cho Admin | Edge `real-english-generate` production đang ACTIVE; local RLS tests | AI generation production không được gọi trong Phase 1 |
| `/writing*` | `features/writing/api.ts` | PostgREST/RPC; Edge grammar là tùy chọn | Mobile test và migration local trước đây; không còn fallback FastAPI | Edge `writing-grammar` chưa deploy, grammar provider có thể unavailable |
| `/translate`, phrasebook | `features/translation/api.ts` | Edge `translate` + MyMemory + local cache | Edge production ACTIVE; test hai chiều đã được người dùng xác nhận trước đó | Quota/provider bên ngoài vẫn có thể unavailable |

`apps/mobile/src/auth/api.ts` và `apps/mobile/src/lib/api.ts` còn tồn tại vì Learning Plan dùng `privateRequest` và vì các kiểu dữ liệu chung vẫn được import. Chúng chưa thể xóa cho đến khi `study-plan` được triển khai và kiểm thử live. Health client không có màn hình production đang gọi.

## Backend legacy phải giữ lại

FastAPI vẫn chứa health, profile, dictionary, translation, Journey, plan, Real English, Writing, gamification và Admin. Phần lớn đã có thay thế Supabase trong mã, nhưng **hai consumer hoạt động ở trên vẫn phụ thuộc FastAPI**. Backend tests tiếp tục chạy trong CI cho đến khi:

1. `study-plan` được deploy với JWT verification, kiểm thử onboarding/regenerate/reschedule/complete và bật cờ mobile;
2. migration Admin, RPC atomic và RLS được áp trên môi trường thử, kiểm thử hai vai trò rồi production;
3. Admin bật `NEXT_PUBLIC_SUPABASE_ADMIN_ENABLED=true` và `NEXT_PUBLIC_ADMIN_ATOMIC_CRUD_ENABLED=true`;
4. hành trình người học và Admin publish được xác minh không cần Uvicorn;
5. có checkpoint/backup phục hồi và migration history Supabase được xử lý an toàn.

## Trạng thái production chỉ đọc

- Edge Functions production: `translate`, `real-english-generate` — ACTIVE, `verify_jwt=true`.
- Thiếu production: `study-plan`, `writing-grammar`.
- `supabase migration list --remote` ngày 15/11/2026 trả cột remote trống cho toàn bộ migration local. Schema đã có một số object do các đợt triển khai thủ công trước, nhưng lịch sử CLI chưa phải nguồn sự thật an toàn; không chạy `db push` cho đến khi backup và reconcile hoàn tất.
- `supabase db lint --remote --level error`: không phát hiện lỗi trên schema production hiện tại. Kết quả này không xác nhận migration mới chưa áp.
