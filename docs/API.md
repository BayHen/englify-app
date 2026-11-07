# Hợp đồng API ban đầu

FastAPI phục vụ `/health` và `/api/v1/health`. Hai endpoint là liveness probe, không truy cập PostgreSQL và trả HTTP 200 khi ứng dụng còn xử lý yêu cầu. Chúng **không** xác nhận cơ sở dữ liệu đã sẵn sàng.

```json
{"data":{"status":"ok"},"error":null}
```

Các response API thành công về sau dùng `{ "data": ..., "error": null }`. Lỗi dùng `{ "data": null, "error": { "code": "...", "message": "..." } }`; lỗi 422 có thêm `details` gồm `field` và `message`. Không trả giá trị đầu vào nhạy cảm hoặc traceback trong response. Mỗi response có header `X-Request-ID` để đối chiếu log. Mã lỗi hiện có: `validation_error`, `http_error`, `internal_error`, `database_not_configured`; các module sau có thể thêm mã riêng ổn định.

Tài liệu OpenAPI ở `/docs` và `/openapi.json` khi chạy backend. API client mobile đã được cập nhật theo envelope health. Supabase Auth xử lý đăng ký, đăng nhập, đăng xuất và đặt lại mật khẩu; FastAPI không nhận mật khẩu.

Các endpoint riêng tư dùng header `Authorization: Bearer <Supabase access token>`:

| Endpoint | Hành vi |
| --- | --- |
| `GET /api/v1/me` | Trả profile và preferences của chủ token. |
| `PUT /api/v1/me/onboarding` | Lưu `learning_goal` (`conversation`, `travel`, `work`, `exams`), `initial_proficiency` (`beginner`, `intermediate`, `advanced`) và `daily_goal_minutes` (1–180). |
| `PATCH /api/v1/me/profile` | Đổi `display_name` (1–80 ký tự). |

Backend xác minh chữ ký JWT qua JWKS của dự án Supabase, cùng `iss`, `aud=authenticated`, `role=authenticated`, `sub` UUID, `iat` và `exp`. Dự án cần khóa ký bất đối xứng (RS256 hoặc ES256); backend không dùng service role key hoặc JWT secret. Khi thiếu token trả 401 `authentication_required`; token sai/hết hạn trả 401 `invalid_token`; JWKS tạm không truy cập được trả 503 `auth_unavailable`. Mọi truy vấn dữ liệu dùng UUID từ token đã xác minh, không lấy `user_id` từ request.

Từ điển và từ đã lưu có các endpoint riêng tư `GET /api/v1/dictionary`, `GET /api/v1/dictionary/{id}`, `GET /api/v1/me/vocabulary`, `POST /api/v1/me/vocabulary/{id}` và `DELETE /api/v1/me/vocabulary/{id}`. Trường trả về gồm định nghĩa tiếng Anh, nghĩa tiếng Việt, IPA, loại từ, ví dụ và nguồn/giấy phép. Xem `docs/DICTIONARY.md` để biết truy vấn, cache ngoại tuyến và giới hạn bộ seed.
# Learning Journey và quiz: xem [LEARNING_ENGINE.md](LEARNING_ENGINE.md) cho endpoint,
# quy tắc mở khóa, chấm bài và idempotency.

Gamification: xem [GAMIFICATION.md](GAMIFICATION.md) cho endpoint XP, nhiệm vụ, huy hiệu, đổi thưởng và thông báo. Mọi dữ liệu điểm và điều kiện đổi thưởng được tính ở backend.
