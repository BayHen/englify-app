# Chế độ khách trên mobile

Kh?ch c? b?n tab Home, Translate, Voca v? Profile. Profile kh?ch gi?i thi?u l?i ?ch t?i kho?n v? d?n ??n Sign in ho?c Create account. Th?nh vi?n c? n?m tab Home, Journey, Explore, Practice v? Profile. Journey, Explore, Practice, d? li?u ?? l?u, ?n t?, XP, ti?n ?? v? c?i ??t t?i kho?n y?u c?u ??ng nh?p. Deep link ???c b?o v? gi? ??ch quay l?i trong b? nh?. ??ng xu?t chuy?n v? Home kh?ch, x?a tr?ng th?i t?i kho?n hi?n t?i v? c?c truy v?n Home/Journey c?a phi?n. D? li?u ngo?i tuy?n theo t?i kho?n ???c gi? tr?n thi?t b? v? ch? ??c l?i b?ng ??ng ID t?i kho?n.

## Kiểm tra và phát hành

Nếu một từ tiếng Anh chưa có mục khớp chính xác trong danh mục, Voca tra thêm qua Free Dictionary API. Kết quả này hiển thị định nghĩa tiếng Anh theo dữ liệu nguồn. Luồng nhập từ vào danh mục và lưu từ vào tài khoản vẫn yêu cầu đăng nhập.

Daily Vocabulary chọn năm từ khác nhau, trong đó có tối đa ba từ mới từ Datamuse khi API trả mục có định nghĩa hợp lệ. Bộ từ song ngữ đi kèm lấp các vị trí còn lại và dùng khi mất mạng. Bộ từ lưu theo ngày địa phương và dùng chung cho khách và thành viên. Recent của khách chỉ nằm trong RAM, tối đa 20 mục. Recent của thành viên vẫn lưu theo ID tài khoản. Cache từ điển công khai lưu riêng dữ liệu từ và nghĩa, tối đa 500 mục, để dùng khi mất mạng.

Áp dụng migration `20261120170000_guest_dictionary_translation.sql` trước khi phát hành mobile và triển khai lại Edge Function `translate` theo cấu hình trong `supabase/config.toml`. Xác minh origin web được cho phép qua `TRANSLATE_ALLOWED_ORIGINS`. Quyền đọc Dictionary của khách chỉ gồm các cột cần cho tìm kiếm tiếng Anh và chỉ các mục đã xuất bản. Import từ ngoài danh mục vẫn cần đăng nhập.

Translate dùng hạn mức chung hiện có và một hạn mức khách toàn dự án 900 ký tự hoặc 40 lượt mỗi ngày UTC. Lời gọi giữ chỗ hạn mức khách chỉ chạy từ Edge Function. Khóa server nằm trong Supabase. Yêu cầu có bearer token tiếp tục được xác minh và tính hạn mức tài khoản.

Chạy `npm.cmd run typecheck -w @englify/mobile`, `npm.cmd run lint -w @englify/mobile` và `npm.cmd test -w @englify/mobile`. Sau khi áp dụng migration trên Supabase local, chạy `supabase/tests/guest_access_smoke.sql` bằng công cụ SQL cục bộ.

Trên bản phát hành thử, mở app trong phiên sạch và xác nhận đi thẳng vào Home. Tìm một từ đã xuất bản và dịch một câu Anh–Việt. Mở Journey từ tab và deep link, đăng nhập bằng tài khoản kiểm thử, rồi xác nhận app quay lại Journey. Đăng xuất từ Profile, nhấn Back, mở lại app và kiểm tra rằng màn tài khoản và dữ liệu người học không xuất hiện. Kiểm tra Console hoặc LogBox sau các thao tác và ghi số request Auth, Profile cùng số lần chuyển route nếu đo hiệu năng.
