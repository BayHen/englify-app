# Quiz Arena V2.6 - Báo cáo kiểm định và mức sẵn sàng phát hành

Ngày kiểm định: 2026-11-18  
Phạm vi: Quiz Arena V2.1-V2.5 trên worktree hiện tại  
Môi trường: Windows, Expo SDK 58, Node 24 trong CI, Supabase local `127.0.0.1`, PostgreSQL local, Python 3.14  
Quyết định: **CONDITIONAL**

Không có lỗi P0/P1 đã biết còn mở trong các đường chạy tự động và local integration đã thực thi. Chưa đủ bằng chứng để kết luận READY vì Android/iOS thật, Gemini thật, kiểm thử tải lớn và Deno local chưa được thực hiện. Không migration nào được triển khai lên production và không dữ liệu production nào bị thay đổi.

## 1. Audit Report

| Feature | Implementation chính | Kiểm thử thực tế | Status |
|---|---|---|---|
| Practice Mode | `arena-practice-screen.tsx`, `arena-api.ts`, migration `20261118020000` | unit, SQL smoke, Auth/RLS integration, Expo Web E2E sáu loại câu hỏi | PASS |
| Time Attack | `time-attack-screen.tsx`, `time-attack-api.ts`, migration `20261118030000` | unit timer/session, SQL smoke, timing/concurrency integration, Web E2E | PASS |
| Ranked Arena | `ranked-screen.tsx`, `ranked-api.ts`, migrations `20261118040000`-`040200` | unit, SQL lifecycle/rating/security, Web E2E | PASS |
| Leaderboard & Season | `ranked-home.tsx`, RPC leaderboard/season admin | SQL ordering, privacy, lifecycle, reward idempotency | PASS |
| Mistake Review | `mistake-review-screen.tsx`, `mistake-review-api.ts`, migrations `20261118050000`-`050300` | unit, SQL scheduling/RLS/reward isolation, Web runtime | PASS |
| Quiz Admin | các component `arena-question-*`, migrations `20261118050400`-`050600` | 9 Admin tests, SQL management smoke, Next production build | PASS |
| CSV/XLSX import | `arena-question-import.ts` | CSV UTF-8, header/size validation, XLSX value-only, formula refusal | PASS |
| Gemini generation | Edge Function `arena-question-generate`, parser contract test trong CI | provider thật và timeout/rate-limit thật chưa chạy tại local | NOT TESTED |
| Android / iOS native | Expo Router screens | không có thiết bị/simulator trong phiên | NOT TESTED |

## 2. End-to-End Test Matrix

| Test ID | Module / môi trường | Kỳ vọng | Kết quả thực tế | Status | Evidence / fix |
|---|---|---|---|---|---|
| E2E-PRA-001 | Practice / Supabase local | catalog chỉ có câu published, đủ số lượng, chấm server-side | SQL smoke và integration qua Auth API đạt | PASS | `quiz_arena_practice_smoke.sql`, `supabase_arena_integration.py` |
| E2E-PRA-002 | Practice / Chromium 390 px | đăng nhập, setup, làm bài, kết quả; sáu loại câu hỏi; không text-node | 6/6 loại câu hỏi, `runtimeErrors: []` | PASS | `.tmp/arena-browser-result.json` (artifact local, không commit) |
| E2E-PRA-003 | Practice / Supabase local | retry không tạo attempt/reward trùng | duplicate submit đồng thời trả cùng kết quả; ledger không trùng | PASS | `supabase_arena_integration.py` |
| E2E-TIM-001 | Time Attack / Vitest | timer dựa trên deadline, background/foreground và clock lệch không thay quyền quyết định server | unit tests đạt | PASS | `time-attack-clock.test.ts`, `use-time-attack-session.test.ts` |
| E2E-TIM-002 | Time Attack / Supabase local | score/combo/life/expiry do server quyết định | SQL formula/boundary và API timing đạt | PASS | `quiz_arena_time_attack_smoke.sql`, `supabase_time_attack_integration.py` |
| E2E-TIM-003 | Time Attack / concurrent local API | start/answer/expiry đồng thời không nhân đôi, XP không đổi | integration đạt | PASS | `supabase_time_attack_integration.py` |
| E2E-RNK-001 | Ranked / Supabase local | rating tăng/giảm, history, finalize lặp idempotent | SQL smoke đạt; một rating event/match | PASS | `quiz_arena_ranked_smoke.sql` |
| E2E-RNK-002 | Ranked / Chromium 390/320 px | hoàn thành match và hiển thị rating; không runtime error | score 2020, rating 1020, `runtimeErrors: []` | PASS | `.tmp/ranked-browser-result.json` |
| E2E-LDB-001 | Leaderboard / Supabase local | weekly/season, tie-break ổn định, phân trang, vị trí bản thân | SQL smoke đạt | PASS | `quiz_arena_ranked_smoke.sql` |
| E2E-SEA-001 | Season / Supabase local | scheduled -> active -> closing -> finalized; không hai active season | lifecycle và repeated finalization đạt | PASS | `quiz_arena_ranked_smoke.sql` |
| E2E-MIS-001 | Mistake Review / Supabase local | lưu lỗi, lịch ôn, mastery và due date đúng; không farm reward | SQL smoke đạt | PASS | `quiz_mistake_review_smoke.sql` |
| E2E-ADM-001 | Admin / Node + Next build | import hợp lệ/không hợp lệ và route build được | 9/9 test, build thành công | PASS | `npm run test/build -w apps/admin` |
| E2E-AI-001 | Gemini thật | timeout, rate-limit, quota và structured output thật | không gọi provider trong phiên | NOT TESTED | cần môi trường staging có quota và secret |
| E2E-NAT-001 | Android | navigation, keyboard, theme, accessibility | không có thiết bị/emulator | NOT TESTED | chạy checklist native trước release |
| E2E-NAT-002 | iOS | navigation, keyboard, theme, accessibility | không có simulator/macOS | NOT TESTED | chạy checklist native trước release |
| E2E-LOAD-001 | tải lớn cô lập | latency/p95 với bank và leaderboard lớn | chưa có dataset/load harness đủ lớn | NOT TESTED | không chạy tải trên production |

## 3. Security Test Report

| Test ID | Mục tiêu | Kết quả | Status | Evidence |
|---|---|---|---|---|
| SEC-001 | learner không đọc answer key | direct read bị từ chối | PASS | Practice/Ranked SQL smoke và Auth integration |
| SEC-002 | user A không đọc/ghi session, answer, mistake của user B | cross-user API/RLS bị chặn | PASS | Arena, Ranked, Mistake SQL/integration |
| SEC-003 | client không sửa XP/rating/lives/leaderboard | direct mutation bị từ chối; RPC server-authoritative | PASS | Arena/Time Attack/Ranked smoke |
| SEC-004 | learner không thực hiện thao tác Admin | RPC create/publish/season/reward bị từ chối | PASS | question-management và ranked smoke |
| SEC-005 | SECURITY DEFINER dùng `search_path=''`, quyền execute giới hạn | db lint không báo lỗi mức error; smoke privileges đạt | PASS | `supabase db lint --local --level error`, SQL smoke |
| SEC-006 | không commit secret | scan chỉ thấy tên biến, role SQL và fake test keys | PASS | `rg` scan ngày kiểm định |
| SEC-007 | Edge Function giữ service/Gemini key phía server | mã chỉ đọc `Deno.env`; không trả key | PASS | static review `arena-question-generate/index.ts` |
| SEC-008 | Deno typecheck và contract test Edge Function trong chính máy kiểm định | Deno không được cài local | BLOCKED | CI đã cấu hình `deno check/test`, cần log CI mới |

Không tắt RLS. Không dùng service-role trong mobile/admin client. Leaderboard chỉ trả display name đã giới hạn, tier/rating/score và cờ `is_me`; không trả email, phone, token, answer hay lịch sử học riêng tư.

## 4. XP & Rating Integrity Report

| Test ID | Bất biến | Kết quả | Status |
|---|---|---|---|
| INT-001 | cùng reward source không cộng XP hai lần | uniqueness + concurrent retry giữ một ledger event | PASS |
| INT-002 | hai Practice session đủ điều kiện cùng ngày chỉ nhận một reward | race test giữ tổng reward 10 XP | PASS |
| INT-003 | Journey XP và history giữ nguyên sau Arena migration | fixture trước/sau giống nhau | PASS |
| INT-004 | Time Attack không tự thay Journey XP | integration xác nhận XP không đổi | PASS |
| INT-005 | Rating tách khỏi XP | Ranked smoke thay rating, không tạo XP | PASS |
| INT-006 | duplicate finalize không thay rating lần hai | chỉ một rating event và rating 1020 | PASS |
| INT-007 | season reward phát lại idempotent | repeated finalization không thêm reward | PASS |
| INT-008 | Mistake Review không farm XP/Ranked reward | review SQL không tạo reward ngoài chính sách | PASS |

`arena_player_ratings` được khóa `FOR UPDATE` khi đóng match; match, current rating và rating event nằm trong một transaction PostgreSQL. Unique constraint trên `arena_rating_events(match_id)` và reward ledger ngăn phát lặp.

## 5. Migration Verification Report

| Test ID | Kịch bản | Kết quả | Status |
|---|---|---|---|
| MIG-001 | schema trước Arena rỗng -> V2.1 | migration + Arena regression đạt | PASS |
| MIG-002 | schema có Journey/history/XP -> V2.1 | câu hỏi, key, completion, history, XP giữ nguyên | PASS |
| MIG-003 | V2.1 -> Time Attack | Practice snapshot/history/reward và Journey/XP giữ nguyên | PASS |
| MIG-004 | V2.1/V2.2 -> Ranked | Practice, Time Attack, Journey/XP giữ nguyên | PASS |
| MIG-005 | toàn bộ schema local | db lint error-level sạch; toàn bộ Arena SQL smoke đạt | PASS |
| MIG-006 | production snapshot thật | không được cấp quyền truy cập/triển khai | NOT TESTED |

Migration theo thứ tự tăng dần `20261118020000` tới `20261118050600`; các sửa schema là additive. Không reset database local dài hạn: checker tạo database clone tạm, chạy fixture, kiểm tra và xóa clone.

## 6. Bug Fix Summary

### BUG-V26-001 - P2 - Upgrade checker lỗi khi chạy trên schema tương lai

- Tái hiện: `supabase_arena_upgrade_check.py --time-attack` thất bại khi clone có migration Ranked/V2.5.
- Nguyên nhân: rewind test giữ trigger V2.4 tham chiếu cột `mode`, FK Ranked phụ thuộc unique constraint và thiếu seed `arena_topics` của V2.5.
- Sửa tập trung: bỏ trigger tương lai trong clone Time Attack, drop constraint bằng `CASCADE` chỉ trong clone, seed canonical topics khi bảng tồn tại.
- Regression: cả `--time-attack` và `--ranked` PASS; dữ liệu Journey/XP/Practice/Time Attack được giữ nguyên.
- Tệp: `scripts/supabase_arena_upgrade_check.py`.

Không xác nhận thêm defect P0/P1 trong lượt kiểm định này. Warning `MODULE_TYPELESS_PACKAGE_JSON` ở Admin test là cảnh báo hiệu năng của Node test loader, không làm sai kết quả build/runtime.

## 7. Release Checklist

- [x] Mobile typecheck, lint, 238/238 test.
- [x] Shared typecheck.
- [x] Admin lint, 9/9 test, Next production build.
- [x] Ruff và backend: 43 pass, 8 skip do integration environment.
- [x] Supabase db lint error-level.
- [x] Practice, Time Attack, Ranked, Mistake, Admin SQL smoke.
- [x] Auth/RLS, answer-key privacy và concurrent reward integration.
- [x] Empty-schema và historical-data migration checks.
- [x] Expo Web Arena runtime không có `Unexpected text node` trong harness đã chạy.
- [ ] Android thật hoặc emulator: NOT TESTED.
- [ ] iOS thật hoặc simulator: NOT TESTED.
- [ ] Gemini staging thật: NOT TESTED.
- [ ] Deno check/test có log CI mới: BLOCKED local.
- [ ] Backup production đã kiểm tra khả năng restore: cần Release Owner/DBA.

Điều kiện nâng từ **CONDITIONAL** lên **READY**: chạy CI Supabase/Deno trên commit ứng viên; smoke Android và iOS; chạy Gemini staging với timeout/rate-limit/quota; xác nhận backup restore và migration dry-run trên bản sao production đã ẩn danh.

## 8. Recovery & Rollback Plan

1. Trước migration, tạo backup PostgreSQL nhất quán và ghi lại version migration, checksum, số bản ghi của quiz attempts, XP events, ratings, matches, standings và question revisions.
2. Restore thử backup vào môi trường cô lập; không coi file backup tồn tại là đủ.
3. Tạm dừng Admin publish/import và season transition trong cửa sổ migration; không cần xóa lịch sử hay reset XP/rating.
4. Chạy migration theo đúng thứ tự bằng tài khoản triển khai tối thiểu; chạy db lint, SQL smoke và truy vấn đối soát ngay sau đó.
5. Nếu migration chưa commit, PostgreSQL tự rollback transaction. Nếu đã commit và lỗi ứng dụng, ưu tiên forward fix additive và feature flag/rollback ứng dụng.
6. Không `down migration` phá hủy bảng Arena trên production: việc đó có thể mất attempts, revisions, rating events và standings. Chỉ restore toàn bộ database khi có phê duyệt sự cố và chấp nhận điểm khôi phục.
7. Nếu chỉ Edge/Admin lỗi, rollback artifact ứng dụng/Edge về phiên bản trước trong khi giữ schema tương thích ngược.
8. Sau recovery, đối soát uniqueness reward/rating, counts lịch sử và lấy mẫu cross-user RLS trước khi mở traffic.

## 9. Known Limitations

- Android/iOS native, keyboard và accessibility bằng screen reader chưa được kiểm thử trong phiên.
- Gemini provider thật, quota, timeout và rate-limit chưa được gọi; chỉ có parser/contract và static review.
- Deno không có trên máy local; kết quả `deno check/test` phải lấy từ GitHub Actions của commit ứng viên.
- Chưa chạy load test quy mô production; chỉ có concurrency có kiểm soát trên Supabase local.
- Không kiểm thử migration trên snapshot production thật; chỉ dùng fixture lịch sử đại diện trong database clone.
- Tám backend integration test bị skip vì thiếu dịch vụ integration tương ứng; chúng không phải test Quiz Arena trực tiếp nhưng phải được xem trong gate toàn hệ thống.

## Lệnh tái kiểm tra chính

```powershell
npm.cmd run typecheck -w apps/mobile
npm.cmd run lint -w apps/mobile
npm.cmd run test -w apps/mobile
npm.cmd run lint -w apps/admin
npm.cmd run test -w apps/admin
npm.cmd run build -w apps/admin
npx.cmd supabase db lint --local --level error
.venv\Scripts\python.exe scripts/supabase_arena_upgrade_check.py --time-attack
.venv\Scripts\python.exe scripts/supabase_arena_upgrade_check.py --ranked
.venv\Scripts\python.exe scripts/supabase_arena_integration.py
.venv\Scripts\python.exe scripts/supabase_time_attack_integration.py
```
