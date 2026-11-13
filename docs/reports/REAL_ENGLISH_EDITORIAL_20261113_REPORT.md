# Báo cáo Real English: duyệt, xuất bản và mục tiêu 5 bài/ngày

> Cập nhật thư viện đọc hợp nhất — 13/11/2026
>
> - Mobile dùng một **Reading library** cho cả expression biên tập thủ công và AI lesson đã publish.
> - Search kiểm tra title, description, English/Vietnamese phrase, usage context và toàn bộ dialogue; hỗ trợ tiếng Việt có dấu hoặc không dấu.
> - Mỗi trang tối đa 5 nội dung. Expression và lesson dùng chung một bộ phân trang.
> - Chi tiết expression và lesson mở trong modal riêng có scroll, đóng bằng nút hoặc backdrop; modal tôn trọng reduced motion của thiết bị.
> - AI lesson review được đưa ngay sau review queue; editor rộng hơn, tự chuyển một cột ở màn hẹp, usage context dùng textarea và action bar không còn bị khuất.
> - Kiểm tra: Mobile TypeScript/Expo lint PASS, 39 tệp và 130 test PASS, Expo Web export PASS; Admin ESLint/test/build PASS.

> Cập nhật hiển thị publish — 13/11/2026
>
> - Kiểm tra production chỉ đọc xác nhận: `published=3`, `pending_review=2`, `archived=1`; batch trong ngày đạt `target=5`, `success=5`.
> - Nguyên nhân trang **Real English** không hiện bài AI đã publish: trang này chỉ đọc catalog `real_english_expressions` cũ, trong khi workflow review lưu bài vào `real_english_lessons`.
> - Admin đã có khối **Published AI lessons** đọc trực tiếp `real_english_lessons` với `status='published'`, sắp xếp theo `published_at`, hiện số lượng, chủ đề, CEFR, thời điểm xuất bản và preview expression.
> - Catalog expression cũ vẫn được giữ nguyên. Không sao chép bài AI sang bảng cũ và không tạo hai nguồn dữ liệu.
> - Feed bài đã xuất bản trên mobile được chuyển lên đầu màn Real English để người học thấy ngay; truy vấn vẫn chịu RLS và chỉ lấy bài `published`.
> - Kiểm tra sau thay đổi: Admin test 4/4, ESLint PASS, Next production build PASS; Mobile TypeScript PASS, Expo lint PASS, Vitest 38 tệp/128 test PASS, Expo Web export PASS.
> - Expo Web export chỉ xác nhận bundle. Runtime Console/LogBox và thiết bị iOS/Android vẫn cần xác minh thủ công sau khi tải lại ứng dụng.

Ngày kiểm tra: 13/11/2026. Nhánh: `feature/real-english-hybrid-v2`.

## Nguyên nhân và trạng thái thực tế

- Bài thật “Ordering Coffee” đã được duyệt và xuất bản, sau đó admin chuyển sang `archived`. Truy vấn mobile chỉ lấy `status='published'`, nên không hiển thị bài đã lưu trữ. Lịch sử duyệt được giữ nguyên; không tự đổi trạng thái bài này.
- Trước bản sửa, giao diện không có Restore, đếm hàng chờ bằng `in_review`, còn nháp mới dùng trạng thái cũ. Cờ feed bài học trên mobile cũng chưa bật trong `.env` cục bộ.
- Production hiện có **5 bài AI mới `pending_review`**, 1 bài cũ `archived`, 0 bài `published`. Kiểm tra chỉ đọc cho thấy 5 bài mới thuộc 5 chủ đề, có 5 fingerprint riêng và cả 5 có expression, hội thoại song ngữ, nguồn Tatoeba đủ metadata. Batch hôm nay `(target=5, success=5)`; thử dispatch thêm trả “No eligible slot remains today.”

## Đã triển khai

Kỹ năng dự án đã đọc và áp dụng: `database-design` (migration và giao dịch), `security-review` (RLS, RPC admin, secrets), `test-engineering` (smoke test SQL và kiểm tra build). Giao diện Admin theo CSS/convention hiện có; không có kỹ năng Next.js dashboard riêng được kích hoạt.

- Migration `20261113010000_real_english_editorial_workflow.sql` giữ nguyên ID/nội dung/lịch sử, bổ sung `pending_review`, `needs_revision`, `publish_failed`, Restore và RPC duyệt có kiểm tra admin. `approve_publish` cập nhật approved rồi published trong một giao dịch; lỗi nội dung khiến toàn bộ giao dịch rollback.
- Kiểm tra title, mô tả, CEFR, ít nhất một expression đang hoạt động, hai câu thoại, nguồn Tatoeba hợp lệ và metadata ghi công trước xuất bản. Bản xóa expression trong editor được ẩn khỏi learner bằng `is_active`, không xóa bản ghi cũ. RLS chỉ cho learner đọc bài published và expression đang hoạt động.
- Admin Studio có lọc trạng thái/CEFR, sắp xếp, phân trang, xem trước, sửa expression/translation, nguồn và giấy phép riêng, thao tác theo trạng thái, xác nhận xuất bản/lưu trữ, khóa gửi trùng và thống kê batch. Mặc định xem `pending_review`; chọn **Archived** để khôi phục bài cũ, rồi duyệt và xuất bản thủ công.
- Khi người dùng mở một bài, Admin từng lỗi `selected.real_english_dialogues.map is not a function`: PostgREST trả quan hệ một-một dưới dạng object. Đã chuẩn hóa các quan hệ lồng nhau ngay sau truy vấn ở Admin và mobile; thêm regression test cho object, mảng và quan hệ rỗng. Chờ người dùng kiểm tra lại tương tác trình duyệt.
- Bảng `real_english_generation_batches` đếm bài AI còn hợp lệ (`pending_review`, `approved`, `published`); bài archived/rejected không chiếm target. Migration `20261113020000_real_english_batch_eligibility.sql` thêm ràng buộc đặt trước slot; migration `20261113030000_real_english_preflight_retry.sql` ghi lỗi nguồn trước Gemini, cooldown và tối đa 3 lần/slot. SQL lịch chọn tối đa một slot mỗi 15 phút từ 07:00 đến 12:45 ICT, xoay 6 chủ đề, chuyển sang chủ đề khác khi nguồn lỗi, dừng ở 5 bài hoặc cap 10 yêu cầu AI. Edge giới hạn output 12.000 token/ngày và `AI_MONTHLY_MAX_ESTIMATED_COST_USD=0` giữ nguyên. Cấu hình đã áp production sau khi người dùng chấp thuận cụ thể.
- Cờ `EXPO_PUBLIC_REAL_ENGLISH_LESSONS_ENABLED=true` đã được đặt trong `apps/mobile/.env` **cục bộ, bị Git bỏ qua**. Mobile dùng cùng ID bài học, lấy bài published bằng Supabase/RLS mỗi lần vào màn hình. Chưa có bài published để xác nhận trực tiếp trên điện thoại.

## Kiểm tra đã chạy

| Kiểm tra | Kết quả |
| --- | --- |
| Migration SQL trên PostgreSQL UTF-8 tạm, từ schema nền | PASS |
| Smoke: learner không thấy bài chưa xuất bản, không gọi được RPC admin | PASS |
| Restore → sửa expression → Approve & Publish, audit, learner đọc bài published | PASS trên DB tạm |
| Publish thiếu hoạt động rollback, không để lại approved | PASS trên DB tạm |
| 5 payload giả lập provider → 5 bài `pending_review`, batch đếm 5, chống lặp và quota | PASS trên DB tạm; không phải 5 lượt Gemini thật |
| SQL body của Cron mới với `EXPLAIN` và pg_net/Vault stubs | PASS trên DB tạm |
| Preflight: ghi lỗi nguồn, backoff và cap 3 lần; archive giải phóng slot | PASS trên DB tạm |
| Tatoeba API v1 thật, 5 keyword `hello`, `buy`, `work`, `train`, `friend` | PASS: lần lượt 22, 24, 24, 25, 22 cặp có metadata hợp lệ; không bảo đảm các lượt sau |
| Migration trên Supabase production: rollback dry-run rồi áp | PASS; ID bài hiện hữu được giữ |
| RPC grant production: authenticated có quyền gọi, anon không có | PASS (chưa thay thế kiểm thử tài khoản thật) |
| Production RLS với claim learner tổng hợp: không thấy bài/expression chưa published | PASS qua truy vấn chỉ đọc; chưa thay thế JWT gateway thật |
| Admin ESLint và Next production build | PASS |
| Admin relation regression test | PASS: 4 test object/mảng/nested/null |
| Mobile TypeScript, Expo lint, Vitest | PASS: 38 tệp, 128 test |
| Edge TypeScript; Expo Web export | PASS |
| 5 bài AI thật trên production, 5 chủ đề/hash riêng, đủ dữ liệu cơ bản | PASS theo truy vấn database; **chưa được biên tập viên duyệt nội dung** |
| Cron production `*/15 0-5 * * *` UTC; dispatch sau khi đạt 5 | PASS: active, dispatch thêm không gửi request |
| Admin tương tác trình duyệt, Expo Web runtime/LogBox, iOS/Android thật | NOT TESTED: công cụ điều khiển trình duyệt lỗi sandbox; cần kiểm tra thủ công |
| 5 bài tự động vào **ngày kế tiếp** | NOT TESTED: lịch mới chưa tới lượt 07:00 ICT ngày kế tiếp |

## Giới hạn và bảo mật

- Bộ duyệt an toàn tự động ban đầu từ chối tăng cap Edge production lên 10 request/12.000 output token/ngày vì có rủi ro quota/chi phí. Người dùng sau đó **chấp thuận rõ đúng hai mức và lịch 07:00–12:45 ICT**; cấu hình mới được áp sau sự chấp thuận đó. Không có key trong mobile/admin, không tự bật dịch vụ trả phí.
- Quota Gemini Free tier phụ thuộc project thực tế. Năm bài hợp lệ mỗi ngày là **mục tiêu**, không bảo đảm trong mọi ngày nếu provider lỗi, hết quota, trùng nội dung hoặc nguồn không đạt điều kiện. Một lượt Tatoeba tạm lỗi HTTP 502 trong buổi kiểm tra trước bản ghi preflight; các lượt sau thành công. Batch và lịch sử hiển thị số thiếu/lỗi mới. Không có bài nào tự xuất bản.
- Kiểm thử SQL dùng Auth stub trong database tạm; production RLS đã thử bằng claim learner tổng hợp. Cần kiểm tra tiếp với hai tài khoản Supabase thật và thử Restore/Publish trong Admin. Không tự xuất bản lại bài đang archived.
- Web export chứng minh bundle, chưa chứng minh route không có lỗi `Unexpected text node` lúc render. Sau khi mở `/real-english` trên web, đăng nhập và thao tác, kiểm tra Console/LogBox. iOS/Android Expo Go chưa được thử trong phiên này.
- Không có secret, token hoặc URL database trong mã và báo cáo. Không dùng FastAPI.

## Cách xác minh tiếp

1. Khởi động lại Admin: `npm.cmd run dev -w apps/admin`; mở **AI lesson review**, chọn lọc **Archived**, mở “Ordering Coffee”, Restore to review, xem nguồn, Approve & publish. Bước xuất bản cần admin chủ động kiểm duyệt nội dung.
2. Khởi động lại Expo: `cd apps/mobile; npx.cmd expo start --tunnel --clear`. Đăng nhập và mở Real English; bài chỉ hiện sau khi published. Kiểm tra reload, bookmark, hoàn thành, nguồn và Console/LogBox trên Web; thử iOS/Android trên thiết bị thật.
3. Ngày kế tiếp sau 07:00 ICT, kiểm tra Admin và `real_english_generation_batches` có 5 bài hợp lệ, không chỉ 5 HTTP request. Nếu thiếu, xem `latest_error`, lịch sử preflight và quota thực tế, không thêm bài giả.

## Tệp chính đã đổi trong nhiệm vụ này

- Admin: `apps/admin/src/app/hybrid-real-english-panel.tsx`, `hybrid-real-english.module.css`, `real-english-relations.ts` và test.
- Mobile: `apps/mobile/src/features/real-english/lesson-feed.tsx`, `lesson-relations.ts` và test. Cờ `.env` local được bật nhưng không commit.
- Edge và lịch: `supabase/functions/real-english-generate/index.ts`, `supabase/functions/.env.example`, `supabase/scripts/configure_real_english_five_daily.sql`, `enable_real_english_five_daily.sql`.
- Database: ba migration `2026111301…`, `2026111302…`, `2026111303…`; bốn smoke test Real English trong `supabase/tests/`.
- Kiểm tra/triển khai: `scripts/deploy_editorial_migration.py`, `deploy_batch_eligibility.py`, `deploy_preflight_retry.py`, `configure_editorial_daily.py`, `enable_editorial_cron.py`, `trigger_editorial_once.py`, `verify_editorial_live.py`, `verify_editorial_http.py`, `verify_editorial_rls_live.py`.
- Tài liệu: báo cáo này và `docs/REAL_ENGLISH_HYBRID_V2.md`. `apps/mobile/.env` chỉ bật cờ cục bộ, Git bỏ qua.
