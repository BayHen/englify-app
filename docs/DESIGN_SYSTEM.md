# Hệ thiết kế gamified — TASK 02.1

## Nguồn token

`packages/shared/src/index.ts` là nguồn duy nhất cho màu, bảng màu sáng/tối, cỡ chữ, chiều cao dòng, khoảng cách, bo góc, bóng và thời lượng chuyển động. `apps/mobile/src/constants/app-theme.ts` chọn palette theo chế độ `system`, `light` hoặc `dark` trong Zustand. Giao diện dùng màu chữ và nền có tương phản riêng cho mỗi theme; màu thưởng vàng dùng cho nhấn mạnh, không thay cho phản hồi bằng chữ.

| Nhóm | Giá trị chính |
| --- | --- |
| Màu | tím `#7456F1`, vàng `#FFC857`, xanh thành công `#37C99B`, đỏ lỗi `#FF7B82` |
| Chữ | `xs` đến `display`, cỡ 12–36, chiều cao dòng 17–43 |
| Khoảng cách | 4, 8, 12, 16, 24, 32, 48 |
| Bo góc | 10, 14, 18, 24, pill |
| Bóng | `soft`, `lifted`; elevation cho Android |
| Chuyển động | 140, 240, 420 ms |

## Component API

Tất cả component được export từ `apps/mobile/src/ui/index.ts`. Props có kiểu TypeScript; tiêu đề, XP, tiến độ, trạng thái bài học và nội dung phần thưởng do màn hình cung cấp, không cố định trong component.

| Component | Vai trò |
| --- | --- |
| `AppButton`, `AppCard`, `AppText`, `AppInput` | Nút, bề mặt, phân cấp chữ và trường nhập |
| `AppModal`, `AppBottomSheet` | Nội dung nổi có nút đóng và xử lý nút Back Android |
| `XPProgressBar`, `LevelBadge` | Tiến độ XP có nhãn truy cập và cấp độ |
| `QuestCard`, `RewardCard`, `LessonNode`, `AchievementBadge` | Thẻ nhiệm vụ, thưởng, bài học và huy hiệu |
| `EmptyState`, `ErrorState`, `LoadingSkeleton` | Trạng thái không có dữ liệu, lỗi và chờ tải |

`useReducedMotion()` kiểm tra thiết lập hệ thống và cập nhật khi đổi trên Android/iOS hoặc web. Modal/sheet bỏ chuyển động khi cần; skeleton đứng yên. Các nút có vùng chạm tối thiểu 48 px; trạng thái không được truyền tải chỉ qua màu. Text cho phép phóng to theo thiết lập thiết bị.

## Showcase và kiểm tra

Trong Expo dev server, mở `/dev/showcase` hoặc Profile → “Open design system showcase”. Route này chuyển về Home trong production. Showcase có dữ liệu minh họa riêng, nút đổi theme và ví dụ cho tất cả component.

```powershell
npm.cmd run web -w apps/mobile
npm.cmd run typecheck -w apps/mobile
npm.cmd run lint -w apps/mobile
npm.cmd run test -w apps/mobile
```

Đã kiểm tra bố cục web ở 390 px và 500 px; 390 px không có cuộn ngang. Bản Android/iOS được kiểm tra bằng Expo bundle, chưa được kiểm tra trực tiếp bằng VoiceOver/TalkBack hoặc thiết bị thật. Các modal/sheet dùng React Native `Modal` để có cùng API trên hai nền tảng; những khác biệt cử chỉ native cần kiểm tra khi có thiết bị.
