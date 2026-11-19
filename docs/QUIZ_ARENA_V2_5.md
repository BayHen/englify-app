# Quiz Arena V2.5 — Quản trị Question Bank

## Phạm vi đã triển khai

Admin có module **Arena questions** riêng cho ngân hàng `arena_questions`: danh sách phân trang phía PostgreSQL, tìm kiếm và lọc CEFR/topic/type/status/difficulty; editor thích nghi sáu loại câu; lifecycle draft → in_review → published → archived; duplicate thành draft; revision history; import CSV/XLSX; Gemini draft generator; topic metadata; analytics và hàng đợi report.

Journey vẫn dùng `quiz_questions` độc lập. Không có bảng Question Bank thứ hai và không đổi XP, Arena score, rating hay leaderboard.

## Versioning và lịch sử

Mỗi lần lưu nội dung tạo một row bất biến trong `arena_question_revisions`. Sửa câu đang published tự đưa bản hiện hành về draft, tăng version và yêu cầu review lại. Practice, Time Attack và Ranked vẫn dùng snapshot `arena_session_questions`; V2.5 bổ sung `revision_id` vào snapshot. Vì vậy thay prompt/key không sửa phiên đang chạy hoặc kết quả cũ. Mistake Review tiếp tục dùng snapshot riêng của V2.4.

Project hiện chỉ có một membership `admin_members`; self-approval được cho phép và mọi create/update/transition/review đều ghi actor vào audit/revision. Không có sửa điểm hồi tố. Nếu answer key published bị sai, Admin tạo revision mới và publish sau review; xử lý điểm cũ cần một workflow riêng trong tương lai.

## Validation

PostgreSQL kiểm tra prompt, CEFR A1–C1, topic published, type, difficulty 1–3, giải thích tiếng Việt và cấu trúc đáp án theo từng type. Choice/reading cần option hợp lệ; fill/grammar cần mảng accepted answers; sentence order cần đầy đủ token; matching cần mapping đầy đủ. Publishing chỉ chấp nhận bản `in_review` hợp lệ.

## Import CSV/XLSX

- CSV yêu cầu UTF-8 và đúng header template; XLSX chỉ đọc worksheet đầu bằng ExcelJS.
- Giới hạn 2 MB CSV, 5 MB XLSX và 500 dòng ở browser; PostgreSQL lặp lại giới hạn 500 row.
- Formula bị từ chối; macro, script và embedded object không được thực thi.
- Mỗi row có lỗi cụ thể và exact duplicate theo normalized prompt + CEFR + topic + type.
- Import là hai bước stage/preview rồi commit; chỉ row hợp lệ, không trùng được tạo thành draft. Không overwrite và không publish tự động.

Dependency `exceljs@4.4.0` còn advisory gián tiếp cho `uuid` khi dùng API buffer UUID; V2.5 không gọi API đó. `npm audit` cũng báo `picomatch` từ dependency tree hiện có. Cần tiếp tục theo dõi bản vá upstream; không chạy `npm audit fix --force` tự động vì có thể downgrade/breaking.

## Gemini

Edge Function `arena-question-generate` xác thực bearer, kiểm tra `englify_is_admin`, request UUID, batch 1–10 và quota 20 request/Admin/ngày. API key/model chỉ nằm ở Edge secrets. Structured JSON được kiểm tra số lượng rồi mỗi câu đi qua cùng RPC validation của editor. Kết quả luôn là draft `origin=ai`, trạng thái job `pending_review`; không tự publish.

Biến cần cấu hình khi deploy: `GEMINI_API_KEY`, tùy chọn `GEMINI_MODEL` trong allowlist Free-tier của dự án. Nếu chưa cấu hình, phần CRUD/import vẫn hoạt động và AI trả lỗi cấu hình.

## Reporting và analytics

Learner có thể report từ review Practice/Time Attack. RPC xác nhận quyền sở hữu session và lấy đúng `revision_id` đã snapshot; response không trả reporter ID. Admin resolve/dismiss có audit. Analytics dùng `quiz_answer_facts` thật để hiển thị attempts/correct/incorrect/accuracy/by-mode và reports; số liệu chỉ hỗ trợ người review, không tự xóa câu.

## Triển khai

Task này không chạy migration production hoặc deploy Edge Function. Sau backup và review:

```powershell
npx.cmd supabase db push
npx.cmd supabase functions deploy arena-question-generate
npm.cmd run build -w apps/admin
```

Thiết lập Edge secrets ngoài repository. Không nạp seed development lên production. Deploy migration trước Admin/mobile để tránh client gọi RPC chưa tồn tại.

## Kiểm tra

```powershell
npm.cmd run test -w apps/admin
npm.cmd run lint -w apps/admin
npm.cmd run build -w apps/admin
npm.cmd run typecheck -w apps/mobile
npm.cmd run lint -w apps/mobile
npm.cmd run test -w apps/mobile
.\.venv\Scripts\python.exe scripts/run_local_sql_test.py supabase/tests/quiz_question_management_smoke.sql
npx.cmd supabase db lint --local --level error
deno test supabase/functions/_shared/arena-question-generator.test.ts
```

## Giới hạn

- Near-duplicate semantic similarity chưa được bật; V2.5 dùng exact normalized deterministic để tránh Gemini dependency.
- Average response time chưa gộp cho mọi mode vì Practice/Journey không lưu thời gian từng câu đủ tin cậy.
- UI report hiện được nối ở Practice và Time Attack review; RPC hỗ trợ mọi Arena session snapshot, còn nút trong Ranked review cần được bổ sung trong lần định dạng lại màn Ranked một dòng.
- Chưa có native device QA hoặc production Gemini call trong task này.
