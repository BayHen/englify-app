# Báo cáo kiểm định Englify Writing V2.6

Ngày kiểm định: 18/11/2026  
Branch: `feature/writing-practice-ux`  
Phạm vi: Writing V2.1–V2.5, mobile Expo SDK 58, Admin, Supabase migrations/RLS/Edge Functions và CI.  
Quyết định phát hành: **CONDITIONAL**.

Không phát hiện lỗi P0/P1 còn mở sau khi sửa lỗi dọn nhầm draft. Tuy nhiên chưa được phép triển khai production và môi trường hiện tại không cho kiểm thử Gemini thật, trình duyệt tự động, Android hoặc iOS thật. Chỉ triển khai sau khi hoàn thành các gate thủ công ở cuối tài liệu.

## 1. Ma trận kiểm định

| Tính năng | Mã nguồn chính | Bằng chứng kiểm thử | Trạng thái |
|---|---|---|---|
| AI Writing Coach | `supabase/functions/writing-ai-coach`, `_shared/writing-ai.ts`, `ai-feedback.tsx` | Validation, malformed response, quota, timeout, JWT/Edge unit test; SQL RLS | PASS |
| AI Rewrite (5 chế độ) | `writing-ai-rewrite`, `writing-ai.ts` | Unit test cho grammar/natural/vocabulary/formal/simple và bảo toàn original | PASS |
| Gemini thật trên production | Edge Functions và Edge Secrets | Không gọi API trả phí/production trong audit; chưa có phiên E2E được cấp quyền | NOT TESTED |
| CEFR A1–C1 | migration `20261117020000`, `writing-library-screen.tsx` | SQL smoke kiểm tra tối thiểu 10 bài đã publish mỗi level; RPC preference | PASS |
| Topics, search, filter, pagination | `englify_writing_library`, mobile library | SQL search `meeting`, page size 5; mobile API/unit/typecheck | PASS |
| 7 loại bài Writing | migration/seed V2.2 | Constraint và seed cho sentence, fill blank, order, paragraph, email, opinion, essay; deterministic/open grading smoke | PASS |
| Daily Challenge | migration `20261117030000`, `daily-writing-panel.tsx` | Assignment ổn định, CEFR, unpublished fallback, invalid/valid/retry | PASS |
| XP và badge | `englify_submit_daily_writing` | SQL transaction smoke + hai request đồng thời; đúng một completion và một XP event | PASS |
| Streak/timezone | migration V2.3 | ICT, UTC, DST New York, missed day, 3-day badge | PASS |
| Writing Analytics | migration `20261117040000`, progress screens | Empty state, qualification, latest score, rewrite exclusion, pagination, cross-user detail | PASS |
| Draft autosave Web | `draft-storage.web.ts` | 6 unit tests: restore, stale revision, account/context isolation, storage error, malformed record, context switching | PASS |
| Draft autosave SQLite | `draft-storage.ts` | Typecheck/export và review SQL; không có thiết bị SQLite thật | NOT TESTED |
| Admin Writing | `apps/admin/src/lib/supabase-admin.ts`, `page.tsx` | Admin build; SQL create/update/archive/audit và learner denial | PASS |
| Android/iOS UI | Expo mobile | Không có thiết bị/emulator được điều khiển trong phiên | NOT TESTED |
| Expo Web runtime | route `/writing`, `/writing-progress` | Export đạt; công cụ browser lỗi Windows sandbox trước khi mở trang | BLOCKED |

`PASS` chỉ được dùng khi có lệnh kiểm thử hoặc invariant SQL cụ thể. Export/bundle không được dùng thay cho kiểm thử runtime.

## 2. Lỗi đã sửa

### W26-001 — P0: có thể xóa nhầm draft khi submit đang chạy

- Tái hiện bằng code review: `clearSubmitted(revision)` lấy `current.current.contextKey` tại thời điểm response về. Nếu người dùng rời bài A và mở bài B trong lúc request A đang chạy, cleanup có thể nhắm vào draft B.
- Nguyên nhân: context submit không được đóng băng cùng revision.
- Sửa: `clearSubmitted(contextKey, revision)` bắt buộc nhận context snapshot của request. Storage chỉ xóa đúng `user_id + context_key` và `revision <= submittedRevision`.
- Regression: test `clears only the submitted context while another exercise is active` xác nhận draft đang mở ở context khác được giữ nguyên.
- Bổ sung: trạng thái save không còn báo `saved` nếu trong lúc flush cũ đã phát sinh pending revision mới.

Không thay đổi schema production cho lỗi này.

## 3. Kết quả kiểm thử

| ID | Hạng mục / môi trường | Kết quả thực tế | Trạng thái | Bằng chứng |
|---|---|---|---|---|
| W26-M01 | Mobile TypeScript / Windows | Không có lỗi | PASS | `npm.cmd run typecheck -w apps/mobile` |
| W26-M02 | Mobile ESLint / Windows | Không có lỗi | PASS | `npm.cmd run lint -w apps/mobile` |
| W26-M03 | Mobile unit/regression | 47 files, 183 tests đạt | PASS | `npm.cmd test -w apps/mobile` |
| W26-M04 | Expo Web export | Bundle `writing` và `writing-progress` được tạo | PASS | `npx.cmd expo export --platform web --clear` |
| W26-M05 | React Native Web runtime/Console | Browser automation không khởi tạo được do `windows sandbox ... helper_unknown_error` | BLOCKED | Không tuyên bố runtime PASS |
| W26-M06 | Android/iOS thật | Không có thiết bị được kiểm thử trực tiếp | NOT TESTED | Quy trình thủ công ở mục 8 |
| W26-A01 | Admin lint/test/build | lint đạt, 6/6 test đạt, Next build đạt | PASS | lệnh ở mục 7 |
| W26-D01 | Migration từ schema trống | 21 migration + seed áp thành công | PASS | `npx.cmd supabase db reset` |
| W26-D02 | Upgrade từ pre-V2 có dữ liệu lịch sử | Body, feedback, word count và metadata được bảo toàn | PASS | `supabase_writing_upgrade_fixture.py` |
| W26-D03 | Database lint | Không có schema error | PASS | `npx.cmd supabase db lint --level error` |
| W26-D04 | SQL security/Writing smoke | 5/5 file đạt | PASS | security definer + V2.1–V2.4 smoke |
| W26-D05 | Auth/RLS integration | Auth/RLS, Writing và Admin isolation đạt | PASS | `scripts/supabase_local_integration.py` |
| W26-D06 | Concurrent Daily Writing | Hai request đồng thời chỉ tạo 1 completion, 1 XP event | PASS | `scripts/supabase_writing_daily_concurrency.py` |
| W26-E01 | Edge shared logic | malformed output, quota, timeout, auth và mode sai đạt qua Vitest | PASS | `writing-ai*.test.ts` |
| W26-E02 | Deno typecheck local | Máy không có executable `deno` | BLOCKED | CI cài `denoland/setup-deno@v2` rồi chạy `deno check` |
| W26-S01 | Secret scan tracked files | Không tìm thấy service key, DB password hoặc Gemini key thật | PASS | `git grep` có loại trừ fixture key cố ý |
| W26-P01 | Ruff script V2.6 | `All checks passed!` | PASS | `.venv\Scripts\ruff.exe check ...` |

## 4. Bảo mật và tính toàn vẹn

- RLS tách submissions, AI feedback, rewrites, revisions, daily assignments/completions và analytics theo `auth.uid()`.
- Edge Function xác thực JWT qua Auth API, truy vấn submission bằng JWT người dùng và xác nhận `user_id` trước khi dùng service role để ghi kết quả.
- Mobile không chứa service-role key hoặc Gemini key. `GEMINI_API_KEY` chỉ thuộc Edge Secrets.
- Input Edge bị giới hạn 1.200 byte cho envelope, body đã lưu 20–5.000 ký tự cho AI; model, token limit và daily quota có allow-list/bounds.
- `SECURITY DEFINER` Writing dùng `SET search_path=''`; quyền execute nhạy cảm chỉ cấp đúng role. Smoke test quyền đạt.
- XP là server-authoritative, transaction/advisory lock + unique constraints bảo vệ retry và concurrent request. Client không truyền số XP.
- Rewrite và retry AI không đi qua XP RPC.
- Draft local được namespace theo user/context. Dữ liệu draft trên SQLite/localStorage **không mã hóa at rest**; không lưu token/API key nhưng nội dung bài viết có thể nhạy cảm. Đây là rủi ro còn lại cần chấp nhận hoặc thiết kế mã hóa riêng trước khi yêu cầu mức bảo vệ cao hơn.
- Local Supabase config mở CIDR phục vụ Docker development; không được sao chép thiết lập này thành network policy production.

## 5. Migration và khôi phục

Đã kiểm tra hai đường:

1. Schema trống → toàn bộ migration hiện tại + development seeds.
2. Schema đến `20261116010000` → chèn user/exercise/submission/feedback lịch sử → áp V2.1–V2.4 → xác minh dữ liệu không đổi → reset lại local mới nhất.

Chiến lược production là forward-only:

1. Chụp backup và ghi lại migration version hiện tại.
2. Chạy kiểm tra trên preview/staging từ bản sao dữ liệu đã ẩn danh.
3. Áp migration theo đúng thứ tự `20261117010000` đến `20261117040000`.
4. Chạy db lint, RLS smoke và truy vấn kiểm kê số submission trước/sau.
5. Chỉ sau đó deploy hai Edge Functions; giữ `WRITING_AI_ENABLED=false` cho đến khi health/config gate đạt.

Nếu migration thất bại: dừng deploy Edge/UI phụ thuộc, lưu log và trạng thái migration, không chạy reset/retry mù trên production. Vì migration thêm bảng/cột và backfill, ưu tiên migration sửa tiếp (forward recovery). Chỉ khôi phục backup khi xác nhận transaction/DDL để lại trạng thái không thể sửa an toàn.

Nếu Edge Function lỗi sau deploy: tắt `WRITING_AI_ENABLED`, rollback function về artifact trước đó; deterministic feedback, submissions, history và draft local vẫn hoạt động.

## 6. Hiệu năng

- Draft debounce 750 ms; flush khi background/unmount; revision tăng đơn điệu và cleanup có điều kiện.
- History và catalog có page size giới hạn; draft/cache local giới hạn 100 mục.
- Analytics dùng index theo user/date, CEFR/topic và latest AI score; không thấy N+1 từ mobile cho danh sách chính.
- Edge timeout 5–8 giây cho Auth/REST và 20 giây cho Gemini; không có retry loop tự động.
- Chưa profile typing FPS, memory hoặc SQL `EXPLAIN ANALYZE` trên tập dữ liệu production-scale: NOT TESTED.

## 7. Lệnh đã chạy

```powershell
npm.cmd run typecheck -w apps/mobile
npm.cmd run lint -w apps/mobile
npm.cmd test -w apps/mobile
npx.cmd expo export --platform web --clear

npm.cmd run lint -w apps/admin
npm.cmd test -w apps/admin
npm.cmd run build -w apps/admin

npx.cmd supabase db reset
npx.cmd supabase db lint --level error
python scripts/run_local_sql_test.py supabase/tests/security_definer_privileges_smoke.sql supabase/tests/writing_ai_v2_smoke.sql supabase/tests/writing_v2_2_smoke.sql supabase/tests/writing_v2_3_smoke.sql supabase/tests/writing_v2_4_smoke.sql
python scripts/supabase_local_integration.py
python scripts/supabase_writing_daily_concurrency.py
.\.venv\Scripts\ruff.exe check scripts/supabase_writing_upgrade_fixture.py scripts/supabase_writing_daily_concurrency.py scripts/supabase_local_integration.py
```

## 8. Gate thủ công bắt buộc trước production

### Expo Web

1. Chạy `cd apps/mobile` rồi `npx.cmd expo start --web --clear`.
2. Đăng nhập tài khoản test, mở `/writing` và `/writing-progress`.
3. Thử autosave → đổi route → mở lại; submit lỗi rồi retry; đổi bài trong lúc request chậm.
4. Kiểm tra Console/LogBox không có `Unexpected text node: A text node cannot be a child of a <View>`.
5. Thử light/dark, zoom 200%, keyboard, screen reader và reduced motion.

### Android/iOS Expo Go

1. Chạy `cd apps/mobile` rồi `npx.cmd expo start --tunnel --clear`.
2. Trên mỗi nền tảng: nhập draft, background/kill app, mở lại và xác nhận restore SQLite.
3. Tắt mạng: tiếp tục nhập và xác nhận `Offline — saved locally`; submit/AI phải bị chặn nhưng draft còn nguyên.
4. Bật mạng, submit; xác nhận history có đúng body và chỉ draft cùng revision bị dọn.
5. Kiểm tra bàn phím, text scaling, VoiceOver/TalkBack, touch target và hai theme.

### Gemini/Edge staging

1. Dùng project staging Free tier, không dùng dữ liệu khách hàng.
2. Deploy migration và `writing-ai-coach`, `writing-ai-rewrite`; cấu hình secret theo `.env.example`.
3. Giữ giới hạn tối đa 5 coach + 5 rewrite/ngày/người và cost cap 0 USD.
4. Thử response hợp lệ, malformed/provider unavailable, 429, timeout, request lặp và cross-user submission ID.
5. Xác nhận log không có bài viết đầy đủ, access token hoặc key.

## 9. Checklist phát hành

- [x] Không còn lỗi mất draft đã biết.
- [x] Không có đường nhân đôi XP đã biết; concurrent test đạt.
- [x] Migration schema trống và upgrade lịch sử đạt trên local.
- [x] RLS/cross-user automated tests đạt.
- [x] Mobile typecheck/lint/unit và Admin lint/test/build đạt.
- [ ] Deno check chạy thành công trên CI mới.
- [ ] GitHub Actions của commit thực tế xanh.
- [ ] Expo Web runtime/manual Console đạt.
- [ ] Android và iOS thật đạt.
- [ ] Gemini Edge E2E trên staging đạt.
- [ ] Backup, staging rehearsal và production change window được phê duyệt.

## 10. Quyết định

**CONDITIONAL** — mã và database local không còn lỗi P0/P1 đã biết, nhưng chưa đủ bằng chứng để tuyên bố READY. Không deploy production cho đến khi các mục chưa đánh dấu trong checklist hoàn tất. Không có migration, Edge Function hay dữ liệu production nào được thay đổi trong V2.6.

