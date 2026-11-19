# Audit Quiz Arena V2.2 — trước triển khai

- V2.1 có trong workspace: Practice độc lập, bank A1–C1, 6 adapter câu hỏi, RPC start/get/submit/end/history, snapshot và RLS. Các thay đổi V2.1 còn chưa commit trong workspace; không suy ra đã deploy production.
- Journey vẫn dùng lesson/attempt riêng. Admin hiện quản trị câu hỏi Journey; bank Arena có bảng/key/publish guard riêng. Không có Time Attack hoặc leaderboard trong Edge Functions.
- Expo SDK 58, React Native 0.88; dùng lại component/palette/tokens, không thêm dependency.
- V2.1 có 22 test mobile mới, SQL smoke, HTTP concurrency và migration preservation. Cần bổ sung timing, combo, lives, sequence, restore và personal records.
- Thiết kế V2.2: dùng lại `arena_sessions` và snapshot, thêm mode discriminator và bảng state/answer/rules timed. RPC Practice chỉ nhận mode practice. Dùng chung helper grading, không đổi cách chấm Journey.
- Easy 10 câu/180 giây/5 lives; Normal 10/120/3; Hard 15/120/2. Snapshot cấu hình trên server; base 100, combo 1/1.2/1.5/2 và speed +50/+30/+10/+0 theo mốc 3/6/10 giây.
- Server chỉ cấp một câu tại một thời điểm, ghi thời điểm cấp đầu tiên, không reset khi reload. Thời gian phản hồi là thời gian server quan sát, gồm mạng và chờ xử lý; không tuyên bố đo phản xạ chính xác hoặc anti-cheat hoàn hảo.
- Điểm Time Attack không cấp XP. Practice và Journey giữ nguyên chính sách XP.
