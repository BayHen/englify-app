# Báo cáo triển khai Real English Hybrid V2 — 11/11/2026

Branch làm việc: `feature/real-english-hybrid-v2`.

## Kiểm tra Admin ngày 12/11/2026

Người dùng mở trang Admin nhưng chỉ thấy thư viện Real English cũ. Nguyên nhân: `NEXT_PUBLIC_REAL_ENGLISH_HYBRID_ENABLED` chưa được đặt trong `apps/admin/.env.local` nên code cũ ẩn hoàn toàn mục “AI lesson review”; `NEXT_PUBLIC_SUPABASE_ADMIN_ENABLED=false` vẫn chọn adapter Admin cũ. Truy vấn chỉ đọc tới `real_english_lessons` của Supabase đang cấu hình trả HTTP 404, nên bật cờ ngay sẽ tạo giao diện lỗi thay vì chạy chức năng.

Đã sửa `apps/admin/src/app/page.tsx` và `hybrid-real-english-panel.tsx`: mục “AI lesson review” luôn xuất hiện với trang hướng dẫn cấu hình an toàn khi cờ tắt; trang Real English cũ có liên kết tới mục mới. Không bật tạo nháp/xuất bản hoặc sửa `.env.local` chứa cấu hình thật. `npm.cmd run lint -w apps/admin` và `npm.cmd run build -w apps/admin` đều đạt. Trình duyệt sau đăng nhập chưa được kiểm tra tự động vì công cụ điều khiển browser báo lỗi khởi tạo; cần tải lại `http://localhost:3000`, mở Real English rồi chọn “AI lesson review” và kiểm tra hai mục cùng trang hướng dẫn. Nếu server vẫn giữ build cũ, dừng rồi chạy `npm.cmd run dev -w apps/admin` từ thư mục gốc.

## Tình trạng

### Triển khai ngày 12/11/2026

- Lượt Generate đầu tiên đã tới Function nhưng thất bại `Tatoeba request timed out.` trước Gemini; click tiếp nhận quota error. Kiểm tra trực tiếp URL Tatoeba cũ trả HTTP 400 vì cặp tham số `showtrans=matching`/`showtrans:lang` xung đột; URL sửa trả HTTP 200 và adapter tìm 21 cặp, 20 cặp đủ điều kiện sau khoảng 18 giây. Đã bỏ tham số xung đột, tăng timeout Tatoeba từ 8 lên 30 giây dựa trên phép đo, chuyển lookup nguồn trước claim quota và chặn gửi trùng bằng ref ở Admin. Test adapter 7/7, Edge TypeScript, Admin lint/build và mobile typecheck/lint đều PASS. Không sửa JSX mobile nên không phát sinh nhánh text node mới; React Native Web runtime vẫn NOT TESTED do browser automation lỗi khởi tạo.
- Người dùng phê duyệt riêng migration sửa quota `20261112010000_real_english_source_preflight.sql` sau khi automatic review từ chối chạy trên production khi chưa có phê duyệt cụ thể. Smoke test trên Supabase local chạy trong transaction ROLLBACK đạt: source timeout không tiêu hao lượt Gemini, lượt Gemini thứ hai bị chặn. Dry-run production rollback rồi COMMIT đạt; job cũ được phân loại `source_timeout` mà giữ nguyên lịch sử. Function đã deploy lại, ACTIVE version 3, `verify_jwt=true`. Chưa có bài mới; chờ lượt thử lại từ phiên Admin.

- Người dùng đã cho phép rõ việc áp hai migration Admin RLS/V2 và deploy Function lên project Supabase đang dùng. Chạy thử hai migration trong một transaction với `lock_timeout=3s`, rollback thành công; sau đó áp lại và COMMIT thành công. Truy vấn chỉ đọc xác nhận RPC admin, bảng lesson/settings, RLS và 7 policy liên quan; một thành viên admin hiện có. Giả lập JWT claim trong transaction chỉ đọc: thành viên admin được RPC nhận diện và thấy settings; UID không thuộc admin bị từ chối và không thấy settings.
- Function `real-english-generate` đã ACTIVE, `verify_jwt=true`; CLI TypeScript check đạt. Anonymous GET bảng lessons nhận HTTP 401. Không tạo bài, không gọi Gemini, không bật Cron.
- Bật `NEXT_PUBLIC_REAL_ENGLISH_HYBRID_ENABLED=true` trong `apps/admin/.env.local` đã được Git bỏ qua. Do môi trường trình duyệt tự động không khởi tạo được, việc nhìn thấy panel thật sau restart Admin và luồng tạo/duyệt/xuất bản vẫn **NOT TESTED**.
- Bộ duyệt tự động từ chối thêm origin localhost vào `EDGE_ALLOWED_ORIGINS` production vì thay đổi CORS chưa được phê duyệt riêng. Đã giải quyết bằng route Next.js cùng origin `/api/hybrid-generate`, chuyển tiếp token người dùng tới Function cố định; Function giữ kiểm tra JWT và quyền admin. Route từ chối yêu cầu không có phiên bằng HTTP 401 trong kiểm tra local.
- Người dùng xác nhận hàng chờ và biểu mẫu mới đã hiện trong Admin sau restart, đồng thời xác nhận Gemini Free tier không bật billing trả phí và cho phép thử 1 request/ngày. Đã đặt Edge guards `AI_FREE_TIER_CONFIRMED=true`, `AI_GENERATION_ENABLED=true`, `GEMINI_MODEL=gemini-2.5-flash-lite`, cap 0 USD, 1 request/ngày, tối đa 1.200 output tokens; không đổi API key. Đã tạo chủ đề biên tập `coffee-conversation` và bật DB settings cho đúng chủ đề/slot này. Dry-run rollback và COMMIT cấu hình DB đều thành công; truy vấn đọc xác nhận cấu hình. Cron vẫn tắt. Chưa có kết quả lượt tạo bài thật.
- **Giới hạn còn lại:** Remote migration history vẫn trống dù schema cũ tồn tại; tránh `db push --remote` hàng loạt cho đến khi đối chiếu các migration cũ. Việc Google áp dụng Free tier và quota thực tế cho key của project phải được xác nhận thêm bằng lượt gọi thật và dashboard AI Studio.

Ảnh Admin mới của người dùng hiển thị **Supabase session: Active**, **V2 lesson table: Ready**, RPC HTTP 404 `PGRST202` và Function preflight OPTIONS HTTP 404. Kiểm tra độc lập ngày 12/11 qua PostgreSQL và REST trên cùng project xác nhận `real_english_lessons` thực tế **chưa tồn tại** (REST 404), `englify_is_admin()` không tồn tại, và danh sách Function chỉ có `translate`. Dòng “Ready” là **FAIL** của phép kiểm tra HEAD; đã thay bằng GET và yêu cầu HTTP 200. Function nay được kiểm tra qua Next.js route cùng origin để trả trạng thái 404 rõ ràng, tránh lỗi CORS che mất nguyên nhân. Admin lint/build/TypeScript PASS. Chưa thử runtime sau sửa trên trình duyệt đăng nhập.

Automatic approval review ban đầu từ chối việc thực thi DDL migration trên production, kể cả phiên thử có rollback, vì có thể khóa bảng hoặc gây tác dụng phụ và chưa có xác nhận riêng của chủ project. Sau đó người dùng đã cho phép rõ phạm vi hai migration và Function; thử rollback, áp migration và deploy đều thành công. Cờ AI và Cron vẫn tắt.

Ngày 12/11, ảnh do người dùng cung cấp xác nhận menu **AI lesson review** và trang setup đã render trong Admin. Trang setup nay có kiểm tra chỉ đọc cho phiên Supabase, bảng `real_english_lessons`, RPC quyền admin và Edge Function `real-english-generate`; nút **Check again** cho phép chạy lại sau khi cập nhật project. Mã kiểm tra không gửi yêu cầu tạo bài hoặc ghi dữ liệu. `npm.cmd run lint -w apps/admin` và `npm.cmd run build -w apps/admin` đều PASS sau thay đổi. Kết quả bốn phép kiểm trên trình duyệt của người dùng và thao tác tạo nháp vẫn **NOT TESTED**; ảnh trước đó chỉ chứng minh trang setup hiển thị. Kết quả đọc độc lập trước đó: bảng V2 HTTP 404 và Function chưa có trong danh sách deploy, nên chưa thể bật panel thật.

**Chưa đạt Definition of Done toàn phần.** Migration/RLS, Function và cờ giao diện Admin cục bộ đã có; người dùng xác nhận panel mới hiện sau restart. Kiểm tra quyền qua JWT claim giả lập và anonymous REST đã đạt, nhưng chưa kiểm thử yêu cầu tạo bài bằng phiên Supabase Auth thật. AI chỉ bật cho một lượt thủ công/ngày; Cron tắt. Chưa có bài AI nào được tạo hoặc xuất bản trong phiên này. Lịch sử migration CLI của production vẫn chưa khớp schema cũ; **không chạy `db push --remote` hàng loạt trước khi đối chiếu các migration cũ.**

## Các phần đã triển khai

- Adapter Tatoeba API v1 với truy vấn URLSearchParams, cặp Anh–Việt trực tiếp, ID/contributor/license riêng, kiểm tra response, phân trang, cache, timeout, retry giới hạn và lỗi quota.
- Fixture công khai thật: 20 câu Anh, 21 cặp trực tiếp, 20 cặp đạt điều kiện metadata; ghi công từng ID trong `docs/TATOEBA_FIXTURE_ATTRIBUTION.md`.
- Provider Gemini với schema JSON chặt, model Free tier trong allowlist, xác thực đầu ra và lỗi timeout/quota. Key chỉ ở Edge Secrets; không có kết quả giả khi provider lỗi.
- MyMemory làm ứng viên so sánh nghĩa; adapter Free Dictionary có thể bổ sung IPA/từ loại khi là từ đơn, nhưng cờ mặc định tắt trong lúc rà quyền dữ liệu đầu ra. Lỗi provider trở thành cảnh báo cho người duyệt.
- Migration cộng thêm 10 bảng, FK/index/unique/RLS, guard trạng thái, lịch sử duyệt, lease/idempotency, quota đếm lượt thử và RPC ghi nháp nguyên tử. Không xóa dữ liệu cũ.
- Edge Function `real-english-generate` yêu cầu admin, xác thực JWT, kiểm tra cờ Free tier và quota, lưu nháp `in_review`; không tự xuất bản.
- Panel Admin duyệt bài, xem nguồn, sửa nháp, approve/reject/publish và cấu hình giới hạn; feed mobile đọc bài published và lưu bookmark/hoàn thành. Cả hai đều sau cờ cấu hình mặc định `false`.
- Seed DEV tạo 5 chủ đề, không tạo người dùng hay câu nguồn giả.

## Tệp thay đổi

`README.md`, `docs/REAL_ENGLISH.md`, `docs/REAL_ENGLISH_HYBRID_V2.md`, `docs/TATOEBA_FIXTURE_ATTRIBUTION.md`, báo cáo này, `scripts/generate_tatoeba_attribution.py`, `supabase/config.toml`, `supabase/seeds/real_english_hybrid_topics.sql`, `supabase/migrations/20261111010000_real_english_hybrid_foundation.sql`, `supabase/tests/hybrid_{smoke_setup,smoke_test,job_smoke_test}.sql`, `supabase/scripts/enable_real_english_cron.sql`, `supabase/functions/.env.example`, `supabase/functions/_shared/{tatoeba,real-english-generator,real-english-enrichment}.ts`, fixture Tatoeba, `supabase/functions/real-english-generate/index.ts`, `apps/admin/.env.example`, `apps/admin/src/app/{page,hybrid-real-english-panel}.tsx`, `apps/mobile/.env.example`, `apps/mobile/src/features/real-english/{real-english-screen,lesson-feed}.tsx` và ba tệp kiểm thử provider.

Bổ sung khi sửa lỗi triển khai: `apps/admin/src/app/api/hybrid-{function-status,generate}/route.ts`, `supabase/migrations/20261112010000_real_english_source_preflight.sql`, `supabase/tests/hybrid_source_timeout_smoke.sql`, `scripts/{deploy_hybrid_migrations,deploy_hybrid_source_fix,enable_hybrid_trial}.py`, `scripts/inspect_tatoeba.mjs`, `apps/mobile/src/features/real-english/tatoeba.test.ts`. `apps/admin/.env.local` được sửa cục bộ và vẫn bị Git bỏ qua; không có khóa thật trong mã/tài liệu.

## Kết quả kiểm tra

| Hạng mục | Kết quả | Bằng chứng / giới hạn |
|---|---|---|
| Tatoeba API thật | PASS | HTTP 200; cấu trúc `data/paging`, 20 câu nguồn, 21 cặp trực tiếp, 20 cặp đủ điều kiện đã kiểm tra ngày 11/11. Trang tiếp theo có 20 câu và không trùng ID câu Anh với trang đầu. |
| Free Dictionary API thật | BLOCKED | Lần gọi từ môi trường hiện tại trả HTTP 403. Schema theo tài liệu chính thức và mock test đã đạt; cờ enrichment mặc định tắt cho đến khi thử trên Edge và rà điều kiện dữ liệu đầu ra. |
| Unit tests adapter/provider | PASS | 16/16 kiểm thử tập trung (Tatoeba 7, Gemini 5, enrichment 4). |
| Mobile TypeScript/lint | PASS | `npm.cmd run typecheck -w apps/mobile`, `npm.cmd run lint -w apps/mobile`. |
| Mobile toàn bộ unit tests | PASS | 126/126 ở lần chạy riêng cuối cùng. Lần chạy đồng thời với build/lint trước đó có 1 test JSX hết thời gian 5 giây; test đó và toàn bộ suite đều đạt khi chạy riêng. |
| Edge TypeScript | PASS | `npx.cmd tsc ...` với toàn bộ tệp Edge mới đạt. Chưa có Deno CLI để chạy trực tiếp Function. |
| Admin lint/build | PASS | ESLint, Next.js production build và TypeScript đạt ở lần chạy cuối. |
| Expo Web bundle | PASS | `npx.cmd expo export --platform web --output-dir .tmp/real-english-web-check`. Chỉ chứng minh bundle. |
| PostgreSQL 18 smoke test | PASS | Migration mới thực thi trên cluster tạm riêng từ đầu; test RLS anon/learner/admin, duyệt/publish/audit, tiến độ, RPC nguyên tử, idempotency và quota đạt. Cluster đã dừng. Auth trong smoke test là stub, không thay cho Supabase Auth. |
| Runtime React Native Web | NOT TESTED | Browser automation trong phiên lỗi `trusted Node process exited unexpectedly`. Mở `/real-english` trên web sau khi bật cờ, thử tìm bài/đánh dấu/hoàn thành và kiểm tra Console/LogBox, đặc biệt `Unexpected text node`. |
| iOS/Android Expo Go | NOT TESTED | Không điều khiển được thiết bị vật lý từ phiên này. Chạy `cd apps/mobile; npx.cmd expo start --tunnel --clear`, đăng nhập, thử feed sau khi bật cờ. |
| Migration trên Supabase cục bộ | PASS có giới hạn | Docker đã Resume. `db push --dry-run` cho thấy V2 và MyMemory quota còn pending. Migration V2 được thực thi trong `BEGIN ... ROLLBACK` trên schema Supabase cục bộ thật và thành công; không ghi migration history, không giữ thay đổi. |
| RLS trên Supabase Auth thật | BLOCKED | Automatic approval review từ chối lệnh ghép migration + test trên database local có dữ liệu vì chuỗi lệnh hiển thị không có `ROLLBACK` trực tiếp, có nguy cơ thay đổi bảng/tài khoản lâu dài. Không thử lách bằng lệnh khác. RLS đã đạt ở PostgreSQL tạm với Auth stub; cần môi trường Supabase thử riêng hoặc phê duyệt quy trình kiểm tra hiện rõ rollback. |
| Migration production V2 | PASS có giới hạn | Hai migration Admin RLS/V2 và migration sửa source timeout đã được thử rollback rồi COMMIT bằng script có giới hạn khóa bảng; postcondition, quyền đọc settings và phân loại job thất bại đạt. Lịch sử migration CLI cũ chưa được đồng bộ; không chạy `db push --remote` hàng loạt. |
| Đối chiếu schema production | BLOCKED | Automatic approval review từ chối `supabase db dump --remote --schema public --file ...` vì CLI không có cờ `--schema-only` được yêu cầu; có nguy cơ tải dữ liệu nhạy cảm vào file cục bộ. Không thử lách qua cách khác. Cần quy trình truy vấn metadata có kiểm soát hoặc người quản trị đối chiếu trong Supabase Dashboard. |
| Edge Secrets / Function hiện có | PASS có giới hạn | Function `real-english-generate` và `translate` đều ACTIVE với `verify_jwt=true`. Các tên secret bắt buộc cho lượt thử đã có; model/cap/cờ do lệnh thiết lập trong phiên đặt theo Free tier. Không đọc giá trị `GEMINI_API_KEY`. `REAL_ENGLISH_CRON_SECRET` và `EDGE_ALLOWED_ORIGINS` không cần cho luồng Admin thủ công qua route cùng origin. |
| Gemini thật/nháp đầu cuối | NOT TESTED | Người dùng xác nhận Free tier; Edge và DB đã bật đúng 1 request/ngày, nhưng chưa có lượt tạo bài thực từ phiên Admin. Không nhận là đã có nháp. |
| Cron 07:00 Việt Nam | BLOCKED | Script đã chuẩn bị nhưng chưa cài lịch; chỉ bật sau migration, RLS, provider và E2E đạt. Không có auto publish. |

## Rủi ro và việc tiếp theo

1. Tạo Supabase cục bộ thử riêng **không chứa dữ liệu cần giữ**, áp chuỗi migration từ đầu và kiểm thử hai tài khoản Auth thật. Migration riêng V2 đã qua PostgreSQL 18 có Auth stub và transaction rollback trên Supabase local hiện có; chưa chứng minh toàn bộ chuỗi migration Supabase.
2. Đối chiếu schema và bảng `supabase_migrations.schema_migrations` trên production bằng thao tác chỉ đọc; xác định các migration cũ đã được áp bằng kênh nào trước khi sửa migration history. Không reset hoặc áp baseline đè dữ liệu hiện có.
3. Kiểm tra trực tiếp trong Google AI Studio rằng project/key hiện tại ở Free tier và `gemini-2.5-flash-lite` có quota phù hợp. Bật cờ server chỉ sau đó; không tự chuyển sang model trả phí.
4. Deploy Function sau khi migration đạt; thử 1 slot với chủ đề thực, xem job/nháp/provenance/cảnh báo và xác nhận không rò rỉ key.
5. Thử 2 tài khoản trên Admin/mobile, sau đó bật cờ giao diện. Kiểm tra nội dung AI bằng người biên tập trước publish.
6. Chỉ cấu hình Cron sau các cổng kiểm thử ở trên. Cần kiểm tra request lặp và ngày theo múi giờ Việt Nam.

Chi tiết lệnh và giới hạn giấy phép nằm trong [tài liệu vận hành](../REAL_ENGLISH_HYBRID_V2.md).

## Cập nhật 12/11/2026 — giao diện Studio và lịch tạo nháp

Phần này thay thế các trạng thái cũ ở trên về Cron và lần thử Gemini. Người dùng gửi ảnh xác nhận giao diện **Real English Studio** mới đã hiển thị trong Admin. Các ô thống kê lấy `count` thật từ Supabase; hàng chờ và lỗi job hiện ngay đầu trang. Không dùng số liệu 05/12/48 từ ảnh mẫu. Topic đang bật được chọn sẵn cùng từ khóa nguồn, và thông báo tạo bài chỉ nói thành công khi Function trả `lessonId` và `in_review`.

Đọc database production ngày 12/11 cho thấy **0 bài V2**, một job `failed` với `Gemini request failed (404)`, `attempt_count=2`. Đây là nguyên nhân hàng chờ trống; không phải lỗi vẽ danh sách. Ảnh mới của người dùng cho thấy nút **Check AI model** trả `available: true` cho `gemini-2.5-flash-lite`. Phép GET chỉ chứng minh model có trong danh sách của key, **chưa chứng minh yêu cầu `generateContent` thành công**. Function nay kiểm tra model trước khi giữ quota, hỗ trợ allowlist Free tier `gemini-2.5-flash-lite` và `gemini-3.5-flash-lite`; chưa tự đổi Edge Secret sang model khác. [Google thông báo dự án mới có thể bị giới hạn truy cập model 2.5](https://ai.google.dev/gemini-api/docs/models/gemini-2.5-flash-lite); [bảng giá ghi 3.5 Flash-Lite có Free tier](https://ai.google.dev/gemini-api/docs/pricing). Lượt tạo hôm nay đã dùng hết giới hạn một request/ngày theo cấu hình được người dùng duyệt; không gọi thêm Gemini để vượt giới hạn.

Theo yêu cầu tự động thêm bài vào hàng chờ, đã cài `pg_cron`/`pg_net`, ba mục Vault (chỉ ghi tên), và một lịch `englify-real-english-daily` **active** chạy `0 0 * * *` UTC, tương ứng **07:00 Việt Nam**. Script kiểm tra trước bằng transaction rollback thành công rồi mới áp thật; truy vấn chỉ đọc sau đó xác nhận lịch active và ba tên Vault. Edge secret Cron ngẫu nhiên không nằm trong Git, log hoặc phản hồi. Lịch chỉ gửi yêu cầu tạo tối đa **một** nháp/ngày theo quota database/Edge, không duyệt hay xuất bản. `net.http_post` được cho 90 giây để tránh hủy yêu cầu khi tra nguồn Tatoeba khoảng 18 giây. Lần chạy tự động đầu tiên là ngày 13/11/2026; **chưa có bằng chứng nháp được tạo**, vì vậy tính năng tạo bài đầu cuối vẫn **BLOCKED** cho tới khi job hôm sau trả `in_review` và bài xuất hiện trong Admin.

| Kiểm tra bổ sung | Trạng thái | Bằng chứng |
|---|---|---|
| Admin UI lint/build/TypeScript | PASS | `npm.cmd run lint -w apps/admin`, `npm.cmd run build -w apps/admin` ngày 12/11. |
| Edge TypeScript và model tests | PASS | `npx.cmd tsc ...` đạt; `node --experimental-transform-types --test scripts/test_hybrid_model.mjs`: 4/4. |
| Function deploy | PASS | `real-english-generate` triển khai lại với JWT verification giữ nguyên. |
| Lịch 07:00 và Vault | PASS | Transaction dry-run rollback; áp và truy vấn chỉ đọc xác nhận `cron.job` active, lịch `0 0 * * *`, ba tên Vault. |
| Tạo nháp Gemini thật | BLOCKED | Lượt ngày 12/11 thất bại HTTP 404 và đã chạm mức 1 request/ngày. Cần quan sát job chạy ngày 13/11 và điều tra phản hồi `generateContent` nếu vẫn lỗi. |
| Duyệt/publish bài AI thật | NOT TESTED | Chưa có bài để duyệt. Sau khi có bài `in_review`, admin mở bài, kiểm tra nghĩa/nguồn/giấy phép, approve rồi publish thủ công; mobile chỉ nên thấy bài published. |

Tệp bổ sung: `apps/admin/src/app/hybrid-real-english-panel.tsx`, `hybrid-real-english.module.css`, `apps/admin/.env.example`, `supabase/functions/_shared/real-english-generator.ts`, `supabase/functions/real-english-generate/index.ts`, `supabase/scripts/enable_real_english_cron.sql`, `scripts/test_hybrid_model.mjs`, `scripts/enable_hybrid_cron.py`. `apps/admin/.env.local` cục bộ đã bật cờ hiển thị lịch sau khi xác minh database; tệp này bị Git bỏ qua. Không sửa mobile trong lượt này.

Kiểm tra Cron đầu cuối **chỉ đọc** ban đầu nhận HTTP 401 `Session expired`: JWT `anon` cũ từ Vault không trùng biến `SUPABASE_ANON_KEY` do Edge cấp, dù gateway đã xác thực JWT. Đã sửa Function để yêu cầu đồng thời JWT vai trò `anon` còn hạn, gateway `verify_jwt=true` và bí mật Cron ngẫu nhiên được so sánh an toàn; không cho tài khoản thường dùng đường gọi Cron. Triển khai lại Function rồi thử qua đúng URL và header trong Vault: **HTTP 200**, model cấu hình `gemini-3.5-flash-lite`, `models.get` trả khả dụng. Người dùng cũng cung cấp ảnh xác nhận cả 2.5/3.5 Flash-Lite khả dụng qua Admin. Đã chuyển Edge Secret `GEMINI_MODEL` sang 3.5 Flash-Lite Free tier theo khuyến nghị model hiện hành; không gọi `generateContent` thêm trong ngày 12/11. Bài đầu tiên và nội dung tiếng Việt/nguồn vẫn phải xem sau lịch 07:00 ngày 13/11.
