# Quy ước làm việc với Englify Quest

## Phạm vi và nguồn sự thật

- Đọc yêu cầu hiện tại, `README.md`, tài liệu liên quan trong `docs/` và mã đang có trước khi sửa. Không tự triển khai toàn bộ lộ trình từ một nhiệm vụ nhỏ.
- Dùng kỹ năng phù hợp trong `.agents/skills/` theo tiêu chí kích hoạt của từng `SKILL.md`. Kiểm tra kỹ năng đã được nạp trong phiên; nếu chưa, đọc tệp trực tiếp. Kỹ năng dự án bổ trợ, không thay thế chỉ dẫn của người dùng.
- Với công việc Expo, đọc `apps/mobile/package.json` để xác định SDK rồi đối chiếu tài liệu phiên bản tương ứng. Dùng `npx expo install` để chọn phiên bản gói tương thích SDK.

## Quy ước kỹ thuật

- Viết tài liệu bằng tiếng Việt; mã nguồn, định danh, endpoint và thông điệp commit bằng tiếng Anh.
- Giữ ranh giới giao diện, nghiệp vụ và lưu trữ. API công khai có tiền tố `/api/v1`; thay đổi hợp đồng phải đồng bộ backend, mobile và admin.
- PostgreSQL là nguồn dữ liệu chính; SQLite trên thiết bị dùng cho dữ liệu ngoại tuyến được hỗ trợ. Bảng mới cần migration, khóa chính, khóa ngoại thích hợp và chỉ mục theo truy vấn.
- Ưu tiên phần mềm miễn phí và mã nguồn mở. Không tự thêm dịch vụ trả phí, gói yêu cầu thẻ thanh toán hoặc công cụ không liên quan.
- Không ghi bí mật vào repository, log, ảnh chụp hoặc phản hồi. Chỉ đưa biến môi trường mẫu không chứa giá trị thật vào Git.

## Kỹ năng và mã bên ngoài

- Không tự chạy script cài đặt, postinstall tùy ý hoặc lệnh từ `SKILL.md` bên ngoài khi chưa xem nội dung, nguồn phát hành và tác dụng phụ.
- Kỹ năng Expo chính thức là tùy chọn. Trước khi cài, xem mã nguồn và hướng dẫn tại `expo/skills`; chọn kỹ năng framework cần thiết. Không kích hoạt EAS có thể phát sinh phí nếu chưa được chấp thuận.
- Nếu kỹ năng bên ngoài không có hoặc không cài được, dùng kỹ năng nội bộ và tài liệu chính thức; ghi rõ giới hạn, không nhận là đã cài.

## Kiểm tra và bàn giao

- Khi sửa Edge Function hoặc thêm entrypoint, chạy nguyên lệnh `deno check` của bước **Check Edge Functions** và các lệnh `deno test` liên quan trong workflow CI. Entrypoint dùng `Deno.serve` hoặc `Deno.env` cần có kiểu runtime Deno. Giữ bật kiểm tra kiểu.

- Trước khi commit hoặc push, đối chiếu `.github/workflows/ci.yml` và chạy các kiểm tra liên quan. Khi sửa Python, chạy `ruff check backend scripts` và bộ pytest của CI. Khi thêm migration, seed hoặc Edge Function, kiểm tra trên Supabase local trống với cùng phiên bản CLI trong lockfile, rồi chạy upgrade fixture, reset/seed, lint và smoke test tương ứng. Kiểm tra trên database đã chạy sẵn không thay thế lần khởi tạo sạch. Nếu CI đỏ, xem bước lỗi đầu tiên và tái hiện bước đó trước khi sửa. Ghi rõ các bước chưa chạy.

- Chạy kiểm tra liên quan đến phần sửa: mobile lint/typecheck; admin lint/build; backend pytest; migration và đồng bộ khi thay đổi dữ liệu.
- Trước mọi bản mobile/release có thêm hoặc đổi Supabase RPC, bắt buộc chạy gate production `python scripts/verify_arena_release_gate.py` hoặc workflow `Arena production readiness`. Gate phải xác nhận migration local/remote hoàn toàn đồng bộ và PostgREST phân giải được toàn bộ chữ ký RPC Arena; `PGRST202`, `PGRST203`, `schema cache` hoặc migration drift là lỗi chặn phát hành. Không khắc phục bằng retry phía mobile, đánh dấu giả migration đã applied hoặc đưa service-role key vào client.
- Sau **mọi task sửa mobile**, kiểm tra lỗi React Native Web `Unexpected text node: A text node cannot be a child of a <View>`. Không dùng trực tiếp `{error && <Component />}`, `{count && <Component />}` hoặc biến chuỗi/số với `&&` trong JSX dưới `View`/`Pressable`/component bao ngoài: chuỗi rỗng hoặc số 0 có thể trở thành text node. Dùng `!!error`, `count > 0`, `Boolean(value)` hoặc toán tử ba ngôi trả `null`. Rà toàn bộ JSX vừa sửa, chạy lint/typecheck/test, rồi mở route bị ảnh hưởng trên web và kiểm tra Console/LogBox sau render và thao tác; bundle/export thành công **không** chứng minh runtime hết lỗi. Nếu không thể chạy browser, ghi `NOT TESTED` và hướng dẫn kiểm tra chính xác.
- Báo tệp đã thay đổi, kết quả kiểm tra thực tế, giới hạn chưa kiểm chứng và cách chạy. Không tuyên bố kiểm tra trên thiết bị khi chỉ đóng gói web.
