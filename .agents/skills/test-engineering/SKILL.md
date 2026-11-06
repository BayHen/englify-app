---
name: test-engineering
description: Thiết kế kiểm thử có ý nghĩa cho mobile, admin, API và đồng bộ khi thêm hành vi hoặc sửa lỗi.
---

# test-engineering

## Tiêu chí kích hoạt

Thêm logic nghiệp vụ, endpoint, migration, đồng bộ hoặc sửa lỗi dễ tái phát.

## Ràng buộc công nghệ

Dùng pytest cho backend và kiểm tra TypeScript hiện có; chỉ thêm runner mới khi cần. CI dùng công cụ miễn phí.

## Hướng dẫn triển khai

Test hành vi quan sát được và bất biến, không sao chép implementation. Dữ liệu test độc lập, không dùng secret thật. Ưu tiên unit test thuật toán và integration test hợp đồng/migration.

## Quy tắc kiểm thử

Chạy tập liên quan; khi sửa lỗi, xác nhận test thất bại trước sửa nếu khả thi. Báo kiểm tra chưa chạy do thiếu thiết bị/dịch vụ.

## Definition of Done

Test bắt được rủi ro cụ thể, bộ liên quan đạt, CI cập nhật khi cần và giới hạn được ghi rõ.

