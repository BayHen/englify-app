# Journey V2.2 – Lộ trình cá nhân hóa

## Kết quả audit

Journey V2.1 đã có hierarchy course/chapter/unit/lesson, prerequisite tường minh, trạng thái mở khóa server-authoritative, checkpoint và ledger XP chống cấp trùng. Hồ sơ cũ đã có `current_cefr`, mục tiêu và thời lượng; kế hoạch tuần cũ được giữ nguyên. V2.2 mở rộng các cấu trúc này, không tạo backend hay cơ sở dữ liệu thứ hai và không viết lại tiến độ lịch sử.

## Hợp đồng dữ liệu

- `journey_selected_cefr`: mức người học chủ động chọn; độc lập với `journey_recommended_cefr` do placement đề xuất.
- Placement gồm session bất biến, response duy nhất theo câu hỏi và kết quả chấm phía PostgreSQL. Client không được đọc answer key.
- Hồ sơ kỹ năng chỉ hiển thị ước tính khi có ít nhất ba evidence đủ điều kiện. Thiếu dữ liệu trả `data_sufficient=false`, không gán điểm 0.
- Daily plan duy nhất theo `(user_id, local_date)`, ổn định cho đến khi người học yêu cầu refresh; tạo plan không ghi XP.

## Thuật toán placement phiên bản 1

Ngân hàng ban đầu có 15 câu, phủ Grammar, Vocabulary và Reading ở năm dải A1–C1. Điểm đúng được nhân trọng số difficulty 1–5 rồi chia tổng trọng số câu đã trả lời. Ngưỡng gợi ý: A1 `<32%`, A2 `32–51%`, B1 `52–69%`, B2 `70–85%`, C1 `>=86%`. Cần ít nhất 12 câu; confidence phụ thuộc số câu và độ phủ ba kỹ năng. Đây chỉ là mức bắt đầu gợi ý, không phải chứng nhận CEFR.

## Gợi ý, thích ứng và tích hợp

Engine chỉ chọn lesson đã publish, chưa khóa và đúng mức đã chọn. Thứ tự ưu tiên là bài đang học rồi bài đủ prerequisite tiếp theo. Mỗi item có `reason_code`, lý do tiếng Việt và destination. Dữ liệu Quiz/Writing chỉ được tổng hợp từ attempt/submission thật; AI rewrite không được dùng làm evidence. Không tự hạ CEFR, không bỏ qua prerequisite và không thay đổi điểm Arena, XP hay Quest.

## Bảo mật và triển khai

Các bảng riêng tư bật RLS và chỉ chủ sở hữu được đọc. Mutation/chấm điểm chạy qua RPC dùng `auth.uid()`, kiểm tra session/question và chặn response trùng. Áp dụng migration theo thứ tự, chạy smoke V2.1 rồi V2.2. Không triển khai production khi chưa reconcile migration và được phê duyệt rõ ràng.
