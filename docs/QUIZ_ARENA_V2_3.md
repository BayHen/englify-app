# Quiz Arena V2.3 — Ranked Arena, leaderboard và season

## Phạm vi hoàn thành

Audit trước triển khai nằm tại [báo cáo audit](reports/QUIZ_ARENA_V2_3_AUDIT.md). V2.3 thêm thi đấu bất đồng bộ; không có matchmaking hoặc PvP trực tiếp.

- Quiz Arena có Practice, Time Attack và Ranked Arena.
- Ranked v1 dùng 10 câu B1 đã publish, 120 giây, 3 lives, base 100 và công thức combo/speed V2.2. Ruleset version được ghim vào match và season.
- Server cấp từng câu, chấm điểm, quản lý deadline/lives/combo, finalize và cập nhật rating trong transaction. Client không gửi score/rating/time.
- Arena Rating tách khỏi XP, level học, Time Attack và Writing. V2.3 không cấp XP.
- Tier Bronze/Silver/Gold/Platinum/Diamond, peak rating, next threshold và rating history.
- Weekly/season leaderboard dùng ba kết quả tốt nhất, có vị trí hiện tại, phân trang và projection bảo vệ riêng tư.
- Season lifecycle: scheduled → active → closing → finalized; chỉ một active season; standings finalized bất biến.
- Reward season cấu hình theo badge/tier/top 10, cấp qua ledger unique và user_badges; không cấp XP.
- Mobile có overview, countdown, gameplay/retry/restore, result, review, leaderboard và history.
- Admin có schedule/transition season, tạo ruleset version mới, bật/tắt reward trước finalization và xem security queue.

## Migration và schema

Áp sau V2.1 20261118020000 và V2.2 20261118030000:

- 20261118040000_quiz_arena_ranked.sql: mode ranked, ruleset, season, rating, match/answer, rating event, standings, reward ledger, security event và RPC cốt lõi.
- 20261118040100_quiz_arena_ranked_admin_config.sql: reward rules theo season, cấu hình ruleset/reward có audit.
- 20261118040200_quiz_arena_ranked_security_limits.sql: tối đa 20 match bắt đầu/user/giờ và heuristic review.

Bảng mới gồm arena_ranked_rulesets, arena_seasons, arena_player_ratings, arena_ranked_matches, arena_ranked_answers, arena_rating_events, arena_season_standings, arena_season_reward_rules, arena_season_rewards và arena_ranked_security_events.

RLS chỉ cho owner đọc rating/match/event/reward của chính mình. Answer events, standings thô, reward config và security events không được learner đọc trực tiếp. Leaderboard đi qua RPC projection tối thiểu.

## RPC

Learner:

| RPC | Vai trò |
| --- | --- |
| englify_ranked_start | Chọn active season/ruleset/bank, chống start trùng |
| englify_ranked_session | Restore/lazy-expire và cấp câu hiện tại |
| englify_ranked_answer | Chấm một đáp án, replay-safe |
| englify_ranked_finalize | Expire hoặc abandon có chính sách rating rõ |
| englify_ranked_me | Current/peak rating, tier, season, recent changes |
| englify_ranked_history | Lịch sử owner, 10 mục/trang |
| englify_ranked_leaderboard | Weekly/season projection, 50 mục/trang |

Admin: englify_admin_upsert_arena_season, englify_admin_transition_arena_season, englify_admin_upsert_ranked_ruleset, englify_admin_set_season_reward và englify_admin_arena_overview. Helper tier/rating/close/view và trigger không cấp quyền client.

## Rating và tier

Initial rating mặc định là 1000.

    accuracy_component = accuracy_percent × 0.70
    score_component = min(score / reference_score, 1) × 100 × 0.30
    raw_delta = round((accuracy_component + score_component - 60) / 2)
    rating_change = clamp(raw_delta, -max_change, +max_change)
    rating_after = max(0, rating_before + rating_change)

Rules v1 dùng reference score 2040 và max change 30. Perfect match được +20; 0%/0 điểm bị giới hạn -30. Abandon có mức -15; match invalid không đổi rating. Đây là mô hình hiệu suất xác định, không phải Elo đối đầu.

| Tier | Rating |
| --- | ---: |
| Bronze | 0–999 |
| Silver | 1000–1199 |
| Gold | 1200–1399 |
| Platinum | 1400–1599 |
| Diamond | 1600+ |

Advisory lock theo user, row lock rating, unique rating event theo match và one-active-match index bảo vệ finalize/retry/concurrency.

## Leaderboard

- Tuần UTC bắt đầu Thứ Hai 00:00 UTC.
- Weekly score là tổng tối đa ba match completed/expired đã rate trong tuần.
- Season score là tổng tối đa ba match completed/expired đã rate trong season.
- Chọn match theo score, correct, completed sớm, rồi ID ổn định.
- Xếp hạng theo tổng score; tỷ lệ tổng correct/tổng question; thời điểm đạt bộ ba sớm hơn; cuối cùng user UUID nội bộ.
- UUID chỉ dùng tie-break và không trả ra. Response chỉ có display name fallback, tier/rating, verified stats, position và is_me. Không có email, phone, auth metadata, answer hay private avatar path.

## Season và reward

- Match mới chỉ bắt đầu trong active season và khoảng thời gian server.
- Match đang chạy được hoàn tất khi season active/closing. Finalization đóng match còn active trước khi chụp standings.
- Finalization cấp reward theo config đang bật, ghi arena_season_rewards unique rồi upsert user_badges.
- Gọi finalization lại không cấp lại. Finalized season, standings và reward config không sửa được.
- Match/rating history không bị xóa khi sang season mới. V2.3 không reset rating và không cấp XP.

## Bảo mật

- Mỗi RPC kiểm tra Auth/owner; sai owner trả 404.
- Không lộ key/câu tương lai; review chỉ có câu đã nộp sau terminal state.
- UUID request và unique constraints ngăn replay; server clock ngăn device-clock forgery.
- Learner không ghi trực tiếp ruleset/season/score/rating/reward.
- Start giới hạn 20 match/user/giờ; một match active; answer body có giới hạn.
- Gắn cờ review cho ít nhất ba answer dưới 500 ms, ba abandon/24 giờ hoặc năm mức tăng lớn liên tiếp. Không tự ban.
- Server-observed elapsed gồm latency/network/DB queue. Bank đã biết và trợ giúp ngoài vẫn là giới hạn; không tuyên bố chống gian lận hoàn hảo.

## File chính và kiểm tra

- Database: ba migration 20261118040000–20261118040200.
- SQL/upgrade: supabase/tests/quiz_arena_ranked_smoke.sql, scripts/supabase_arena_upgrade_check.py và CI.
- Mobile: ranked-api, use-ranked-session, ranked-home, ranked-screen và route ranked-arena/[id].
- Admin: arena-season-management, supabase-admin và page.
- PASS mobile typecheck/lint; 234 tests/55 files.
- PASS Admin lint/build.
- PASS Ranked SQL smoke và upgrade database tạm, gồm bảo toàn Journey/Practice/Time Attack/XP.

Browser Chromium qua Auth/PostgREST local đã hoàn tất một match đủ 10 câu, reload giữa game, review, weekly/season leaderboard, light 390px và dark 320px. Không có page error, lỗi React hoặc lỗi React Native Web “Unexpected text node”; viewport 320px không tràn ngang. Tài khoản test dùng một lần đã được xóa. Bundle không được xem là bằng chứng thay cho kiểm tra runtime này.

## Giới hạn và triển khai

Không có real-time PvP, opponent Elo, matchmaking, push/cron tự động hoặc dịch vụ trả phí. Transition season do admin thực hiện. Không public avatar vì avatar_url hiện là storage path riêng tư và chưa có consent/public projection.

NOT TESTED: Android/iOS thật, screen reader thật, OS kill, large-font và tải lớn.

Trước staging cần backup, đối chiếu migration history, áp V2.1 → V2.2 → ba migration V2.3, nạp Question Bank đã publish, chạy SQL/upgrade/integration, kiểm tra rules/reward rồi mới activate season. Không nạp seed development vào production.

Task này không deploy production migration, merge branch hay publish release.
