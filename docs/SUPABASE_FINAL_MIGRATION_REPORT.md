# Báo cáo chuyển đổi Supabase — chưa hoàn tất

Ngày: 10/11/2026. **BLOCKED cho mục tiêu Supabase-only. `backend/` vẫn cần để chạy các tính năng hiện hành và chưa được xóa.** Đây là báo cáo trạng thái triển khai, không phải chứng nhận hoàn tất.

## Đã chuyển đổi và giữ nguyên dữ liệu

| Chức năng FastAPI cũ | Supabase/thay thế hiện tại | Trạng thái |
| --- | --- | --- |
| Auth email, session, password | Supabase Auth đã có; sửa persistence trên Web và lỗi session tạm thời | Unit PASS; local Auth PASS; thiết bị NOT TESTED |
| `/me`, `/me/onboarding`, `/me/profile`, `/me/preferences` | `auth/profile-repository.ts` gọi PostgREST và RPC `englify_save_onboarding`; constraint avatar path | Unit + local Auth/RLS PASS; live mobile NOT TESTED |
| Avatar upload/đọc | Supabase Storage `avatars` đã có từ trước | Live NOT TESTED |
| `/dictionary`, `/me/vocabulary` | Mobile repository gọi Supabase PostgREST trên `dictionary_entries`, `saved_vocabulary`, RLS đã có | Unit PASS; live/RLS BLOCKED |
| `/translate`, `/translation/phrases` | Phrasebook gốc biên tập chuyển sang mobile; khớp chính xác hai chiều, trường hợp khác báo unavailable | Unit PASS; UI NOT TESTED |

Các API `/journey`, `/lessons/*`, `/learning-plan/*`, `/gamification/*`, `/real-english/*`, `/writing/*` và toàn bộ `/admin/*` **vẫn cần FastAPI**. Logic Python chấm bài, XP, quest, plan, grammar và quyền admin chưa được port sang RPC/Edge Function; client không thể tự tính các kết quả đáng tin cậy này. Không có file nào trong `backend/` bị xóa.

## Database và bảo mật

- Preflight trước fix: Alembic `20261109_13`, 41 bảng trong `public`, 0 constraint chưa validate. Migration `20261110_14` thu hồi quyền rộng trên `alembic_version`; `20261110_15` thêm avatar ownership constraint và RPC onboarding. Sau fix revision 15, 1 profile và 4 progress không đổi. Không migration dữ liệu học nào được chạy trên remote.
- Supabase local có baseline SQL, security migration, ba seed, config avatar/deep link; `db reset` từ DB trống exit 0. Baseline **chưa** được đăng ký vào history remote và không được chạy lại trên DB hiện hữu.
- Đối chiếu chỉ đọc local/remote sau security migration: tập bảng + cờ RLS, cột, policy `public`, constraint, index và avatar policy có **0 khác biệt** trong các mục được so sánh. Đây là kiểm tra cấu trúc, không kiểm tra số liệu hoặc function body.
- Từ điển đã lọc `language=en`, `is_published=true`, `archived_at IS NULL`; saved word ghi `user_id` của Supabase session, unique conflict được bỏ qua. Auth/PostgREST local đã kiểm tra hai JWT và anon: không đọc/ghi chéo profile hoặc vocabulary, không ghi XP trực tiếp. Chưa xác nhận RLS remote bằng test accounts.
- Answer keys, XP, progress và admin vẫn là dữ liệu server-owned; không cấp quyền ghi trực tiếp từ client để đạt mục tiêu xóa backend giả tạo.
- Không đưa connection string, password, token hoặc service-role key vào mã nguồn/tài liệu.

## Kiểm thử sau thay đổi

- Mobile typecheck, lint: **PASS**; Vitest **49/49 PASS**.
- Admin lint/build: **PASS** ở lần kiểm tra nền trước thay đổi mobile; admin chưa được refactor.
- Backend pytest: **48 PASS, 0 SKIPPED** trên PostgreSQL 18 disposable trong Docker sau khi nạp Auth stub và ba bộ seed. Lần chạy đầu thất bại 4 bài vì đặt nhầm `ENGLIFY_DATABASE_URL` cho test giả định thiếu DB và chưa nạp seed Real English/Writing; đã sửa cấu hình test và chạy lại đủ 48 bài đạt.
- Ruff backend và script preflight: **PASS**.
- Migration Alembic từ DB trống, seed và bài SQL RLS/FK: **PASS** trên PostgreSQL Docker disposable với Auth stub. Test tích hợp backend về grading, XP, admin CRUD cũng PASS. Đây là xác minh **logic FastAPI hiện tại**, không phải RPC Supabase thay thế.
- Supabase CLI 3.1.0, baseline/seed/bucket và RLS qua REST local: **PASS** sau `db reset --network-id ...` và script `supabase_local_integration.py` với hai tài khoản tự xóa. `db reset` lần đầu thiếu network ID nên health fail dù schema/seed đã áp; chạy lại với cùng network ID exit 0.
- `npm.cmd run check` sau profile migration: **PASS** (mobile typecheck/lint, Vitest 53/53, shared typecheck, admin lint/build). `npx.cmd expo install --check`: **PASS**. `npm audit --omit=dev`: 5 moderate, 0 high/critical; chưa tự nâng cấp ngoài phạm vi.
- Remote metadata security: trước fix `anon` và `authenticated` có toàn bộ CRUD trên `public.alembic_version`; sau migration `20261110_14`, mọi quyền CRUD của hai role đã bị thu hồi và RLS bật. Revision hiện tại 15, profile=1 và progress=4 được xác nhận bằng query chỉ đọc. RPC và avatar constraint có trên remote; chưa chạy thao tác mobile live.
- Admin CRUD và XP/grading **trên bản thay thế Supabase**: **BLOCKED** vì RPC/Edge Function tương đương chưa triển khai. Test 48 bài chỉ xác nhận logic backend cũ.
- Expo Web runtime, iOS/Android thật, deep link, offline reconnect: **NOT TESTED**. Kiểm tra `Unexpected text node` tĩnh trên JSX vừa sửa: không có JSX mới; mở route `/dictionary` và `/translation` trên Web, xem Console/LogBox sau tìm/lưu/đổi tab để xác nhận runtime.

## Tệp và cách chạy

Tệp mới/sửa trong đợt: `apps/mobile/src/lib/supabase-query.ts`, `auth/profile-repository.ts` và test, `auth/provider.tsx`, `features/dictionary/api.ts` và test, `features/translation/api.ts`, `phrasebook.ts` và test, `supabase/config.toml`, baseline + hai migration SQL, ba seed, hai Alembic revision và script integration; cùng README và báo cáo. Các tệp audit/preflight/Auth từ đợt trước vẫn chưa commit. Chưa xóa tệp nào.

Hiện vẫn chạy FastAPI từ root:

```powershell
.\.venv\Scripts\python.exe -m uvicorn app.main:app --app-dir backend --host 0.0.0.0 --port 8000 --reload
```

Chạy mobile từ `apps/mobile`:

```powershell
npx.cmd expo start --tunnel --clear
```

Chạy admin từ root: `npm.cmd run admin`. Các biến `EXPO_PUBLIC_API_URL` và `NEXT_PUBLIC_API_URL` vẫn cần cho các tính năng chưa chuyển. **Không loại bỏ chúng cho đến khi tất cả consumer đã chuyển và regression đạt.**

## Cần làm để hoàn tất và gỡ FastAPI

1. Tạo local/staging Supabase disposable, xác nhận backup/restore, baseline schema thực và hai tài khoản user + một admin.
2. Port profile, Real English, writing, lesson grading, XP/quest/reward, plan và admin sang RPC/Edge Function với transaction, quyền, idempotency và test parity.
3. Chạy test tích hợp với dữ liệu thật, đếm bản ghi/FK trước-sau, kiểm tra offline/restart và device; chỉ khi không còn lời gọi FastAPI mới xóa `backend/` và config/script liên quan.

Chi tiết inventory: `docs/SUPABASE_MIGRATION_AUDIT.md`. Kết quả test: `docs/SUPABASE_MIGRATION_TEST_REPORT.md`.

## Cập nhật 2026-11-10: Real English

- Đã chuyển tìm kiếm, lưu/bỏ lưu biểu thức và quiz ngữ cảnh trên mobile sang Supabase PostgREST/RPC. Nội dung chỉ lấy bản đã xuất bản; quiz không trả đáp án trước khi nộp.
- Migration `20261110100000_real_english_rpc.sql` cấp quyền lưu biểu thức có RLS theo người dùng và tạo hai RPC chấm quiz phía database. Alembic revision `20261110_16` đã áp dụng vào database cấu hình. Kiểm tra chỉ đọc sau migration: 1 profile, 4 bản ghi tiến độ, 2 RPC; không đổi số lượng profile/tiến độ.
- Supabase local reset/seed và bài kiểm thử hai tài khoản: PASS, gồm quiz, idempotency, chặn đáp án không hợp lệ, chặn truy cập chéo, anonymous và ghi XP từ client. `npm.cmd run check`: PASS, 55 mobile tests, mobile/shared typecheck, mobile/admin lint và admin build. Ruff: PASS.
- Chưa kiểm thử trực tiếp trên Expo Web hoặc điện thoại; mở `/real-english`, tìm và lưu biểu thức, làm quiz rồi xem Console/LogBox để xác nhận không có `Unexpected text node`. Lần sửa này không thêm JSX.
- FastAPI vẫn phục vụ Journey, kế hoạch học, gamification, writing, admin và các API khác. Chưa được xóa `backend/` hoặc bỏ `EXPO_PUBLIC_API_URL`; cần thay thế và kiểm thử các nghiệp vụ này trước.