---
name: fastapi-backend
description: Tạo endpoint, schema, service và kiểm thử FastAPI; dùng cho công việc API Python.
---

# fastapi-backend

## Tiêu chí kích hoạt

Thay đổi `backend/app`, endpoint hoặc hợp đồng API; không áp dụng cho frontend thuần túy.

## Ràng buộc công nghệ

Python >=3.11, FastAPI, Pydantic; SQLAlchemy/Alembic khi cần dữ liệu; REST có tiền tố `/api/v1`.

## Hướng dẫn triển khai

Tách router, nghiệp vụ và truy cập dữ liệu theo nhu cầu. Request/response có kiểu; kiểm tra quyền ở server. Không trả stack trace, bí mật hoặc dữ liệu người khác.

## Quy tắc kiểm thử

Test đường thành công, dữ liệu sai và quyền truy cập; chạy `python -m pytest backend/tests`, kiểm tra import và OpenAPI khi đổi route.

## Definition of Done

Endpoint có hợp đồng, quyền, lỗi và test; tài liệu API cập nhật theo hành vi.

