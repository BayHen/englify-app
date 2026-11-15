# Báo cáo kiểm thử chuyển backend sang Supabase

Ngày: 10/11/2026. **Trạng thái tổng thể: BLOCKED; không được xóa `backend/`.**

## Thay đổi trong đợt này

- Lập inventory chức năng, API, bảng, quyền và rủi ro ở `docs/SUPABASE_MIGRATION_AUDIT.md`.
- Thêm `scripts/supabase_preflight.py`: transaction chỉ đọc, báo revision, số bản ghi theo bảng, cờ RLS/policy và constraint chưa validate; không xuất URL hoặc nội dung người dùng.
- Thêm Supabase CLI local, baseline SQL, ba seed và cấu hình bucket/deep link. `db reset` với cùng network ID đã tái tạo local schema/seed/bucket thành công. Chưa đăng ký baseline vào migration history remote.
- Thêm migration `20261110_14` chỉ thu hồi quyền anon/authenticated trên `public.alembic_version` và bật RLS. Đã áp vào DB đang cấu hình sau khi kiểm tra revision cũ; không sửa dữ liệu học.
- Mobile: Supabase Auth cho phép lưu session trên Web (trước đây `persistSession=false`); lỗi đọc session tạm thời không tự xóa state đăng nhập. Chưa thay API profile bằng Supabase direct vì chưa có kiểm chứng parity/RLS.
- Mobile: `features/dictionary/api.ts` dùng PostgREST và RLS cho tìm/lưu/xóa từ; `features/translation` dùng phrasebook biên tập của dự án cho khớp chính xác. Provider LibreTranslate cũ không được cấu hình tại máy hiện tại; dịch toàn văn vẫn trả `unavailable`.
- Mobile: `auth/profile-repository.ts` đọc/sửa profile, preferences qua PostgREST và onboarding qua RPC. Migration revision 15 thêm kiểm tra avatar path và giữ timestamp onboarding trong transaction. Local integration xác nhận cập nhật profile, chặn path avatar khác user, RPC lặp không đổi mốc hoàn thành.

## Kết quả thực thi

| Kiểm tra | Kết quả | Bằng chứng / giới hạn |
| --- | --- | --- |
| TypeScript mobile | PASS | `npm.cmd run typecheck -w apps/mobile`, exit 0 |
| ESLint mobile | PASS | `npm.cmd run lint -w apps/mobile`, exit 0 |
| Unit/component test mobile | PASS | `npm.cmd run test -w apps/mobile`: 21 file, 53 test; có test mới về profile repository, từ điển, idempotent upsert và fallback dịch không bịa kết quả |
| ESLint admin | PASS | `npm.cmd run lint -w apps/admin`, exit 0 |
| Build admin | PASS | `npm.cmd run build -w apps/admin`, Next.js build và TypeScript exit 0 |
| Pytest backend | PASS | PostgreSQL 18 Docker disposable + Auth stub + seed: **48 pass, 0 skip**. Lần chạy đầu 4 fail do cấu hình test/seed; đã sửa môi trường và chạy lại toàn bộ. |
| Ruff backend | PASS | `\.venv\Scripts\python.exe -m ruff check backend`, exit 0 |
| Preflight script | PASS | Ruff và `py_compile` exit 0 |
| Preflight PostgreSQL hiện hữu | PASS (chỉ đọc) | Trước fix: revision `20261109_13`, 41 bảng trong `public`, 1 profile, 4 lesson, 4 learning progress; 0 constraint chưa validate. Sau fix: `20261110_15`, RLS Alembic bật, quyền client bị thu hồi, RPC/constraint có mặt; profile/progress không đổi. |
| Supabase CLI baseline, migration trên DB local trống | PASS | `npx.cmd supabase db reset --network-id englify-local-test-20261110`: baseline + security migration + ba seed + bucket avatar; exit 0. Không chạy trên remote. |
| PostgreSQL test local | PASS | Docker engine đã chạy; migration Alembic từ DB trống, seed và SQL RLS/FK exit 0 trên container disposable. Pytest đủ 48 pass. |
| Supabase Auth/PostgREST local | PASS | Script tạo/xóa hai user local: đăng nhập, profile riêng, onboarding RPC giữ timestamp, cập nhật profile, chặn avatar path khác user, từ điển, lưu từ idempotent, chặn ghi hộ user khác, chặn anon đọc profile và chặn client ghi XP. Chạy lại sau `db reset` đạt. |
| Parity schema local/remote | PASS (cấu trúc) | Query chỉ đọc: 0 khác biệt về bảng+cờ RLS, cột, policy public, constraint, index và avatar policy. Chưa so function body hoặc dữ liệu. |
| Quyền Alembic metadata remote | PASS | Trước fix anon/authenticated có CRUD; sau revision `20261110_14`, cả SELECT/INSERT/UPDATE/DELETE đều false và RLS true. Profile=1, progress=4 không đổi. |
| Expo SDK compatibility | PASS | `npx.cmd expo install --check`: dependencies up to date. |
| Dependency audit production | PASS với cảnh báo | `npm audit --omit=dev`: 5 moderate, 0 high, 0 critical; chưa sửa ngoài phạm vi. |
| Supabase migration history remote | BLOCKED | Baseline local chưa được đánh dấu là đã áp dụng trên remote; cần backup, đối chiếu schema và dữ liệu trước khi chuyển source of truth. Không chạy `db push` lên project thật. |
| Từ điển và phrasebook trên ứng dụng thật | NOT TESTED | Unit test đạt nhưng chưa có phiên Supabase Auth và thiết bị để xác nhận RLS, dữ liệu seed, đồng bộ offline và UI. |
| RLS hai user, admin, Storage ownership | BLOCKED | Cần DB test có auth fixture / hai tài khoản, test phân quyền và backup; test hiện bị skip. |
| Auth live, profile, avatar, bài học, XP, plan, writing, translation | NOT TESTED | Chưa chạy E2E với tài khoản thử và implementation Supabase thay thế chưa hoàn chỉnh. |
| Android/iOS thiết bị thật, deep link, offline reconnect | NOT TESTED | Không có phiên thử trên thiết bị; Web bundle/TypeScript không chứng minh native. |
| Runtime React Native Web sau sửa mobile | NOT TESTED | Chưa mở browser tương tác trong đợt này; kiểm tra route `/login`, đăng nhập, reload, Console/LogBox và `Unexpected text node` trước khi xác nhận. JSX vừa sửa không thêm phép `&&` render text. |

## Tồn tại và bảo mật

- FastAPI vẫn xử lý đa số nghiệp vụ; không thể xóa server hoặc `EXPO_PUBLIC_API_URL`. Cần port sang RPC/Edge Function với kiểm tra identity, transaction, idempotency và error contract.
- Không để client ghi trực tiếp `learning_progress`, `xp_events`, lesson attempts, answer keys hoặc admin catalog. Supabase `SECURITY DEFINER` có thể bypass RLS; mỗi function phải kiểm tra `auth.uid()`, có `SET search_path = ''`, revoke EXECUTE rộng và test chéo tài khoản. Xem [Supabase Database Functions](https://supabase.com/docs/guides/database/functions).
- Profile/vocabulary RLS đã được chứng thực bằng hai JWT **local**; Storage upload và RLS remote chưa kiểm thử. Bảng Alembic metadata remote trước fix có grant rộng; security migration đã thu hồi quyền và bật RLS. Không đưa session token hoặc service key vào log.
- Một số màn hình demo cố ý dùng dữ liệu mẫu và có nhãn; không dùng chúng để báo tính năng Supabase đã hoạt động.
- Web Auth persistence dùng storage mặc định của Supabase JS trong trình duyệt; cần thử reload và logout thật. Thiết bị native dùng Expo SecureStore.

## Các bước tiếp theo có thể kiểm chứng

1. Tạo bản sao Supabase thử nghiệm và backup có thể restore, sau đó chạy `scripts/supabase_preflight.py` trước/sau; đối chiếu số dòng và FK.
2. Tạo baseline bằng `supabase db pull --remote` từ trạng thái schema thật; kiểm tra lịch sử migration remote và các object trong `auth`/`storage`. Lệnh pull có thể cập nhật migration history; chỉ thực hiện sau backup. [Supabase CLI workflow](https://supabase.com/docs/guides/local-development/cli-workflows).
3. Chuyển profile, dictionary/read catalog trước; chuyển chấm quiz/XP/offline sync bằng RPC transaction và test lặp request; chuyển admin cuối cùng với audit.
4. Chạy regression hai user và thiết bị thật, kiểm tra số dòng, snapshot/rollback rồi mới cân nhắc gỡ FastAPI.

Lệnh khởi động hiện hành vẫn cần FastAPI; không hướng dẫn chạy mobile mà thiếu API khi các route còn phụ thuộc nó. Từ root: `\.venv\Scripts\python.exe -m uvicorn app.main:app --app-dir backend --host 0.0.0.0 --port 8000 --reload`. Từ `apps/mobile`: `npx.cmd expo start --tunnel --clear`.
