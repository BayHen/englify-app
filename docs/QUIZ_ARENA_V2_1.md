# Quiz Arena V2.1 — Practice Mode và Question Bank

## 1. Audit và tính năng hoàn thành

Arena trước đây chỉ liệt kê lesson Journey chưa khóa rồi chuyển sang `/lesson/[id]`. Journey dùng `quiz_questions`, `quiz_options`, `quiz_answer_keys`, tiến độ mở khóa và `lesson_attempts`; mỗi lần pass bài lần đầu được cấp XP theo lesson. Các bảng và RPC đó được giữ nguyên.

Question Bank Arena dùng adapter độc lập vì Journey yêu cầu lesson, có loại `grammar`/`listening` riêng và không có hợp đồng Sentence Ordering/Reading như Practice. Không đổi enum hoặc cách chấm Journey để phục vụ Arena. Tái sử dụng `englify_normalize_answer`, `xp_events`, `user_levels`, `gamification_config`, `reward_notifications`, Auth, palette, typography và component UI có sẵn.

Đã triển khai:

- Home Arena mới: cấp độ/XP hiện tại, cấu hình Practice, gợi ý luyện tập và lịch sử phân trang.
- CEFR A1–C1, topic, loại câu hỏi, difficulty có nội dung và số câu 5/10/15/20.
- Chín topic nội dung: Grammar, Vocabulary, Reading Comprehension, Everyday English, Business English, Travel English, Sentence Structure, Phrasal Verbs, Idioms; Mixed Practice tổng hợp các topic.
- Bộ chọn chỉ hiển thị topic/type có câu đã xuất bản ở level đang chọn. Nếu bộ lọc không đủ số câu, nút bắt đầu bị vô hiệu hóa; server vẫn kiểm tra lại và trả lỗi rõ ràng khi số lượng đã thay đổi.
- Sáu dạng bài: Multiple Choice, Fill in the Blank, Matching, Grammar Correction, Sentence Ordering, Reading Comprehension.
- Điều hướng Previous/Next giữ đáp án; matching phải ghép một-một; ordering có Undo/Clear.
- Submit có khóa chống bấm lặp, giữ đáp án khi mất mạng và retry theo session ID.
- Xác nhận trước khi kết thúc, bao gồm browser Back; quiz đã kết thúc không được nộp lại.
- Kết quả: số đúng/sai, accuracy, thời gian phía server, XP đã ghi, giải thích tiếng Việt và topic cần ôn. Có review tất cả/chỉ câu sai, Practice Again và Back to Arena.
- Không có Time Attack, Ranked Arena hay speed bonus.
- Seed development gồm **270 câu hỏi gốc** do dự án biên soạn, có đủ ít nhất 5 câu cho mỗi loại ở mỗi CEFR và đủ 20 câu cho Mixed Practice ở mọi CEFR. CEFR dùng để tổ chức nội dung, không phải kết quả thi xếp lớp được chuẩn hóa.

## 2. File thay đổi

| Nhóm | File |
| --- | --- |
| Migration | `supabase/migrations/20261118020000_quiz_arena_practice.sql` |
| Seed/config | `supabase/seeds/quiz_arena_development.sql`, `supabase/config.toml` |
| Route/Auth guard | `apps/mobile/src/app/quiz-practice/[id].tsx`, `apps/mobile/src/app/_layout.tsx` |
| Home | `apps/mobile/src/features/learning/quiz-arena-screen.tsx` |
| Client/model | `apps/mobile/src/features/learning/arena-api.ts`, `arena-model.ts` |
| UI | `apps/mobile/src/features/learning/arena-practice-screen.tsx`, `arena-question-input.tsx` |
| Mobile tests | `arena-api.test.ts`, `arena-model.test.ts`, `arena-question-input.test.tsx` trong cùng thư mục learning |
| SQL tests | `supabase/tests/quiz_arena_practice_smoke.sql` |
| Integration/upgrade | `scripts/supabase_arena_integration.py`, `scripts/supabase_arena_upgrade_check.py` |
| CI | `.github/workflows/ci.yml` |
| Tài liệu | `docs/QUIZ_ARENA_V2_1.md`, `docs/DATABASE.md`, `README.md` |

Các thay đổi Writing từ task trước được giữ nguyên; chúng không thuộc triển khai Arena này. Không đổi contract hoặc UI quản trị Journey hiện hữu.

## 3. Migration và bảo toàn dữ liệu

Migration additive tạo năm bảng:

- `arena_questions`: metadata, nội dung và lựa chọn công khai. Chỉ admin được đọc/ghi bảng trực tiếp.
- `arena_answer_keys`: đáp án và giải thích tiếng Việt; người học không có policy đọc.
- `arena_sessions`: cấu hình, trạng thái, thời gian, thống kê và kết quả; chỉ owner được SELECT.
- `arena_session_questions`: snapshot nội dung/đáp án của từng session, giữ lịch sử khi bank thay đổi. Không cấp quyền đọc trực tiếp cho authenticated.
- `arena_reward_claims`: unique `(user_id, reward_day)` và unique session, chặn thưởng lặp theo ngày UTC.

Có PK, FK và index cho truy vấn bank/history, không sửa/xóa hàng Journey. Chỉ mở rộng constraint source type của `xp_events` để nhận thêm `arena`, giữ tất cả source type cũ. Không thêm database, backend hoặc dịch vụ trả phí cho sản phẩm.

Publish guard kiểm tra key, cấu trúc lựa chọn, ID duy nhất, matching đầy đủ và token ordering. Phải unpublish trước khi sửa key. RPC chỉ xuất các trường được cho phép; đáp án và giải thích chỉ xuất hiện trong kết quả đã nộp của owner. Câu bị thu hồi không được dùng trong phiên active hoặc phiên mới. Review của phiên đã hoàn thành vẫn giữ snapshot lịch sử; phiên abandoned không trả snapshot câu hỏi.

## 4. RPC/API

Tất cả RPC mới dùng Supabase Auth và PostgREST, cùng kiểu tích hợp Journey hiện có; không thêm endpoint FastAPI hoặc thay đổi `/api/v1` hiện hữu.

| RPC | Chức năng |
| --- | --- |
| `englify_arena_catalog()` | Đếm câu published theo level/topic/type/difficulty, trả chính sách thưởng |
| `englify_arena_start(request_id, level, topic, kind, count, difficulty)` | Chọn câu phía server, tạo snapshot, idempotent theo user/request ID |
| `englify_arena_session(session_id)` | Lấy phiên thuộc user; active không có key |
| `englify_arena_submit(session_id, answers)` | Validate/chấm điểm/ghi kết quả/thưởng trong một transaction |
| `englify_arena_end(session_id)` | Kết thúc phiên active, không cấp XP |
| `englify_arena_history(page)` | Lịch sử của owner, 10 phiên/trang |

Sai owner trả HTTP 404; input không hợp lệ bị từ chối; không nhận score, XP hoặc duration do client cung cấp. Session ID là idempotency key của submit; kết quả completed bất biến kể cả retry sau khi mất response. Start dùng UUID ổn định cho retry và không nhận cấu hình khác với cùng UUID. Giới hạn 10 session active; session cũ có thể resume/end từ history.

Text answer dùng chuẩn hóa sẵn có; matching so sánh mapping một-một. Ordering kiểm tra mỗi token đúng một lần và chấm theo chuỗi từ hiển thị, nên hai token có chữ giống hệt nhau được hoán đổi ID mà không bị chấm sai.

## 5. Chính sách XP

- Đạt ít nhất 70% trên quiz ít nhất 5 câu: nhận **10 XP** nếu chưa có claim Arena trong ngày UTC hiện tại.
- Mỗi user tối đa 10 XP Arena/ngày UTC, không phụ thuộc replay, topic, level hay số câu. Quiz không đạt vẫn lưu review nhưng không cấp XP.
- Session ID là `source_id`, source type là `arena`; không dùng lại lesson ID hoặc danh tính phần thưởng Journey.
- Advisory lock cùng namespace user mà Journey dùng, unique claim và unique XP event bảo vệ submit đồng thời.
- Ghi claim, XP event, user level, notification và kết quả trong cùng transaction.
- Không thay đổi lesson XP, quest, badge hoặc điều kiện mở khóa Journey. Arena không giả lập hoàn thành lesson.

## 6. Kết quả kiểm tra thực tế

- PASS: mobile TypeScript và ESLint.
- PASS: **210 mobile tests trong 51 files**, gồm 22 test mới cho API, retry/mất mạng, cấu hình, completeness và render adapter sáu loại bài.
- PASS: cả 8 SQL smoke test trong CI, gồm security/admin/content/Writing và Arena.
- PASS: Arena SQL test cho đúng/sai của sáu loại, A1–C1, topic/difficulty, key privacy, shape giả, score giả, idempotency, replay reward, RLS, history và unpublished content.
- PASS: test hai token có chữ giống nhau được chấm theo câu hiển thị.
- PASS: Auth/PostgREST integration bằng hai tài khoản local; hai session độc lập nộp đồng thời chỉ chia sẻ một claim 10 XP; hai request submit cùng session trả cùng kết quả.
- PASS: Journey HTTP grading sau Arena vẫn ghi completion, cấp lesson XP và cộng vào tổng XP chung.
- PASS: migration trên schema ứng dụng cũ chưa có dữ liệu; nâng cấp trên DB biệt lập có câu hỏi, completion, lesson attempt, quiz attempt và XP mẫu. So sánh checksum 12 bảng cũ trước/sau migration và seed.
- PASS: database lint `--level error`, Ruff cho scripts và `git diff --check`.
- PASS: Chromium headless ở viewport điện thoại 390×844: Home, bộ chọn type, cả sáu loại bài, Previous/Next, Submit, review đáp án/chỉ câu sai, mất mạng submit rồi retry, empty bank và xác nhận End/Cancel.
- PASS: browser Back của phiên unfinished bị chặn để xác nhận. Thử light/dark qua color scheme browser. Console/page errors sau render và thao tác không có `Unexpected text node`.

Browser test dùng Chromium/Playwright đã có trên máy và route hostname test về Supabase loopback, không gửi dữ liệu test đến project thật. Repo không thêm dependency browser; browser script thử nghiệm ở `.tmp` không phải một job CI mới. Các kiểm tra RPC/SQL/unit và kiểm tra bảo toàn nâng cấp đã được thêm vào CI.

## 7. Chưa xác minh

- NOT TESTED: thiết bị Android/iOS thật, VoiceOver/TalkBack, cỡ chữ hệ thống lớn và hành vi app bị hệ điều hành kill.
- NOT TESTED: production/staging, tải lớn, người dùng thực và mốc chuyển ngày UTC trong thời gian thực.
- NOT TESTED: workflow chạy lại trên GitHub Actions; đã chạy các lệnh liên quan ở local.
- Bộ integration cũ toàn ứng dụng từng dừng tại Edge study-plan với HTTP 503/name resolution ở môi trường local; không dùng kết quả đó để tuyên bố toàn bộ Edge Functions đã pass. Arena không phụ thuộc Edge Function, và Journey/Arena đã được kiểm tra trực tiếp qua Auth/PostgREST.

## 8. Giới hạn hiện tại

- Cấu hình giao nhau có thể chưa đủ 5/10/15/20 câu; UI hiển thị số câu thật và yêu cầu nới bộ lọc, không nhân bản câu cho đủ số lượng.
- Đáp án unfinished giữ trong phiên màn hình và khi Previous/Next. Reload/cold-start chưa phục hồi phần đáp án chưa nộp; resume tải lại bộ câu hỏi của session.
- Practice cần mạng để tạo/nộp phiên; không tự đồng bộ submit ngoại tuyến hoặc cấp XP local.
- Quản trị bank hiện qua SQL/Supabase bằng quyền admin và publish guard. Chưa thêm màn CRUD bank riêng vào dashboard admin; trình quản trị Journey cũ giữ nguyên.
- Giải thích/accepted answers là nội dung biên tập xác định, không chấm bằng AI. Một cách diễn đạt khác chưa có trong accepted answers có thể bị đánh dấu sai; cần biên tập bổ sung khi xuất bản nội dung.
- Seed là bộ nội dung phát triển ban đầu, không tự chạy trên production. Cần duyệt sư phạm trước khi xuất bản rộng rãi.

## 9. Chạy lại và triển khai

Local đã có Supabase:

```powershell
npx.cmd supabase start
npx.cmd supabase migration up --local
.\.venv\Scripts\python.exe scripts/run_local_sql_test.py supabase/seeds/quiz_arena_development.sql
.\.venv\Scripts\python.exe scripts/run_local_sql_test.py supabase/tests/quiz_arena_practice_smoke.sql
.\.venv\Scripts\python.exe scripts/supabase_arena_upgrade_check.py
.\.venv\Scripts\python.exe scripts/supabase_arena_integration.py
npm.cmd run typecheck -w apps/mobile
npm.cmd run lint -w apps/mobile
npm.cmd test -w apps/mobile
npm.cmd run web -w apps/mobile
```

Upgrade check chỉ chạy ở loopback và tạo DB tên `arena_upgrade_check_<random>` từ schema-only clone, tự xóa DB tạm trong finally; không reset database development hoặc sao chép dữ liệu người dùng vào clone. HTTP test dùng tài khoản tạm và xóa trong finally. Không chạy các script test với URL production.

Trước triển khai: backup, đối chiếu migration history, áp migration mới lên staging, nhập/duyệt bank và publish sau khi key hợp lệ. Kiểm tra Auth/RLS/XP, mở `/quiz-arena` và `/quiz-practice/<id>` trên Web/iOS/Android, thử submit/retry/review/end và Journey regression. Không cần deploy Edge Function mới. Chỉ đưa migration và mobile lên production khi có ủy quyền riêng; task này chưa deploy/publish production.
