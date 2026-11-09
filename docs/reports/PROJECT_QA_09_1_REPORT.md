# Báo cáo QA toàn dự án — TASK 09.1

Ngày kiểm tra: **09/11/2026**. Môi trường: Windows, Node 24.13, Python 3.14.3, PostgreSQL 18 cục bộ trong `.tmp` dùng riêng cho QA. Không dùng database Supabase chứa dữ liệu người học. Fixture Auth chỉ được nạp trên database QA.

## Kết quả theo phạm vi

| Phạm vi | Trạng thái | Bằng chứng và giới hạn |
| --- | --- | --- |
| Mobile UI và điều hướng | **PASS** cho typecheck/lint/38 test ban đầu, **39 test sau sửa**; web Login và Explore render ở 360 × 780 không có lỗi console, gồm `Unexpected text node`. **NOT TESTED** trên Android/iOS thật, cỡ chữ lớn, VoiceOver/TalkBack và các route sau đăng nhập. |
| Backend API | **PASS**: Ruff, 33/33 pytest trên PostgreSQL QA đã migration/seed; gồm phản hồi health, auth, dữ liệu và các luồng tích hợp. Chưa chạy kiểm thử tải/hiệu năng. |
| PostgreSQL, migration và RLS | **PASS**: tạo database QA trống, nạp Auth stub, `alembic upgrade head` tới `20261107_12`, 41 bảng public, seed phát triển và `rls_and_constraints.sql` đều đạt. Đây là Supabase Auth giả lập cho test, chưa chứng minh policy trên dự án Supabase thật. |
| SQLite offline và đồng bộ | **PASS**: test mobile hàng đợi/backoff/cô lập user và backend offline sync/idempotency/XP. **NOT TESTED**: SQLite thực, tắt/bật mạng và khởi động lại trên Expo Go. |
| Xác thực | **PASS**: test JWT, quyền API, cô lập hai tài khoản trên PostgreSQL QA. **BLOCKED**: đăng ký, email xác nhận, khôi phục mật khẩu, phục hồi session với Supabase Free thật cần tài khoản thử nghiệm và dịch vụ cấu hình chạy. |
| Từ điển | **PASS**: API/database integration và test cache/kiểu dữ liệu mobile. **NOT TESTED**: phát âm TTS và cache trên thiết bị thật. |
| Dịch thuật | **PASS**: test phrasebook và trạng thái unavailable; không suy diễn thành dịch toàn văn. **BLOCKED**: chất lượng cặp en–vi trên LibreTranslate tự host chưa có provider đang chạy. |
| Learning Journey và gamification | **PASS**: test hoàn thành unit, khóa bài, replay, XP, badge, gửi trùng và cô lập user trên database QA. **NOT TESTED**: luồng nhìn thấy sau đăng nhập trên thiết bị thật. |
| Speaking | **PASS**: test lưu lịch sử và rà soát không tạo điểm phát âm giả. **NOT TESTED**: TTS, quyền micro, ghi/phát/xóa âm trên Android/iOS thật. |
| Writing | **PASS**: test quy tắc, lưu bài và provider failure; bài tích hợp PostgreSQL đạt. **BLOCKED**: LanguageTool tự host chưa chạy để xác nhận grammar feedback trực tiếp. |
| Admin Dashboard | **PASS**: ESLint, Next build/TypeScript, API test phân quyền 401/403, CRUD/publish/audit và nội dung đọc qua API mobile. **BLOCKED**: đăng nhập/publish bằng admin Supabase thật trên trình duyệt. |

## Kiểm tra đã chạy

| Lệnh/kiểm tra | Kết quả |
| --- | --- |
| `npm.cmd run typecheck -w apps/mobile`; `npm.cmd run lint -w apps/mobile`; `npm.cmd run test -w apps/mobile` | **PASS**; 39/39 test trong 16 tệp sau sửa |
| `npm.cmd run typecheck -w packages/shared` | **PASS** |
| `npm.cmd run lint -w apps/admin`; `npm.cmd run build -w apps/admin` | **PASS**; build bao gồm TypeScript |
| `python -m ruff check backend`; `python -m pip check` | **PASS** |
| `python -m pytest backend/tests -q --tb=short` với `ENGLIFY_TEST_DATABASE_URL` trỏ database QA | **PASS**: 33/33; một cảnh báo deprecation của Starlette TestClient/httpx |
| `alembic upgrade head`, seed và `backend/tests/sql/rls_and_constraints.sql` trên database QA | **PASS** |
| `npx.cmd expo install --check` | **PASS**: không báo lệch phiên bản Expo SDK 58 |
| Chrome headless web Login/Explore 360 × 780, kiểm tra console sau render | **PASS**: không ghi nhận lỗi runtime; đây là smoke test, không phải native E2E |
| `npm.cmd audit --omit=dev --audit-level=critical --json` | **PASS** trong phạm vi npm advisory: 0 high/critical, 5 moderate runtime |
| `npm.cmd audit --audit-level=critical --json` | **PASS** trong phạm vi npm advisory: 0 high/critical, 14 moderate toàn cây |
| Prettier | **NOT TESTED**: dự án không có cấu hình/lệnh Prettier; không cài formatter mới chỉ để kiểm tra. `git diff --check` đạt. |
| Native E2E, Supabase thật, LanguageTool và LibreTranslate | **NOT TESTED/BLOCKED** như bảng phạm vi; không có thiết bị, phiên test hay dịch vụ tương ứng trong lượt QA. |

## Lỗi phát hiện và sửa

1. **Race đổi tài khoản khi đồng bộ offline.** Trước sửa, outbox kiểm tra user rồi `syncLesson`/`saveWord` đọc session lần hai. Nếu account đổi giữa hai bước, request có thể mang JWT của account mới. Đã truyền token của session vừa kiểm tra vào request; thêm test đổi account sau sự kiện đầu, xác nhận sự kiện sau không gửi và token cũ được dùng cho sự kiện đầu. Backend tiếp tục kiểm tra JWT, owner, đáp án và XP.
2. **Cận dưới PyJWT cho phép bản có advisory critical.** Môi trường QA dùng PyJWT 2.15.1; khai báo cũ `>=2.10` vẫn có thể cài bản `<=2.13.0`. Đã nâng lên `>=2.14,<3`. [Advisory GHSA-ffc3-869f-jxw9 của maintainer](https://github.com/jpadilla/pyjwt/security/advisories/GHSA-ffc3-869f-jxw9) ghi 2.14.0 là bản vá. Ứng dụng còn giới hạn thuật toán bất đối xứng riêng, không trộn HS256 trong allowlist đó.

## Tệp thay đổi

- `apps/mobile/src/features/offline/sync.ts`, `sync.test.ts`: dùng token đã xác nhận và test race.
- `apps/mobile/src/features/learning/api.ts`, `apps/mobile/src/features/dictionary/api.ts`: cho phép outbox truyền token đã xác nhận.
- `backend/pyproject.toml`: cận dưới PyJWT đã vá.
- `docs/reports/PROJECT_QA_09_1_REPORT.md`: báo cáo này.

## Giới hạn, rủi ro và bước tiếp theo

- Không thấy lỗ hổng **critical chưa xử lý** trong npm audit, advisory PyJWT đã kiểm tra và các luồng quyền đã test. Đây không phải chứng nhận bảo mật toàn bộ: chưa chạy công cụ quét advisory cho toàn bộ thư viện Python; 14 advisory npm mức moderate chưa được triage từng mục, không tự nâng gói ngoài phạm vi QA.
- Cache SQLite/profile trên thiết bị không có lớp mã hóa riêng; không lưu token/mật khẩu ở cache đó. Cần đánh giá chính sách lưu trữ nếu sản phẩm có yêu cầu riêng về thiết bị bị truy cập trái phép.
- Chưa có E2E native/automation được cấu hình. Trên Android/iPhone với Expo Go tương thích SDK 58: chạy FastAPI, `cd apps/mobile; npx.cmd expo start --clear`; đăng nhập tài khoản test, mở từng module, thử lỗi/empty/loading và kiểm tra LogBox. Với offline: tải bài, tắt mạng, làm bài, khởi động lại, bật mạng, xác nhận đồng bộ một lần và XP không trùng; đổi tài khoản khi còn outbox. Kiểm tra quyền mic/TTS/xóa âm ở Speaking.
- Với Supabase thật: dùng hai tài khoản học viên và một admin test do người phát triển quản lý; xác nhận đăng ký/email, đăng nhập, logout, reset, RLS chéo user, admin 403 với học viên, publish rồi thấy nội dung trên mobile. Không đưa mật khẩu/token/chuỗi DB vào báo cáo.
- Nếu cần formatter thống nhất, chọn và cấu hình Prettier trong task riêng; hiện CI kiểm tra ESLint/Ruff nhưng chưa có cổng Prettier.
