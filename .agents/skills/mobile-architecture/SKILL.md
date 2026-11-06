---
name: mobile-architecture
description: Thiết kế cấu trúc Expo React Native, điều hướng và ngoại tuyến khi thêm module hoặc tái cấu trúc mobile.
---

# mobile-architecture

## Tiêu chí kích hoạt

Thêm màn hình, module hoặc luồng dữ liệu trong `apps/mobile`; không áp dụng cho sửa văn bản thuần túy.

## Ràng buộc công nghệ

Expo SDK từ `apps/mobile/package.json`, React Native, TypeScript, Expo Router; thêm gói Expo qua `npx expo install` sau khi đối chiếu tài liệu SDK.

## Hướng dẫn triển khai

Giữ route trong `src/app`; tách UI, nghiệp vụ, API client và lưu trữ. Xác định trạng thái tải, lỗi và ngoại tuyến. Dùng safe area và hỗ trợ Android/iOS.

## Quy tắc kiểm thử

Chạy mobile lint, typecheck và khởi động Expo. Với đồng bộ, thử mất mạng, dữ liệu trùng và khởi chạy lại; web bundle không xác nhận native.

## Definition of Done

Route hoạt động, dữ liệu có nguồn rõ ràng, lỗi có giao diện, kiểm tra liên quan đạt.

