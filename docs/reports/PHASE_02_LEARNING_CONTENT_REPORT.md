# Báo cáo Phase 2 — Learning Experience & Content System

Ngày: 15/11/2026  
Nhánh: `feature/real-english-hybrid-v2`  
Trạng thái: **PASS trên môi trường local; BLOCKED triển khai production** vì lịch sử migration Phase 1 chưa được đối soát. Không deploy production.

## 1. Tính năng đã triển khai

### Task 05 — Real English

- RPC tìm kiếm server-side cho English/Vietnamese, bỏ dấu tiếng Việt, CEFR, topic, category và saved-only.
- Phân trang server-side 5 mục; không tải toàn bộ lesson/nested content vào memory.
- Detail phrase/dialogue/source chỉ tải khi mở modal.
- Sáu trạng thái: Not started (không có row), Reading, Read, Practiced, Passed, Mastered.
- Bookmark, ẩn/hiện bản dịch, TTS từng phrase/câu thoại, lưu vocabulary đã liên kết, comprehension server-authoritative.
- Chỉ `status='published'` và expression published/non-archived xuất hiện trong RPC.

### Task 06 — A1–A2 foundation

- Metadata từ điển A1–C2, topic, example translation, usage notes, quality status và source URL.
- Staging tables admin-only và pipeline CSV/JSON transactional/idempotent.
- Workflow không tự publish; nội dung AI vẫn phải review thủ công.
- Admin có mục **Import review** để kiểm tra nguồn, giấy phép, lỗi validation và payload trước quy trình xuất bản.
- Seed project-original: **16 vocabulary mới** và chuẩn hóa metadata cho **10 vocabulary hiện có**; tổng cộng **26 vocabulary DEV có metadata A1/A2**.
- Sáu Real English expression DEV hiện có được gắn CEFR/topic; không tạo attribution ngoài nguồn thật.
- Mục tiêu 1.500 vocabulary, 120 Journey lessons, 150 Real English lessons và 300 quiz là mục tiêu theo giai đoạn, chưa được tuyên bố hoàn thành.

### Task 07 — Smart Vocabulary Review

- Due deck theo user, hai chiều EN→VI và VI→EN, reveal answer, Again/Hard/Good/Easy.
- Lịch SM-2-inspired xác định, algorithm version 1; lưu stability, difficulty, lapse/review count và review history.
- UUID request chống ghi lặp và không cấp XP trực tiếp cho thao tác reveal/rating.
- Client chỉ được thêm từ và sửa note; các cột lịch ôn chỉ thay đổi qua RPC server-authoritative.
- Dictionary, Real English, Home và Learning Plan đã có điểm vào/loại task phù hợp.
- Rating offline được giữ trong SQLite/web outbox và đồng bộ bằng cùng request ID.

## 2. Thay đổi dữ liệu

- Migration: `supabase/migrations/20261115020000_phase2_learning_content.sql`.
- Seed: `supabase/seeds/phase2_a1_a2_content.sql`.
- Bảng mới: comprehension questions/keys/attempts, content import batches/items.
- Cột mới chỉ mang tính cộng thêm; chuyển trạng thái tiến độ giữ nguyên ý nghĩa và timestamp hoàn thành.
- Answer keys, import staging và mutation scheduling không cấp quyền công khai.

## 3. Kiểm thử thực tế

| Kiểm tra | Kết quả |
| --- | --- |
| Mobile TypeScript | PASS |
| Mobile ESLint | PASS |
| Mobile Vitest | PASS — 40 files, 135 tests |
| Python Ruff cho import pipeline | PASS |
| Backend + import pytest | PASS — 43 passed, 8 skipped |
| `git diff --check` | PASS; chỉ cảnh báo LF/CRLF Windows |
| Supabase `db reset` Phase 2 | PASS — áp toàn bộ migration và seed từ database rỗng |
| Supabase `db lint --level error` | PASS — không có schema error |
| Phase 2 SQL smoke/RLS/SRS | PASS |
| Security-definer và Admin atomic smoke | PASS |
| Local Auth/RLS/API integration | PASS |
| Admin mutation concurrency | PASS — retry idempotent |
| Admin ESLint + build | PASS |
| Admin tests | PASS — 6 tests |
| Expo Web export | PASS — các route Phase 2 bundle thành công |
| Android/iOS Expo Go | NOT TESTED |
| React Native Web runtime/Console | NOT TESTED |

SQL smoke test đã thực thi trên PostgreSQL local và xác nhận search bỏ dấu, filter, phân trang 5 mục, reading→passed, comprehension idempotency, SRS idempotency, chặn client sửa lịch ôn và learner bị chặn khỏi import staging.

## 4. Skills đã dùng

- `learning-engine`, `database-design`, `api-integration`, `gamified-ui`.
- `mobile-architecture`, `expo-design-system`, `expo-native-ui`, `expo-router`.
- `test-engineering`.

## 5. Giới hạn và bước tiếp theo

- Chưa apply migration lên staging/production vì Phase 1 migration history chưa reconcile.
- Phrase chỉ hiện nút Save vocabulary khi admin đã liên kết `dictionary_entry_id`; không tự tạo nghĩa/từ chưa review.
- Comprehension cần biên tập câu hỏi cho từng lesson trước publish; migration không sinh filler tự động.
- Expo Web đã export thành công nhưng runtime Console và layout native vẫn NOT TESTED; phải kiểm tra không có `Unexpected text node` trước khi phát hành.
- Tiếp tục import nội dung theo batch nhỏ đã review; không tạo hàng loạt để chạy theo số lượng mục tiêu.

Không tự động bắt đầu Phase 3.
