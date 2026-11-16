# Dictionary V3: Free Dictionary API, MyMemory và Supabase

## Kiến trúc đang dùng

Dictionary V3 giữ Supabase PostgreSQL làm nguồn dữ liệu chính. Mobile không gọi trực tiếp API bên thứ ba để tạo một mục từ có thể lưu. Luồng tìm một từ tiếng Anh chính xác như sau:

1. Mobile tìm trong `dictionary_entries` bằng Supabase Data API và RLS.
2. Nếu đã có mục từ chính xác, ứng dụng dùng bản ghi hiện hữu và không gọi dịch vụ ngoài. Nội dung do biên tập viên tạo không bị ghi đè.
3. Nếu chưa có, mobile gọi Edge Function `dictionary-import` bằng access token hiện tại.
4. Function xác minh phiên Supabase, tra Free Dictionary API, rồi gọi Edge Function `translate` hiện hữu để dịch Anh → Việt bằng MyMemory.
5. Function lưu mục đã kiểm tra vào `dictionary_entries` bằng service role ở phía server. Unique `(language, normalized_term)` và `on_conflict` giúp thao tác có tính idempotent.
6. Mobile nhận lại UUID PostgreSQL thật. Saved Vocabulary, Flashcards, Vocabulary Review và hàng đợi offline tiếp tục dùng cùng một `entry_id`; hệ thống không tạo ID tạm.

Tìm kiếm tiếng Việt, tìm tiền tố và danh sách mặc định chỉ đọc dữ liệu Supabase. Chỉ truy vấn gồm đúng một từ tiếng Anh, tối đa 80 ký tự, mới có thể kích hoạt import.

## Nguồn dữ liệu và giấy phép

- Định nghĩa, IPA, loại từ, ví dụ, audio và từ liên quan: [Free Dictionary API](https://dictionaryapi.dev/) tại endpoint `https://api.dictionaryapi.dev/api/v2/entries/en/{word}`.
- Mỗi phản hồi có thể chứa `license` và `sourceUrls`. Function lưu tên giấy phép vào `license_id` và ghi `source_name = Free Dictionary API`. Nội dung thường được trả theo CC BY-SA 3.0, nhưng ứng dụng ưu tiên giá trị giấy phép thực tế trong phản hồi thay vì giả định cho mọi mục.
- Bản dịch Anh–Việt: [MyMemory](https://mymemory.translated.net/doc/spec.php) thông qua Edge Function `translate` hiện hữu. Quota và xử lý `unavailable` của Translate không bị nhân bản trong Dictionary.
- Nội dung biên tập của dự án vẫn mang `source_name = Englify Quest editorial` và `license_id = project-owned`; Dictionary V3 không sửa các bản ghi này.

Không scrape từ điển thương mại. Không dùng API trả phí. Khi provider trả 404, hệ thống báo không tìm thấy và không tạo nghĩa giả. Khi MyMemory tạm thời không khả dụng, mục tiếng Anh hợp lệ vẫn có thể được lưu với `translation = null` và cảnh báo rõ; không dùng nguyên văn tiếng Anh làm bản dịch tiếng Việt.

Theo tài liệu MyMemory hiện hành, tham số `q` tối đa 500 byte và lượt anonymous miễn phí giới hạn 5.000 ký tự/ngày. Edge Function `translate` đã kiểm tra giới hạn 500 byte và giữ quota theo người dùng/toàn hệ thống. Khi quota trả HTTP 429, `dictionary-import` không ghi bản ghi mới để tránh dùng đường import nhằm vượt giới hạn dịch.

## Bảo mật và quyền riêng tư

- `dictionary-import` yêu cầu JWT của người dùng và xác minh lại bằng Supabase Auth trước khi truy cập provider hoặc database.
- `SUPABASE_SERVICE_ROLE_KEY` chỉ tồn tại trong Edge Runtime. Không đặt key này trong Expo, `.env.example`, bundle mobile, log hoặc phản hồi API.
- Function chỉ nhận `{ "word": "..." }`, từ chối trường thừa, câu nhiều từ, payload lớn và origin web không nằm trong allowlist.
- Chỉ URL HTTPS hợp lệ được chấp nhận cho audio, nguồn và giấy phép.
- RLS vẫn bảo vệ `saved_vocabulary` theo `auth.uid()`. Import mục từ công khai không thay đổi lịch ôn, lịch sử học hoặc dữ liệu người dùng.
- Từ người dùng tra được gửi tới Free Dictionary API và MyMemory. Không nhập dữ liệu cá nhân hoặc bí mật vào ô Dictionary/Translate.

## Cấu hình và triển khai

Không cần API key cho Free Dictionary API hoặc MyMemory anonymous. Supabase tự cung cấp `SUPABASE_URL`, public key và service role secret cho Edge Runtime. Nếu web được sử dụng, cấu hình `TRANSLATE_ALLOWED_ORIGINS`; `dictionary-import` dùng `DICTIONARY_ALLOWED_ORIGINS` nếu có, nếu không sẽ dùng chung allowlist Translate.

```powershell
npx.cmd supabase functions deploy dictionary-import --use-api --yes
npx.cmd supabase functions list
```

Function phải xuất hiện ở trạng thái `ACTIVE` và có `verify_jwt = true`. Không thêm service role key vào `apps/mobile/.env`.

Khởi động Expo với workflow hiện tại:

```powershell
cd D:\englify-app\apps\mobile
npx.cmd expo start --tunnel --clear
```

## Kiểm thử

```powershell
npm.cmd test -w apps/mobile -- --run src/features/dictionary
npm.cmd run typecheck -w apps/mobile
npm.cmd run lint -w apps/mobile
npm.cmd run export:web -w apps/mobile
```

Các trường hợp cần kiểm tra thủ công trên Expo Go:

1. Tìm một từ seed có sẵn: không tạo mục trùng.
2. Tìm một từ tiếng Anh hợp lệ chưa có: kết quả có định nghĩa thật và có thể Save.
3. Tìm một chuỗi không tồn tại: hiện trạng thái không tìm thấy, không bịa nội dung.
4. Mất mạng sau khi đã xem từ: cache hiển thị lại mục đã lưu cục bộ.
5. Lưu từ, mở Flashcards, đánh giá Vocabulary Review, đăng xuất/đăng nhập: tiến độ và lịch ôn không mất.
6. Kiểm tra Pronounce: ưu tiên audio HTTPS khi có; Expo Speech là fallback theo hành vi giao diện hiện hữu.

## Giới hạn

- Free Dictionary API và MyMemory là dịch vụ bên ngoài, có thể chậm, thiếu IPA/audio/ví dụ, giới hạn lượt gọi hoặc tạm ngừng.
- Bản ghi Supabase hiện lưu một định nghĩa chính, một loại từ và một ví dụ. Edge Function vẫn kiểm tra tối đa ba nghĩa từ provider và trả `details.senses`; giao diện Dictionary hiện hữu không được thay đổi trong task này nên chỉ trình bày trường chính.
- Cache trên thiết bị chỉ phục vụ nội dung đã tải; nó không thay thế Supabase cho quyền sở hữu Saved Vocabulary hoặc lịch ôn.
- Không tuyên bố hoạt động trên iPhone/Android thật nếu chưa chạy kiểm tra trực tiếp trên thiết bị.
