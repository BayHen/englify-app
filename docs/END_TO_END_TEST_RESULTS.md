# Kết quả kiểm thử end-to-end — 10/11/2026

> Cập nhật 11/11/2026: Function `translate` hiện `ACTIVE` với JWT verification; quota migration MyMemory đã áp dụng và kiểm tra RPC bằng giao dịch rollback. Sau bản sửa chọn bản khớp, người dùng xác nhận trên Expo Go `License → Giấy phép.` và `giấy phép → License`. Các bảng dưới ghi nhận đợt kiểm tra trước khi deploy.

| Luồng | Trạng thái | Bằng chứng/giới hạn |
| --- | --- | --- |
| Auth → profile → onboarding | PASS cục bộ | Supabase Auth hai tài khoản disposable, profile/RLS, RPC onboarding; thiết bị thật chưa thử |
| Từ điển, lưu từ, Real English quiz | PASS cục bộ | PostgREST/RLS, quiz chấm server, request lặp, tài khoản khác bị chặn |
| Kế hoạch 7 ngày | PASS cục bộ | Edge `study-plan` + RPC: đọc onboarding, tạo lịch, đổi mục tiêu, hoàn thành task thường, chặn task lesson, dời ngày bỏ lỡ, giữ lịch sử; remote Edge chưa deploy |
| Gamification claim | PASS cục bộ | Tổng XP từ server, không đủ XP bị từ chối, claim lặp cùng ID, notification chỉ của chủ sở hữu. Quiz mới cấp XP/quest/badge trong giao dịch RPC. |
| Translate Edge MyMemory | PASS unit | Auth/quota/input/response kiểm tra bằng mock; API MyMemory trực tiếp trả 200 hai chiều ngày 11/11/2026. Edge remote chưa deploy. |
| Translate qua Edge remote trên thiết bị | BLOCKED | Người dùng chưa cho phép deploy Function; cần kiểm tra trên Expo Go sau khi deploy. |
| Register → lesson → quiz → XP → progress không cần FastAPI | PASS cục bộ; thiết bị NOT TESTED | Hai tài khoản Auth thử nghiệm; user hoàn thành toàn unit 4 bài, 5 dạng câu hỏi, XP server, mở khóa và lịch sử lưu; request lặp không thêm thưởng. Mobile dùng RPC rev21. Chưa thử login/route trên thiết bị thật. |
| Writing submit → feedback → history không cần FastAPI | PASS cục bộ; live UI BLOCKED | RPC chấm quy tắc, lưu bản gốc và feedback riêng, idempotency, RLS hai tài khoản; Edge grammar thật trả `unavailable` khi không có LanguageTool. Mobile còn cờ FastAPI mặc định vì Edge chưa deploy. |
| Admin publish → mobile hiển thị → analytics không cần FastAPI | PASS cục bộ ở mức DB; live UI BLOCKED | RLS hai tài khoản, draft/publish từ điển, mobile thấy nội dung đã phát hành, audit và metrics RPC đạt. Adapter có unit tests, cờ Admin vẫn tắt; migration Admin chưa áp production, trình duyệt chưa thử. |
| Expo Web Console/LogBox | NOT TESTED | Công cụ browser trong phiên lỗi khởi tạo. Metro trả HTTP 200 cho `/journey`, `/writing`, `/translation` sau khi bundle; đây chưa phải kiểm tra runtime. Chạy Expo từ `apps/mobile` bằng `npx.cmd expo start --tunnel --clear`, mở Web `/translation`, `/plan`, `/journey`, `/writing`; thao tác rồi xem Console/LogBox, đặc biệt `Unexpected text node`. |
| Android/iOS Expo Go | NOT TESTED | Không có phiên thiết bị. Cùng Supabase project, mở QR trên thiết bị; thử đăng nhập, dịch, plan, reward và kiểm tra lỗi/runtime. |

Kiểm tra tự động: `npm.cmd run check` đạt 92 Vitest tests, TypeScript, lint, admin build; backend pytest trên DB Supabase cục bộ đạt `48 passed`; `python scripts/supabase_local_integration.py` đạt sau Supabase local reset và xóa hai tài khoản test cuối lượt. Migration live đến revision 22; số profile 1, tiến độ 4, XP events 6, reward claims 1 được kiểm tra sau rev19; rev20–22 chỉ thêm hàm. Migration Admin rev SQL tiếp theo mới chạy cục bộ, chưa áp lên DB thật. Không có dữ liệu người dùng bị xóa. Không đánh dấu các luồng chưa port là PASS nhờ test FastAPI cũ.
