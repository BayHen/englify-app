# Journey V2.6 – Quản trị chương trình học

V2.6 bổ sung khu vực **Journey curriculum** trong Admin, dùng lại Course/CEFR, Chapter, Unit, Lesson, lesson revision, prerequisite và checkpoint hiện hữu. Không tạo grading engine, hệ thống quyền hay kho XP mới.

## Vòng đời nội dung

Lesson đi theo `draft → in_review → approved → published`; có thể chuyển về draft để sửa hoặc archive. Nội dung published chỉ được phát hành từ một revision đã qua review. Mỗi lần soạn tạo revision mới; attempt cũ tiếp tục trỏ tới revision cũ. Archive chỉ ẩn nội dung, không xóa progress, attempt, XP hoặc milestone.

## Bảo mật

RPC quản trị kiểm tra `englify_is_admin()` ở server, dùng `SECURITY DEFINER` với `search_path=''`. Learner không được đọc draft, gọi thao tác review/publish hoặc xem batch import. Block cấm trường `html` và được kiểm tra bởi validator Journey V2.3.

## Công cụ quản trị

- Chapter và Unit được tạo/sửa dưới dạng draft; nội dung đã publish không bị sửa trực tiếp.
- Prerequisite dùng guard chống self-reference, cross-course và chu trình của Journey V2.1.
- Reorder chỉ chấp nhận draft sibling; form cấu hình hỗ trợ thao tác bàn phím mà không phụ thuộc drag-and-drop.
- Checkpoint dùng grading engine V2.4, giữ ngưỡng 70%; checkpoint published không bị sửa âm thầm.
- CSV tối đa 2 MB, XLSX tối đa 5 MB và 500 dòng. Công thức Excel bị từ chối. Quan hệ dùng `external_id`, import luôn là draft và request có tính idempotent.
- Gemini chạy trong Edge Function với secret phía server, tối đa 10 yêu cầu/Admin/ngày, validate block có cấu trúc và chỉ tạo draft chờ human review.
- Analytics chỉ trả số liệu tổng hợp, không trả bài làm riêng tư.

## Giới hạn kiểm chứng

Không có Deno CLI trong môi trường Windows hiện tại nên unit test Edge Function Gemini được thêm vào CI nhưng chưa chạy cục bộ. Không gọi provider Gemini thật và không triển khai Edge Function/production migration trong phiên này. Admin browser runtime và upload file bằng trình duyệt cũng cần kiểm tra sau khi chạy local dashboard.
