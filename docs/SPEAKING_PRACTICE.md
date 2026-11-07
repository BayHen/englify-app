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
