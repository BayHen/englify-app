# Luyện nói miễn phí — TASK 07.1

Màn hình `/speaking` dùng `expo-speech` cho giọng mẫu và `expo-audio` để ghi/phát lại giọng của người học. Danh sách giọng tiếng Anh được lấy từ thiết bị lúc chạy; nếu không có giọng phù hợp, ứng dụng thử giọng mặc định. Người học chọn một câu mẫu, nghe, ghi âm, phát lại và so sánh bằng mắt với văn bản. Ứng dụng **không nhận dạng lời nói, không tính điểm phát âm và không khẳng định độ chính xác**.

## Quyền và dữ liệu

- Quyền microphone chỉ được hỏi khi bấm **Start recording**. Nếu từ chối, vẫn nghe được giọng mẫu; có nút mở phần cài đặt quyền của ứng dụng.
- Ghi âm không chạy nền. Khi ứng dụng rời tiền cảnh, bản ghi đang thực hiện bị dừng và loại bỏ. Cấu hình `expo-audio` không bật background recording.
- Trên Android/iOS, bản ghi mới được tạo trong thư mục document riêng của ứng dụng. Mỗi câu chỉ giữ bản ghi mới nhất; ghi lại sẽ xóa bản cũ sau khi bản mới lưu thành công. Nút **Delete this recording** xóa tệp cục bộ. Không có yêu cầu mạng hoặc tải âm thanh lên server.
- Số buổi tự đánh dấu hoàn thành và vị trí bản ghi mới nhất lưu bằng `expo-sqlite/kv-store`, phân tách theo ID tài khoản. Cùng một bản ghi không được tính hai lần. Xóa âm thanh không xóa số buổi đã hoàn thành.
- Trên web, `MediaRecorder` tạo blob tạm chỉ phát lại trong phiên trình duyệt; blob không được lưu bền vững qua lần tải lại. Số buổi tự hoàn thành lưu trong `localStorage` của trình duyệt. Trình duyệt cần môi trường an toàn (`localhost` hoặc HTTPS) để xin quyền micro.

## Phụ thuộc và cấu hình

Expo SDK 58 dùng `expo-speech`, `expo-audio`, `expo-file-system` và `expo-sqlite`; hai gói audio/file được chọn bằng `npx expo install`. `apps/mobile/app.json` khai báo thông điệp xin quyền iOS và không bật ghi âm nền. `SpeechProvider` trong `src/features/speaking/speech-provider.ts` tách thao tác âm thanh khỏi UI, để có thể thay nhà cung cấp sau này. Hiện chỉ có triển khai cục bộ bằng Expo.

## Chạy và xác minh

Từ thư mục gốc trên Windows:

```powershell
npm.cmd run typecheck --workspace apps/mobile
npm.cmd run lint --workspace apps/mobile
npm.cmd run test --workspace apps/mobile
npm.cmd start -- --clear
```

Kiểm tra trên thiết bị Android/iOS có Expo Go hỗ trợ SDK 58: đăng nhập, mở Speaking, chọn giọng, nghe câu mẫu; từ chối quyền micro và xác nhận thông báo; cấp quyền trong cài đặt, ghi tối thiểu một giây, dừng, phát lại, ghi lần nữa, xóa tệp, khởi động lại ứng dụng và kiểm tra số buổi đã lưu. Thử đưa ứng dụng ra nền khi đang ghi để xác nhận bản ghi dở không được giữ. Kiểm tra web tương tự trên Chrome/Edge `localhost` hoặc HTTPS; lưu ý blob web mất khi tải lại. Build Metro/TypeScript không thay thế kiểm tra microphone và loa thật.

API tham chiếu: [Expo Audio SDK 58](https://docs.expo.dev/versions/v58.0.0/sdk/audio/), [Expo Speech SDK 58](https://docs.expo.dev/versions/v58.0.0/sdk/speech/), [Expo FileSystem SDK 58](https://docs.expo.dev/versions/v58.0.0/sdk/filesystem/).

## Bộ chọn giọng V2

Màn Speaking chỉ hiển thị một hàng **Reference voice** với tên, locale và nút mở. Sheet có ô tìm theo tên/ngôn ngữ/locale, các bộ lọc vùng thực sự hiện diện trên thiết bị, danh sách `FlatList` và dấu chọn giọng đang dùng. Chạm một hàng mới thay đổi giọng; cuộn không chọn. ID giọng được lưu theo tài khoản và nền tảng trong `expo-sqlite/kv-store` (web dùng `localStorage`). Khi mở lại, ứng dụng chỉ dùng ID còn có trong danh sách thiết bị; nếu ID biến mất, ưu tiên giọng tiếng Anh US có sẵn, sau đó là giọng tiếng Anh đầu tiên. Nếu thiết bị không liệt kê giọng tiếng Anh, nút phát thử TTS mặc định của thiết bị và sheet cho phép tải lại danh sách. Không suy luận giới tính từ tên giọng.

Thay đổi nằm trong `src/features/speaking/{speaking-screen,speech-provider,voice-catalog,voice-picker,voice-preference}*` và `src/ui/app-bottom-sheet.tsx`. Sheet dùng safe area, đóng bằng nền/Back, tránh bàn phím trên iOS, và tắt chuyển động khi hệ thống yêu cầu giảm chuyển động. Bottom tab của màn Speaking vẫn thuộc Practice.

Bản xem trước chỉ dành cho development: `/dev/ui-v2-preview?screen=voice` dùng **sample voices có nhãn**, không phát âm hoặc thay thế giọng thiết bị. Ảnh Chrome web 360 × 780: [hàng đóng](reports/voice-selector-collapsed.png), [sheet sáng](reports/voice-selector-sheet-light.png), [sheet tối](reports/voice-selector-sheet-dark.png), [sau khi chọn giọng UK](reports/voice-selector-selected.png). Console sau render/mở sheet/chọn giọng không ghi nhận lỗi, gồm `Unexpected text node`.

Skill đã áp dụng: `speech-engineering`, `mobile-architecture`, `expo-native-ui`, `expo-design-system`, `expo-router`, `test-engineering`. `expo-animation` được tham khảo cho reduced motion; không thêm animation mới. Không có skill tên `frontend-design` trong phiên này; không cài thêm skill hoặc thư viện UI. Các kiểm tra mã và test được ghi trong phần bàn giao task; phát âm, khởi động lại và lưu giọng trên Android/iOS thật **chưa kiểm thử**. Để xác nhận: trên Expo Go SDK 58, mở Speaking, chọn giọng, phát câu mẫu; khởi động lại ứng dụng để kiểm tra ID được khôi phục; đổi sang giọng khác, thử tìm kiếm/lọc, thu hồi giọng đã chọn trong cài đặt TTS của thiết bị nếu có thể, rồi mở lại và xác nhận fallback. Kiểm tra VoiceOver/TalkBack, cỡ chữ lớn, bàn phím trong sheet và LogBox.

Kết quả tự động: mobile TypeScript và ESLint đạt; 43/43 test trong 18 tệp đạt; `expo install --check` đạt; export Android/iOS/web đạt. Đây là kiểm tra build, logic lọc/lưu web và bản xem trước; **không** xác nhận TTS hay lưu lựa chọn trên thiết bị thật.
