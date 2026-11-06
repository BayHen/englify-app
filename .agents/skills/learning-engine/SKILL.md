---
name: learning-engine
description: Xây quy tắc kế hoạch học, flashcard, spaced repetition, quiz và tiến độ khi thay đổi logic học tập.
---

# learning-engine

## Tiêu chí kích hoạt

Sửa thuật toán lập kế hoạch, lịch ôn, chấm quiz hoặc ghi tiến độ.

## Ràng buộc công nghệ

Ưu tiên thuật toán xác định được, không cần AI trả phí; PostgreSQL là nguồn dữ liệu gốc, ngoại tuyến cần quy tắc đồng bộ.

## Hướng dẫn triển khai

Tách quy tắc thuần khỏi UI/lưu trữ. Định nghĩa UTC, bài chưa học, câu trả lời lặp. Ghi version thuật toán khi đổi lịch hiện có; không cấp XP hai lần cho attempt.

## Quy tắc kiểm thử

Test mốc thời gian, timezone, đúng/sai, request lặp và đồng bộ ngoại tuyến với dữ liệu cố định.

## Definition of Done

Quy tắc giải thích được, kết quả tái lập, tiến độ nhất quán và test biên đạt.

