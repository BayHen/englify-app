# Học ngoại tuyến và đồng bộ

## Phạm vi

- Khi trực tuyến, mở **Journey → Lesson → Download for offline use** để lưu bài đã mở khóa. Journey và kết quả tra từ đã tải có thể xem khi mất mạng.
- Bài đã tải có thể làm ngoại tuyến. **Save attempt for sync** lưu câu trả lời và mã yêu cầu duy nhất trên thiết bị. Ứng dụng không chấm, cộng XP hay mở khóa cho đến khi FastAPI kiểm tra.
- Từ đã có trong bộ nhớ đệm có thể lưu khi mất mạng; thao tác được đưa vào hàng đợi. Xóa từ đã lưu hiện cần kết nối.
- iOS/Android dùng `expo-sqlite` cho bài, Journey và hàng đợi; từ điển dùng `expo-sqlite/kv-store`. Web dùng `localStorage`, có thể bị xóa bởi cài đặt trình duyệt.
- Profile được lưu theo user ID sau khi tải thành công. Nếu phiên đăng nhập trên thiết bị vẫn hợp lệ nhưng API mất kết nối, ứng dụng dùng profile này để mở bài đã tải sau khi khởi động lại. Nếu token hết hạn và Supabase không thể khôi phục phiên, cần kết nối lại để đăng nhập.

## Quy tắc đồng bộ

- Dữ liệu cục bộ gắn với Supabase user ID. Hàng đợi giữ trạng thái `pending`, `synced`, `conflict` hoặc `rejected`; bản ghi đã đồng bộ không bị xóa. Không lưu access token trong SQLite.
- Khi trở lại trực tuyến, bộ đồng bộ chạy ở cấp ứng dụng, kể cả khi đang ở Home; có thể chọn **Sync now** trên Journey/Lesson/Dictionary. Hệ thống thử lại mỗi 30 giây khi ứng dụng đang mở. Lỗi mạng/server thử lại theo cấp số nhân tối đa 5 phút. Lỗi 401 giữ mục chờ. Trước mỗi mục, user ID của phiên hiện tại phải khớp chủ sở hữu hàng đợi. Gửi bài theo thứ tự thời gian để server mở khóa đúng quy tắc.
- `GET /api/v1/lessons/{id}/offline-package` chỉ cho tải bài đã mở khóa và trả `content_version` SHA-256. Migration `20261107_12` cập nhật dấu thời gian khi sửa nội dung con/đáp án. `POST /api/v1/lessons/{id}/offline-sync` yêu cầu phiên bản, câu trả lời, `request_id`; backend kiểm tra JWT, quyền, đáp án, phiên bản và XP trong giao dịch. Gửi lại cùng mã trả kết quả cũ, không thưởng XP lần hai.
- Nội dung thay đổi sẽ trả 409. Câu trả lời cũ vẫn trên máy với trạng thái cần xem lại; tải phiên bản mới và làm lại. Lịch sử đã được server chấp nhận không bị xóa.

## Cài đặt và kiểm tra

Từ thư mục gốc:

```powershell
npm.cmd install
.\.venv\Scripts\python.exe -m alembic -c backend/alembic.ini upgrade head
npm.cmd run typecheck --workspace @englify/mobile
npm.cmd run lint --workspace @englify/mobile
npm.cmd run test --workspace @englify/mobile
```

Kiểm thử backend tích hợp dùng PostgreSQL tạm đã migration/seed, qua `ENGLIFY_TEST_DATABASE_URL`; không trỏ biến này vào database người dùng.

Kiểm tra thiết bị: tải bài khi online; tắt mạng; mở bài và gửi câu trả lời; xác nhận trạng thái chờ và XP không đổi; bật mạng; chọn **Sync now**; kiểm tra kết quả server và gửi lại không tạo XP. Đăng xuất/đăng nhập lại để kiểm tra dữ liệu vẫn thuộc đúng tài khoản. Web và `expo export` không thay thế được bước thử trên thiết bị.

## Giới hạn

- Bản tải không chứa âm thanh riêng; câu hỏi nghe dùng TTS của thiết bị nếu có.
- Journey ngoại tuyến hiển thị trạng thái từ bản lưu gần nhất, có thể cũ đến lúc đồng bộ.
- Mục bị từ chối được giữ lại; chưa có giao diện sửa câu trả lời cũ và gửi lại trực tiếp.
