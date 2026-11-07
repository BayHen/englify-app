# Báo cáo kiểm chứng Phase 08 — Admin và học ngoại tuyến

Ngày kiểm tra: 07/11/2026. Phạm vi: TASK 08.1 và TASK 08.2. Không dùng database người học làm fixture; pytest tích hợp chạy trên PostgreSQL tạm đã migration và seed.

## Trạng thái theo task

| Task | Trạng thái | Bằng chứng và phần còn thiếu |
| --- | --- | --- |
| **08.1 Admin Dashboard** | **BLOCKED** | FastAPI kiểm tra JWT và `admin_members`; test tích hợp chứng minh tài khoản thường nhận 403, admin tạo/sửa/publish, nội dung xuất hiện qua API mobile và có audit log. Admin lint/build đạt. Chưa xác nhận đăng nhập, biên tập và xuất bản bằng tài khoản admin Supabase thật trên trình duyệt; môi trường kiểm tra không có phiên đăng nhập của tài khoản được cấp quyền. Cần người giữ tài khoản thực hiện quy trình bên dưới. |
| **08.2 Offline Learning & Synchronization** | **NOT TESTED** | Test backend xác nhận tải bài mở khóa, từ chối bài bị khóa, kiểm tra phiên bản, gửi trùng không tăng XP; test mobile xác nhận hàng đợi, backoff, cô lập user ID và lưu cache. TypeScript/lint và bundle Android/iOS/web đạt. Chưa chạy chu trình SQLite thực trên Expo Go, tắt/bật mạng, khởi động lại và xem LogBox sau tương tác. Cần thử trên Android/iPhone theo quy trình bên dưới. |

Không gán PASS cho hai task vì các kiểm tra runtime nêu trên chưa có bằng chứng. `expo export` chỉ chứng minh Metro tạo bundle, không chứng minh giao diện hoặc SQLite hoạt động trên thiết bị.

## Tính năng và kiến trúc đã rà soát

- Admin: Next.js gọi `/api/v1/admin/*` bằng Supabase access token. FastAPI kiểm tra chữ ký JWT và tra `public.admin_members` cho mọi endpoint; tên bảng/cột CRUD nằm trong allowlist. Nội dung mới bắt đầu ở bản nháp, publish/ẩn/lưu trữ mềm qua API. Bảng quyền và audit bật RLS, không mở quyền ghi cho client. Migration `20261107_11` giữ nội dung cũ và lịch sử người học.
- Học ngoại tuyến: Expo SDK 58 dùng `expo-sqlite` cho gói bài, Journey, profile theo user ID và outbox; từ điển dùng SQLite KV trên native. Web dùng `localStorage`. Bản tải kèm `content_version`; migration `20261107_12` theo dõi sửa nội dung con và đáp án. Backend kiểm tra JWT, khóa bài, phiên bản, đáp án và XP; `request_id` duy nhất chống gửi trùng. Câu trả lời chờ được giữ nguyên, không chấm điểm ở mobile.
- Khi API mất kết nối nhưng phiên Supabase trên máy còn hợp lệ, profile đã lưu cho đúng user ID cho phép mở bài tải xuống sau khởi động lại. Đồng bộ chạy ở cấp ứng dụng khi kết nối trở lại; giữ thứ tự sự kiện và backoff tối đa 5 phút. Mục thành công vẫn trong lịch sử cục bộ; mục xung đột/bị từ chối được giữ để xem xét.
- API và mobile cùng dùng tiền tố `/api/v1`, `content_version`, `request_id` và kiểu dữ liệu bài học. `admin_members` lấy quyền từ database, không từ metadata client. Không thấy secret/service key trong mã mobile/admin được rà soát.

## Lỗi phát hiện và sửa trong lần kiểm chứng

1. **Hàng đợi có thể dùng phiên của tài khoản mới.** Trước đây outbox chỉ lọc theo user ID khi đọc SQLite, còn API lấy token của phiên hiện tại. Đã thêm kiểm tra user ID của session trước *mỗi* lần gửi và test đổi tài khoản. Không sửa hoặc xóa sự kiện cũ.
2. **Khởi động lại khi mất mạng không vào được bài đã tải.** AuthProvider trước đây luôn cần `/me` thành công. Đã lưu profile theo user ID sau lần tải thành công và chỉ dùng bản này khi API không kết nối (`status=0`); phản hồi 401 vẫn đăng xuất. Thêm test cô lập cache.
3. **Đồng bộ chỉ chạy khi đang mở một trong ba màn có SyncStatus.** Đã thêm `SyncEngine` ở root để thử đồng bộ sau reconnect kể cả khi người học đang ở Home.

## Kết quả kiểm tra

| Kiểm tra | Kết quả |
| --- | --- |
| `python -m pytest backend/tests -q --tb=short` với PostgreSQL tạm, migration/seed | **PASS:** 33 bài; 1 cảnh báo deprecation từ Starlette TestClient |
| `python -m ruff check backend` | **PASS** |
| Alembic trên database phát triển | **PASS:** `20261107_12 (head)` |
| `npm.cmd run lint --workspace @englify/admin` | **PASS** |
| `npm.cmd run build --workspace @englify/admin` | **PASS:** Next.js build và TypeScript |
| Mobile lint, typecheck, Vitest | **PASS:** 36 bài trong 15 tệp; gồm test `Unexpected text node` trên JSX |
| `npx.cmd expo install --check` | **PASS:** dependency phù hợp Expo SDK 58 |
| `npx.cmd expo export --platform all` | **PASS:** bundle iOS, Android và web |
| `git diff --check` | **PASS:** không có lỗi whitespace; Git chỉ cảnh báo chuyển LF/CRLF trên Windows |
| Đăng nhập/publish trên browser bằng admin thật | **BLOCKED:** không có phiên đăng nhập admin trong môi trường kiểm tra |
| SQLite, reconnect, LogBox trên Android/iOS | **NOT TESTED:** chưa điều khiển thiết bị trong phiên kiểm tra |

## Tệp liên quan

- Admin: `apps/admin/src/app/page.tsx`, `apps/admin/src/lib/client.ts`, `backend/app/api/admin.py`, `backend/migrations/versions/20261107_11_admin_dashboard.py`, `backend/tests/test_admin_integration.py`, `docs/ADMIN_DASHBOARD.md`.
- Offline: `apps/mobile/src/features/offline/*`, `apps/mobile/src/features/learning/api.ts`, `apps/mobile/src/features/learning/journey-screen.tsx`, `apps/mobile/src/features/learning/lesson-screen.tsx`, `apps/mobile/src/features/dictionary/screen.tsx`, `backend/app/api/learning.py`, `backend/migrations/versions/20261107_12_offline_content_version.py`, `backend/tests/test_offline_integration.py`, `docs/OFFLINE_SYNC.md`.
- Sửa trong lần review: `apps/mobile/src/auth/provider.tsx`, `apps/mobile/src/app/_layout.tsx`, `apps/mobile/src/features/offline/{sync.ts,sync.test.ts,sync-engine.tsx,storage.ts,storage.web.ts,storage.web.test.ts}`, `docs/OFFLINE_SYNC.md` và báo cáo này.

## Giới hạn và bảo mật

- Offline cache và profile không được mã hóa riêng ở tầng ứng dụng. Chúng nằm trong vùng lưu trữ ứng dụng, không chứa token/mật khẩu, nhưng người có quyền truy cập dữ liệu thiết bị có thể đọc nội dung học và câu trả lời. Cần cân nhắc chính sách xóa bản lưu *theo yêu cầu người dùng*, tránh xóa outbox chưa đồng bộ.
- Nếu token hết hạn và Supabase không thể khôi phục phiên khi mất mạng, người dùng cần kết nối lại. Không nới quyền endpoint để giải quyết trường hợp đó.
- Một bài đã đổi nội dung trả 409; câu trả lời cũ giữ trên máy nhưng chưa có công cụ chỉnh trực tiếp sự kiện xung đột. Journey offline có thể hiển thị trạng thái cũ; XP và mở khóa chỉ có hiệu lực sau khi server xác nhận.
- Không có dịch vụ trả phí. Chưa có bằng chứng runtime trình duyệt cho lỗi React Native Web `Unexpected text node`; test tĩnh và bundle không thay thế Console/LogBox.

## Quy trình xác minh tiếp theo

1. **Admin:** chạy FastAPI và `npm.cmd run admin`, vào `http://localhost:3000`, đăng nhập bằng tài khoản Supabase đã được cấp quyền trong `admin_members` (không gửi mật khẩu qua chat). Tạo một từ vựng bản nháp có mã nhận diện mới, xác nhận mobile API chưa trả từ; publish, xác nhận API/mobile trả từ; kiểm tra audit log. Đăng xuất, đăng nhập tài khoản thường và xác nhận thao tác admin nhận 403. Lưu trữ mềm bản thử sau khi ghi nhận kết quả.
2. **Android/iOS:** chạy FastAPI ở địa chỉ thiết bị truy cập được; trong `apps/mobile` chạy `npx.cmd expo start --clear` rồi mở Expo Go tương thích SDK 58. Đăng nhập, vào Journey, tải một bài đã mở khóa; tắt mạng và khởi động lại app; xác nhận bài vẫn mở. Làm bài và lưu chờ; XP không đổi. Bật mạng, giữ app ở Home hoặc bấm **Sync now**, xác nhận kết quả server, XP chỉ cộng một lần và bài tiếp theo mở. Tắt/bật mạng lần nữa, xác nhận không tạo attempt hoặc XP trùng; đổi tài khoản và xác nhận không gửi bài của tài khoản cũ. Kiểm tra Console/LogBox trên web sau render và bấm các nút ở Journey/Lesson/Dictionary, đặc biệt lỗi `Unexpected text node`.
3. Sau khi các bước runtime trên đạt, cập nhật trạng thái task trong báo cáo. Trước đó giữ **BLOCKED/NOT TESTED** như bảng trên.
