# Migration Supabase V3 — trạng thái chưa hoàn tất

> Cập nhật 11/11/2026: Sau khi người dùng cho phép, migration quota MyMemory `20261111100000_mymemory_quota.sql` đã áp dụng lên database đang cấu hình và Edge Function `translate` đã triển khai riêng, trạng thái `ACTIVE`, `verify_jwt=true`. Gateway không đăng nhập trả 401. Sau bản sửa chọn bản khớp, người dùng xác nhận trên Expo Go `License → Giấy phép.` và `giấy phép → License`. Các ghi nhận “chưa deploy” bên dưới là trạng thái của ngày 10/11/2026; `study-plan` và `writing-grammar` vẫn chưa được triển khai trong lượt này.

Ngày 10/11/2026. **Chưa đạt Supabase-only. Không xóa `backend/`.** Báo cáo phân biệt code đã port, bản đã deploy và kiểm thử thực tế.

## Đối chiếu nghiệp vụ

| FastAPI cũ | Supabase thay thế | Trạng thái |
| --- | --- | --- |
| Auth, profile, onboarding, avatar | Supabase Auth, PostgREST, Storage, RPC onboarding | Code và local RLS đạt; Web/thiết bị live chưa thử |
| Dictionary, lưu từ | PostgREST/RLS và SQLite cache | Code và local RLS đạt |
| Real English, quiz ngữ cảnh | PostgREST/RLS, RPC quiz chấm server | Code và local test hai tài khoản đạt |
| Dịch văn bản tùy ý | Edge `translate` → MyMemory REST; quota RPC | Unit tests đạt, MyMemory trực tiếp hai chiều HTTP 200; **Edge chưa deploy remote** |
| Kế hoạch 7 ngày | Edge `study-plan`, quy tắc TS khớp Python v1, RPC lưu/hoàn thành/dời lịch | Local end-to-end đạt; **Edge chưa deploy remote**, mobile vẫn dùng FastAPI mặc định qua cờ `EXPO_PUBLIC_SUPABASE_PLAN_ENABLED=false` để giữ tính năng |
| Đọc XP/level/quest/badge, nhận thưởng/thông báo | RPC gamification, PostgREST thông báo | Local test và migration live rev19 đạt; mobile dùng Supabase |
| Journey, lesson detail, chấm bài, offline sync và cấp XP | RPC Supabase chấm đáp án, khóa bài, version nội dung, idempotency và thưởng XP trong giao dịch | Local E2E hoàn thành cả unit; mobile đã dùng RPC, migration live rev21; thiết bị thật chưa thử |
| Writing, grammar feedback, lịch sử | RPC lưu bản gốc/feedback và chấm theo quy tắc; Edge `writing-grammar` tùy chọn cho LanguageTool | Local E2E/RLS đạt, live migration rev22; mobile vẫn dùng FastAPI mặc định qua cờ `EXPO_PUBLIC_SUPABASE_WRITING_ENABLED=false` vì Edge chưa deploy |
| Admin CRUD, publish, audit, analytics | RLS/trigger và adapter Supabase đã chuẩn bị, kiểm thử hai tài khoản cục bộ | Chưa áp migration Admin lên database thật, cờ Admin vẫn tắt; FastAPI giữ nguyên |

## Migration, dữ liệu và bảo mật

- Migration additive 14–22 đã áp lên database đang cấu hình. Revision hiện tại `20261110_22`. Kiểm tra sau rev19: 1 profile, 4 tiến độ, 6 XP events, 1 reward claim; rev20–22 chỉ thêm hàm, không xóa dữ liệu. Sau rev22: 4 bài Writing đã phát hành và 0 bài đã nộp giữ nguyên. Baseline chỉ chạy trên Supabase **mới**, không áp lại lên database hiện hữu.
- `20261110110000_translation_quota.sql`: chỉ lưu bộ đếm, 10 lượt/phút, 50 lượt hoặc 5.000 ký tự/ngày/người, 400.000 ký tự/tháng dự án; RLS bật, anon/auth không đọc bảng trực tiếp. Provider hiện tại là MyMemory, không cần key.
- `20261110120000_learning_plan_rpc.sql`: khóa theo user, chỉ một plan active, giữ plan cũ ở trạng thái paused, task bài học không thể tự hoàn thành. Edge sinh lịch từ onboarding, bài đã học, 10 quiz gần đây và từ cần ôn; giữ phiên bản thuật toán 1.
- `20261110130000_gamification_rpc.sql`: overview từ dữ liệu server, claim thưởng dưới khóa giao dịch, idempotent và kiểm tra level/XP; client không có quyền ghi `xp_events`.
- `20261110140000_journey_read_rpc.sql` và `20261110150000_journey_submit_rpc.sql`: đọc bài không lộ đáp án, khóa bài tuần tự, chấm 5 dạng câu hỏi, kiểm tra nội dung ngoại tuyến, ghi lịch sử/XP/quest/badge trong cùng giao dịch. Hai tài khoản test hoàn thành cả unit; request lặp chỉ cấp XP một lần.
- `20261110160000_writing_rpc.sql`: chấm câu có cấu trúc, hướng dẫn tự xem lại đoạn văn, giữ bản gốc và feedback riêng, request lặp không tạo lịch sử mới. Chỉ service role của Edge được gắn feedback LanguageTool; khi provider thiếu, quy tắc vẫn chạy và lưu trạng thái `unavailable`.
- Thử Supabase local từ DB trống và hai tài khoản disposable: PASS cho Auth/RLS, profile, dictionary, Real English, quota, plan Edge/RPC/đổi mục tiêu/dời lịch, reward claim/thông báo/chặn truy cập chéo. Chưa kiểm tra concurrency nhiều kết nối hoặc thiết bị thật.

## Kiểm tra đã chạy

- `npm.cmd run check`: PASS; 92/92 tests qua Vitest hiện có (gồm 3 test adapter Admin), mobile/shared typecheck, mobile/admin lint và admin production build. Lượt lint cuối không có cảnh báo.
- Backend trên Supabase **cục bộ** với `ENGLIFY_TEST_DATABASE_URL` trỏ loopback: `48 passed`, không skip; migration Admin chưa áp production. Kiểm thử theo quyền RLS thay cho giả định bảng private không có bất kỳ GRANT nào; tài khoản thường vẫn đọc 0 đáp án.
- Ruff cho các migration/script mới: PASS. `git diff --check`: không có lỗi whitespace; cảnh báo chuyển LF/CRLF trên Windows không phải lỗi nội dung.
- `npx.cmd expo start --tunnel --clear` trong `apps/mobile`: Metro khởi động và tunnel được cấp; **chưa xác nhận render trên thiết bị**.
- Supabase Edge local `translate`: thiếu auth 401, input sai 422, kiểm tra trước đây qua runtime thật. MyMemory provider EN→VI/VI→EN/Unicode/error qua unit test PASS; gọi API MyMemory trực tiếp hai chiều HTTP 200, Edge remote **NOT TESTED**.
- `npx.cmd expo start --tunnel --clear` chạy được; Metro phục vụ `/journey`, `/writing`, `/translation` qua HTTP 200 sau lần bundle đầu. Browser automation vẫn lỗi khởi tạo nên Expo Web Console/LogBox **NOT TESTED**. JSX mới không dùng chuỗi/số trực tiếp với `&&`; cần mở các route trên Web, thao tác rồi xem lỗi `Unexpected text node`. iOS/Android thật **NOT TESTED**.
- E2E học viên/viết/Admin không phụ thuộc FastAPI **BLOCKED** vì các bản port chưa hoàn tất. Xem `docs/END_TO_END_TEST_RESULTS.md`.

## Chặn triển khai và việc tiếp theo

Supabase CLI đã đăng nhập. Lệnh deploy Edge lên dự án thật bị CLI chặn vì cần xác nhận rõ (`HostedMutationConsentRequiredError`), sau đó người dùng chọn **chưa deploy**; chưa có Function nào được deploy qua lượt này. MyMemory không yêu cầu key hoặc gói trả phí. Chỉ khi người dùng chủ động cho phép triển khai mới deploy Edge, thử live rồi bật `EXPO_PUBLIC_SUPABASE_PLAN_ENABLED=true` và `EXPO_PUBLIC_SUPABASE_WRITING_ENABLED=true` trên mobile.

Admin đã có bản RLS/adapter cục bộ, cần kiểm thử đầy đủ trước khi chuyển cờ. Người dùng đã chọn **chưa deploy** Edge; không triển khai plan/writing/translate lên dự án thật. MyMemory không yêu cầu key. Chạy E2E với hai user + admin, xác nhận lịch sử/XP/khóa bài, Web và thiết bị thật. Chỉ khi mọi consumer FastAPI đã biến mất, có Git checkpoint phục hồi và E2E đạt mới xóa `backend/` và config cũ. Không xóa backend trong trạng thái hiện tại.
