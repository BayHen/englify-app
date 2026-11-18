# Writing V2.5 — autosave, Writing ngoại tuyến và editor mobile

## Audit và kiến trúc

Trước V2.5, nội dung chưa nộp chỉ nằm trong React state và được khóa bằng exercise ID. Draft mất khi route unmount/reload và Daily Challenge có thể dùng chung khóa với bài thường. Dự án đã có `expo-sqlite` tương thích Expo SDK 58, vì vậy V2.5 không thêm dependency hoặc backend mới.

Draft dùng database riêng `englify-writing.db` để migration local không xung đột database Journey/outbox. Schema version 1 gồm:

- `writing_drafts`: một bản ghi duy nhất theo `(user_id, context_key)`;
- `writing_exercise_cache`: metadata bài đã tải, khóa theo user và exercise;
- index `(user_id, updated_at desc)` cho danh sách My Drafts.

`context_key` là `exercise:<exercise-id>` cho bài thường và `daily:<assignment-id>` cho Daily Challenge. Nhờ vậy cùng một exercise không làm hai luồng ghi đè nhau. Web dùng localStorage với cùng hợp đồng và namespace theo user.

## Autosave và revision safety

- Mỗi lần gõ tăng revision local và lên lịch ghi sau 750 ms.
- Đổi exercise flush draft cũ trước khi activate context mới.
- Mất focus route, app chuyển background và component unmount đều yêu cầu flush ngay.
- Save SQLite chỉ nhận revision lớn hơn revision đã lưu; response cũ không thể ghi đè bản mới.
- Khi submit, client chụp revision đã gửi. Chỉ draft có revision nhỏ hơn hoặc bằng revision đó mới được xóa sau khi server xác nhận submission. Nếu người học tiếp tục gõ trong lúc chờ server, revision mới vẫn tồn tại.
- Submit lỗi, timeout hoặc Daily Challenge chưa đạt không xóa draft.
- Request UUID và server RPC hiện có tiếp tục chống duplicate submission; client không tạo XP.

Lifecycle flush cải thiện độ bền khi background hoặc điều hướng bình thường nhưng không bảo đảm phục hồi sau crash hệ điều hành, force-kill đúng lúc đang ghi hoặc thiết bị hỏng.

## Recovery và My Drafts

Khi mở exercise, client tải draft mới nhất đúng user/context. Load có sequence guard để thao tác mở bài cũ không ghi đè bài mới khi người dùng chuyển nhanh. UI hiển thị thời điểm phục hồi và cho phép tiếp tục hoặc discard. Discard luôn dùng hộp thoại xác nhận và không xóa submission đã nộp.

My Drafts sắp xếp theo thời gian sửa, hiển thị title, CEFR, topic, word count và preview. SQLite chỉ đọc `substr(content, 1, 160)` cho danh sách, không tải toàn bộ bài dài. localStorage trên web không hỗ trợ partial read nên phải parse từng draft trong index; danh sách bị giới hạn 100 bản ghi.

## Offline

Exercise đã tải được cache theo tài khoản. Khi API không khả dụng, Writing dùng cache để người học mở instructions và tiếp tục draft. Các thao tác sau luôn online-only:

- lưu submission chính thức;
- Daily Challenge completion và XP;
- AI Coach và AI Rewrite;
- đồng bộ history/progress từ Supabase.

V2.5 không đưa Writing submission vào outbox và không tự submit khi reconnect. UI không hiển thị thành công giả, không cấp XP local và không gọi Gemini khi gõ.

## Bảo vệ dữ liệu

- Draft không chứa access token, refresh token, API key hoặc Supabase secret.
- Mọi key/query local đều có user ID; đổi tài khoản không hiển thị draft của tài khoản trước.
- Nội dung draft không được ghi vào analytics hoặc console.
- SQLite và localStorage **không được mã hóa ở trạng thái nghỉ** trong phiên bản này. Không tuyên bố mã hóa. Người học không nên lưu thông tin đặc biệt nhạy cảm trong bài nháp; xóa draft bằng My Drafts khi không còn cần.
- Draft không tự upload lên Supabase. Chỉ nút Submit mới tạo submission chính thức.

## UI và accessibility

Khi chọn bài, màn hình chuyển sang editor tập trung thay vì giữ toàn bộ thư viện phía trên. Header bài hiển thị CEFR, topic, loại bài, prompt, instructions/hint, thời gian và word count. Multiline input có vùng viết cao hơn, cuộn nội bộ, giữ Return để xuống dòng và tiếp tục dùng safe area/keyboard avoiding của `Page`.

Save status có text riêng: Saving, Saved on this device, Unable to save, hoặc Offline — saved locally. Chỉ lỗi save dùng alert semantics để autosave thành công không liên tục ngắt screen reader. Các thao tác Continue, Discard, Submit và Back có label văn bản và touch target từ design system hiện có.

## Kiểm tra

```powershell
npm.cmd run typecheck -w apps/mobile
npm.cmd run lint -w apps/mobile
npm.cmd test -w apps/mobile
cd apps/mobile
npx.cmd expo export --platform web --output-dir .tmp/writing-v2-5-web
```

Unit tests kiểm tra create/update/restore, nhiều context, account isolation, stale revision, stale submission cleanup, corrupted/cross-account record và storage write failure. Existing tests tiếp tục kiểm tra submit idempotency, Daily Challenge, AI Coach/Rewrite và Supabase contracts.

## Giới hạn và kiểm tra thủ công

- iOS/Android SQLite, keyboard, background/foreground và force-close cần kiểm tra trên thiết bị thật; web export không thay thế native runtime test.
- Browser cần kiểm tra Console/LogBox sau typing, chuyển bài, background giả lập, offline và submit; đặc biệt lỗi `Unexpected text node`.
- Web localStorage phụ thuộc quota và chế độ privacy của trình duyệt. Khi write thất bại UI hiển thị Unable to save và không tuyên bố đã lưu.
- Không có migration PostgreSQL hoặc deploy production trong V2.5.

## Kết quả xác minh ngày 17/11/2026

- PASS — mobile TypeScript và ESLint.
- PASS — 182 mobile tests trong 47 files, gồm 5 test draft storage mới.
- PASS — Expo Web export tạo bundle `/writing` với SQLite web adapter/localStorage.
- PASS — full Supabase Auth/RLS/integration regression; submission, Daily Writing, XP và history vẫn hoạt động ở test local.
- PASS — Admin ESLint, 6 tests và production build.
- PASS — static audit vùng Writing V2.5 không phát hiện conditional JSX kiểu chuỗi/số `&& <Component>` có thể tạo text node dưới View.
- NOT TESTED — thao tác browser Console/LogBox vì Windows browser automation không khởi tạo (`helper_unknown_error`). Web export chỉ chứng minh bundle, không chứng minh runtime interaction.
- NOT TESTED — SQLite, keyboard, background/foreground và force-close trên Android/iOS vật lý.
- Không deploy, publish hoặc thay đổi production Supabase.

