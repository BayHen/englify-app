# Giao diện Admin — Content Studio

Ngày 12/11/2026, toàn bộ Admin dùng cùng ngôn ngữ thị giác với **AI lesson review**: nền tím đậm, lớp nội dung nổi, viền mảnh, nhấn lavender và màu trạng thái rõ ràng. Thay đổi áp dụng cho đăng nhập, menu, Dashboard, Vocabulary, Courses, Units, Lesson Builder, Lesson Items, Quiz Builder, Quiz Options, Real English, Badge Rules, Learning Analytics, Publishing và Audit Log. AI lesson review giữ các thẻ chuyên biệt của riêng luồng duyệt.

`apps/admin/src/app/admin-studio.css` ghi đè các kiểu chung từ `globals.css`; `layout.tsx` nạp kiểu chung sau cùng. `page.tsx` bổ sung mô tả ngắn và header Content Studio cho từng module. Không đổi endpoint, thao tác CRUD, phân quyền, trạng thái xuất bản hoặc dữ liệu. Các ô thống kê tiếp tục hiển thị số thực từ API; không dùng số liệu trong ảnh tham khảo.

## Kiểm tra

```powershell
npm.cmd run lint -w apps/admin
npm.cmd run build -w apps/admin
npm.cmd run dev -w apps/admin
```

Mở `http://localhost:3000`, đăng nhập bằng tài khoản đã có quyền Admin và đi qua từng mục ở menu. Ở module nội dung, thử tìm kiếm, phân trang, mở một mục để sửa, tạo bản nháp thử trong môi trường phát triển và kiểm tra trạng thái nút. Ở AI lesson review, mở hàng chờ và mục cấu hình. Kiểm tra thêm bề rộng cửa sổ khoảng 500 px và 1440 px, thứ tự focus bằng phím Tab, độ tương phản thông báo và Console.

Trong lượt sửa giao diện này, ESLint và Next.js build đã đạt; ảnh chụp local xác nhận màn hình đăng nhập ở cửa sổ 500 px và 1440 px. Giao diện **sau đăng nhập** chưa được kiểm chứng bằng trình duyệt tự động do không có phiên Admin trong trình duyệt kiểm tra. Không có thay đổi database hoặc mobile.
