# Nền tảng mobile — TASK 01.3

## Cấu trúc và luồng

Expo Router dùng `src/app` cho các route `/login`, `/register`, `/onboarding`, `/home`, `/journey`, `/explore`, `/coach`, `/profile`; `/` chuyển đến `/login`. Root layout đặt `SafeAreaProvider`, TanStack Query, theme và error boundary. `src/components` chứa màn hình dùng chung, `src/state` chứa Zustand store, `src/lib` chứa API client và dữ liệu mẫu.

Đăng nhập/đăng ký hiện là **demo cục bộ**: nhập giá trị mẫu để đi tới Home hoặc Onboarding; không gửi hoặc lưu mật khẩu. Nội dung các trang là mock data, chưa kết nối endpoint học tập. AI Coach chỉ đưa gợi ý luyện tập; chưa có AI, ghi âm hoặc chấm phát âm. Theme có chế độ hệ thống, sáng, tối; lựa chọn hiện chỉ tồn tại trong bộ nhớ phiên.

## Cấu hình môi trường

Sao chép `apps/mobile/.env.example` thành `apps/mobile/.env`. `EXPO_PUBLIC_API_URL` là URL công khai, không chứa token. Trên điện thoại thật, dùng IP LAN của máy phát triển; `localhost` trên điện thoại trỏ về chính điện thoại. Android emulator thường cần `10.0.2.2` thay cho `localhost`; iOS simulator thường truy cập được host qua `localhost` khi máy chủ đang chạy. API client có timeout 10 giây, lỗi HTTP có mã và kiểm tra dữ liệu trả về. Chưa có màn hình gọi API; endpoint health đã được chuẩn bị.

## Lệnh phát triển và kiểm tra

Từ thư mục gốc trên Windows:

```powershell
npm.cmd ci
npm.cmd run mobile
npm.cmd run android -w apps/mobile
npm.cmd run ios -w apps/mobile
npm.cmd run web -w apps/mobile
npm.cmd run lint -w apps/mobile
npm.cmd run typecheck -w apps/mobile
npm.cmd run test -w apps/mobile
```

Lệnh iOS simulator yêu cầu macOS và Xcode; Android emulator yêu cầu Android Studio/SDK. Trên Windows, có thể xem bản web hoặc dùng Expo Go trên thiết bị phù hợp SDK 58. Các kiểm tra web và TypeScript không chứng minh hành vi native; cần thử thủ công trên Android/iOS khi có thiết bị.
