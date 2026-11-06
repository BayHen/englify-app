---
name: security-review
description: Rà soát auth, phân quyền, bí mật và dữ liệu người học trước thay đổi nhạy cảm hoặc khi được yêu cầu review.
---

# security-review

## Tiêu chí kích hoạt

Thêm auth, endpoint admin, dữ liệu cá nhân, upload, tích hợp ngoài hoặc yêu cầu đánh giá bảo mật.

## Ràng buộc công nghệ

Kiểm tra quyền ở FastAPI; client không phải ranh giới tin cậy. Không đưa secret vào `EXPO_PUBLIC_*`, Git hay log; không tự cài công cụ quét ngoài phạm vi.

## Hướng dẫn triển khai

Xác định tài sản, vai trò và luồng dữ liệu. Kiểm tra truy cập chéo tài khoản, input, giới hạn tài nguyên, token và lỗi. Xem skill bên ngoài trước khi chạy lệnh; không thực thi script setup không tin cậy.

## Quy tắc kiểm thử

Test không xác thực, sai vai trò, ID của người khác và input bất thường; báo phần chỉ đánh giá tĩnh.

## Definition of Done

Lỗ hổng cụ thể được sửa hoặc ghi thành rủi ro; đường nhạy cảm có test quyền, không lộ bí mật.

