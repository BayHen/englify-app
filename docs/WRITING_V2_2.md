# Writing V2.2 — thư viện bài viết CEFR A1–C1

> Daily Writing Challenge, XP, streak, calendar và milestones được mở rộng tại [WRITING_V2_3.md](WRITING_V2_3.md).

## Phạm vi và trạng thái kế thừa

Writing V2.2 mở rộng nền tảng V2.1 theo hướng cộng thêm. Bài nộp, phản hồi quy tắc, lịch sử AI, bản viết lại và revision hiện có không bị xóa hoặc ghi đè. Cơ chế chấm xác định vẫn được dùng cho bài có đáp án; bài viết mở chỉ nhận hướng dẫn tự rà soát và không được trình bày như điểm năng lực hay điểm bài luận.

V2.1 đã có hai Edge Function `writing-ai-coach` và `writing-ai-rewrite`, quota theo người dùng, idempotency và RLS. V2.2 bổ sung ngữ cảnh CEFR/chủ đề/dạng bài vào lời gọi AI nhưng không tự gửi bài, không tự xuất bản nội dung và không gọi dịch vụ trả phí. Xem thêm [WRITING_AI_V2_1.md](WRITING_AI_V2_1.md).

## Mô hình dữ liệu

Migration `20261117020000_writing_cefr_library.sql` bổ sung:

- `writing_topics`: 10 chủ đề có slug, mô tả, icon, thứ tự, trạng thái xuất bản và lưu trữ mềm.
- `writing_exercises`: liên kết chủ đề, `cefr_level`, tiêu đề, hướng dẫn, số từ tối thiểu/khuyến nghị, thời lượng, độ khó và thời điểm lưu trữ.
- `user_preferences.writing_cefr_level`: trình độ viết riêng A1–C1. Cột này độc lập với `current_cefr`, nên đổi cấp độ Writing không làm thay đổi trình độ chung của người học.
- Bảy dạng bài: `sentence`, `fill_blank`, `sentence_order`, `paragraph`, `email`, `opinion`, `essay`.

Seed `supabase/seeds/writing_v2_development.sql` tạo 50 bài gốc của dự án: tối thiểu 10 bài cho mỗi cấp A1, A2, B1, B2 và C1. Seed chạy lặp an toàn theo slug, không tạo tài khoản và không sửa lịch sử học.

## RPC và bảo mật

- `englify_writing_library`: tìm theo tiêu đề, đề bài hoặc hướng dẫn; lọc theo CEFR, chủ đề, dạng bài; phân trang phía PostgreSQL.
- `englify_writing_topics`: chỉ trả chủ đề đã xuất bản cùng số bài khả dụng ở cấp độ được chọn.
- `englify_set_writing_level`: lưu cấp độ Writing của chính người đang đăng nhập.
- `englify_submit_writing`: chấm xác định khi có answer key; `fill_blank` và `sentence_order` bắt buộc có key. Bài mở không có key nhận `self_review`, không có điểm AI giả.

Người học chỉ đọc chủ đề/bài đã xuất bản và chưa lưu trữ. Answer key không được cấp quyền đọc cho client. Chỉ thành viên trong `admin_members` có thể tạo, sửa, xuất bản hoặc lưu trữ nội dung; thay đổi được ghi audit log. RLS vẫn cô lập submission, feedback, rewrite và revision theo `auth.uid()`.

## Trải nghiệm mobile

Route `/writing` cung cấp:

- lựa chọn và lưu cấp độ Writing A1–C1;
- 10 chủ đề và số bài theo cấp độ;
- gợi ý xác định, ưu tiên bài chưa hoàn thành rồi đến độ khó;
- tìm kiếm, lọc dạng bài/chủ đề và phân trang 5 bài;
- editor phù hợp bài ngắn, bài mở và sắp xếp câu;
- số từ, thời lượng ước tính, lịch sử gần đây và phản hồi đã lưu;
- AI Coach/Rewrite chỉ cho bài mở đã nộp và chỉ khi người dùng bấm yêu cầu.

## Quản trị nội dung

Admin có hai resource `Writing topics` và `Writing exercises`. Form dùng chung hỗ trợ tạo/sửa, tìm kiếm, phân trang, xuất bản và lưu trữ mềm. Exercise editor quản lý CEFR, chủ đề, dạng bài, token sắp xếp và answer key. Quyền Admin được kiểm tra ở database; tài khoản người học không thể ghi nội dung qua việc gọi Supabase trực tiếp.

## Chạy và kiểm tra cục bộ

Docker Desktop phải hoạt động. Các lệnh sau chỉ reset Supabase **local**, không chạy với project production:

```powershell
npx.cmd supabase db reset
npx.cmd supabase db lint --level error
python scripts/run_local_sql_test.py supabase/tests/security_definer_privileges_smoke.sql supabase/tests/writing_ai_v2_smoke.sql supabase/tests/writing_v2_2_smoke.sql
.\.venv\Scripts\python.exe scripts\supabase_local_integration.py
npm.cmd run typecheck -w apps/mobile
npm.cmd run lint -w apps/mobile
npm.cmd test -w apps/mobile
npm.cmd run lint -w apps/admin
npm.cmd test -w apps/admin
npm.cmd run build -w apps/admin
```

Chạy Expo và mở route Writing:

```powershell
cd apps/mobile
npx.cmd expo start --tunnel --clear
```

Trên Expo Web cần mở `/writing`, đổi từng cấp độ, tìm kiếm, lọc, chuyển trang, nộp từng dạng bài và kiểm tra Console/LogBox không có `Unexpected text node: A text node cannot be a child of a <View>`.

## Triển khai

Task này không áp migration hoặc deploy Edge Function lên Supabase production. Trước khi triển khai phải đối chiếu migration history của project, backup, chạy migration trên staging/local, sau đó chỉ áp riêng migration V2.1/V2.2 và deploy Function khi có ủy quyền rõ ràng. Không đưa Gemini key, service role key hoặc database URL vào ứng dụng Expo hay Git.

## Giới hạn

- 50 bài là dữ liệu phát triển gốc của dự án, không phải bộ đề chuẩn hóa hoặc chứng nhận CEFR.
- Gợi ý bài học là thuật toán xác định đơn giản, chưa phải mô hình thích nghi thống kê.
- AI Coach có thể sai; nội dung AI là gợi ý, không phải điểm chính thức.
- Kiểm thử thiết bị iOS/Android vật lý và provider Gemini thật phải được báo riêng; build/export không thay thế kiểm thử runtime.

## Kết quả xác minh ngày 17/11/2026

- PASS — `supabase db reset` áp toàn bộ migration và seed từ database local trống.
- PASS — database lint không phát hiện schema error.
- PASS — ba SQL smoke test về quyền `SECURITY DEFINER`, Writing AI V2.1 và Writing V2.2.
- PASS — local integration gồm Auth/RLS, hồ sơ, Dictionary, Real English, Journey, Writing và Admin.
- PASS — mobile TypeScript, ESLint và 174 unit test trong 46 file.
- PASS — Admin ESLint, 6 unit test và production build.
- PASS — Deno check cho `writing-ai-coach` và `writing-ai-rewrite`.
- PASS — Expo Web export và HTTP SSR `/writing` trả 200.
- NOT TESTED — thao tác runtime/Console trên browser: công cụ browser cục bộ không khởi tạo được do lỗi môi trường `helper_unknown_error`. Cần mở `/writing` theo quy trình ở trên và xác nhận không có LogBox/text-node error.
- NOT TESTED — thiết bị iOS/Android vật lý, Gemini thật và production Supabase. Không có migration hoặc Function production nào được triển khai trong task này.
