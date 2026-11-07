# Kế hoạch học theo quy tắc

Kế hoạch học dùng quy tắc Python xác định (`algorithm_version = 1`), không gọi AI hoặc dịch vụ trả phí. Endpoint `GET /api/v1/learning-plan` tạo kế hoạch 7 ngày từ lựa chọn onboarding nếu chưa có kế hoạch đang hoạt động. Ngày được tính theo UTC.

## Đầu vào và quy tắc

- `learning_goal`, `initial_proficiency`, `daily_goal_minutes` và `preferred_topics` lấy từ `user_preferences`. Chủ tài khoản có thể sửa qua `PUT /api/v1/learning-plan/preferences`; thao tác này tạo kế hoạch mới.
- Bài học được lấy theo thứ tự khóa học/đơn vị; bài đã `completed` hoặc `mastered` bị loại khỏi lịch mới. Bài học vẫn phải qua quy tắc mở khóa và quiz của backend.
- Tỷ lệ đúng của tối đa 10 lượt quiz gần nhất dưới 60% làm tăng ôn tập và giảm nhịp bài mới. Từ đã lưu đến hạn tạo phiên ôn tập. Chủ đề được luân phiên theo ngày; nội dung bài học hiện chưa có phân loại chủ đề nên chủ đề chỉ gợi ý cho phần luyện tập.
- Thời lượng tác vụ mỗi ngày không vượt mục tiêu đã chọn. Kế hoạch ngắn 1–4 phút có một mục từ vựng nhỏ. Kế hoạch có ôn tập, từ vựng, bài học nếu còn bài, luyện nói hoặc viết tùy mục tiêu và dung lượng ngày.

## Lưu trữ và bảo vệ dữ liệu

Migration `20261107_08` thêm `preferred_topics`, phiên bản thuật toán, ngày bắt đầu và `learning_plan_tasks`. Khi tạo lại kế hoạch, bản cũ chuyển sang `paused`; tác vụ cũ và lịch sử quiz, tiến độ bài, từ đã lưu vẫn còn. Tác vụ bài học hiển thị hoàn thành dựa trên `learning_progress`, không nhận tự báo hoàn thành từ thiết bị. Các tác vụ luyện tập được người dùng tự đánh dấu và không tạo XP. Tạo lại kế hoạch không sao chép dấu hoàn thành tự báo của tác vụ cũ.

`POST /api/v1/learning-plan/reschedule` chuyển tác vụ chưa hoàn thành ở ngày đã qua sang ngày kế tiếp còn chỗ, giữ nguyên ID và `original_date`. Tác vụ có thể chuyển ra ngoài 7 ngày đầu nếu lịch đầy. Thao tác lặp lại không tiếp tục dời tác vụ đã chuyển. Mỗi thao tác ghi dùng transaction và khóa theo người dùng. RLS chỉ cho chủ tài khoản đọc tác vụ; ứng dụng khách không có quyền ghi trực tiếp.

## API và giao diện

| Phương thức | Đường dẫn | Tác dụng |
| --- | --- | --- |
| GET | `/api/v1/learning-plan` | Lấy hoặc tạo kế hoạch đầu tiên |
| PUT | `/api/v1/learning-plan/preferences` | Đổi mục tiêu, cấp độ, thời lượng, chủ đề và tạo lại |
| POST | `/api/v1/learning-plan/regenerate` | Tạo lại từ tiến độ hiện tại |
| POST | `/api/v1/learning-plan/reschedule` | Dời mục quá hạn |
| POST | `/api/v1/learning-plan/tasks/{id}/complete` | Tự đánh dấu mục luyện tập, lặp lại an toàn |

Màn hình `/learning-plan` truy cập từ Home, hiển thị tổng quan tuần, lịch theo ngày và trạng thái tác vụ. Nút bài học đi vào tuyến bài học thực; backend tiếp tục kiểm tra khóa bài. Các màn hình nói/viết hiện là bài tập mẫu, nên việc tự đánh dấu chỉ là ghi nhận đã luyện, không phải chấm điểm hay xác nhận năng lực.

## Chạy và kiểm tra

Sau khi cấu hình `ENGLIFY_DATABASE_URL` ở `.env` gốc, chạy `cd backend; ..\.venv\Scripts\python.exe -m alembic upgrade head` và khởi động FastAPI theo README. Mobile cần `EXPO_PUBLIC_API_URL` trỏ tới FastAPI. Trên Windows: `npm.cmd run start --workspace apps/mobile -- --clear`.

Kiểm tra quy tắc: ` .\.venv\Scripts\python.exe -m pytest backend/tests/test_learning_plan.py -q`. Kiểm tra trên PostgreSQL nên dùng database thử nghiệm tách biệt và tài khoản Auth thử nghiệm; không dùng dữ liệu người học thật. Chưa có đồng bộ lịch tự động vào lúc đổi ngày hoặc thông báo nhắc học; dùng nút dời mục quá hạn.
