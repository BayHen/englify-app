---
name: database-design
description: Thiết kế PostgreSQL, migration Alembic và SQLite ngoại tuyến khi thêm hoặc đổi dữ liệu bền vững.
---

# database-design

## Tiêu chí kích hoạt

Tạo bảng, quan hệ, chỉ mục, migration hoặc quy tắc đồng bộ.

## Ràng buộc công nghệ

PostgreSQL là nguồn chính; SQLite mobile cho ngoại tuyến. Dùng SQLAlchemy/Alembic khi được thêm vào backend; không xóa dữ liệu người dùng ngoài yêu cầu.

## Hướng dẫn triển khai

Mỗi bảng có khóa chính, khóa ngoại phù hợp, unique cho bất biến và chỉ mục theo truy vấn. Dùng UTC; xác định ID, version và xung đột trước đồng bộ hai chiều.

## Quy tắc kiểm thử

Chạy migration trên DB trống và có dữ liệu mẫu; kiểm tra ràng buộc, truy vấn chính và nâng cấp không mất dữ liệu.

## Definition of Done

Schema, migration, chỉ mục và `docs/DATABASE.md` khớp nhau; thử nâng cấp đạt.

