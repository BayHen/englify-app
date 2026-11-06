# Englify Quest Mobile

Ứng dụng dùng Expo SDK 58 và **Expo Router**. Entry point là `expo-router/entry` trong `apps/mobile/package.json`; route đầu tiên nằm tại `src/app/index.tsx`, navigator tại `src/app/_layout.tsx`. Không cần tạo `App.tsx`.

## Chạy trên Windows

Từ thư mục gốc `D:\englify-app`:

```powershell
npm.cmd ci
npm.cmd start -- --clear
```

Hoặc từ `D:\englify-app\apps\mobile`:

```powershell
npx.cmd expo start --clear
```

Không chạy `npx expo start` trực tiếp ở thư mục gốc: Expo sẽ coi monorepo root là ứng dụng và tìm `expo/AppEntry.js` / `../../App`, trong khi ứng dụng thật nằm trong `apps/mobile`.

Để mở trên iPhone bằng Expo Go, cài Expo Go tương thích với SDK 58, kết nối iPhone và máy Windows vào cùng mạng, chạy lệnh trên rồi quét mã QR bằng Camera. Nếu LAN bị chặn, dùng `npx.cmd expo start --tunnel --clear` **trong `apps/mobile`**. URL API trong `apps/mobile/.env` phải truy cập được từ iPhone; `localhost` trên iPhone là chính điện thoại. Sau khi đổi `.env`, khởi động lại Expo.

Kiểm tra entry/bundle cục bộ: `npx.cmd expo export --platform ios` từ `apps/mobile`. Kiểm tra tĩnh: `npm.cmd run typecheck -w apps/mobile`, `npm.cmd run lint -w apps/mobile`, `npm.cmd run test -w apps/mobile`. Xuất bundle không thay thế kiểm thử trên iPhone thật.
