# Hợp đồng API ban đầu

FastAPI phục vụ `/health` và `/api/v1/health`. Hai endpoint là liveness probe, không truy cập PostgreSQL và trả HTTP 200 khi ứng dụng còn xử lý yêu cầu. Chúng **không** xác nhận cơ sở dữ liệu đã sẵn sàng.

```json
{"data":{"status":"ok"},"error":null}
```

Các response API thành công về sau dùng `{ "data": ..., "error": null }`. Lỗi dùng `{ "data": null, "error": { "code": "...", "message": "..." } }`; lỗi 422 có thêm `details` gồm `field` và `message`. Không trả giá trị đầu vào nhạy cảm hoặc traceback trong response. Mỗi response có header `X-Request-ID` để đối chiếu log. Mã lỗi hiện có: `validation_error`, `http_error`, `internal_error`, `database_not_configured`; các module sau có thể thêm mã riêng ổn định.

Tài liệu OpenAPI ở `/docs` và `/openapi.json` khi chạy backend. API client mobile đã được cập nhật theo envelope health. Chưa có endpoint nội dung học tập hay auth.
