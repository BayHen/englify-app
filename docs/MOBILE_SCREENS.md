# Màn hình di động – TASK 02.2

Ứng dụng Expo có các tuyến `/login`, `/register`, `/onboarding`, `/home`, `/journey`, `/dictionary`, `/translation`, `/real-english`, `/speaking`, `/writing`, `/quiz-arena`, `/rewards` và `/profile`. Trang Home dẫn tới các hoạt động; Explore và Coach tiếp tục là các trang điều hướng bổ sung. Mỗi màn hình dùng thiết kế chung, vùng an toàn, chiều rộng nội dung thích ứng và giao diện sáng/tối theo chế độ hệ thống hoặc lựa chọn trong Profile.

## Nội dung mẫu

- Đăng ký, đăng nhập và đặt lại mật khẩu dùng Supabase Auth khi đã cấu hình dự án. Mật khẩu chỉ chuyển trực tiếp tới Supabase Auth qua SDK; ứng dụng không lưu mật khẩu. Xem `docs/AUTHENTICATION.md` để cấu hình.
- Level, XP, tiến độ bài học, nhiệm vụ mỗi ngày, huy hiệu và phần thưởng đều là **ví dụ minh họa**, không phải tiến độ của người dùng. Hoàn thành quiz hoặc nói một câu không cộng XP.
- Dictionary nay tìm mục từ seed qua FastAPI và có cache SQLite, từ đã lưu, lịch sử tìm kiếm, flashcards và giọng đọc thiết bị; xem `docs/DICTIONARY.md`. Translation vẫn chỉ tra các cặp câu được biên soạn; Real English vẫn hiển thị bộ câu mẫu ngoại tuyến. Không gọi API dịch thuật.
- Speaking hướng dẫn người học tự đọc; chưa ghi âm, nhận dạng tiếng nói hoặc chấm phát âm. Writing kiểm tra số từ, chữ hoa đầu câu và dấu kết câu trên thiết bị; chưa có chấm điểm AI.
- Quiz Arena chấm ba câu hỏi có sẵn trên thiết bị. Điểm chỉ tồn tại khi màn hình đang mở. Rewards cho xem trước, không thể đổi thưởng.

## Trạng thái và giới hạn

Dictionary, Translation và Writing có trạng thái trống tương ứng với truy vấn hoặc bản nháp chưa có kết quả. `AppErrorBoundary` xử lý lỗi hiển thị toàn ứng dụng; thư viện UI cung cấp `ErrorState` và `LoadingSkeleton` cho luồng dữ liệu bất đồng bộ khi được kết nối ở các tác vụ sau. Hiện tại dữ liệu nằm sẵn trên thiết bị, nên các màn hình này không tạo thời gian chờ giả hay gọi backend giả. Hiệu ứng kết thúc quiz tôn trọng cài đặt giảm chuyển động.

Chưa kiểm thử trực tiếp trên thiết bị Android/iOS. Lệnh xuất bundle cho cả hai nền tảng đã chạy thành công; cần kiểm thử thủ công trên thiết bị hoặc simulator trước khi phát hành.

## Chạy và kiểm tra

Tại thư mục gốc:

```bash
npm install
npm run start -w apps/mobile
npm run typecheck -w apps/mobile
npm run lint -w apps/mobile
npm run test -w apps/mobile
```

Có thể dùng `npm run android -w apps/mobile` hoặc `npm run ios -w apps/mobile` khi máy có emulator/simulator tương ứng. Các màn hình mẫu phía sau đăng nhập nay cần Supabase Auth và backend đã cấu hình.
