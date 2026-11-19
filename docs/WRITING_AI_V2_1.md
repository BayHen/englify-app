# Writing V2.1 — AI Writing Coach và AI Rewrite

## Báo cáo audit ngắn

Trước thay đổi này, Writing đã dùng Supabase Auth và các RPC `englify_submit_writing`, `englify_writing_history`, `englify_writing_submission`. Bài gốc được lưu trong `writing_submissions`; kết quả quy tắc và trạng thái LanguageTool nằm riêng trong `writing_feedback`. `request_id` chống nộp trùng, RLS chỉ cho người học đọc bài của mình, còn `writing-grammar` xác minh JWT và quyền sở hữu trước khi gọi LanguageTool tự lưu trữ.

Khoảng trống của bản cũ là chưa có dữ liệu AI được xác thực, revision có phiên bản, quota AI theo người dùng hoặc giao diện so sánh bản gốc/bản cải thiện. Writing V2.1 mở rộng theo kiểu cộng thêm; không sửa dữ liệu cũ, không thay grading xác định của bài có cấu trúc và không loại bỏ LanguageTool.

## Kiến trúc đã triển khai trong mã nguồn

Luồng AI là `Expo → Supabase Edge Function → Gemini Developer API → PostgreSQL`. Mobile không biết `GEMINI_API_KEY` và không gọi Gemini trực tiếp.

- `writing-ai-coach`: chỉ phân tích submission paragraph đã lưu và thuộc phiên đăng nhập. Kết quả JSON được kiểm tra điểm 0–100, giới hạn mảng/chuỗi và yêu cầu mỗi lỗi phải trích từ bài gốc.
- `writing-ai-rewrite`: hỗ trợ `grammar`, `natural`, `vocabulary`, `formal`, `simple`; bản gốc trong phản hồi phải khớp tuyệt đối với submission.
- `writing_ai_feedback`: feedback và điểm do server ghi; client chỉ đọc dữ liệu của mình.
- `writing_ai_rewrites`: bản viết cải thiện tách riêng, không ghi đè bài gốc.
- `writing_revisions`: revision do người học chủ động lưu, đánh số tuần tự và có thể tham chiếu feedback/rewrite.
- `writing_ai_usage`: quota theo loại request/ngày, claim bằng transaction và advisory lock; idempotency key ngăn tính hai lần.

Giao diện mobile giữ phần feedback quy tắc/LanguageTool, sau đó hiển thị AI Coach cho bài paragraph đủ điều kiện. Người học có thể xem điểm ước lượng, ưu điểm, lỗi chi tiết, năm chế độ rewrite, chuyển Original/Improved, sao chép và lưu revision. Điểm AI được ghi rõ là hướng dẫn ước lượng, không phải chứng chỉ CEFR/IELTS.

## Bảo mật và giới hạn

- Edge Function xác minh JWT qua Supabase Auth, truy vấn submission bằng JWT người dùng và kiểm tra `user_id`.
- Authenticated client không có quyền INSERT/UPDATE feedback, rewrite, usage hoặc revision trực tiếp. Revision chỉ được tạo qua RPC kiểm tra ownership.
- Service-role và Gemini key chỉ nằm trong Edge Secrets; không dùng biến `EXPO_PUBLIC_*`.
- Mặc định tối đa 5 Coach và 5 Rewrite mỗi người mỗi ngày. Cấu hình Edge không chấp nhận giá trị lớn hơn 5 trong giai đoạn này.
- Chỉ paragraph đã lưu, dài 20–5000 ký tự, mới được gửi tới Gemini. Bài sentence/fill/order vẫn dùng grading xác định.
- Provider timeout, quota hoặc JSON sai không xóa submission và không thay feedback quy tắc.
- AI vẫn có thể bỏ sót hoặc đề xuất chưa phù hợp. Người học phải kiểm tra trước khi sử dụng.

## Biến môi trường Edge

Không đưa giá trị thật vào Git. Cấu hình trong Supabase Edge Secrets:

```env
GEMINI_API_KEY=<secret>
GEMINI_MODEL=<model-Free-tier-da-duoc-xac-minh>
AI_FREE_TIER_CONFIRMED=true
AI_MONTHLY_MAX_ESTIMATED_COST_USD=0
WRITING_AI_ENABLED=true
WRITING_AI_COACH_DAILY_LIMIT=5
WRITING_AI_REWRITE_DAILY_LIMIT=5
WRITING_AI_MAX_OUTPUT_TOKENS=2048
EDGE_ALLOWED_ORIGINS=<cac-origin-web-duoc-phep>
```

Chỉ đặt `AI_FREE_TIER_CONFIRMED=true` sau khi kiểm tra project Gemini thực sự dùng Free tier và không bật billing trả phí. Native Expo không gửi Origin; Expo Web phải nằm trong `EDGE_ALLOWED_ORIGINS`.

## Kiểm tra local

Các lệnh database sau chỉ dành cho Supabase local có thể xóa dữ liệu phát triển. Không chạy `db reset` với production:

```powershell
npx.cmd supabase start
npx.cmd supabase db reset
npx.cmd supabase db lint --level error
python scripts/run_local_sql_test.py supabase/tests/security_definer_privileges_smoke.sql supabase/tests/writing_ai_v2_smoke.sql
npx.cmd deno check supabase/functions/writing-ai-coach/index.ts supabase/functions/writing-ai-rewrite/index.ts
npm.cmd run typecheck -w apps/mobile
npm.cmd run lint -w apps/mobile
npm.cmd run test -w apps/mobile
```

Để thử provider local, tạo file secret local không commit, bật các cờ Writing AI và dùng tài khoản Supabase local. Kiểm tra: submission paragraph hợp lệ, input ngắn, năm rewrite mode, hết quota, nhấn lặp, phiên hết hạn và tài khoản thứ hai.

## Triển khai (chưa thực hiện)

1. Sao lưu và đối chiếu migration history của project Supabase. Repository từng có lịch sử remote không khớp; không chạy bulk `db push` khi chưa đối chiếu.
2. Review riêng `20261117010000_writing_ai_v2.sql`, thử trên database tạm, sau đó mới áp migration lên project thật khi có ủy quyền.
3. Đặt Edge Secrets bằng Supabase Dashboard/CLI; không dán key vào terminal log hoặc chat.
4. Deploy `writing-ai-coach` và `writing-ai-rewrite` với JWT verification bật.
5. Chạy test hai tài khoản để xác nhận RLS, rồi thử một request Coach và từng rewrite mode trong giới hạn Free tier.
6. Khởi động Expo từ `apps/mobile` bằng `npx.cmd expo start --tunnel --clear` và kiểm tra Android/iOS/Web thực tế.

## Trạng thái xác minh ngày 17/11/2026

- Mobile TypeScript: PASS.
- Mobile unit tests: PASS — 46 tệp, 172 test; gồm validator AI, timeout/quota, đủ năm rewrite mode, API client, Edge authorization và luồng lỗi LanguageTool cũ.
- Deno check cho toàn bộ Edge Functions: PASS.
- Expo Web export: PASS; route `/writing` được bundle thành công.
- Supabase migration/RLS local: PASS — `supabase db reset` áp toàn bộ migration và seed từ database trống; `db lint --level error` không phát hiện lỗi; smoke test SECURITY DEFINER, quota/idempotency và RLS hai tài khoản đều đạt.
- Supabase integration local: PASS — Auth/RLS, profile, dictionary, Real English, quota, learning plan, gamification, Journey, Writing cũ và Admin không phát hiện regression.
- Gemini thật, deploy production và thiết bị Android/iOS: NOT TESTED; không có migration/function nào được deploy trong task này.
- Expo Web runtime/Console và lỗi `Unexpected text node`: NOT TESTED bằng browser automation; cần làm theo quy trình bên dưới sau khi migration local sẵn sàng.

## Kiểm tra thủ công sau triển khai

1. Mở `/writing`, nộp paragraph ít nhất 20 ký tự và xác nhận bài gốc/feedback quy tắc xuất hiện trước.
2. Nhấn **Improve with AI**; xác nhận loading chặn nhấn lặp, điểm có nhãn ước lượng và lỗi có Original/Suggestion/Explanation.
3. Thử cả năm mode; chuyển Original/Improved, copy, sửa và lưu revision; tải lại để xác nhận history còn nguyên.
4. Tắt mạng hoặc Function; xác nhận bài gốc vẫn tồn tại và lỗi AI không đăng xuất người dùng.
5. Trên Expo Web, thao tác toàn bộ route và xem Console/LogBox; không được có `Unexpected text node: A text node cannot be a child of a <View>`.

