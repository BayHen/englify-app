# Báo cáo Phase 1 — Critical Fixes & System Stability

Ngày: 15/11/2026  
Nhánh kiểm tra: `feature/real-english-hybrid-v2`  
Trạng thái tổng thể: **BLOCKED** — migration, RLS, transaction, concurrency và integration đã PASS trên Supabase local disposable. Phase vẫn bị chặn ở triển khai production/staging, reconcile migration history và các luồng còn phụ thuộc FastAPI; không deploy hoặc thay đổi production trong Phase này.

## 1. Root causes

1. `apps/admin/src/lib/supabase-admin.ts` ghi câu hỏi/đáp án và badge/rule bằng các PostgREST request tách biệt. Request thứ hai thất bại có thể để lại bản ghi chính không nhất quán; retry tạo mới không có idempotency key.
2. Supabase-only chưa hoàn tất: Learning Plan vẫn gọi FastAPI khi cờ tắt; `study-plan` không có trong danh sách Edge Functions production. Admin local đang đặt `NEXT_PUBLIC_SUPABASE_ADMIN_ENABLED=false`, nên catalog/analytics/audit vẫn đi FastAPI.
3. Migration history của Supabase CLI chưa được reconcile: `supabase migration list --remote` trả cột remote trống cho toàn bộ migration local, dù một số object đã được áp thủ công trước đây. Vì vậy `db push` trực tiếp lên production không an toàn.
4. CI cũ chỉ chạy JavaScript và backend unit tests; không reset Supabase disposable, không kiểm tra migration/RPC/RLS/Edge, không chạy Admin unit test và không kiểm tra concurrency.
5. Security integration trước đây thiếu request invalid/expired JWT và thao tác Storage chéo tài khoản. Các ca đã được bổ sung và đã PASS trên Supabase local.

## 2. Thay đổi đã triển khai trong mã

### Admin transaction safety

- Thêm migration `20261115010000_admin_atomic_crud.sql`:
  - bảng private `admin_mutation_requests`, khóa `(actor_id, request_id)`;
  - RPC `englify_admin_upsert_quiz_question` ghi câu hỏi + answer key trong một transaction;
  - RPC `englify_admin_upsert_badge` ghi badge + rule trong một transaction;
  - kiểm tra `auth.uid()` và `englify_is_admin()` bên trong `SECURITY DEFINER`;
  - `SET search_path=''`, revoke `PUBLIC`/`anon`, chỉ grant execute cho `authenticated`;
  - validation field whitelist, UUID, kind, payload, answer shape, metric và target;
  - retry cùng request ID trả response đã commit; transaction lỗi rollback cả reservation.
- Admin giữ request ID qua lần retry; chỉ tạo ID mới sau khi save thành công.
- Cờ `NEXT_PUBLIC_ADMIN_ATOMIC_CRUD_ENABLED=false` giữ môi trường hiện hành không gọi RPC chưa deploy.
- Bổ sung Admin adapter tests cho RPC routing và thiếu idempotency key.

### Security và database tests

- `admin_atomic_crud_smoke.sql`: learner bị chặn, retry không nhân đôi, trigger ép lỗi bảng phụ chứng minh rollback, audit trigger hiện hữu không bị thay thế.
- `security_definer_privileges_smoke.sql`: chặn PUBLIC execute SECURITY DEFINER, yêu cầu empty search path, chặn client đọc idempotency table/answer keys và ghi XP.
- `supabase_admin_atomic_concurrency.py`: hai request đồng thời cùng idempotency key phải trả cùng record và chỉ tạo một badge/rule/request.
- `supabase_local_integration.py`: thêm invalid JWT, expired JWT, avatar own upload/read và chặn đọc/ghi chéo account.
- Tất cả script từ chối chạy nếu Supabase không phải loopback; không in key/token.

### CI/CD

- JavaScript job chạy thêm Admin unit tests.
- Python job lint cả `backend` và `scripts`, tiếp tục giữ pytest legacy khi FastAPI còn hoạt động.
- Supabase job mới:
  - khởi động/reset Supabase local disposable;
  - lint database;
  - Deno check bốn Edge Functions;
  - chạy SQL privilege/transaction smoke tests;
  - chạy Auth/RLS/publishing integration và concurrency test;
  - luôn dừng stack, không dùng production secrets.
- Workflow YAML đã parse thành công cục bộ.

## 3. FastAPI migration status

Inventory đầy đủ nằm tại `docs/SUPABASE_PHASE1_DEPENDENCY_INVENTORY.md`.

| Luồng | Trạng thái | Lý do |
| --- | --- | --- |
| Profile/Auth/Onboarding | PASS trong mã Supabase | Không còn active FastAPI call; live device chưa kiểm tra Phase này |
| Dictionary/Journey/XP/Real English/Writing/Translation | PASS trong mã, giới hạn theo báo cáo trước | Không phát hiện active FastAPI consumer; một số live/device test chưa chạy |
| Mobile Learning Plan | **BLOCKED** | `study-plan` chưa deploy production; fallback FastAPI còn active |
| Admin catalog/analytics/audit | **BLOCKED** | Flag Admin Supabase hiện false; RPC atomic chưa apply/test production |
| Xóa `backend/` | **BLOCKED** | Hai consumer trên còn phụ thuộc FastAPI; backend tests vẫn cần trong CI |

Edge production được kiểm tra chỉ đọc: `translate` và `real-english-generate` ACTIVE với `verify_jwt=true`; không có `study-plan` hoặc `writing-grammar`.

## 4. Security findings

| Hạng mục | Trạng thái | Bằng chứng / giới hạn |
| --- | --- | --- |
| Không lộ service-role trong mobile/admin | PASS (static) | Client chỉ dùng publishable key; script không in secret |
| Admin authorization trong RPC mới | PASS (code review) | `auth.uid()` + `englify_is_admin`, revoke/grant hẹp |
| SECURITY DEFINER search path/privilege | PASS local | SQL regression kiểm tra execute privilege, empty search path và bảng answer key có RLS/admin policy |
| Anonymous/invalid/expired JWT | PASS local | Auth integration từ chối token thiếu, sai và hết hạn |
| Learner gọi Admin RPC/publish | PASS local | SQL/HTTP regression xác nhận learner bị từ chối |
| User A đọc User B | PASS local | Integration xác nhận cách ly dữ liệu giữa hai tài khoản |
| Direct XP mutation/duplicate reward | PASS local | Privilege test và integration xác nhận XP server-authoritative/idempotent |
| Concurrent Admin mutation | PASS local | Hai worker cùng idempotency key chỉ tạo một badge/rule/request |
| Unpublished content | PASS local | Integration xác nhận draft không lộ và publish workflow hoạt động |
| Avatar Storage cross-account | PASS local | Own upload/read hoạt động; cross-account read/write và forged path bị chặn |
| Unauthorized AI generation | NOT TESTED | Edge local không chạy; không gọi production generation trong audit |

`supabase db lint --remote --level error` trả **PASS, 0 schema errors** cho schema production hiện tại. Đây là kiểm tra chỉ đọc và không chứng minh migration mới.

## 5. Test results thực tế

| Kiểm tra | Kết quả |
| --- | --- |
| `npm.cmd run check` | PASS |
| Mobile TypeScript/ESLint/Vitest | PASS — 39 files, 132 tests |
| Shared TypeScript | PASS |
| Admin ESLint | PASS |
| Admin unit tests | PASS — 6 tests |
| Admin production build | PASS |
| Ruff `backend scripts` | PASS sau khi sửa 4 lỗi lint cũ |
| Backend pytest | PASS một phần — 40 passed, 8 skipped vì thiếu test DB |
| Python compile cho script mới | PASS |
| CI YAML parse | PASS |
| `git diff --check` | PASS; chỉ có cảnh báo LF/CRLF Windows |
| Remote schema lint | PASS — 0 errors |
| Supabase local `start/reset` | PASS — 16 migration, toàn bộ seed và bucket `avatars` được tạo |
| Supabase local database lint | PASS — 0 schema errors |
| Migration/RPC/RLS SQL smoke | PASS — privilege/RLS và atomic rollback/idempotency |
| Admin mutation concurrency | PASS — retry đồng thời không nhân đôi dữ liệu |
| Auth/RLS/Storage/domain integration | PASS — profile, dictionary, Real English, quota, plan, gamification, Journey, writing, admin publish/audit |
| Edge Deno check local | NOT TESTED — Deno chưa cài tại máy; CI đã cấu hình |
| GitHub Actions run | NOT TESTED — workflow chưa được push/run |
| Browser Admin full CRUD | NOT TESTED |
| Android/iOS/Expo Go | NOT TESTED |
| Register → Login → Onboarding → Journey → Quiz → XP → Profile | NOT TESTED end-to-end trong Phase này |
| Admin create/edit/publish → mobile complete | NOT TESTED end-to-end |
| AI generate/review/publish → Real English | NOT TESTED; không gọi production AI |

## 6. Files changed

- `.github/workflows/ci.yml`
- `apps/admin/.env.example`
- `apps/admin/package.json`
- `apps/admin/src/app/page.tsx`
- `apps/admin/src/lib/supabase-admin.ts`
- `apps/admin/src/lib/supabase-admin.test.mjs`
- `supabase/migrations/20261115010000_admin_atomic_crud.sql`
- `supabase/tests/admin_atomic_crud_smoke.sql`
- `supabase/tests/security_definer_privileges_smoke.sql`
- `scripts/run_local_sql_test.py`
- `scripts/supabase_admin_atomic_concurrency.py`
- `scripts/supabase_local_integration.py`
- `scripts/enable_hybrid_cron.py`
- `scripts/generate_tatoeba_attribution.py`
- `docs/SUPABASE_PHASE1_DEPENDENCY_INVENTORY.md`
- `docs/reports/PHASE_01_CRITICAL_STABILITY_REPORT.md`

## 7. Skills used

- `database-design`: transaction RPC, idempotency table, migration và rollback tests.
- `security-review`: auth boundary, SECURITY DEFINER, privilege, RLS, Storage và secret handling.
- `test-engineering`: regression, concurrency, disposable database và honest status.
- `api-integration`: Admin adapter/error contract và inventory consumer/provider.
- `mobile-architecture`, `learning-engine`, `expo-router`: xác định consumer mobile, bảo toàn Journey/XP/navigation và không sửa route ngoài phạm vi.

## 8. Manual actions required

### Lệnh tái kiểm tra local

1. Mở/Resume Docker Desktop và chờ Linux engine hoạt động.
2. Chạy trên database local disposable (đã PASS trong phiên này):

```powershell
npx.cmd supabase start
npx.cmd supabase db reset
npx.cmd supabase db lint --level error
.\.venv\Scripts\python.exe scripts\run_local_sql_test.py supabase\tests\security_definer_privileges_smoke.sql supabase\tests\admin_atomic_crud_smoke.sql
.\.venv\Scripts\python.exe scripts\supabase_local_integration.py
.\.venv\Scripts\python.exe scripts\supabase_admin_atomic_concurrency.py
```

3. Không chạy các test reset trên production.
4. Tạo project staging/backup có thể restore, reconcile migration history và chạy toàn bộ test ở staging.
5. Chỉ sau khi staging PASS: xin phê duyệt riêng để apply migration production, deploy `study-plan`, chạy live auth/RLS, rồi bật:

```env
NEXT_PUBLIC_SUPABASE_ADMIN_ENABLED=true
NEXT_PUBLIC_ADMIN_ATOMIC_CRUD_ENABLED=true
EXPO_PUBLIC_SUPABASE_PLAN_ENABLED=true
```

6. Chạy các hành trình end-to-end và thiết bị thật. Chỉ khi tất cả PASS mới xem xét loại FastAPI/config cũ.

## 9. Remaining risks

- Migration SQL mới đã PASS trên PostgreSQL local disposable nhưng chưa được áp lên staging/production.
- Migration history remote trống làm tăng rủi ro áp lại object đã tồn tại; cần backup và reconciliation trước mọi `db push`.
- Cờ Supabase Admin/atomic/plan đang tắt để giữ tính năng hiện tại; vì vậy transaction safety mới chưa active production.
- Edge `study-plan` chưa deploy; tắt FastAPI lúc này sẽ làm Learning Plan hỏng.
- CI Supabase job chưa chạy trên GitHub runner lần đầu; thời gian pull image và Deno dependency chưa được đo.

Không tự động chuyển sang Phase 2.
