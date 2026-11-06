# Công cụ dịch miễn phí

## Trạng thái hiện tại

API `POST /api/v1/translate` nhận `{ "source": "en", "target": "vi", "text": "Hello." }` (hoặc đổi chiều). API yêu cầu Supabase access token và trả về `data.status` là `translated` hoặc `unavailable`. `scope=exact_phrase` chỉ có nghĩa là khớp nguyên cụm trong bộ phrasebook tự biên soạn của dự án. Đây **không phải** dịch văn bản tự do. Cụm không khớp trả `unavailable`, không ghép từ hoặc bịa bản dịch.

`GET /api/v1/translation/phrases` trả các câu gợi ý. Màn hình mobile có chọn chiều dịch, nhập văn bản, kết quả, sao chép và lưu tối đa 100 cụm trên **thiết bị hiện tại** bằng Expo SQLite KV. Dữ liệu lưu này chưa đồng bộ tài khoản; xóa dữ liệu ứng dụng sẽ xóa các cụm đã lưu.

## LibreTranslate tự lưu trữ (tùy chọn)

[Danh sách model chính thức](https://github.com/LibreTranslate/Documentation/blob/main/src/content/docs/guides/supported_languages.md) liệt kê model `en→vi` và `vi→en` phiên bản 1.9. Có model không đảm bảo instance cụ thể đã cài hoặc chất lượng đạt yêu cầu. Provider kiểm tra `GET /languages` và `targets` trước mỗi lần gọi `POST /translate`; timeout 5 giây và lỗi upstream trả `unavailable`. Không gửi văn bản tới dịch vụ trả phí.

Chưa có instance LibreTranslate đang chạy để kiểm tra chất lượng đầu ra thực tế cho dự án này. Vì vậy **dịch toàn văn EN↔VI đang hoãn**, mặc định không kích hoạt. Khi có instance tự lưu trữ:

1. Cài cả hai model EN↔VI theo tài liệu LibreTranslate. Không chạy script cài đặt không rõ nguồn gốc.
2. Gọi `/languages` của chính instance và xác nhận `en.targets` có `vi`, `vi.targets` có `en`.
3. Dịch và người biết hai ngôn ngữ đánh giá tối thiểu: “I am learning English.”, “Where is the train station?”, “The bank is closed today.”, “Tôi đang học tiếng Anh.”, “Tôi cần đặt vé tàu.”; kiểm tra nghĩa, dấu tiếng Việt và trường hợp đa nghĩa. Ghi nhận kết quả thực tế trước khi bật.
4. Đặt `ENGLIFY_LIBRETRANSLATE_URL=http://localhost:5000` (hoặc HTTPS origin) và chỉ liệt kê chiều đã kiểm chứng trong `ENGLIFY_LIBRETRANSLATE_VERIFIED_PAIRS=en:vi,vi:en`. Khởi động lại API. Không đặt URL này trong cấu hình mobile: văn bản đi qua backend.

Ứng dụng vẫn gắn nhãn kết quả máy dịch để người dùng tự kiểm tra. Model có thể dịch sai ngữ cảnh, thành ngữ hoặc thuật ngữ chuyên ngành. Cụm phrasebook do nhóm dự án tự soạn; không dùng dữ liệu từ từ điển thương mại.
