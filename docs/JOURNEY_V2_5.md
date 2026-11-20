# Journey V2.5 – Gamification thống nhất

V2.5 tiếp tục dùng `xp_events`, `user_levels`, `quests`, `quest_claims`, badges và rewards hiện hữu; không tạo ví XP thứ hai. Khi một Journey lesson chuyển sang completed/mastered lần đầu, trigger trong cùng transaction ghi một ngày hoạt động UTC, kiểm tra Unit/Chapter milestone theo required content và curriculum version, rồi phát XP qua ledger có source identity duy nhất.

Unit milestone thưởng 20 XP; Chapter milestone thưởng 50 XP. Reward đã phát không bị thu hồi khi curriculum sau này thay đổi và không được cấp lại khi replay. Global Learning Streak là số ngày UTC liên tiếp có Journey completion được server xác nhận; Writing streak vẫn là metric riêng. Nhiều hoạt động cùng ngày chỉ tạo một streak day nhưng vẫn tăng activity count.

RPC `englify_journey_gamification` mở rộng overview cũ bằng learning streak và milestone gần đây. Daily/weekly quest vẫn dùng claim tự động hiện hữu và progress từ `learning_progress`; client không được ghi progress, XP, streak hay milestone. RLS chỉ cho chủ sở hữu đọc dữ liệu cá nhân.
