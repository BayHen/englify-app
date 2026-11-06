# Từ điển Anh–Việt – TASK 04.1

## Nguồn dữ liệu và quyền sử dụng

`backend/seeds/development.sql` chứa 10 mục từ được biên soạn riêng cho Englify Quest: định nghĩa tiếng Anh, nghĩa tiếng Việt và ví dụ là nội dung gốc của dự án; IPA được ghi thủ công. **Không nhập hay trích xuất dữ liệu từ từ điển thương mại hoặc API bên thứ ba.** Cột `source_name` ghi `Englify Quest editorial`, `license_id` ghi `project-owned`. Đây là nội dung thuộc dự án, không phải tuyên bố CC0 hoặc giấy phép tái phân phối cho bên ngoài. Không yêu cầu ghi công bên thứ ba cho bộ seed hiện tại; giao diện vẫn hiển thị nguồn/giấy phép để sẵn sàng cho dữ liệu khác về sau.

Giới hạn: bộ seed chỉ phục vụ phát triển và thử nghiệm, chưa đủ độ bao phủ để làm từ điển tổng quát. IPA chỉ là một cách phát âm phổ biến, có thể khác theo vùng. Trước khi nhập bộ dữ liệu ngoài, phải ghi rõ nguồn, phiên bản, URL giấy phép, quyền sử dụng thương mại, quyền lưu offline, yêu cầu ghi công và giới hạn phân phối; chỉ nhập dữ liệu sau khi các quyền này phù hợp. Không scrape từ điển có bản quyền.

## Cơ sở dữ liệu và API

Migration `20261106_03` bổ sung `ipa`, `audio_url`, `source_name`, `license_id` vào `dictionary_entries` và chỉ mục tìm tiền tố tiếng Anh. `audio_url` chỉ chấp nhận HTTPS; seed hiện không chứa audio. `saved_vocabulary` đã có FK đến profile và mục từ, unique `(user_id, entry_id)`. Các thao tác lưu/xóa chạy trong transaction, chống lưu trùng. RLS vẫn giới hạn từ đã lưu theo `auth.uid()`; FastAPI kiểm tra token và lọc theo UUID đã xác minh.

| Endpoint | Mô tả |
| --- | --- |
| `GET /api/v1/dictionary?q=...&limit=50` | Tìm tiền tố từ tiếng Anh hoặc chuỗi trong nghĩa tiếng Việt; tối đa 50 kết quả. |
| `GET /api/v1/dictionary/{id}` | Chi tiết một mục từ. |
| `GET /api/v1/me/vocabulary` | Danh sách từ đã lưu của người gọi, tối đa 200. |
| `POST /api/v1/me/vocabulary/{id}` | Lưu mục từ; gọi lại không tạo bản sao. |
| `DELETE /api/v1/me/vocabulary/{id}` | Xóa mục từ của chính người gọi. |

Các endpoint hiện yêu cầu Supabase access token. Kết quả dùng envelope `{ "data": ..., "error": null }`. Không có endpoint tải dữ liệu từ từ điển bên ngoài.

## Ứng dụng di động và ngoại tuyến

Màn hình Dictionary tìm API thật, hiển thị định nghĩa, nghĩa, IPA, loại từ và ví dụ. Mục từ đã xem/tìm được lưu vào SQLite KV store trên iOS/Android; tìm kiếm khi mất mạng chỉ trả mục đã cache. Danh sách từ đã lưu và lịch sử tìm kiếm dùng khóa riêng theo user ID. Flashcards lấy từ danh sách đã lưu; khi offline có thể xem bộ thẻ cache nhưng không thể lưu/xóa trên server. Chưa có đồng bộ thao tác offline hoặc thuật toán spaced repetition; `next_review_at` dành cho giai đoạn sau. Bộ cache giới hạn 500 từ và 200 mục đã lưu mỗi người. Trên web, cache chỉ nằm trong bộ nhớ và mất khi tải lại trang.

Nút phát âm dùng **giọng đọc tiếng Anh của thiết bị** qua Expo Speech; IPA không phải file âm thanh. iOS có thể không phát tiếng khi thiết bị bật silent mode. Chưa tải hoặc lưu file audio offline. Chất lượng giọng tùy hệ điều hành và gói giọng đã cài.

Cache từ vựng công khai và danh sách đã lưu chỉ chứa nội dung học; không lưu access token trong SQLite. Không dùng cache làm nguồn xác thực hoặc quyền truy cập. Nếu dùng thiết bị chung, xóa dữ liệu ứng dụng để xóa cache học tập của người dùng trước.

## Chạy và kiểm tra

Áp dụng migration từ Supabase PostgreSQL đã cấu hình, sau đó nạp seed bằng `psql -f backend/seeds/development.sql`. Kiểm tra bằng `python -m pytest backend/tests`, `npm run test -w apps/mobile`, `npm run typecheck -w apps/mobile`, `npm run lint -w apps/mobile`. Bài integration test database dùng `ENGLIFY_TEST_DATABASE_URL` với PostgreSQL tạm chứa Auth fixture; không trỏ vào dự án thật. Xem thêm `docs/AUTHENTICATION.md`.
