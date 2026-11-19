# Quiz Arena V2.2 — Time Attack, combo và điểm nâng cao

## 1. Audit và tính năng hoàn thành

Audit trước triển khai nằm ở [QUIZ_ARENA_V2_2_AUDIT.md](reports/QUIZ_ARENA_V2_2_AUDIT.md). V2.1 được xác nhận từ mã workspace và local tests, không suy ra đã deploy. Practice có bank A1–C1, sáu adapter, snapshot, RPC, history và XP giới hạn. Journey/Admin/Edge Functions không có Time Attack; không cần tạo lại backend hoặc bank.

V2.2 bổ sung:

- Home đa mode: Practice Mode và Time Attack; không có nút Ranked giả.
- Chọn CEFR A1–C1 và difficulty Easy/Normal/Hard. Cấu hình thật lấy từ PostgreSQL.
- Một câu tại một thời điểm, server cấp thứ tự và ghi thời điểm cấp đầu tiên; getter/reload không reset thời gian câu hiện tại.
- Countdown nổi bật, official score, progress, lives có văn bản accessible, combo hiện tại và max combo.
- Lock Answer, feedback đúng/sai và Next; đáp án chỉ được khóa khi server đã nhận. Request không chắc kết quả giữ UUID/đáp án để retry.
- Dừng khi hết giờ, hết lives hoặc hết câu; xác nhận trước khi abandon, bao gồm browser Back. Dialog không dừng đồng hồ.
- Kết quả chính thức, correct/incorrect/unanswered, accuracy, thời gian, combo, reason, personal-best indicator; review đáp án đã nhận và giải thích tiếng Việt.
- Personal records theo difficulty và rules version; history phân trang; Play Again và Back to Arena.
- Khôi phục score/combo/lives/progression đã nhận sau reload/foreground; không có chế độ offline tự cấp điểm chính thức.
- Tái sử dụng Auth, `arena_sessions`, `arena_session_questions`, Question Bank, adapter câu hỏi và design tokens/component hiện hữu. Không thêm package, database sản phẩm, dịch vụ trả phí, Edge Function, Ranked hoặc multiplayer.

## 2. File thay đổi trong V2.2

| Nhóm | File |
| --- | --- |
| Migration | `supabase/migrations/20261118030000_quiz_arena_time_attack.sql` |
| SQL tests | `supabase/tests/quiz_arena_time_attack_smoke.sql` |
| HTTP tests | `scripts/supabase_time_attack_integration.py` |
| Upgrade tests | `scripts/supabase_arena_upgrade_check.py` thêm `--time-attack` |
| API/clock | `apps/mobile/src/features/learning/time-attack-api.ts`, `time-attack-clock.ts` |
| State/lifecycle | `apps/mobile/src/features/learning/use-time-attack-session.ts` |
| UI | `apps/mobile/src/features/learning/time-attack-home.tsx`, `time-attack-screen.tsx`, `time-attack-timer.tsx` |
| Route | `apps/mobile/src/app/time-attack/[id].tsx`, `apps/mobile/src/app/_layout.tsx` |
| Home | `apps/mobile/src/features/learning/quiz-arena-screen.tsx` |
| Mobile tests | `time-attack-api.test.ts`, `time-attack-clock.test.ts`, `use-time-attack-session.test.ts` trong thư mục learning |
| CI/docs | `.github/workflows/ci.yml`, `README.md`, `docs/DATABASE.md`, tài liệu này và báo cáo audit |

V2.1/Writing còn có thay đổi từ task trước trong workspace; không xóa hoặc đảo ngược chúng. Không có production deployment, merge hay release trong task này.

## 3. Schema và bảo toàn dữ liệu

Migration additive cần chạy **sau V2.1 `20261118020000`**:

- Thêm `arena_sessions.mode`, mặc định `practice` cho dữ liệu cũ; unique `(id,user_id)` và index history theo mode.
- `arena_time_attack_rules`: cấu hình server theo difficulty, version, số câu, giây, lives, base points và enabled.
- `arena_time_attack_sessions`: state/timestamp/rules snapshot/score/combo/lives. FK ghép về session và owner. Có check trạng thái, count, lives, score, độ dài thời gian và timestamp kết thúc.
- `arena_time_attack_answers`: một event duy nhất cho mỗi session/question, một request ID duy nhất trong session và một position duy nhất. Có FK về snapshot, thời điểm cấp/nhận, elapsed ms, correctness và điểm đã ghi.
- Một user chỉ có một timed session active; unique index và advisory lock bảo vệ điều này.

Không thêm bank hoặc lưu đáp án lần thứ hai ngoài snapshot dùng chung. Các bảng timed có RLS: owner chỉ đọc metadata session của mình; không có quyền ghi score/lives/timer/combo. Answer events không được SELECT trực tiếp bằng quyền người học. Rule chỉ admin được sửa; sửa số câu/time/lives/base phải tăng version. Game đang chạy ghim rule cũ.

Năm RPC Practice được mở rộng bằng mode guard/filter để không đọc toàn bộ câu hoặc bulk-submit timed game. Grading V2.1 được trích thành helper riêng tư dùng chung `englify_arena_grade`; giữ nguyên chuẩn hóa text, matching và token ordering. Không đổi grading hoặc XP Journey. History Practice chỉ chứa mode practice.

Kiểm tra upgrade dùng schema-only clone trên DB tạm riêng, tạo fixture Journey/quiz attempt và Practice completion/XP trước migration. Checksum 17 bảng cũ giữ nguyên sau nâng cấp, bỏ qua riêng cột metadata `mode` mới. DB tạm tự xóa trong finally; không reset DB development hoặc sao chép dữ liệu người dùng thật vào fixture.

## 4. RPC mới

| RPC | Hợp đồng |
| --- | --- |
| `englify_time_attack_start(request_id, level, difficulty)` | Server chọn cấu hình/câu và tạo ID, start/deadline; start retry giữ cùng game |
| `englify_time_attack_session(session_id)` | Owner restore, lazy-expire nếu quá hạn; lần cấp câu mới ghi question start đúng một lần |
| `englify_time_attack_answer(session_id, question_id, request_id, answer)` | Kiểm tra thứ tự, deadline, input; ghi answer/score/combo/lives một transaction |
| `englify_time_attack_finish(session_id, abandon=false)` | Mặc định chỉ finalize khi đã hết giờ; `abandon=true` kết thúc sớm có chủ ý |
| `englify_time_attack_history(page)` | Finalize session quá hạn của user và trả 10 game/trang |
| `englify_time_attack_records()` | Rules, totals và personal records được tính từ session chính thức |

Các helper grading/scoring/view/close không cấp quyền execute cho authenticated/anon. Không có endpoint FastAPI mới. Không nhận score, combo, lives, duration, deadline hoặc response time do client báo. Sai owner trả HTTP 404; xung đột sequence/replay trả 409; validation trả lỗi input rõ ràng. Đáp án đến lúc deadline vừa qua có thể trả trạng thái expired để UI khôi phục kết quả; không ghi answer mới. Game đã terminal từ chối answer mới, nhưng retry cùng request đã nhận vẫn trả trạng thái hiện hành mà không cộng điểm.

## 5. Cấu hình và công thức điểm

| Difficulty | Số câu | Thời gian | Lives |
| --- | ---: | ---: | ---: |
| Easy | 10 | 180 giây | 5 |
| Normal | 10 | 120 giây | 3 |
| Hard | 15 | 120 giây | 2 |

Base mặc định 100. Giá trị được validate và snapshot trên server. UI không gửi time/lives/số câu tùy ý cho Time Attack.

Với đáp án đúng, tăng combo trước rồi tính:

| Combo sau câu đúng | Multiplier |
| --- | ---: |
| 1–2 | 1.0× |
| 3–4 | 1.2× |
| 5–6 | 1.5× |
| 7+ | 2.0× |

`points = floor(base_points × multiplier_bps / 10000) + speed_bonus`.

| Elapsed milliseconds, làm tròn lên từ timestamp server | Bonus cho câu đúng |
| --- | ---: |
| 0–3000 | 50 |
| 3001–6000 | 30 |
| 6001–10000 | 10 |
| Trên 10000 | 0 |

Câu sai: 0 points/bonus, combo về 0 và mất một life. Max combo không giảm; lives không âm. Nếu câu cuối đồng thời làm mất life cuối, completion reason ưu tiên `no_lives`. Mọi đáp án mới bị chặn nếu thời điểm server xử lý đã đạt deadline.

Một game Normal hoàn hảo, mọi câu trong mốc nhanh nhất: **2040 điểm**. Test kiểm tra tổng này và phép floor với base 101 ở multiplier 1.2.

**Điểm Arena không phải XP. Time Attack V2.2 cấp 0 XP.** Practice vẫn tối đa 10 XP/ngày UTC theo V2.1; Journey giữ nguyên lesson rewards, quest và mở khóa. Không có chuyển đổi điểm thành XP, do đó replay timed game không tạo vòng farm XP.

Accuracy dùng `correct_count / question_count`, câu chưa trả lời làm giảm overall accuracy. Incorrect count chỉ gồm câu đã trả lời sai; unanswered hiển thị riêng.

## 6. Timing và chống gian lận

- Server `clock_timestamp()` xác định start, expiry, lần cấp câu và lúc xử lý answer sau các database lock. Chỉ một câu hiện tại được trả về.
- Sau khi nhận answer, server không lộ câu tiếp theo ngay trong response. Next/restore cấp câu đó lần đầu và bắt đầu đồng hồ speed riêng. Người học chờ giữa hai câu vẫn mất thời gian tổng.
- Getter/retry không reset start của câu đã cấp. Reload/background không đổi expiry hoặc bổ sung lives.
- Speed dùng khoảng thời gian **server quan sát được**, gồm network, render/thao tác và chờ database lock. Không trừ thời gian do client tự khai; không tuyên bố đo phản xạ con người chính xác hoặc công bằng tuyệt đối giữa mạng nhanh/chậm.
- UI neo deadline server vào `performance.now()`, dùng half-RTT để ước lượng phần mạng khi hiển thị. Không dùng `Date.now()` của thiết bị làm đồng hồ game chính thức.
- Tick UI 250 ms chỉ cập nhật component đồng hồ; khi màn hình ẩn/mất focus thì dừng cập nhật. Foreground bắt buộc GET đồng bộ và khóa answer tới khi nhận state mới. Một response cũ từ trước khi chuyển nền không được đánh dấu đã sync cho foreground mới.
- Khi UI ước lượng hết giờ, khóa input và yêu cầu server finalize. UI không tự tuyên bố official result; clock skew/latency có thể làm hiển thị checking result trong lúc chờ.
- Advisory lock theo user, row locks và unique constraints bảo vệ start/answer đồng thời. UUID retry và question sequence không cho tăng combo/score hai lần.
- Mỗi lần nhận đáp án là transaction: không có bước client tự cập nhật official score, official combo hoặc PB.
- Key chỉ hiện trong post-game review của câu đã nộp; không gửi câu tương lai hoặc đáp án trước game. Câu bị thu hồi kết thúc phiên an toàn dạng abandoned, giữ các answer đã nhận.

Không tuyên bố anti-cheat hoàn hảo: người học có thể đã biết nội dung, dùng trợ giúp ngoài hoặc dùng nhiều thiết bị. Thiết kế bảo vệ số liệu chính thức và XP, không xác thực một con người duy nhất. Không có leaderboard/ranking hay dịch vụ chống gian lận ngoài.

Expiration được finalize khi get/answer/finish/history/records/start kiểm tra session; không thêm cron hoặc daemon. Deadline vẫn được kiểm tra trước mọi answer, nên session chưa được truy cập lại sau background không thể nhận điểm muộn.

## 7. Personal records

Aggregate có index, chỉ dùng game `completed`/`expired`, loại abandoned. Không có bảng mutable PB nhận input client và không thể nhân bản record bằng retry.

- Highest score, best accuracy, highest combo theo difficulty + rules version, gộp các CEFR trong cùng nhóm.
- Fastest qualifying completion chỉ tính `all_questions` và accuracy ít nhất 70%.
- `total_sessions` gồm cả active/abandoned; `completed_sessions` gồm completed/expired.
- New-personal-best indicator được ghim lúc game kết thúc, chỉ khi score cao hơn record trước; bằng điểm không phải new best.
- Nếu cùng highest score: chọn session kết thúc sớm hơn, rồi ID để phá hòa ổn định.
- Difficulty tạm disabled không làm mất record. Khi đổi rules version, tile so sánh version hiện tại; toàn bộ result cũ vẫn trong history.

## 8. Kết quả kiểm tra thực tế

- PASS: TypeScript, ESLint, Ruff và `git diff --check`.
- PASS: **229 mobile tests / 54 files**, gồm 19 test mới cho API/timing và command/lifecycle.
- PASS: 9 SQL smoke test hiện hành, gồm timed scoring/rules/timing/security và regression Practice/Writing/Admin.
- PASS: multiplier boundaries, speed boundaries 3000/3001/6000/6001/10000/10001 ms, wrong answer, reset combo, life exhaustion, integer rounding, tổng perfect game 2040.
- PASS: sequence, replay, forged answer payload, Practice API bypass, cross-user access, direct score/lives write, private scoring helper/answer-event access, expiry và giữ câu đã nhận.
- PASS: Easy/Normal/Hard defaults, rule version guard, snapshot game đang chạy và record khi tạm khóa difficulty.
- PASS: HTTP Auth/PostgREST với hai tài khoản local: concurrent start cùng ID chỉ một game; duplicate answer cùng ID không inflate; hai request ID khác nhau cho cùng câu chỉ một request được nhận; request còn lại 409.
- PASS: HTTP restore sau mất response, repeat GET không reset speed time, expired submission, personal records và không tạo XP.
- PASS: upgrade V2.2 trên schema V2.1 trống và fixture có Practice/Journey/XP; regression SQL trên DB clone biệt lập. V2.1 upgrade check cũ cũng pass.
- PASS: Practice/Journey HTTP integration: completed lessons và lesson rewards vẫn hoạt động, Practice claim vẫn giới hạn đúng và hai nguồn không làm hỏng tổng XP.
- PASS: reward shop cũ vẫn claim/retry cùng claim ID, không tạo claim trùng hoặc thay đổi total XP; fixture nằm trong SQL transaction rollback.
- PASS: database lint mức error.
- PASS: Chromium headless 390px: timed play đủ 10 câu, combo/lives/official score, new PB và giải thích tiếng Việt.
- PASS: browser mất response sau khi server đã nhận rồi retry; browser Back xác nhận; đổi `Date.now()` về quá khứ; hidden/foreground không reset deadline/question clock; reload giữ progress đã nhận.
- PASS: expiry trong lúc hidden, dark mode và viewport 320px không tràn ngang; abandon, history và records.
- PASS: Console/page errors sau render và thao tác không có `Unexpected text node: A text node cannot be a child of a <View>`.

Bốn lifecycle tests dùng React/AppState mock và command harness, không phải native renderer. Browser test dùng Chromium/Playwright sẵn có trong máy, tài khoản loopback dùng một lần và hostname test được route về local; không chạm production. Không thêm browser dependency/job vào CI. SQL, HTTP và upgrade tests mới đã được nối vào CI.

## 9. Giới hạn và phần chưa xác minh

- NOT TESTED: Android/iOS vật lý, app bị OS kill, screen reader thật, cỡ chữ hệ thống lớn, chất lượng motion/performance trên máy yếu.
- NOT TESTED: production/staging, tải lớn, mạng thực rất chậm/không ổn định và workflow GitHub Actions chạy lại.
- Client chưa lưu draft Time Attack chưa được server nhận qua cold-start. Answer đã nhận phục hồi từ server; chưa nhận thì người học cần nhập lại, deadline vẫn chạy.
- Game cần mạng. Không có offline official scoring; mất mạng có thể mất cơ hội trả lời trước deadline.
- Timing hiển thị là ước lượng dựa RTT; scoring tính cả latency phía server. Không có bù latency do client khai, nên đây không phải phép đo phản xạ hay hệ thống thi đấu công bằng tuyệt đối.
- Native background/foreground được kiểm tra bằng command harness và hành vi tương đương trên browser, không tuyên bố đã chạy AppState trên điện thoại thật.
- Whole-app Edge integration trước đây có lỗi local study-plan 503/name resolution; task này không xác nhận tất cả Edge Functions. Time Attack/Practice/Journey trực tiếp đã chạy bằng Auth/PostgREST.
- Bank/accepted answers là nội dung xác định của V2.1; không thêm AI hoặc CRUD admin riêng cho Time Attack. Admin đổi cấu hình qua quyền DB hiện hữu.

## 10. Chạy lại và yêu cầu triển khai

Không được giả định V2.1 đã có ở server. Backup và đối chiếu migration history trước staging/production. Áp lần lượt V2.1 `20261118020000`, V2.2 `20261118030000` và các migration tiền đề còn thiếu; bank phải có đủ 10/15 câu published cho level đã chọn. Rule mặc định được tạo trong migration mới.

Local:

```powershell
npx.cmd supabase start
npx.cmd supabase migration up --local
.\.venv\Scripts\python.exe scripts/run_local_sql_test.py supabase/tests/quiz_arena_practice_smoke.sql supabase/tests/quiz_arena_time_attack_smoke.sql
.\.venv\Scripts\python.exe scripts/supabase_time_attack_integration.py
.\.venv\Scripts\python.exe scripts/supabase_arena_upgrade_check.py --time-attack
npm.cmd run typecheck -w apps/mobile
npm.cmd run lint -w apps/mobile
npm.cmd test -w apps/mobile
npm.cmd run web -w apps/mobile
```

Seed development V2.1 chỉ dùng khi cần nội dung local; không reset DB có dữ liệu cần giữ. CI reset chỉ áp dụng stack disposable của runner. Các script HTTP xóa tài khoản test trong finally; upgrade script chỉ xóa DB tạm có tên do chính nó tạo.

Kiểm tra thủ công `/quiz-arena` → Time Attack → Easy/Normal/Hard, cả foreground/background, offline/retry, Clock thay đổi, hết giờ/lives, review, records và Practice/Journey regression. Mở Console/LogBox sau render và thao tác để kiểm tra lỗi text node. Điện thoại thật phải xác minh riêng.

Không có Edge Function hoặc biến môi trường sản phẩm mới. Backend V2.1 thiếu RPC Time Attack thì UI hiển thị thông báo chưa khả dụng và vẫn cho dùng Practice. Chỉ publish mobile sau khi migration/bank staging pass và có ủy quyền triển khai riêng. Task này chưa deploy migration production, merge hay phát hành release.
