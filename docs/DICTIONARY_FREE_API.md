# Từ điển: Free Dictionary API

Màn hình `/dictionary` giữ nguyên thiết kế hiện tại. Danh sách mặc định và tìm kiếm tiếng Việt vẫn đọc `dictionary_entries` (Supabase). Khi tìm **một từ tiếng Anh**, ứng dụng tra thêm `https://api.dictionaryapi.dev/api/v2/entries/en/{word}` và hiển thị phát âm IPA, loại từ, định nghĩa, ví dụ, nguồn và giấy phép theo dữ liệu nhà cung cấp. Từ đã tồn tại trong kho biên tập không bị thay thế.

Free Dictionary API không có endpoint duyệt danh sách từ hay bản dịch tiếng Việt. Với từ tiếng Anh mới, ứng dụng dùng **Edge Function `translate` hiện có (MyMemory)** để lấy nghĩa tiếng Việt và chỉ hiển thị khi nhà cung cấp trả bản dịch hợp lệ. Nếu hết quota hoặc API lỗi, vẫn hiển thị định nghĩa tiếng Anh, không dùng bản dịch giả. Tìm kiếm tiếng Việt vẫn dựa trên dữ liệu Supabase. Phát âm dùng `expo-speech` như trước.

## Kích hoạt lưu từ API

Chức năng Save phải lưu vào `dictionary_entries` trước khi thêm vào `saved_vocabulary` để không làm hỏng khóa ngoại và lịch ôn tập. Deploy Edge Function mới trong Supabase tương ứng với project:

```bash
supabase functions deploy dictionary-import
```

Function xác thực JWT của người dùng, tra cứu lại từ qua Free Dictionary API từ server, dùng `SUPABASE_SERVICE_ROLE_KEY` **chỉ trong Supabase Edge Runtime**, kiểm tra bản ghi hiện có và chèn nếu chưa tồn tại. Trước khi chèn, function gọi `translate` với JWT người dùng để lấy nghĩa tiếng Việt bằng MyMemory và tuân thủ quota hiện có. Nếu dịch thất bại, vẫn lưu từ với `translation: null` để người dùng có thể tiếp tục học; lần Save sau có thể bổ sung nghĩa cho từ đã import mà không ghi đè bản biên tập. Không cần thêm service-role key vào ứng dụng. `EDGE_ALLOWED_ORIGINS` (danh sách origin được phép, phân cách bằng dấu phẩy) cần cấu hình nếu dùng trình duyệt web; Expo native không gửi Origin. Giữ chính sách JWT verification bật. **Cần deploy cả `translate` và `dictionary-import`.**

Nguồn dữ liệu và điều khoản bản quyền tùy bản ghi do API trả về; trường `source_name` và `license_id` được hiển thị trên thẻ. Kiểm tra điều kiện của nguồn dữ liệu trước khi phân phối hoặc tái sử dụng nội dung ở quy mô lớn. API ngoài có thể bị giới hạn tần suất hoặc gián đoạn.

## Kiểm thử thủ công

1. Tìm `curious`: nếu chưa có từ biên tập, thẻ hiện dữ liệu nguồn Free Dictionary API; nghĩa Việt từ MyMemory (nếu khả dụng); nút Pronounce phát âm.
2. Save word, chuyển sang Saved và Flashcards, sau đó mở lại app: từ và nghĩa Việt được lưu lại nếu dịch thành công.
3. Tìm từ tiếng Việt có sẵn: kết quả Supabase vẫn hiện.
4. Tìm từ vô nghĩa: không thêm bản ghi giả.
5. Tắt mạng: xem cache, không đưa ID tạm `external:` vào hàng đợi đồng bộ.
6. Kiểm tra React Native Web Console/LogBox để xác nhận không có `Unexpected text node`.
7. Giả lập MyMemory trả lỗi 429/mất mạng: định nghĩa tiếng Anh vẫn hiện và vẫn lưu được từ; không ghi đè nghĩa của bản biên tập.
