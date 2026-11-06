---
name: gamified-ui
description: Thiết kế giao diện bài học, XP, nhiệm vụ và phần thưởng; dùng cho trải nghiệm gamification của mobile.
---

# gamified-ui

## Tiêu chí kích hoạt

Làm hành trình, bài học, quiz, XP, huy hiệu hoặc phần thưởng; không áp dụng cho admin thông thường.

## Ràng buộc công nghệ

React Native/Expo; token trong `packages/shared`; theme sáng/tối và reduced motion. Màu primary `#7456F1`, reward `#FFC857`, success `#37C99B`, error `#FF7B82`.

## Hướng dẫn triển khai

Làm rõ mục tiêu học trước điểm thưởng. Phản hồi đúng/sai không chỉ bằng màu; animation có ý nghĩa. Không hiển thị phần thưởng chưa được backend xác nhận như đã nhận.

## Quy tắc kiểm thử

Kiểm tra cỡ chữ, tương phản, vùng chạm, screen reader, dark mode, reduced motion, tải và lỗi.

## Definition of Done

Người học hiểu bước tiếp theo; UI dùng token chung, dễ tiếp cận và hoạt động ở kích thước màn hình mục tiêu.

