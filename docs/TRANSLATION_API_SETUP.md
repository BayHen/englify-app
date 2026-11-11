# Thiết lập dịch MyMemory qua Supabase Edge Function

Mobile gọi `supabase.functions.invoke('translate')` với phiên Supabase Auth. Edge Function kiểm tra token, đặt chỗ quota bằng RPC `englify_reserve_translation`, rồi gọi `https://api.mymemory.translated.net/get` qua HTTPS. Không cần API key, FastAPI hay dịch vụ trả phí.

## Giới hạn và quyền riêng tư

Theo [đặc tả MyMemory](https://mymemory.translated.net/doc/spec.php), tham số `q` tối đa **500 byte UTF-8** mỗi request. Chỉ gửi **một câu/đoạn ngắn**; ứng dụng báo lỗi cho văn bản dài, không cắt ngầm hoặc chia nhiều request. [Quota công bố](https://mymemory.translated.net/doc/usagelimits.php) cho truy cập ẩn danh là **5.000 ký tự/ngày**, có thể chia sẻ theo IP egress của Edge Function. Migration `20261111100000_mymemory_quota.sql` đặt ngân sách toàn dự án 4.500 ký tự/ngày, 10 yêu cầu/phút/người dùng và 50 yêu cầu/ngày/người dùng. Quota MyMemory vẫn có thể cạn trước nếu IP được dùng ở nơi khác; Edge trả 429. Request lỗi upstream cũng tính vào ngân sách nội bộ để tránh lạm dụng. Cache trong bộ nhớ mobile giữ tối đa 100 kết quả trong một giờ theo user + cặp ngôn ngữ + văn bản; mất khi khởi động lại ứng dụng. Câu người dùng tự lưu vẫn ở bộ nhớ local như trước.

Nội dung nhập được gửi đến MyMemory. Không nhập bí mật hoặc dữ liệu nhạy cảm. Tham khảo [điều khoản MyMemory](https://mymemory.translated.net/terms-and-conditions) trước khi sử dụng thương mại. Kết quả là bản dịch từ dịch vụ bên ngoài, có thể thiếu chính xác; không có bản dịch giả khi API lỗi. Thử nghiệm thực tế cho thấy MyMemory nhạy chữ hoa/chữ thường: `License` từng trả nguyên văn, `giấy phép` từng trả “mining”. Với từ/cụm tối đa ba từ, provider viết hoa chữ đầu khi tra cứu; nếu kết quả chính chỉ lặp lại nguồn, provider xét bản khớp gần từ cùng phản hồi có điểm match từ 0,98 và cùng cụm nguồn. Nếu không có bản dịch khác, app báo lỗi thay vì hiện nguyên văn như bản dịch. Provider mới đã gọi MyMemory thật và nhận `License → Giấy phép.`, `giấy phép → License`; Edge Function phiên bản 2 đã triển khai. Đây là quy tắc hạn chế lỗi rõ ràng, không bảo đảm mọi nghĩa theo ngữ cảnh. MyMemory `get` không có tự phát hiện ngôn ngữ nguồn trong hợp đồng dùng ở đây; người dùng chọn English/Vietnamese thủ công. Chức năng không phù hợp để dịch tài liệu dài.

## Cấu hình và triển khai

1. Cấu hình `EXPO_PUBLIC_SUPABASE_URL` và `EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY` trong `apps/mobile/.env`; không đưa service role key vào mobile.
2. Áp các migration Supabase theo thứ tự trên một dự án thử nghiệm trước, gồm `20261110110000_translation_quota.sql` và `20261111100000_mymemory_quota.sql`. Migration chỉ thêm scope quota và thay function, không xóa lịch sử.
3. Đặt `TRANSLATE_ALLOWED_ORIGINS` trong Edge Secrets với các origin Expo Web thực tế, phân cách dấu phẩy. Native không gửi Origin. Không cần Azure secret nào.
4. Function `translate` đã được triển khai lên dự án Supabase đang cấu hình ngày 11/11/2026 sau khi người dùng cho phép; trạng thái `ACTIVE`, `verify_jwt = true`. Khi cập nhật bản sau, triển khai riêng Function này bằng `npx.cmd supabase functions deploy translate --remote=<PROJECT_REF> --use-api --yes` sau khi kiểm thử và được phép triển khai.
5. Chạy Expo từ `apps/mobile`: `npx.cmd expo start --tunnel --clear`.

## Kiểm tra

- Sau deploy, đăng nhập rồi dịch một câu mới English → Vietnamese và Vietnamese → English. Kiểm tra cả câu trống, hơn 500 byte (ví dụ nhiều dấu tiếng Việt), copy/lưu, 429 và retry khi mạng phục hồi.
- Chạy `npm.cmd run test -w apps/mobile -- src/features/translation`, `npm.cmd run typecheck -w apps/mobile`, `npm.cmd run lint -w apps/mobile`.
- Web: mở route `/translation`, thao tác thật và kiểm tra Console/LogBox không có `Unexpected text node`. Android/iOS cần xác minh riêng trên thiết bị; test unit không thay thế kiểm tra đó.
- 401: phiên hết hạn; 422: input/cặp ngôn ngữ sai; 429: quota; 502: dữ liệu upstream lỗi; 504: timeout 8 giây.
- Nếu điện thoại báo Function chưa triển khai, kiểm tra `npx.cmd supabase functions list --remote=<PROJECT_REF> --output json`. Trước khi sửa ngày 11/11/2026, dự án trả `[]` và gateway `404 NOT_FOUND`; sau khi áp migration và deploy, Function ở trạng thái `ACTIVE`, request không có phiên đăng nhập trả `401` như mong đợi. Sau bản sửa chọn bản khớp, người dùng xác nhận trên Expo Go `License → Giấy phép.` và `giấy phép → License`. Không dùng URL Expo Tunnel thay cho Supabase Function URL.

Không ghi token, mật khẩu, văn bản riêng tư hay URL database vào log/báo lỗi.

## Màn hình từ điển và phát âm

Màn hình Translate gọi [Free Dictionary API](https://dictionaryapi.dev/) trực tiếp qua HTTPS cho một từ tiếng Anh; không cần API key. Phản hồi có thể thiếu IPA, audio, ví dụ hoặc từ liên quan. Khi thiếu dữ liệu hoặc API trả 404, vẫn hiển thị bản dịch MyMemory. Nguồn dữ liệu và liên kết giấy phép được hiển thị cạnh phần từ điển, còn nguồn dịch ghi trong [TRANSLATION.md](TRANSLATION.md). Nút dịch ví dụ tạo một request MyMemory thật và tính vào quota; câu quá 500 byte không được gửi. Audio dùng `expo-audio`, fallback giọng thiết bị `expo-speech` với `en-US`; trên iPhone ở chế độ im lặng, TTS có thể không phát tiếng theo [Expo Speech](https://docs.expo.dev/versions/v58.0.0/sdk/speech/).

Để kiểm tra sau khi tải lại Expo Go: dịch `License` và `giấy phép`, mở chi tiết từ `license` để xem IPA/định nghĩa/audio, thử câu dài để xác nhận không hiện trường từ điển, dịch ví dụ nếu có, copy và lưu. Kiểm tra bản ghi đã lưu trước đây vẫn hiện. Android và Expo Web cần kiểm tra runtime riêng; test unit không chứng minh phát âm thực trên thiết bị.
