# Từ điển: Free Dictionary API

Màn hình `/dictionary` giữ nguyên thiết kế hiện tại. Danh sách mặc định và tìm kiếm tiếng Việt vẫn đọc `dictionary_entries` (Supabase). Khi tìm **một từ tiếng Anh**, ứng dụng tra thêm `https://api.dictionaryapi.dev/api/v2/entries/en/{word}` và hiển thị phát âm IPA, loại từ, định nghĩa, ví dụ, nguồn và giấy phép theo dữ liệu nhà cung cấp. Từ đã tồn tại trong kho biên tập không bị thay thế.

Free Dictionary API không có endpoint duyệt danh sách từ hay bản dịch tiếng Việt. Vì vậy kết quả mới từ API có thể chưa có dòng nghĩa tiếng Việt; không suy diễn bản dịch từ định nghĩa tiếng Anh. Tìm kiếm tiếng Việt chỉ dựa trên dữ liệu biên tập. Phát âm dùng `expo-speech` như trước.

## Kích hoạt lưu từ API

Chức năng Save phải lưu vào `dictionary_entries` trước khi thêm vào `saved_vocabulary` để không làm hỏng khóa ngoại và lịch ôn tập. Deploy Edge Function mới trong Supabase tương ứng với project:

```bash
supabase functions deploy dictionary-import
```

Function xác thực JWT của người dùng, tra cứu lại từ qua Free Dictionary API từ server, dùng `SUPABASE_SERVICE_ROLE_KEY` **chỉ trong Supabase Edge Runtime**, kiểm tra bản ghi hiện có và chèn nếu chưa tồn tại. Không cần thêm service-role key vào ứng dụng. `EDGE_ALLOWED_ORIGINS` (danh sách origin được phép, phân cách bằng dấu phẩy) cần cấu hình nếu dùng trình duyệt web; Expo native không gửi Origin. Giữ chính sách JWT verification bật.

Nguồn dữ liệu và điều khoản bản quyền tùy bản ghi do API trả về; trường `source_name` và `license_id` được hiển thị trên thẻ. Kiểm tra điều kiện của nguồn dữ liệu trước khi phân phối hoặc tái sử dụng nội dung ở quy mô lớn. API ngoài có thể bị giới hạn tần suất hoặc gián đoạn.

## Kiểm thử thủ công

1. Tìm `curious`: nếu chưa có từ biên tập, thẻ hiện dữ liệu nguồn Free Dictionary API; nút Pronounce phát âm.
2. Save word, chuyển sang Saved và Flashcards, sau đó mở lại app: từ lưu vẫn tồn tại.
3. Tìm từ tiếng Việt có sẵn: kết quả Supabase vẫn hiện.
4. Tìm từ vô nghĩa: không thêm bản ghi giả.
5. Tắt mạng: xem cache, không đưa ID tạm `external:` vào hàng đợi đồng bộ.
6. Kiểm tra React Native Web Console/LogBox để xác nhận không có `Unexpected text node`.
