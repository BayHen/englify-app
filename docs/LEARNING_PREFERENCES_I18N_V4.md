# Learning Preferences và giao diện song ngữ V4

## Nguyên nhân lỗi 404

Việc đọc và lưu `user_preferences` đã dùng Supabase trực tiếp qua `profile-repository.ts`; bảng thiếu dữ liệu được trả về dưới dạng `preferences: null`, không phải lỗi HTTP.

Lỗi 404 xuất hiện ở thao tác làm mới kế hoạch sau khi thay đổi mục tiêu, trình độ hoặc thời lượng. `features/plan/api.ts` kiểm tra `EXPO_PUBLIC_SUPABASE_PLAN_ENABLED`; khi biến này thiếu hoặc khác `true`, ứng dụng gọi endpoint FastAPI cũ `/api/v1/learning-plan/regenerate`. Backend này không còn là đường triển khai chính nên trả 404. Kiểm tra chỉ đọc ngày 16/11/2026 cũng xác nhận project Supabase production chưa có Edge Function `study-plan`.

Client V4 đã bỏ fallback FastAPI của Learning Plan và luôn gọi Edge Function xác thực `study-plan`. Vì vậy cần deploy function này trước khi phát hành client V4.

## Kiến trúc Preferences

- `profiles` và `user_preferences` tiếp tục là nguồn dữ liệu theo tài khoản trong PostgreSQL/Supabase.
- `user_preferences.user_id` là duy nhất; RLS hiện có chỉ cho người dùng thao tác hàng của mình.
- Giá trị giao diện được ánh xạ vào schema hiện có: mục tiêu `conversation/work/travel/exams/real_english`, CEFR A1-C2, `daily_goal_minutes`, giọng `en-US/en-GB/en-AU` và ngôn ngữ `en/vi`.
- Không có migration mới. Không xóa hoặc ghi lại tiến độ học.
- Hàng preference chưa tồn tại được đọc thành `null`; màn hình không biến trường hợp này thành lỗi kết nối.

## Kiến trúc bản địa hóa

Tài nguyên nằm trong `apps/mobile/src/i18n/`:

- `types.ts`: ngôn ngữ và khóa dịch được kiểm tra kiểu;
- `en.ts`, `vi.ts`: nhãn giao diện tĩnh duy trì cục bộ;
- `translate.ts`: tra cứu có fallback tiếng Anh;
- `storage.ts`: SecureStore trên native và localStorage trên web;
- `index.tsx`: Context phản ứng, không cần khởi động lại;
- `errors.ts`: ánh xạ lỗi sang thông báo phù hợp ngôn ngữ.

Context là nguồn trạng thái giao diện duy nhất. Lựa chọn được ghi cục bộ ngay để lần mở sau không nhấp nháy tiếng Anh, rồi đồng bộ vào `user_preferences.interface_language` khi có phiên đăng nhập. Lựa chọn offline được đánh dấu chờ đồng bộ và thử lại ở lần tải profile tiếp theo.

Không dùng MyMemory hoặc API bên ngoài để dịch nhãn giao diện. Nội dung học tiếng Anh, câu hỏi, từ vựng và văn bản của người dùng không bị tự động dịch.

## Thêm ngôn ngữ mới

1. Thêm mã vào `InterfaceLanguage`.
2. Tạo tài nguyên mới với kiểu `TranslationResources`.
3. Bổ sung tài nguyên vào `translate.ts` và `LanguageSelector`.
4. Thêm giá trị hợp lệ bằng migration additive cho ràng buộc `interface_language`.
5. Chạy typecheck, lint, test và kiểm tra text overflow trên thiết bị.

## Phạm vi hoàn thành

- Learning Setup: tiêu đề, lựa chọn, nút, trạng thái lưu, modal và lỗi.
- Profile → Settings → Language: dùng cùng state và cùng cột Supabase.
- Profile: tiêu đề, thống kê, thiết lập học tập, mục tiêu, huy hiệu, giao diện và đăng xuất.
- Thanh điều hướng chính: Home, Journey, Explore, Practice, Profile.
- Lỗi Preferences cho 401/403/409/422/429, mất mạng và lỗi bất ngờ.

## Đồng bộ giao diện toàn ứng dụng

Lớp giao diện dùng chung hiện dịch nhãn tĩnh của Auth, Onboarding, Home, Journey, Explore, Dictionary, Translation, Real English, Vocabulary Review, Speaking, Writing, Quiz, Rewards, Learning Plan, Profile và Account. `AppText`, `AppButton`, `AppInput`, form xác thực, modal và bottom sheet sử dụng cùng `I18nContext`, nên thay đổi ngôn ngữ có hiệu lực ngay mà không cần khởi động lại.

`ui-literal-vi.ts` chỉ chứa nội dung giao diện cũ chưa chuyển sang khóa ngữ nghĩa. `translateLiteral` dùng đối sánh chính xác và một số mẫu định dạng an toàn cho phân trang, số lượng và nhãn thao tác. Không gửi nội dung đến dịch vụ dịch bên ngoài.

Nội dung học tiếng Anh, câu hỏi, lựa chọn trả lời, từ vựng, hội thoại, dữ liệu do quản trị viên xuất bản và văn bản người dùng nhập được giữ nguyên theo chủ đích. Chúng không phải chuỗi giao diện và không được tự động Việt hóa. Thông báo mới do dịch vụ từ xa trả về cần được bổ sung vào ánh xạ lỗi khi hợp đồng API thay đổi.

## Triển khai

Sau khi review và kiểm thử local, deploy riêng function, không reset database:

```powershell
npx.cmd supabase functions deploy study-plan --use-api --yes
```

`supabase/config.toml` phải tiếp tục đặt `verify_jwt = true`. Không cần `EXPO_PUBLIC_SUPABASE_PLAN_ENABLED`; client V4 không còn fallback FastAPI.

Khởi động lại Expo:

```powershell
cd apps/mobile
npx.cmd expo start --tunnel --clear
```

## Kiểm thử

```powershell
npm.cmd run typecheck -w apps/mobile
npm.cmd run lint -w apps/mobile
npm.cmd run test -w apps/mobile
```

Kết quả cục bộ ngày 16/11/2026 sau khi đồng bộ giao diện: typecheck PASS, 44 tệp test và 156 test PASS. Kiểm thử trình duyệt tương tác và thiết bị vật lý phải được ghi riêng; bundle thành công không thay thế kiểm thử runtime.
