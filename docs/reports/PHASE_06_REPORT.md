# Báo cáo xác minh Phase 06 — Englify Quest

Ngày kiểm tra: 07/11/2026. Phạm vi: **TASK 06.1 Rule-Based Learning Plan** và **TASK 06.2 Real English Module**. Trạng thái dưới đây dựa trên mã hiện tại và lệnh đã chạy trong đợt xác minh này; `PASS` không có nghĩa đã thử trên điện thoại thật.

## Kết quả từng nhiệm vụ

| Nhiệm vụ | Trạng thái | Bằng chứng và giới hạn |
| --- | --- | --- |
| 06.1 — Kế hoạch học theo quy tắc | **PASS** | Sáu kiểm thử quy tắc xác định; kiểm thử API trên PostgreSQL tạm xác nhận tạo từ onboarding, sửa mục tiêu, tái tạo, dời lịch, giữ bài hoàn thành, quyền truy cập theo tài khoản. Migration `20261107_08` và API đã có. Chưa có tự động tạo tuần kế tiếp hoặc thông báo nhắc học. |
| 06.2 — Real English | **PASS** | Kiểm thử API trên PostgreSQL tạm xác nhận sáu loại nội dung, tìm kiếm, lưu/bỏ lưu, chấm đúng/sai, nộp lặp, cô lập RLS và không cấp quyền đọc bảng đáp án. Migration `20261107_09`, sáu mục/sáu quiz seed và màn hình mobile đã có. TTS và thao tác giao diện trên thiết bị thật chưa thử. |

## Tính năng đã triển khai

- 06.1: quy tắc Python có phiên bản; lịch bảy ngày dùng onboarding, tiến độ bài, tỷ lệ quiz và từ cần ôn; tổng quan tuần và tác vụ hằng ngày; đổi mục tiêu, tạo lại và dời mục quá hạn. Bản kế hoạch cũ được chuyển `paused`; lịch sử bài học và quiz được giữ lại. Bài học phải hoàn thành qua backend, không thể tự đánh dấu từ mobile.
- 06.2: nội dung biểu đạt có nghĩa tiếng Việt, ngữ cảnh, ví dụ, nhãn trang trọng, ghi chú vùng miền, nguồn/giấy phép; tìm kiếm và lọc; danh sách lưu riêng; câu hỏi ngữ cảnh được chấm tại server; TTS từ thiết bị. Sáu hội thoại/ví dụ mẫu do dự án biên soạn, không có media bên thứ ba.

## Rà soát kiến trúc, API và dữ liệu

- Mobile giữ route trong Expo Router, API client có kiểu riêng từng feature, dùng hệ thành phần chung và safe area từ `Page`. Backend xác thực JWT qua dependency hiện có; hai router đều nằm dưới `/api/v1`.
- PostgreSQL là nguồn dữ liệu chính. Migration 08 có khóa ngoại ghép `(plan_id, user_id)` và RLS chỉ đọc tác vụ của chủ sở hữu. Migration 09 có khóa ngoại, unique cho mục đã lưu và `request_id`, chỉ mục theo truy vấn, RLS cho bảng cá nhân. Role `authenticated` không có `SELECT` trên bảng chứa đáp án quiz.
- Đối chiếu schema/API bằng toàn bộ bài integration trên PostgreSQL tạm đã migration và seed. Database phát triển đang ở `20261107_09` theo `alembic current`; đợt xác minh này không ghi dữ liệu người học vào database đó.
- Mã nội dung ghi `source_name`, `license_id`, `provenance_note`. `project-original` là nhãn nguồn gốc nội bộ, không phải giấy phép tái phân phối công khai. Không tìm thấy script phim, URL video hoặc âm thanh được nhúng trong seed Phase 06.

## Rà soát phụ thuộc và kiểm tra đã chạy

| Kiểm tra | Kết quả |
| --- | --- |
| `npx.cmd expo install --check` với Expo SDK 58 | PASS — dependencies up to date; không cài thêm gói. |
| `npm.cmd run typecheck --workspace apps/mobile` | PASS |
| `npm.cmd run lint --workspace apps/mobile` | PASS |
| `npm.cmd run test --workspace apps/mobile` | PASS — 11 tệp, 28 tests. |
| `npm.cmd run lint --workspace apps/admin` | PASS |
| `npm.cmd run build --workspace apps/admin` | PASS — Next.js build và TypeScript. |
| `.\.venv\Scripts\python.exe -m ruff check backend` | PASS sau khi sửa thứ tự import. |
| `.\.venv\Scripts\python.exe -m pytest backend/tests -q` với `ENGLIFY_TEST_DATABASE_URL` trỏ tới PostgreSQL tạm | PASS — 28 tests; một cảnh báo deprecation từ `httpx`/Starlette. |
| `npx.cmd expo export --platform all --output-dir ..\..\.tmp\phase06-export` | PASS — bundle iOS, Android, web. |

Nếu không đặt `ENGLIFY_TEST_DATABASE_URL`, năm bài integration của toàn backend bị **SKIPPED**; đợt này đã chạy lại chúng trên database tạm tách biệt và đạt. Không dùng dự án Supabase phát triển làm fixture kiểm thử.

## Lỗi phát hiện và sửa trong đợt rà soát

1. `backend/app/main.py` có thứ tự import router sai chuẩn Ruff. Đã sắp xếp lại; Ruff toàn backend đạt.
2. API quiz Real English trước đây nhận lại cùng `request_id` dù `selected_option` đã đổi, rồi trả kết quả cũ. Đã đổi thành HTTP 409, giới hạn độ dài lựa chọn và thêm test hồi quy. Toàn bộ backend tests đạt sau sửa.
3. Tài liệu 06.1 mô tả lịch 1–4 phút luôn là từ vựng, khác quy tắc thực tế. Đã cập nhật để mô tả mục ngắn theo hoạt động ưu tiên của ngày.

## Tệp thay đổi trong đợt xác minh

- `backend/app/main.py`
- `backend/app/api/real_english.py`
- `backend/tests/test_real_english.py`
- `docs/LEARNING_PLAN.md`
- `docs/reports/PHASE_06_REPORT.md`

Các tệp triển khai Phase 06 đã rà: `backend/app/api/learning_plan.py`, `backend/app/planning/rules.py`, migration `20261107_08`/`20261107_09`, `backend/seeds/real_english_development.sql`, `backend/seeds/load_real_english.py`, `apps/mobile/src/features/plan/`, `apps/mobile/src/features/real-english/`, `docs/LEARNING_PLAN.md`, `docs/REAL_ENGLISH.md`. Các thay đổi Phase 06 hiện có trong working tree chưa được commit; báo cáo không ghi nhận chúng là commit đã phát hành.

## Giới hạn, bảo mật và kiểm tra chưa thực hiện

- **NOT TESTED — thiết bị Android/iOS và Expo Go:** môi trường hiện tại là Windows, không có iOS simulator hoặc thiết bị được điều khiển trong phiên. Bundle Metro đạt nhưng chưa xác nhận nhấn nút, TTS, màu sáng/tối, bàn phím và mạng trên máy thật. Cách kiểm tra: đặt `EXPO_PUBLIC_API_URL` trong `apps/mobile/.env` thành địa chỉ LAN của máy chạy FastAPI; chạy ` .\.venv\Scripts\python.exe -m uvicorn app.main:app --app-dir backend --host 0.0.0.0 --reload` và `npm.cmd start -- --clear` ở hai terminal; mở QR bằng Expo Go phù hợp SDK 58 trên Android và iPhone cùng mạng; đăng nhập, mở Learning plan và Real English, thử tìm/lưu/quiz/TTS, đổi theme và thử khi mất mạng. Không dùng `localhost` làm API URL trên điện thoại.
- **NOT TESTED — giao diện tương tác trực tiếp trên web:** đã build web nhưng chưa thao tác bằng trình duyệt ở đợt này. Chạy `npm.cmd start -- --web --clear`, đăng nhập và kiểm tra cùng luồng trên `localhost`.
- Kế hoạch chưa tự động gia hạn tuần mới hoặc dời mục quá hạn khi đổi ngày; người học dùng các nút tạo lại/dời lịch. Tác vụ nói/viết là tự xác nhận, chưa có chấm phát âm hoặc đánh giá bài viết. Quiz Real English chưa cấp XP.
- Quyền riêng tư dựa trên JWT FastAPI và RLS PostgreSQL; tuyệt đối không đặt service role key trên mobile. Seed phát triển không tạo user và loader từ chối khi `ENGLIFY_ENVIRONMENT=production`. Nội dung mới từ bên ngoài phải được kiểm tra quyền và ghi nguồn trước khi xuất bản.

## Hành động tiếp theo

1. Thử các luồng Phase 06 trên Android/iPhone thật và web bằng tài khoản phát triển; ghi lại lỗi UI hoặc TTS theo thiết bị.
2. Bổ sung gia hạn tuần và lịch theo múi giờ người học nếu sản phẩm cần lịch địa phương thay cho ngày UTC.
3. Xác định giấy phép tái phân phối công khai cho nội dung biên soạn nội bộ trước khi phát hành hoặc chia sẻ dataset.
