---
name: speech-engineering
description: Triển khai TTS, ghi âm và luyện nói Expo khi thêm tính năng âm thanh hoặc phản hồi phát âm.
---

# speech-engineering

## Tiêu chí kích hoạt

Thêm phát âm văn bản, ghi âm, phát lại, nhận dạng hoặc đánh giá phát âm.

## Ràng buộc công nghệ

Ưu tiên Expo Speech và Expo Audio theo SDK đang dùng; kiểm tra API phiên bản. Không dùng dịch vụ chấm phát âm trả phí; nhận dạng cơ bản không tương đương đánh giá chuyên sâu.

## Hướng dẫn triển khai

Xin quyền microphone đúng lúc; xử lý từ chối, ngắt ứng dụng, lỗi thiết bị và dọn tài nguyên. Không lưu/tải giọng nói ngoài yêu cầu. Hoãn đánh giá chuyên sâu nếu thiếu giải pháp miễn phí đáng tin.

## Quy tắc kiểm thử

Kiểm tra phát/dừng, quyền bị từ chối, nền/tiền cảnh và Android/iOS phù hợp; ghi rõ phần chưa thử trên thiết bị.

## Definition of Done

Âm thanh hoạt động trên nền tảng được xác nhận, quyền và dữ liệu an toàn, UI diễn đạt đúng giới hạn.

