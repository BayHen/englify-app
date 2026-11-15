# Kiểm kê chuyển backend sang Supabase

Ngày kiểm kê: 10/11/2026. Trạng thái: **đang chuyển đổi; chưa được phép gỡ `backend/`**.

## Kiến trúc và nguồn sự thật hiện tại

- Mobile: Expo SDK 58, Expo Router trong `apps/mobile/src/app`, TypeScript; `apps/mobile/src/auth/supabase.ts` tạo một Supabase client. Auth và avatar đã dùng Supabase trực tiếp. `apps/mobile/src/auth/api.ts` và các module trong `features/` vẫn gọi FastAPI theo `EXPO_PUBLIC_API_URL`.
- Admin: Next.js; `apps/admin/src/lib/client.ts` đăng nhập bằng Supabase Auth nhưng CRUD, publishing, analytics và audit gọi `/api/v1/admin` của FastAPI.
- Dữ liệu: PostgreSQL của Supabase, schema ứng dụng ở `public`; `auth.users` do Supabase quản lý. **Alembic `20261106_01` → `20261110_14` vẫn quản lý DB đang hoạt động.** Baseline và security migration trong `supabase/migrations` đã kiểm tra trên local Supabase; chưa ghi nhận vào migration history remote. Không chạy baseline `CREATE TABLE` trên DB đã có dữ liệu.
- Offline: SQLite trên thiết bị và localStorage trên Web trong `features/offline`; outbox đồng bộ qua FastAPI. TTS/ghi âm ở thiết bị; avatar ở Supabase Storage bucket `avatars` (policy tạo trong revision 13).
- Deep link: `auth-callback` và `reset-password` trong Expo Router; callback PKCE xử lý tại `auth/provider.tsx`. Cấu hình redirect trên Supabase Dashboard vẫn cần xác minh trực tiếp.
- Môi trường: mobile dùng `EXPO_PUBLIC_SUPABASE_URL`, `EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY`, `EXPO_PUBLIC_API_URL`; admin dùng `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`, `NEXT_PUBLIC_API_URL`; FastAPI dùng `ENGLIFY_*`. Không đưa giá trị thật vào tài liệu.

## Inventory tính năng

| Tính năng | Hiện tại / frontend | Phụ thuộc API / dữ liệu | Thay thế Supabase cần có | Rủi ro / xác minh |
| --- | --- | --- | --- | --- |
| Đăng ký, đăng nhập, đăng xuất, khôi phục và đổi mật khẩu | `auth/provider.tsx`, các route Auth, `change-password.tsx` | Supabase Auth; profile nay tải trực tiếp từ Supabase | Giữ Auth client và deep link; tải profile qua RLS | Trung bình; đăng ký và callback trên thiết bị **NOT TESTED** |
| Profile và onboarding | `auth/provider.tsx`, `profile-repository.ts`, `edit-profile`, `learning-preferences`, `onboarding` | Trước đây `/me*`; nay `profiles`, `user_preferences` qua PostgREST và RPC | **Đã chuyển**; RPC giữ timestamp onboarding, constraint avatar thuộc UID, RLS local test đạt | Trung bình; live mobile/Storage upload chưa thử |
| Avatar | `features/profile/avatar.ts`, `change-avatar` | Supabase Storage `avatars`; đường dẫn lưu trong `profiles.avatar_url` qua `/me/profile` | Giữ Storage; cập nhật profile trực tiếp dưới RLS, xác minh path thuộc user và dọn file lỗi | Cao; cần test upload/ownership, thiết bị **NOT TESTED** |
| Từ điển, từ đã lưu | `features/dictionary`, cache, offline outbox | Trước đây `/dictionary`, `/me/vocabulary`; `dictionary_entries`, `saved_vocabulary` | **Đã chuyển mobile sang PostgREST**, lọc published, ghi theo UID với RLS; test unit đạt | Trung bình; test live user/offline replay/cross-user **BLOCKED** |
| Dịch | `features/translation` | Trước đây `/translate`, `/translation/phrases`; phrasebook, provider LibreTranslate trong Python | **Đã chuyển phrasebook exact match sang client**; provider LibreTranslate không được cấu hình trong môi trường hiện tại; khi không khớp trả unavailable | Trung bình; cần kiểm tra UI và nguồn phrasebook; full-text provider **BLOCKED** |
| Journey, lesson, quiz, offline package | `features/learning`, `features/offline` | `/journey`, `/lessons/*`; courses, units, lessons, items, questions, answer keys, progress, attempts | Read view/RPC giữ khóa lesson; RPC chấm bài server-side, kiểm tra content version và request ID trong transaction | **Rất cao**; không để client đọc đáp án hoặc ghi XP; **BLOCKED** |
| Kế hoạch học | `features/plan` | `/learning-plan/*`; preferences, plans, tasks, Python rule engine | Port thuật toán sang SQL/Edge Function; transaction và lịch sử bất biến | Cao; regeneration/reschedule **BLOCKED** |
| Gamification | `features/gamification` | `/gamification/*`; XP, level, quest, badge, reward claims, notifications | RPC có lock, idempotency và quyền; read view theo user | **Rất cao**; thưởng giả/trùng **BLOCKED** |
| Real English | `features/real-english` | `/real-english/*`; expressions, saved, context quiz/attempt | Query nội dung published + RPC chấm quiz, ghi attempt | Cao; đáp án và provenance **BLOCKED** |
| Writing | `features/writing` | `/writing/*`; exercises, answer keys, submissions, feedback | RPC cho bài cấu trúc; Edge Function nếu dùng LanguageTool; lịch sử dưới RLS | Cao; không lộ answer keys, không bịa grammar feedback **BLOCKED** |
| Speaking | `features/speaking` | TTS/recording/history cục bộ | Giữ local; chỉ tạo bảng ghi server nếu luồng hiện tại thực sự dùng | Thấp; native permission/playback **NOT TESTED** |
| Admin và publishing | `apps/admin/src/app/page.tsx` | `/admin/*`; `admin_members`, `admin_audit_logs`, catalog | RPC/Edge Function kiểm tra admin trong DB, validation, transaction/audit | **Rất cao**; user thường không được ghi catalog **BLOCKED** |
| Home/Explore/Rewards/Profile UI | Các route và feature screen tương ứng | Tổng hợp các module trên; một số màn hình demo dùng `getMockContent` | Giữ UI và nhãn demo; chỉ đổi data service khi hợp đồng tương đương | Trung bình; regression trực quan **NOT TESTED** |

## Bản đồ API cũ

`auth/api.ts` là điểm chung cho các lời gọi có JWT còn lại. Consumer: `features/learning/api`, `plan/api`, `gamification/api`, `real-english/api`, `writing/api`, `offline/sync`. `auth/provider`, `features/dictionary/api` và `features/translation/api` đã rời FastAPI. Admin vẫn có `apps/admin/src/lib/client.ts`; `lib/api.ts` còn health qua FastAPI. Không thể xóa `EXPO_PUBLIC_API_URL` hoặc Uvicorn khi các consumer kia còn hoạt động.

## Lược đồ và bảo mật hiện có

Migration Alembic đã tạo các nhóm `profiles`, `user_preferences`, dictionary/saved/review, courses/units/lessons/items/questions/answer keys, progress/attempts, plans/tasks, XP/levels/quests/badges/rewards/notifications, Real English, writing, admin, và Storage policy. Revision 13 thêm trường profile và bucket avatar. RLS và quyền SQL cho một số bảng đã có; **không suy ra RLS đúng chỉ vì policy có trong source**. Phải đối chiếu schema đang triển khai, `pg_policies`, `relrowsecurity`, grant, và test bằng hai JWT thật. Các bảng answer key và admin audit không được mở bằng SELECT/INSERT rộng cho client.

## Phương án chuyển đổi bảo toàn dữ liệu

1. Chụp backup Supabase và ghi revision Alembic, số dòng từng bảng, số user, số liên kết FK trước cutover. Không sao chép `auth.users` sang một project khác bằng SQL thô.
2. Nếu giữ nguyên Supabase project/PostgreSQL hiện tại, dữ liệu không cần copy; cần chuyển quyền sở hữu migration có kiểm soát. Baseline local đã được tạo và thử từ DB trống; phải đối chiếu remote, backup và đánh dấu version đã áp dụng trước `db push`. Không chạy lại DDL cũ. Nếu sang project khác, lập bản đồ user ID/Auth và quy trình reset password riêng trước import.
3. Chuyển từng service sang PostgREST/RPC/Edge Function; kiểm thử hợp đồng, RLS, idempotency, dữ liệu trước/sau và offline queue. Chỉ phát hành feature khi parity đạt; không dùng mock/fake success để che lỗi.
4. Đối chiếu số dòng, FK, XP và lịch sử học, thử rollback bằng backup trên môi trường thử nghiệm. Cuối cùng mới gỡ FastAPI, script, CI và biến môi trường cũ.

## Cổng chặn hiện tại

- Supabase local đã có và chạy test Auth/PostgREST/RLS. Chưa có backup/restore của remote hoặc quy trình ghi nhận baseline remote được kiểm chứng; không chạy baseline CREATE TABLE trên DB người dùng.
- Chưa có SQL/RPC tương đương cho quiz, XP, plan, writing, admin; client Supabase trực tiếp không đủ bảo vệ các quy tắc này.
- Đã kiểm tra đăng nhập hai tài khoản và RLS qua PostgREST **local** cho profile, vocabulary, XP; Storage upload và deep link trên thiết bị thật chưa kiểm chứng.
- Preflight **chỉ đọc** trên DB cấu hình trước fix xác nhận revision `20261109_13`, 41 bảng trong `public` (gồm `alembic_version`), `unvalidated_constraints=0`, 1 profile, 4 lesson, 4 progress. Sau security/profile migrations, revision `20261110_15`, bảng `alembic_version` bật RLS và không còn quyền client; profile/progress không đổi. Tạo snapshot/backup trước bước ghi lớn.

Đối chiếu chi tiết kết quả chạy: `docs/SUPABASE_MIGRATION_TEST_REPORT.md`.
