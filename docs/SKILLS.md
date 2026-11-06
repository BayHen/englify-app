# Danh mục Agent Skills — TASK 01.2

## Trạng thái đã kiểm tra

- Phiên Codex hiện có các kỹ năng hệ thống `imagegen`, `openai-docs`, `skill-creator`, `skill-installer`; kỹ năng người dùng `design-taste-frontend`, `find-skills`, `image-to-code`, `imagegen-frontend-mobile`, `imagegen-frontend-web`; kỹ năng plugin `computer-use`, `documents`, `pdf`, `plugin-management`, `presentations`, `sites`, `sites-remix`, `spreadsheets`, `excel-live-control`, `template-creator`, `visualize`, `create-pet`, `pets`, `update-pet`. Danh sách này phản ánh phiên hiện tại, không đảm bảo mọi phiên khác đều nạp cùng bộ.
- Đã đọc `skill-creator/SKILL.md` trước khi tạo kỹ năng; công cụ này hướng dẫn frontmatter `name`/`description`, nội dung ngắn có phạm vi rõ và chạy `quick_validate.py`.
- Chưa phát hiện kỹ năng `expo-*` hoặc plugin Expo chính thức trong danh mục kỹ năng của phiên. `apps/mobile/AGENTS.md` do Expo starter tạo có hướng dẫn Expo, nhưng **không phải** một Expo Skill đã cài.
- Dự án đang dùng `expo ~58.0.23`, React Native `0.88.1`, React `19.3.0`, Node môi trường `24.13.0`. [Tài liệu SDK 58 của Expo](https://docs.expo.dev/versions/v58.0.0/) xác nhận dòng React Native 0.88, React 19.3 và Node tối thiểu 22.13. Khi nâng SDK phải kiểm tra lại cả kỹ năng lẫn gói phụ thuộc.

## Kỹ năng nội bộ

| Kỹ năng | Phạm vi |
| --- | --- |
| `mobile-architecture` | Cấu trúc ứng dụng, điều hướng, ranh giới dữ liệu |
| `gamified-ui` | Giao diện học tập và phần thưởng dễ tiếp cận |
| `fastapi-backend` | Endpoint, schema, service, quyền truy cập |
| `database-design` | PostgreSQL, migration và SQLite ngoại tuyến |
| `api-integration` | Hợp đồng REST và xử lý lỗi client |
| `learning-engine` | Kế hoạch học, lịch ôn, quiz, tiến độ |
| `speech-engineering` | TTS, ghi âm và giới hạn đánh giá phát âm |
| `security-review` | Auth, phân quyền, bí mật, dữ liệu người học |
| `test-engineering` | Kiểm thử hành vi và CI |

Mỗi kỹ năng nằm tại `.agents/skills/<tên>/SKILL.md`, có YAML frontmatter, điều kiện kích hoạt, giới hạn công nghệ, cách làm, quy tắc kiểm thử và Definition of Done. Kỹ năng dự án có thể được đọc theo đường dẫn nếu phiên Codex chưa tự khám phá thư mục này.

## Expo Skills chính thức

[Expo công bố bộ kỹ năng chính thức](https://github.com/expo/skills) và [hướng dẫn cài đặt](https://docs.expo.dev/skills/). Đề xuất cài plugin Expo cho Codex khi bắt đầu nhiệm vụ mobile chuyên sâu; ưu tiên `expo-overview`, `expo-project-structure`, `expo-router`, `expo-design-system`, `expo-native-ui`, `expo-data-fetching` và `expo-upgrade` theo nhiệm vụ. Các kỹ năng framework này không gắn với một SDK cố định trong phần mô tả; trước mỗi lần dùng vẫn phải đối chiếu API với tài liệu SDK 58 và chạy `npx expo install` để chọn phiên bản gói tương thích.

Expo khuyến nghị cách cài plugin cho Codex:

```text
codex plugin add expo@openai-curated
```

Hoặc tìm `expo` trong `/plugins`. Chỉ chạy sau khi xem manifest, `SKILL.md` và lệnh/script kèm theo của phiên bản sẽ cài, rồi làm mới phiên để xác nhận kỹ năng xuất hiện. Không chạy lệnh cài đặt được sao chép từ nguồn không tin cậy; không cài toàn bộ kỹ năng bằng script chưa xem nội dung. Chưa cài plugin trong TASK 01.2 vì yêu cầu là **kiểm tra và đề xuất cài đặt**, không yêu cầu kích hoạt plugin. Do đó chưa thể xác nhận tính tương thích runtime của plugin trong phiên này; kỹ năng nội bộ và tài liệu Expo SDK 58 là phương án hiện dùng.

Các kỹ năng `eas-*` phục vụ dịch vụ Expo có thể phát sinh chi phí hoặc cần tài khoản. Chính sách miễn phí của dự án yêu cầu xem giới hạn và có chấp thuận rõ trước khi kích hoạt dịch vụ có phí. Không đưa token EAS hoặc biến môi trường thật vào kỹ năng hay tài liệu.

## Xác minh

Kiểm tra từng thư mục kỹ năng bằng `quick_validate.py` của `skill-creator`; kiểm tra tên frontmatter trùng tên thư mục. Đây là xác minh cấu trúc, không phải xác nhận chất lượng hành vi. Sau khi thêm/chỉnh kỹ năng, đọc lại hướng dẫn và kiểm tra Git diff để tránh script, secret hoặc thay đổi ngoài phạm vi.
