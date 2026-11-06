---
name: api-integration
description: Kết nối mobile/admin với REST API, kiểu chung và xử lý lỗi/mất mạng khi ứng dụng tiêu thụ endpoint.
---

# api-integration

## Tiêu chí kích hoạt

Ứng dụng gọi backend hoặc hợp đồng giữa các ứng dụng thay đổi.

## Ràng buộc công nghệ

REST `/api/v1`, TypeScript client, Pydantic backend. `EXPO_PUBLIC_*` là dữ liệu công khai, không chứa secret; chỉ thêm TanStack Query khi cần cache server state.

## Hướng dẫn triển khai

Response typed; xử lý timeout, 401/403, lỗi server và mất mạng. Không nuốt lỗi; tránh request/ghi trùng. Cập nhật cả provider và consumer khi đổi hợp đồng.

## Quy tắc kiểm thử

Kiểm tra thành công/lỗi, URL cấu hình, mất mạng và retry an toàn; chạy typecheck client và test endpoint.

## Definition of Done

Luồng dữ liệu chạy, lỗi hiển thị đúng, hợp đồng nhất quán, không lộ credential.

