# Rà Writing: autosave và xóa draft — 18/11/2026

## Phạm vi

Đọc route `/writing`, API submission, Daily Writing, hook draft, hai adapter lưu trữ, các SQL RPC liên quan và tài liệu Writing V2.3/V2.5. Tập trung sửa các lỗi đã tái hiện trong thứ tự autosave và xóa draft. Đây không phải xác nhận đã kiểm thử toàn bộ Writing trên thiết bị.

## Lỗi và bản sửa

1. Discard draft đang viết đặt context về null. Người học tiếp tục gõ nhưng change không lưu gì. Giữ context đang mở và revision tăng liên tục để nội dung mới vẫn được autosave.
2. Discard có thể xóa trước khi một save đang chạy kết thúc; save đó ghi lại draft vừa xóa. Đưa save và delete vào cùng một hàng đợi theo thứ tự gọi.
3. Xóa draft sau submit chưa xử lý pending autosave; timer có thể ghi lại draft đã nộp. Flush trước khi xóa, vẫn giữ điều kiện revision để không xóa nội dung mới hơn bản đã gửi.
4. Chỉ xóa pending khi chính đối tượng pending đó được lưu xong, thay vì chỉ so sánh số revision có thể trùng giữa các context.

## File thay đổi

- `apps/mobile/src/features/writing/use-writing-drafts.ts`
- `apps/mobile/src/features/writing/use-writing-drafts.test.ts`
- Báo cáo này.

## Kiểm tra thực tế

- Ba test hồi quy đầu tiên FAIL trước bản sửa, PASS sau bản sửa.
- Thêm test giữ nội dung gõ mới sau submit: PASS.
- PASS: mobile typecheck và lint.
- PASS: 188 tests trong 48 files.
- PASS: bốn SQL smoke test Writing V2.1/V2.2/V2.3/V2.4 trên Supabase local sau khi khởi động Docker.
- PASS: git diff --check.
- Rà conditional JSX của Writing library, daily panel và AI panel: không thấy render chuỗi/số bằng `&&` trực tiếp dưới View. Bản sửa không đổi JSX.
- Unit tests mới kiểm tra lệnh async của hook với React hooks/storage được mock; không kiểm tra render, effect lifecycle hay SQLite thật.
- NOT TESTED: browser Console/LogBox, công cụ browser lỗi khởi tạo `trusted Node process exited unexpectedly`.
- NOT TESTED: thiết bị Android/iOS, background/foreground thật và production.

## Chạy lại

```powershell
npm.cmd run typecheck -w apps/mobile
npm.cmd run lint -w apps/mobile
npm.cmd test -w apps/mobile
```

Kiểm tra runtime bắt buộc còn lại:

1. Chạy `npm.cmd run web -w apps/mobile`, mở `/writing`, đăng nhập tài khoản test và mở DevTools Console.
2. Mở bài, gõ nội dung, discard, rồi gõ nội dung khác. Chờ hơn 750 ms, tải lại trang và mở lại bài: nội dung mới phải được phục hồi.
3. Gõ rồi discard ngay khi autosave đang chạy: tải lại không được xuất hiện draft đã xóa.
4. Submit rồi gõ thêm khi request đang chạy: phần gõ thêm phải còn sau reload. Nếu không gõ thêm, draft đã nộp không được xuất hiện lại.
5. Lặp lại với Daily Challenge; kiểm tra feedback, XP/streak và không thưởng trùng khi retry.
6. Sau render và các thao tác trên, Console/LogBox không được có `Unexpected text node: A text node cannot be a child of a <View>`.
