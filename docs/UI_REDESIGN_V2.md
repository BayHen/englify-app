# Englify Quest — Giao diện V2

## Hướng thiết kế

Giao diện dùng hình ảnh hành trình học tập: hồ sơ người thám hiểm, cáo đồng hành do dự án tự tạo bằng React Native View, bản đồ bài học và các dấu mốc. Màu tím `#7456F1` dành cho hành động chính; vàng cho phần thưởng; xanh cho hoàn thành. Mọi màn hỗ trợ sáng/tối qua token trong `packages/shared/src/index.ts`. Font Nunito cho nội dung và Baloo 2 cho tiêu đề được nạp bằng `expo-font`; nếu font không tải được, hệ thống vẫn có font mặc định.

## Cấu trúc màn hình

- **Home:** lời chào, avatar/settings, hero với bài học kế tiếp, XP/cấp độ thật, quest hằng ngày, Journey nổi bật, lưới sáu công cụ và huy hiệu đã mở. Dữ liệu đến từ API gamification/Journey; khi mất mạng có thể dùng bản Journey đã lưu. Không có số tiến độ mẫu trong Home thật.
- **Navigation:** thanh dưới gồm Home, Journey, Explore, Practice, Profile. Các route cũ như Dictionary, Translation, Speaking, Writing, Rewards và Lesson vẫn giữ nguyên; tab tương ứng sáng khi ở màn con. Khu vực điều hướng nằm ngoài ScrollView và trong safe area.
- **Journey:** mỗi unit là một world; nút bài học nối thành đường đi, phân biệt locked, available, in progress, completed và mastered. Nút vẫn là Pressable có nhãn trợ năng và tiếp tục dùng API kiểm tra quyền mở khóa.
- **Explore/Practice:** công cụ được gom theo mục đích, có icon và mô tả ngắn. Dictionary, Translation, Real English, Speaking, Writing và Quiz Arena vẫn đi tới route chức năng hiện có.
- **Profile:** hiển thị cấp, XP, số bài hoàn thành từ backend; giữ mục tiêu học, chế độ sáng/tối và đăng xuất. Rewards vẫn hiển thị dữ liệu backend.
- Các màn Auth, Onboarding và học tập khác dùng header, nhịp khoảng cách, icon theo ngữ cảnh, font và safe area chung qua `Page`/`AppCard`; trạng thái loading/empty/error hiện có được giữ lại.

## Chuyển động và khả năng tiếp cận

Thanh XP và phản hồi thưởng dùng Reanimated; người dùng bật reduced motion sẽ thấy trạng thái cuối ngay hoặc không có hiệu ứng xuất hiện. Tab không có chuyển động lặp. Nút có nhãn trợ năng, bài bị khóa có `disabled`, thanh tiến độ có `accessibilityRole=progressbar`. Không dùng màu làm dấu hiệu trạng thái duy nhất.

## Bản xem trước và ảnh

Trong development, mở `/dev/ui-v2-preview` để xem Home với **dữ liệu mẫu được gắn nhãn**. Thêm `?screen=journey`, `?screen=explore` hoặc `?screen=practice` để xem bố cục liên quan. Route này chuyển về Login khi build production. Nút trong preview vẫn đi qua bảo vệ route hiện có; nó không tạo tiến độ hoặc XP.

Ảnh chụp bằng Chrome headless với viewport web 360 × 780, chưa phải ảnh từ thiết bị iOS/Android:

- [Home sáng](reports/ui-v2-home-light.png)
- [Home tối](reports/ui-v2-home-dark.png)
- [Journey](reports/ui-v2-journey.png)
- [Explore](reports/ui-v2-explore.png)

## Explore V2

Explore có header riêng sát vùng an toàn phía trên với nhãn “DISCOVER & LEARN”, tiêu đề và mô tả ngắn. Banner “Follow the next clue” dẫn tới Journey; ba công cụ Dictionary, Translation và Real English giữ nguyên đường dẫn, dùng bố cục hai thẻ nhỏ và một thẻ rộng. Không hiển thị tiến độ hay gợi ý từ dữ liệu giả. Thanh tab vẫn nằm ngoài vùng cuộn, Explore được chọn khi route này đang mở. Card có phản hồi khi nhấn; banner xuất hiện nhẹ nếu người dùng không bật giảm chuyển động.

Ảnh kiểm tra web 360 × 780: [Explore sáng](reports/ui-explore-v2-light.png), [Explore tối](reports/ui-explore-v2-dark.png). Console của cả hai lần render không có lỗi, bao gồm `Unexpected text node`. Mobile TypeScript, lint, 37/37 test và export Android/iOS/web đều đạt. Chưa kiểm tra trên Android/iOS thật hoặc với cỡ chữ hệ thống tăng lớn; trên thiết bị hãy mở Explore, cuộn đến Real English, nhấn từng công cụ và kiểm tra tab được chọn cùng Console/LogBox.

## Kiểm tra và giới hạn

Chạy từ thư mục gốc:

```powershell
npm.cmd run typecheck --workspace @englify/mobile
npm.cmd run lint --workspace @englify/mobile
npm.cmd run test --workspace @englify/mobile
npm.cmd run typecheck --workspace @englify/shared
cd apps/mobile
npx.cmd expo install --check
npx.cmd expo export --platform all
npx.cmd expo start --clear
```

Kết quả kiểm tra ngày 07/11/2026: mobile typecheck và lint đạt; 37/37 bài test đạt (16 tệp); shared typecheck đạt; `expo install --check` không báo gói lệch phiên bản; export Android, iOS và web đạt. Kiểm tra Chrome headless trên viewport web 360 × 780 cho Home sáng/tối, Journey và Explore không ghi nhận lỗi console, bao gồm lỗi `Unexpected text node`. Chưa kiểm thử trên thiết bị Android/iOS thật, chưa xác nhận bằng tài khoản đăng nhập thật trong lần kiểm tra giao diện này.

Trên Android/iPhone có Expo Go phù hợp với SDK hiện tại: đăng nhập và thử Home → Journey → Lesson, Explore → Dictionary/Translation/Real English, Practice → Speaking/Writing/Quiz, Profile → Rewards; đổi theme và cỡ chữ hệ thống, mở bàn phím trên form, kiểm tra TalkBack/VoiceOver, xoay màn nếu thiết bị cho phép. Kiểm tra Console/LogBox sau mỗi thao tác, nhất là lỗi `Unexpected text node`. Build thành công và ảnh chụp web không chứng minh các bước thiết bị đạt.

Các skill `expo-overview`, `expo-ui` và `frontend-design` không có trong phiên này; đã dùng `expo-design-system`, `expo-native-ui`, `expo-animation`, `expo-router` và `gamified-ui`. Gói `@expo/ui` đã có trong dự án nhưng không đồng nghĩa skill `expo-ui` đã được nạp. Không dùng ảnh, icon hoặc âm thanh có bản quyền từ ứng dụng khác.
