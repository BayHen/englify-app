# Giao diện xác thực V4

## Thay đổi

Đăng nhập, đăng ký và quên mật khẩu dùng cùng bố cục tối giản qua `AuthScreenLayout`, `AuthBrandHeader`, các ô nhập có trạng thái focus/lỗi, nút chính và liên kết nội tuyến. Form không dùng thẻ bao lớn, mascot hay nhãn trang trí. Nút hiện mật khẩu nằm trong ô nhập. Đăng ký kiểm tra tên, email, mật khẩu và xác nhận mật khẩu tại từng trường; giữ nguyên lời gọi Supabase và hướng điều hướng cũ. Form gửi email khôi phục có trạng thái “Check your email” không xác nhận tài khoản có tồn tại; gửi lại sau 60 giây. Trang chẩn đoán Supabase vẫn ở `/dev/auth-diagnostic` trong development, không còn liên kết từ màn đăng nhập và bị chuyển về Login trong production.

## Tệp sửa

- `apps/mobile/src/components/auth-ui.tsx`: component giao diện dùng chung.
- `apps/mobile/src/components/auth-form.tsx`, `auth-screen.tsx`: đăng nhập, đăng ký và kiểm tra trường.
- `apps/mobile/src/components/forgot-password-screen.tsx`, `apps/mobile/src/app/forgot-password.tsx`: khôi phục và trạng thái gửi email.
- `apps/mobile/src/auth/validation.ts`, `validation.test.ts`: kiểm tra trường đăng ký.

## Kiểm tra và giới hạn

Ảnh chụp Chrome headless ở kích thước web 360 × 780: [Đăng nhập sáng](reports/auth-v4-login-light.png), [Đăng nhập tối](reports/auth-v4-login-dark.png), [Đăng ký](reports/auth-v4-register.png), [Quên mật khẩu](reports/auth-v4-forgot.png). Console không ghi nhận lỗi trên các route này, gồm `Unexpected text node`. Chưa kiểm thử bằng tài khoản Supabase thật, liên kết email khôi phục, bàn phím thiết bị, VoiceOver/TalkBack hoặc Android/iPhone thật trong lần sửa UI này.

Kết quả tự động: TypeScript đạt; ESLint đạt không cảnh báo; 38/38 test đạt (16 tệp); `expo export --platform all` đạt cho Android, iOS và web. Export không thay thế kiểm tra trên thiết bị thật.

Kiểm tra thiết bị: chạy `cd apps/mobile; npx.cmd expo start --clear`, mở Expo Go, thử nhập sai rồi đúng trên cả ba form, bật/tắt mật khẩu, mở bàn phím và cuộn trên màn hình nhỏ, chuyển theme, tăng cỡ chữ hệ thống, dùng TalkBack/VoiceOver; kiểm tra Console/LogBox sau mỗi thao tác. Dùng tài khoản thử nghiệm do người phát triển quản lý để xác minh email đăng ký/khôi phục; không gửi mật khẩu hoặc token vào log.
